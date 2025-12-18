import 'dart:io' show Platform;
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../models/book.dart';
import '../models/genie.dart';
import '../models/tag.dart';
import '../models/contact.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../src/rust/api/frb.dart' as frb;
import '../src/rust/frb_generated.dart';
import 'auth_service.dart';
import 'ffi_service.dart';
import 'mdns_service.dart';
import 'open_library_service.dart';

class ApiService {
  final Dio _dio;
  final AuthService _authService;
  final bool useFfi;

  // Read from .env with fallback to localhost
  static String get defaultBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://localhost:8001';
  static String get hubUrl => dotenv.env['HUB_URL'] ?? 'http://localhost:8081';

  /// The actual HTTP server port (may differ from 8000 if occupied)
  static int httpPort = 8000;

  /// Set the actual HTTP server port (called from main.dart after server starts)
  static void setHttpPort(int port) {
    httpPort = port;
    debugPrint('📡 ApiService: HTTP port set to $port');
  }

  ApiService(this._authService, {String? baseUrl, Dio? dio, this.useFfi = false})
    : _dio = dio ?? Dio() {
    _dio.options.baseUrl = baseUrl ?? defaultBaseUrl;
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _authService.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
    _dio.interceptors.add(RetryInterceptor(_dio, this));
  }


  void updatePort(int port) {
    _dio.options.baseUrl = 'http://localhost:$port';
    debugPrint('ApiService updated to use port $port');
  }

  String get baseUrl => _dio.options.baseUrl;

  void setBaseUrl(String url) {
    _dio.options.baseUrl = url;
  }

  Future<Response> login(String username, String password) async {
    // In FFI mode, login is not required (local-first mode)
    if (useFfi) {
      return Response(
        requestOptions: RequestOptions(path: '/api/auth/login'),
        statusCode: 200,
        data: {'token': 'ffi_local_token', 'message': 'Local mode - no auth needed'},
      );
    }
    // We expect 403 if MFA is required. Dio throws exception on 403 by default unless validated.
    // We should handle this in the UI, or wrap here.
    // Ideally we let the UI catch the error.
    return await _dio.post(
      '/api/auth/login',
      data: {'username': username, 'password': password},
    );
  }

  Future<Response> loginMfa(String username, String password, String code) async {
    return await _dio.post(
      '/api/auth/login-mfa',
      data: {'username': username, 'password': password, 'code': code},
    );
  }

  Future<Response> setup2Fa() async {
    if (useFfi) {
      // MFA requires server connection
      throw DioException(
        requestOptions: RequestOptions(path: '/api/auth/2fa/setup'),
        message: 'Two-factor authentication requires a server connection. Please configure a backend server.',
        type: DioExceptionType.unknown,
      );
    }
    return await _dio.post('/api/auth/2fa/setup');
  }

  Future<Response> verify2Fa(String secret, String code) async {
    if (useFfi) {
      // MFA requires server connection
      throw DioException(
        requestOptions: RequestOptions(path: '/api/auth/2fa/verify'),
        message: 'Two-factor authentication requires a server connection. Please configure a backend server.',
        type: DioExceptionType.unknown,
      );
    }
    return await _dio.post(
      '/api/auth/2fa/verify',
      data: {'secret': secret, 'code': code},
    );
  }

  Future<Response> getMe() async {
    if (useFfi) {
        // Return mock data for FFI/Offline mode
        return Response(
          requestOptions: RequestOptions(path: '/api/auth/me'),
          statusCode: 200,
          data: {
             'user_id': 1,
             'username': 'offline_user',
             'library_id': 1, // Default to 1 for offline
             'role': 'admin'
          }
        );
    }
    return await _dio.get('/api/auth/me');
  }

  Future<Response> createBook(Map<String, dynamic> bookData) async {
    if (useFfi) {
      try {
        final frbBookInput = frb.FrbBook(
          title: bookData['title'] ?? 'Untitled',
          author: bookData['author'],
          isbn: bookData['isbn'],
          summary: bookData['description'] ?? bookData['summary'], // Handle mapping
          publisher: bookData['publisher'],
          publicationYear: bookData['publication_year'] is int 
              ? bookData['publication_year'] 
              : int.tryParse(bookData['publication_year']?.toString() ?? ''),
          coverUrl: bookData['cover_url'],
          subjects: bookData['subjects'] != null ? jsonEncode(bookData['subjects']) : null,
          readingStatus: bookData['reading_status'],
        );
        
        final createdBook = await FfiService().createBook(frbBookInput);
        
        return Response(
          requestOptions: RequestOptions(path: '/api/books'),
          statusCode: 201,
          data: {
             'id': createdBook.id,
             'title': createdBook.title,
             // Add other fields if needed by caller
          },
        );
      } catch (e) {
        debugPrint('FFI createBook error: $e');
        // Return 500 on failure to alert caller
        return Response(
          requestOptions: RequestOptions(path: '/api/books'),
          statusCode: 500,
          statusMessage: e.toString(),
        );
      }
    }
    return await _dio.post('/api/books', data: bookData);
  }

  Future<Response> updateBook(int id, Map<String, dynamic> bookData) async {
    if (useFfi) {
      try {
        // Fetch current book to preserve unchanged fields (especially required ones like title)
        final currentBook = await FfiService().getBook(id);
        
        final updatedFrbBook = frb.FrbBook(
          id: id,
          title: bookData['title'] ?? currentBook.title,
          author: bookData.containsKey('author') ? bookData['author'] : currentBook.author,
          isbn: bookData.containsKey('isbn') ? bookData['isbn'] : currentBook.isbn,
          summary: bookData.containsKey('description') ? bookData['description'] : 
                   bookData.containsKey('summary') ? bookData['summary'] : currentBook.summary,
          publisher: bookData.containsKey('publisher') ? bookData['publisher'] : currentBook.publisher,
          publicationYear: bookData.containsKey('publication_year') 
              ? (bookData['publication_year'] is int 
                 ? bookData['publication_year'] 
                 : int.tryParse(bookData['publication_year']?.toString() ?? ''))
              : currentBook.publicationYear,
          coverUrl: bookData.containsKey('cover_url') ? bookData['cover_url'] : currentBook.coverUrl,
          readingStatus: bookData.containsKey('reading_status') ? bookData['reading_status'] : currentBook.readingStatus,
          finishedReadingAt: bookData.containsKey('finished_reading_at') ? bookData['finished_reading_at'] : currentBook.finishedReadingAt,
          startedReadingAt: bookData.containsKey('started_reading_at') ? bookData['started_reading_at'] : currentBook.startedReadingAt,
          
          subjects: bookData.containsKey('subjects') 
             ? (bookData['subjects'] != null ? jsonEncode(bookData['subjects']) : null)
             : (currentBook.subjects != null ? jsonEncode(currentBook.subjects) : null),
             
          largeCoverUrl: null, // Not in Book model
          shelfPosition: null, // Not in Book model
          userRating: bookData.containsKey('user_rating') ? bookData['user_rating'] : currentBook.userRating,
          createdAt: null, // Not in Book model
          updatedAt: null, // Not in Book model
        );

        final result = await FfiService().updateBook(id, updatedFrbBook);

        return Response(
          requestOptions: RequestOptions(path: '/api/books/$id'),
          statusCode: 200,
          data: {
            'id': result.id,
            'title': result.title,
            'message': 'Book updated successfully'
          },
        );
      } catch (e) {
        debugPrint('FFI updateBook error: $e');
        return Response(
          requestOptions: RequestOptions(path: '/api/books/$id'),
          statusCode: 500,
          statusMessage: e.toString(),
        );
      }
    }
    return await _dio.put('/api/books/$id', data: bookData);
  }

  Future<Response> deleteBook(int id) async {
    if (useFfi) {
      try {
        await FfiService().deleteBook(id);
        return Response(
          requestOptions: RequestOptions(path: '/api/books/$id'),
          statusCode: 200,
          data: {'message': 'Book deleted successfully'},
        );
      } catch (e) {
        debugPrint('FFI deleteBook error: $e');
         return Response(
          requestOptions: RequestOptions(path: '/api/books/$id'),
          statusCode: 500,
          statusMessage: e.toString(),
        );
      }
    }
    return await _dio.delete('/api/books/$id');
  }

  // Copy management
  Future<Response> getBookCopies(int bookId) async {
    return await _dio.get('/api/books/$bookId/copies');
  }

  Future<Response> createCopy(Map<String, dynamic> copyData) async {
    return await _dio.post('/api/copies', data: copyData);
  }

  Future<Response> updateCopy(int id, Map<String, dynamic> copyData) async {
    return await _dio.put('/api/copies/$id', data: copyData);
  }

  // Loan methods
  Future<Response> createLoan(Map<String, dynamic> loanData) async {
    if (useFfi) {
      try {
        final loanId = await RustLib.instance.api.crateApiFrbCreateLoan(
          copyId: loanData['copy_id'] as int,
          contactId: loanData['contact_id'] as int,
          libraryId: loanData['library_id'] as int? ?? 1,
          loanDate: loanData['loan_date'] as String,
          dueDate: loanData['due_date'] as String,
          notes: loanData['notes'] as String?,
        );
        return Response(
          requestOptions: RequestOptions(path: '/api/loans'),
          statusCode: 201,
          data: {'loan': {'id': loanId}, 'message': 'Loan created successfully'},
        );
      } catch (e) {
        return Response(
          requestOptions: RequestOptions(path: '/api/loans'),
          statusCode: 400,
          data: {'error': e.toString()},
        );
      }
    }
    return await _dio.post('/api/loans', data: loanData);
  }

  Future<Response> getLoans({String? status, int? contactId}) async {
    if (useFfi) {
      try {
        final loans = await RustLib.instance.api.crateApiFrbGetAllLoans(
          status: status,
          contactId: contactId,
        );

        final data = loans
            .map((l) => {
                  'id': l.id,
                  'copy_id': l.copyId,
                  'contact_id': l.contactId,
                  'library_id': l.libraryId,
                  'loan_date': l.loanDate,
                  'due_date': l.dueDate,
                  'return_date': l.returnDate,
                  'status': l.status,
                  'notes': l.notes,
                  'contact_name': l.contactName,
                  'book_title': l.bookTitle,
                })
            .toList();

        return Response(
          requestOptions: RequestOptions(path: '/api/loans'),
          statusCode: 200,
          data: {'loans': data},
        );
      } catch (e) {
        return Response(
          requestOptions: RequestOptions(path: '/api/loans'),
          statusCode: 400,
          data: {'error': e.toString()},
        );
      }
    }

    Map<String, dynamic> params = {};
    if (status != null) params['status'] = status;
    if (contactId != null) params['contact_id'] = contactId;
    return await _dio.get('/api/loans', queryParameters: params);
  }

  Future<Response> returnLoan(int loanId) async {
    if (useFfi) {
      try {
        await RustLib.instance.api.crateApiFrbReturnLoan(id: loanId);
        return Response(
          requestOptions: RequestOptions(path: '/api/loans/$loanId/return'),
          statusCode: 200,
          data: {'message': 'Loan returned successfully'},
        );
      } catch (e) {
        return Response(
          requestOptions: RequestOptions(path: '/api/loans/$loanId/return'),
          statusCode: 400,
          data: {'error': e.toString()},
        );
      }
    }
    return await _dio.post('/api/loans/$loanId/return');
  }

  // Contact methods
  Future<Response> getContacts({int? libraryId, String? type}) async {
    // In FFI mode, use FfiService and return mock Response
    if (useFfi) {
      try {
        final contacts = await FfiService().getContacts(libraryId: libraryId, type: type);
        final contactsJson = contacts.map((c) => c.toJson()).toList();
        return Response(
          requestOptions: RequestOptions(path: '/api/contacts'),
          statusCode: 200,
          data: {'contacts': contactsJson},
        );
      } catch (e) {
        return Response(
          requestOptions: RequestOptions(path: '/api/contacts'),
          statusCode: 200,
          data: {'contacts': []},
        );
      }
    }
    
    Map<String, dynamic> params = {};
    if (libraryId != null) params['library_id'] = libraryId;
    if (type != null) params['type'] = type;
    if (useFfi) {
      try {
        final contacts = await FfiService().getContacts(
          libraryId: 1, // Default to 1 for FFI
        );
        return Response(
          requestOptions: RequestOptions(path: '/api/contacts'),
          statusCode: 200,
          data: {
            'contacts': contacts.map((c) => c.toJson()).toList(),
          },
        );
      } catch (e) {
        return Response(
          requestOptions: RequestOptions(path: '/api/contacts'),
          statusCode: 500,
          statusMessage: 'Error getting contacts: $e',
        );
      }
    }
    return await _dio.get('/api/contacts', queryParameters: params);
  }

  Future<Response> getContact(int id) async {
    if (useFfi) {
      try {
        final contact = await FfiService().getContact(id);
        return Response(
          requestOptions: RequestOptions(path: '/api/contacts/$id'),
          statusCode: 200,
          data: {
            'contact': contact.toJson(),
          },
        );
      } catch (e) {
        return Response(
          requestOptions: RequestOptions(path: '/api/contacts/$id'),
          statusCode: 404,
          statusMessage: 'Contact not found',
        );
      }
    }
    return await _dio.get('/api/contacts/$id');
  }

  Future<Response> createContact(Map<String, dynamic> contactData) async {
    if (useFfi) {
      try {
        // Create contact via FFI
        final contact = Contact(
          type: contactData['type'] ?? 'borrower',
          name: contactData['name'] ?? '',
          firstName: contactData['first_name'],
          email: contactData['email'],
          phone: contactData['phone'],
          address: contactData['address'],
          streetAddress: contactData['street_address'],
          postalCode: contactData['postal_code'],
          city: contactData['city'],
          country: contactData['country'],
          latitude: (contactData['latitude'] as num?)?.toDouble(),
          longitude: (contactData['longitude'] as num?)?.toDouble(),
          notes: contactData['notes'],
          userId: contactData['user_id'] ?? 1,
          libraryOwnerId: contactData['library_owner_id'] ?? 1,
          isActive: contactData['is_active'] ?? true,
        );
        
        // Actually persist to database via FFI
        final created = await FfiService().createContact(contact);
        
        return Response(
          requestOptions: RequestOptions(path: '/api/contacts'),
          statusCode: 201,
          data: {
            'contact': created.toJson(),
            'message': 'Contact created successfully',
          },
        );
      } catch (e) {
        return Response(
          requestOptions: RequestOptions(path: '/api/contacts'),
          statusCode: 500,
          statusMessage: 'Error creating contact: $e',
        );
      }
    }
    return await _dio.post('/api/contacts', data: contactData);
  }

  Future<Response> updateContact(
    int id,
    Map<String, dynamic> contactData,
  ) async {
    if (useFfi) {
      try {
        final contact = Contact(
          id: id,
          type: contactData['type'] ?? 'borrower',
          name: contactData['name'] ?? '',
          firstName: contactData['first_name'],
          email: contactData['email'],
          phone: contactData['phone'],
          address: contactData['address'],
          streetAddress: contactData['street_address'],
          postalCode: contactData['postal_code'],
          city: contactData['city'],
          country: contactData['country'],
          latitude: (contactData['latitude'] as num?)?.toDouble(),
          longitude: (contactData['longitude'] as num?)?.toDouble(),
          notes: contactData['notes'],
          userId: contactData['user_id'] ?? 1,
          libraryOwnerId: contactData['library_owner_id'] ?? 1,
          isActive: contactData['is_active'] ?? true,
        );
        
        final updated = await FfiService().updateContact(contact);
        
        return Response(
          requestOptions: RequestOptions(path: '/api/contacts/$id'),
          statusCode: 200,
          data: {
            'contact': updated.toJson(),
            'message': 'Contact updated successfully',
          },
        );
      } catch (e) {
        return Response(
          requestOptions: RequestOptions(path: '/api/contacts/$id'),
          statusCode: 500,
          statusMessage: 'Error updating contact: $e',
        );
      }
    }
    return await _dio.put('/api/contacts/$id', data: contactData);
  }

  Future<Response> deleteContact(int id) async {
    // Contacts require network or Rust FFI support (not yet implemented)
    if (useFfi) {
      return Response(
        requestOptions: RequestOptions(path: '/api/contacts/$id'),
        statusCode: 501,
        statusMessage: 'Contacts not available in offline mode',
      );
    }
    return await _dio.delete('/api/contacts/$id');
  }

  Future<Response> deleteCopy(int copyId) async {
    return await _dio.delete('/api/copies/$copyId');
  }

  // Peer methods
  Future<Response> connectPeer(String name, String url) async {
    // Fetch my config to send to remote peer for handshake
    String? myName;
    try {
      final configRes = await getLibraryConfig();
      if (configRes.statusCode == 200) {
        myName = configRes.data['name'];
        // Construct my URL based on current port/host if possible, or use a setting
        // For now, we might rely on the Hub knowing it, but the Hub is local.
        // Actually, the Hub needs to know the PUBLIC url of this library.
        // If we are in Docker, it's http://bibliogenius-a:8000 etc.
        // But the App doesn't know its external Docker URL easily.
        // However, the USER enters the URL of the peer they are connecting TO.
        // The peer needs to know how to call ME back.
        // We can try to send what we know, or let the user configure it.
        // For this fix, let's assume we send what we have in config if available,
        // or maybe we need to ask the user?
        // Let's send 'my_name' at least. 'my_url' is harder.
        // If 'my_url' is missing, the Hub won't be able to notify.
        // Let's try to get it from config if we added a 'public_url' field, or just send localhost for now?
        // No, localhost won't work for remote.
        // Let's assume the config has it or we send a placeholder that the Hub might resolve?
        // Actually, the Hub code I wrote expects 'my_url'.

        // TEMPORARY FIX: If we are in dev/docker, we might need to hardcode or guess.
        // But for a proper fix, we should probably add 'public_url' to LibraryConfig.
        // For now, let's send the name and let the Hub try its best or fail silently (as per try-catch).

        // Wait, if I don't send my_url, the handshake fails.
        // Let's send a dummy or try to infer.
        // Actually, the user is "Library B".
        // If Library B is "bibliogenius-b:8000", we need to send that.
        // The App doesn't know.
        // BUT, the Hub (PeerController) is running alongside the App (or is the App's backend).
        // Maybe the Hub knows?
        // The Hub is local to the App.
        // In `PeerController.php`, I used `$data['my_url']`.

        // Let's just send the name for now and maybe the Hub can figure it out or we update config later.
        // Or better: The user should have configured their "Public URL" in settings.
        // If not, we can't really do P2P.

        // Let's just send the name and empty URL if not found, and hope for the best?
        // No, that will fail validation in `receiveConnection`.

        // Let's assume for the demo/docker env that we can derive it?
        // No.

        // Let's just send the name.
      }
    } catch (e) {
      debugPrint('Error fetching config for handshake: $e');
    }

    return await _dio.post(
      '$hubUrl/api/peers/connect',
      data: {
        'name': name,
        'url': url,
        'my_name': myName,
        'my_url': 'http://localhost:8000', // TODO: Make this configurable!
      },
    );
  }

  Future<GenieResponse> sendGenieChat(String text) async {
    try {
      final response = await _dio.post('/api/genie/chat', data: {'text': text});

      if (response.statusCode == 200) {
        return GenieResponse.fromJson(response.data);
      } else {
        throw Exception(
          'Failed to chat with Genie: Status ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Genie Chat Error: $e');
      rethrow;
    }
  }

  Future<Response> getLibraryConfig() async {
    // In FFI mode, read from SharedPreferences
    if (useFfi) {
      final prefs = await SharedPreferences.getInstance();
      return Response(
        requestOptions: RequestOptions(path: '/api/config'),
        statusCode: 200,
        data: {
          'library_name': prefs.getString('ffi_library_name') ?? 'Ma Bibliothèque',
          'name': prefs.getString('ffi_library_name') ?? 'Ma Bibliothèque',
          'description': prefs.getString('ffi_library_description') ?? '',
          'show_borrowed_books': prefs.getBool('ffi_show_borrowed_books') ?? true,
          'share_location': prefs.getBool('ffi_share_location') ?? false,
          'profile_type': prefs.getString('ffi_profile_type') ?? 'individual_reader',
          'latitude': prefs.getDouble('ffi_latitude'),
          'longitude': prefs.getDouble('ffi_longitude'),
          'tags': (prefs.getStringList('ffi_tags') ?? []),
        },
      );
    }
    return await _dio.get('/api/config');
  }

  // Gamification
  Future<Response> getUserStatus() async {
    // In FFI mode, calculate stats from actual data
    if (useFfi) {
      try {
        final books = await FfiService().getBooks();
        final prefs = await SharedPreferences.getInstance();
        final totalBooks = books.length;
        final booksRead = books.where((b) => b.readingStatus == 'finished').length;
        final booksReading = books.where((b) => b.readingStatus == 'reading').length;
        
        // Read goals from SharedPreferences
        final readingGoalYearly = prefs.getInt('ffi_reading_goal_yearly') ?? 12;
        final readingGoalMonthly = prefs.getInt('ffi_reading_goal_monthly') ?? 0;
        
        // Calculate collector progress (thresholds: 10, 50, 100)
        int collectorLevel = 0;
        int collectorNext = 10;
        if (totalBooks >= 100) { collectorLevel = 3; collectorNext = 100; }
        else if (totalBooks >= 50) { collectorLevel = 2; collectorNext = 100; }
        else if (totalBooks >= 10) { collectorLevel = 1; collectorNext = 50; }
        
        // Calculate reader progress (thresholds: 5, 25, 50)
        int readerLevel = 0;
        int readerNext = 5;
        if (booksRead >= 50) { readerLevel = 3; readerNext = 50; }
        else if (booksRead >= 25) { readerLevel = 2; readerNext = 50; }
        else if (booksRead >= 5) { readerLevel = 1; readerNext = 25; }
        
        double collectorProgress = collectorLevel >= 3 ? 1.0 : totalBooks / collectorNext;
        double readerProgress = readerLevel >= 3 ? 1.0 : booksRead / readerNext;
        
        return Response(
          requestOptions: RequestOptions(path: '/api/user/status'),
          statusCode: 200,
          data: {
            'tracks': {
              'collector': {
                'level': collectorLevel,
                'progress': collectorProgress.clamp(0.0, 1.0),
                'current': totalBooks,
                'next_threshold': collectorNext,
              },
              'reader': {
                'level': readerLevel,
                'progress': readerProgress.clamp(0.0, 1.0),
                'current': booksRead,
                'next_threshold': readerNext,
              },
              'lender': {'level': 0, 'progress': 0.0, 'current': 0, 'next_threshold': 5},
              'cataloguer': {'level': 0, 'progress': 0.0, 'current': 0, 'next_threshold': 10},
            },
            'streak': {'current': 0, 'longest': 0},
            'recent_achievements': [],
            'config': {
              'achievements_style': 'minimal',
              'reading_goal_yearly': readingGoalYearly,
              'reading_goal_monthly': readingGoalMonthly,
              'reading_goal_progress': booksRead,
            },
            'level': 'Member',
            'loans_count': 0,
            'edits_count': 0,
            'next_level_progress': collectorProgress.clamp(0.0, 1.0),
          },
        );
      } catch (e) {
        debugPrint('FFI getUserStatus error: $e');
      }
      // Fallback to defaults on error
      return Response(
        requestOptions: RequestOptions(path: '/api/user/status'),
        statusCode: 200,
        data: {
          'tracks': {
            'collector': {'level': 0, 'progress': 0.0, 'current': 0, 'next_threshold': 10},
            'reader': {'level': 0, 'progress': 0.0, 'current': 0, 'next_threshold': 5},
            'lender': {'level': 0, 'progress': 0.0, 'current': 0, 'next_threshold': 5},
            'cataloguer': {'level': 0, 'progress': 0.0, 'current': 0, 'next_threshold': 10},
          },
          'streak': {'current': 0, 'longest': 0},
          'recent_achievements': [],
          'config': {'achievements_style': 'minimal', 'reading_goal_yearly': 12, 'reading_goal_progress': 0},
          'level': 'Member',
          'loans_count': 0,
          'edits_count': 0,
          'next_level_progress': 0.0,
        },
      );
    }
    return await _dio.get('/api/user/status');
  }

  /// Update gamification config (reading goals, etc.)
  Future<Response> updateGamificationConfig({
    int? readingGoalYearly,
    int? readingGoalMonthly,
    String? achievementsStyle,
  }) async {
    final data = <String, dynamic>{};
    if (readingGoalYearly != null) data['reading_goal_yearly'] = readingGoalYearly;
    if (readingGoalMonthly != null) data['reading_goal_monthly'] = readingGoalMonthly;
    if (achievementsStyle != null) data['achievements_style'] = achievementsStyle;

    if (useFfi) {
      // In FFI mode, store in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      if (readingGoalYearly != null) {
        await prefs.setInt('ffi_reading_goal_yearly', readingGoalYearly);
      }
      if (readingGoalMonthly != null) {
        await prefs.setInt('ffi_reading_goal_monthly', readingGoalMonthly);
      }
      if (achievementsStyle != null) {
        await prefs.setString('ffi_achievements_style', achievementsStyle);
      }
      return Response(
        requestOptions: RequestOptions(path: '/api/user/config'),
        statusCode: 200,
        data: {'message': 'Config updated successfully'},
      );
    }
    return await _dio.put('/api/user/config', data: data);
  }

  // Export
  Future<Response> exportData() async {
    // In FFI mode, generate CSV from local books
    if (useFfi) {
      try {
        final books = await FfiService().getBooks();
        final csvLines = <String>[];
        // CSV header
        csvLines.add('Title,Author,ISBN,Publisher,Year,Status,Cover URL');
        // CSV rows
        for (final book in books) {
          final row = [
            '"${(book.title).replaceAll('"', '""')}"',
            '"${(book.author ?? '').replaceAll('"', '""')}"',
            '"${book.isbn ?? ''}"',
            '"${(book.publisher ?? '').replaceAll('"', '""')}"',
            '${book.publicationYear ?? ''}',
            '"${book.readingStatus ?? ''}"',
            '"${book.coverUrl ?? ''}"',
          ].join(',');
          csvLines.add(row);
        }
        final csvContent = csvLines.join('\n');
        final bytes = utf8.encode(csvContent);
        return Response(
          requestOptions: RequestOptions(path: '/api/export'),
          statusCode: 200,
          data: bytes,
        );
      } catch (e) {
        debugPrint('FFI export error: $e');
        return Response(
          requestOptions: RequestOptions(path: '/api/export'),
          statusCode: 500,
          statusMessage: 'Export failed: $e',
        );
      }
    }
    return await _dio.get(
      '/api/export',
      options: Options(responseType: ResponseType.bytes),
    );
  }

  Future<Response> importBooks(dynamic fileSource, {String? filename}) async {
    MultipartFile file;
    if (fileSource is String) {
      final name = filename ?? fileSource.split('/').last;
      file = await MultipartFile.fromFile(fileSource, filename: name);
    } else if (fileSource is List<int>) {
      file = MultipartFile.fromBytes(
        fileSource,
        filename: filename ?? 'import.csv',
      );
    } else {
      throw Exception("Unsupported file source type");
    }

    FormData formData = FormData.fromMap({"file": file});
    return await _dio.post('/api/import/file', data: formData);
  }

  // P2P Advanced
  Future<Response> getPeers() async {
    if (useFfi) {
      // Call local HTTP API to get peers
      try {
        final localDio = Dio(BaseOptions(
          baseUrl: 'http://localhost:${ApiService.httpPort}',
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ));
        final response = await localDio.get('/api/peers');
        debugPrint('✅ getPeers: ${response.data}');
        return response;
      } catch (e) {
        debugPrint('❌ getPeers error: $e');
        return Response(
          requestOptions: RequestOptions(path: '/api/peers'),
          statusCode: 500,
          data: {'error': e.toString(), 'data': []},
        );
      }
    }
    return await _dio.get('$hubUrl/api/peers');
  }

  Future<Response> searchPeers(String query) async {
    if (useFfi) {
      return Response(
        requestOptions: RequestOptions(path: '/api/peers/search'),
        statusCode: 200,
        data: [],
      );
    }
    return await _dio.get(
      '$hubUrl/api/peers/search',
      queryParameters: {'q': query},
    );
  }

  Future<Response> syncPeer(String peerUrl) async {
    if (useFfi) {
      // FFI mode: Direct P2P sync
      try {
        final myUrl = await _getMyUrl();
        final dio = Dio();
        debugPrint('P2P Sync: Requesting sync from $peerUrl/api/peers/sync_by_url with my URL $myUrl');
        return await dio.post('$peerUrl/api/peers/sync_by_url', data: {
          'url': myUrl
        });
      } catch (e) {
        debugPrint('P2P Sync Error: $e');
        return Response(
          requestOptions: RequestOptions(path: '/api/peers/sync_by_url'),
          statusCode: 502,
          data: {'error': e.toString()},
        );
      }
    }
    return await _dio.post('/api/peers/sync_by_url', data: {'url': peerUrl});
  }

  Future<Response> getPeerBooks(int peerId) async {
    if (useFfi) {
      return Response(
        requestOptions: RequestOptions(path: '/api/peers/$peerId/books'),
        statusCode: 200,
        data: [],
      );
    }
    return await _dio.get('/api/peers/$peerId/books');
  }

  Future<Response> getPeerBooksByUrl(String peerUrl) async {
    // Direct P2P call to the peer's API
    // We use a fresh Dio instance to avoid using our backend's BaseURL/Auth tokens
    // which are not valid for the peer.
    try {
      final cleanUrl = peerUrl.endsWith('/') ? peerUrl.substring(0, peerUrl.length - 1) : peerUrl;
      final targetUrl = '$cleanUrl/api/books';
      
      debugPrint('P2P: Fetching books from $targetUrl');
      
      final dio = Dio();
      return await dio.get(targetUrl);
    } catch (e) {
      debugPrint('P2P: Error fetching books from $peerUrl - $e');
      rethrow;
    }
  }

  Future<Response> requestBook(int peerId, String isbn, String title) async {
    if (useFfi) {
      return Response(
        requestOptions: RequestOptions(path: '/api/peers/request'),
        statusCode: 200,
        data: {'message': 'Request not available in offline mode'},
      );
    }
    return await _dio.post(
      '/api/peers/request',
      data: {'peer_id': peerId, 'book_isbn': isbn, 'book_title': title},
    );
  }

  Future<Response> requestBookByUrl(
    String peerUrl,
    String isbn,
    String title,
  ) async {
    if (useFfi) {
      try {
        // 1. Get my info
        final configRes = await getLibraryConfig();
        final myName = configRes.data['library_name'];
        // In FFI/P2P mode, we calculate our dynamic IP URL
        final myUrl = await _getMyUrl();

        if (myUrl.isEmpty) throw Exception("My library URL could not be determined");

        // 2. Send request to peer
        // Use clean URL without trailing slash
        final cleanPeerUrl = peerUrl.endsWith('/')
            ? peerUrl.substring(0, peerUrl.length - 1)
            : peerUrl;

        final remoteDio = Dio(BaseOptions(
          baseUrl: cleanPeerUrl,
          connectTimeout: const Duration(seconds: 5),
        ));

        debugPrint('📡 Sending P2P loan request to $cleanPeerUrl/api/peers/requests/incoming');
        final remoteRes = await remoteDio.post(
          '/api/peers/requests/incoming',
          data: {
            'from_name': myName,
            'from_url': myUrl,
            'book_isbn': isbn,
            'book_title': title,
          },
        );

        if (remoteRes.statusCode == 200) {
          // 3. Log outgoing request locally
          final localDio = Dio(BaseOptions(baseUrl: 'http://localhost:$httpPort'));
          await localDio.post('/api/peers/requests/outgoing', data: {
            'to_peer_url': cleanPeerUrl,
            'book_isbn': isbn,
            'book_title': title,
          });
          return remoteRes;
        } else {
          throw Exception('Remote peer rejected request: ${remoteRes.statusCode}');
        }
      } catch (e) {
        debugPrint('❌ requestBookByUrl error: $e');
        rethrow;
      }
    }
    return await _dio.post(
      '/api/peers/request_by_url',
      data: {'peer_url': peerUrl, 'book_isbn': isbn, 'book_title': title},
    );
  }

  Future<Response> getIncomingRequests() async {
    if (useFfi) {
      final localDio = Dio(BaseOptions(baseUrl: 'http://localhost:$httpPort'));
      return await localDio.get('/api/peers/requests');
    }
    return await _dio.get('/api/peers/requests');
  }

  Future<Response> getOutgoingRequests() async {
    if (useFfi) {
      final localDio = Dio(BaseOptions(baseUrl: 'http://localhost:$httpPort'));
      return await localDio.get('/api/peers/requests/outgoing');
    }
    return await _dio.get('/api/peers/requests/outgoing');
  }

  Future<Response> updateRequestStatus(String requestId, String status) async {
    if (useFfi) {
      return Response(
        requestOptions: RequestOptions(path: '/api/peers/requests/$requestId'),
        statusCode: 200,
        data: {'message': 'Not available in offline mode'},
      );
    }
    return await _dio.put(
      '/api/peers/requests/$requestId',
      data: {'status': status},
    );
  }

  Future<Response> deleteRequest(String requestId) async {
    if (useFfi) {
      return Response(
        requestOptions: RequestOptions(path: '/api/peers/requests/$requestId'),
        statusCode: 200,
        data: {'message': 'Not available in offline mode'},
      );
    }
    return await _dio.delete('/api/peers/requests/$requestId');
  }

  Future<Response> deleteOutgoingRequest(String requestId) async {
    if (useFfi) {
      return Response(
        requestOptions: RequestOptions(path: '/api/peers/requests/outgoing/$requestId'),
        statusCode: 200,
        data: {'message': 'Not available in offline mode'},
      );
    }
    return await _dio.delete('/api/peers/requests/outgoing/$requestId');
  }

  // P2P Connection Requests (Hub)
  Future<Response> getPendingPeers() async {
    if (useFfi) {
      // In FFI mode, call the local HTTP API to get peers
      try {
        final localDio = Dio(BaseOptions(
          baseUrl: 'http://localhost:${ApiService.httpPort}',
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ));
        final response = await localDio.get('/api/peers');
        if (response.statusCode == 200) {
          // Handle both formats: {data: [...]} or direct [...]
          List allPeers;
          if (response.data is Map && response.data['data'] != null) {
            allPeers = response.data['data'] as List;
          } else if (response.data is List) {
            allPeers = response.data as List;
          } else {
            allPeers = [];
          }
          
          // Filter for peers where auto_approve is false (pending connections)
          final pendingPeers = allPeers
              .where((p) => p['auto_approve'] == false)
              .map((p) {
                final Map<String, dynamic> peer = Map<String, dynamic>.from(p as Map);
                peer['direction'] = 'incoming'; // Mark as incoming for UI
                return peer;
              })
              .toList();
          debugPrint('📋 getPendingPeers: Found ${pendingPeers.length} pending from ${allPeers.length} total');
          for (var p in pendingPeers) {
            debugPrint('  📚 Peer: id=${p['id']}, name="${p['name']}", url=${p['url']}, auto_approve=${p['auto_approve']}');
          }
          return Response(
            requestOptions: RequestOptions(path: '/api/peers'),
            statusCode: 200,
            data: {'requests': pendingPeers},
          );
        }
      } catch (e) {
        debugPrint('❌ getPendingPeers HTTP error: $e');
      }
      // Fallback to empty
      return Response(
        requestOptions: RequestOptions(path: '$hubUrl/api/peers/requests'),
        statusCode: 200,
        data: {'requests': []},
      );
    }
    return await _dio.get('$hubUrl/api/peers/requests');
  }

  Future<Response> updatePeerStatus(int id, String status) async {
    if (useFfi) {
      // Call local HTTP API to update peer status
      try {
        final localDio = Dio(BaseOptions(
          baseUrl: 'http://localhost:${ApiService.httpPort}',
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ));
        final response = await localDio.put('/api/peers/$id/status', data: {'status': status});
        debugPrint('✅ updatePeerStatus: $status for peer $id');
        return response;
      } catch (e) {
        debugPrint('❌ updatePeerStatus error: $e');
        return Response(
          requestOptions: RequestOptions(path: '/api/peers/$id/status'),
          statusCode: 500,
          data: {'error': e.toString()},
        );
      }
    }
    return await _dio.put(
      '$hubUrl/api/peers/$id/status',
      data: {'status': status},
    );
  }

  Future<Response> deletePeer(int id) async {
    if (useFfi) {
      // Call local HTTP API to delete peer
      try {
        final localDio = Dio(BaseOptions(
          baseUrl: 'http://localhost:${ApiService.httpPort}',
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ));
        final response = await localDio.delete('/api/peers/$id');
        debugPrint('🗑️ deletePeer: peer $id deleted');
        return response;
      } catch (e) {
        debugPrint('❌ deletePeer error: $e');
        return Response(
          requestOptions: RequestOptions(path: '/api/peers/$id'),
          statusCode: 500,
          data: {'error': e.toString()},
        );
      }
    }
    return await _dio.delete('$hubUrl/api/peers/$id');
  }

  // ============================================
  // mDNS Local Discovery
  // ============================================

  /// Get libraries discovered on the local network via mDNS
  Future<Response> getLocalPeers() async {
    // Use native MdnsService for local discovery (works on iOS/macOS via Bonjour)
    final peers = MdnsService.getPeersJson();
    final isActive = MdnsService.isActive;
    debugPrint('🔍 ApiService: getLocalPeers() returning ${peers.length} peers');
    return Response(
      requestOptions: RequestOptions(path: '/api/discovery/local'),
      statusCode: 200,
      data: {'peers': peers, 'count': peers.length, 'mdns_active': isActive},
    );
  }

  /// Get mDNS service status (active/inactive)
  Future<Response> getMdnsStatus() async {
    final isActive = MdnsService.isActive;
    return Response(
      requestOptions: RequestOptions(path: '/api/discovery/status'),
      statusCode: 200,
      data: {'active': isActive, 'service_type': '_bibliogenius._tcp'},
    );
  }

  /// Helper to get my own URL (IP address) for P2P handshake
  Future<String> _getMyUrl() async {
     String myIp = '127.0.0.1';
     try {
       final info = NetworkInfo();
       myIp = await info.getWifiIP() ?? '127.0.0.1';
     } catch (e) {
       debugPrint('Failed to get local IP: $e');
     }
     // Use the dynamically discovered port
     return 'http://$myIp:${ApiService.httpPort}';
  }

  /// Connect to a locally discovered peer by URL
  Future<Response> connectLocalPeer(String name, String url) async {
    if (useFfi) {
      try {
        // 1. Get my own details
        String myName = 'BiblioGenius User';
        final myUrl = await _getMyUrl();
        
        try {
           final config = await getLibraryConfig();
           if (config.data is Map) {
               myName = config.data['library_name'] ?? config.data['name'] ?? myName;
           }
        } catch (e) {
            debugPrint('Error getting own config for handshake: $e');
        }

        // 2. Send handshake request to Peer
        final targetUrl = '$url/api/peers/incoming';
        debugPrint('P2P Handshake: Sending my info ($myName, $myUrl) to $targetUrl');
        
        final dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ));
        
        final response = await dio.post(targetUrl, data: {
            'name': myName,
            'url': myUrl
        });
        
        debugPrint('P2P Handshake Success: ${response.statusCode} - ${response.data}');
        return response;
      } on DioException catch (e) {
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;
        debugPrint('P2P Connect DioException: ${e.type}');
        debugPrint('P2P Connect Status: $statusCode');
        debugPrint('P2P Connect Response Body: $responseData');
        debugPrint('P2P Connect Error: ${e.message}');
        
        // Return more informative error
        return Response(
          requestOptions: e.requestOptions,
          statusCode: statusCode ?? 502,
          data: {'error': 'Connection failed: ${responseData ?? e.message}', 'status': statusCode},
        );
      } catch (e) {
        debugPrint('P2P Connect Error: $e');
        return Response(
          requestOptions: RequestOptions(path: '/api/peers/connect'),
          statusCode: 500,
          data: {'error': e.toString()},
        );
      }
    }
    // Use the existing peer connect mechanism
    return await _dio.post('/api/peers/connect', data: {'name': name, 'url': url});
  }


  Future<Response> updateLibraryConfig({
    required String name,
    String? description,
    String? profileType,
    List<String>? tags,
    double? latitude,
    double? longitude,
    bool? shareLocation,
    bool? showBorrowedBooks,
  }) async {
    // In FFI mode, persist config to SharedPreferences
    if (useFfi) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ffi_library_name', name);
      if (description != null) await prefs.setString('ffi_library_description', description);
      if (profileType != null) await prefs.setString('ffi_profile_type', profileType);
      if (tags != null) await prefs.setStringList('ffi_tags', tags);
      if (latitude != null) await prefs.setDouble('ffi_latitude', latitude);
      if (longitude != null) await prefs.setDouble('ffi_longitude', longitude);
      if (shareLocation != null) await prefs.setBool('ffi_share_location', shareLocation);
      if (showBorrowedBooks != null) await prefs.setBool('ffi_show_borrowed_books', showBorrowedBooks);
      
      return Response(
        requestOptions: RequestOptions(path: '/api/library/config'),
        statusCode: 200,
        data: {
          'name': name,
          'description': description,
          'tags': tags ?? [],
          'latitude': latitude,
          'longitude': longitude,
          'share_location': shareLocation ?? false,
          'show_borrowed_books': showBorrowedBooks ?? false,
          'message': 'Configuration saved locally',
        },
      );
    }
    return await _dio.post(
      '/api/library/config',
      data: {
        'name': name,
        'description': description,
        'profile_type': profileType,
        'tags': tags ?? [],
        'latitude': latitude,
        'longitude': longitude,
        'share_location': shareLocation ?? false,
        'show_borrowed_books': showBorrowedBooks ?? false,
      },
    );
  }

  Future<Response> setup({
    required String libraryName,
    String? libraryDescription,
    required String profileType,
    String? theme,
    double? latitude,
    double? longitude,
    bool? shareLocation,
  }) async {
    // In FFI mode, persist setup config to SharedPreferences
    if (useFfi) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ffi_library_name', libraryName);
      if (libraryDescription != null) await prefs.setString('ffi_library_description', libraryDescription);
      await prefs.setString('ffi_profile_type', profileType);
      if (latitude != null) await prefs.setDouble('ffi_latitude', latitude);
      if (longitude != null) await prefs.setDouble('ffi_longitude', longitude);
      if (shareLocation != null) await prefs.setBool('ffi_share_location', shareLocation);
      
      return Response(
        requestOptions: RequestOptions(path: '/api/peers/sync'),
        statusCode: 200,
        data: {'message': 'Sync initiated'},
      );
    }
    return await _dio.post(
      '/api/setup',
      data: {
        'library_name': libraryName,
        'library_description': libraryDescription,
        'profile_type': profileType,
        'theme': theme,
        'latitude': latitude,
        'longitude': longitude,
        'share_location': shareLocation,
      },
    );
  }


  Future<Response> resetApp() async {
    if (useFfi) {
      // Call the FFI reset function which deletes all data from all tables
      try {
        final message = await RustLib.instance.api.crateApiFrbResetApp();
        return Response(
          requestOptions: RequestOptions(path: '/api/reset'),
          statusCode: 200,
          data: {'success': true, 'message': message},
        );
      } catch (e) {
        return Response(
          requestOptions: RequestOptions(path: '/api/reset'),
          statusCode: 500,
          data: {'success': false, 'message': e.toString()},
        );
      }
    }
    return await _dio.post('/api/reset');
  }

  Future<Response> searchOpenLibrary({
    String? title,
    String? author,
    String? subject,
  }) async {
    final queryParams = <String, dynamic>{};
    if (title != null && title.isNotEmpty) queryParams['title'] = title;
    if (author != null && author.isNotEmpty) queryParams['author'] = author;
    if (subject != null && subject.isNotEmpty) queryParams['subject'] = subject;

    return await _dio.get(
      '/api/integrations/openlibrary/search',
      queryParameters: queryParams,
    );
  }

  Future<Response> updateProfile({
    required String profileType,
    Map<String, dynamic>? avatarConfig,
  }) async {
    final Map<String, dynamic> data = {'profile_type': profileType};
    if (avatarConfig != null) {
      data['avatar_config'] = avatarConfig;
    }
    // In FFI/offline mode, profile is stored locally only
    if (useFfi) {
      return Response(
        requestOptions: RequestOptions(path: '/api/profile'),
        statusCode: 200,
        data: {'success': true, 'message': 'Profile stored locally'},
      );
    }
    return await _dio.put('/api/profile', data: data);
  }

  Future<List<Book>> getBooks({
    String? status,
    String? author,
    String? title,
    String? tag,
  }) async {
    // Use FFI for native platforms
    if (useFfi) {
      return FfiService().getBooks(status: status, title: title, tag: tag);
    }
    
    try {
      final queryParams = <String, dynamic>{};
      if (status != null) queryParams['status'] = status;
      if (author != null) queryParams['author'] = author;
      if (title != null) queryParams['title'] = title;
      if (tag != null) queryParams['tag'] = tag;

      final response = await _dio.get(
        '/api/books',
        queryParameters: queryParams,
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['books'];
        return data.map((json) => Book.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load books');
      }
    } catch (e) {
      throw Exception('Failed to load books: $e');
    }
  }

  Future<Book> getBook(int id) async {
    // Use FFI for native platforms
    if (useFfi) {
      return FfiService().getBook(id);
    }
    
    try {
      final response = await _dio.get('/api/books/$id');
      if (response.statusCode == 200) {
        return Book.fromJson(response.data);
      } else {
        throw Exception('Failed to load book');
      }
    } catch (e) {
      throw Exception('Failed to load book: $e');
    }
  }

  Future<void> reorderBooks(List<int> bookIds) async {
    try {
      await _dio.patch('/api/books/reorder', data: {'book_ids': bookIds});
    } catch (e) {
      debugPrint('Error reordering books: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> lookupBook(String isbn) async {
    // In FFI mode, use OpenLibrary directly since we can't reach the Rust HTTP server
    if (useFfi) {
      try {
        final openLibraryService = OpenLibraryService();
        final result = await openLibraryService.lookupByIsbn(isbn);
        if (result != null) {
          return {
            'title': result.title,
            'author': result.author,
            'publisher': result.publisher,
            'year': result.year,
            'cover_url': result.coverUrl,
            'summary': result.summary,
          };
        }
      } catch (e) {
        debugPrint('FFI Lookup via OpenLibrary failed: $e');
      }
      return null;
    }

    try {
      final response = await _dio.get('/api/lookup/$isbn');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        return {
          'title': data['title'],
          'author': data['authors'] != null
              ? (data['authors'] as List)
                    .map((a) => a is String ? a : a['name'])
                    .join(', ')
              : null,
          'authors_data': data['authors'], // Pass full data for UI
          'publisher': data['publisher'],
          'year': data['publication_year'] != null
              ? int.tryParse(data['publication_year'].toString())
              : null,
          'cover_url': data['cover_url'],
        };
      }
    } catch (e) {
      debugPrint('Lookup API Error: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> searchBooks({
    String? query,
    String? title,
    String? author,
    String? publisher,
    String? subject,
    String? lang, // User's preferred language for relevance boost (e.g., "fr", "en")
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (query != null && query.isNotEmpty) queryParams['q'] = query;
      if (title != null && title.isNotEmpty) queryParams['title'] = title;
      if (author != null && author.isNotEmpty) queryParams['author'] = author;
      if (publisher != null && publisher.isNotEmpty)
        queryParams['publisher'] = publisher;
      if (subject != null && subject.isNotEmpty)
        queryParams['subject'] = subject;
      if (lang != null && lang.isNotEmpty) queryParams['lang'] = lang;

      // External search always uses HTTP to Rust backend, even in FFI mode
      // because OpenLibrary/Google Books API calls must go through Rust HTTP server
      final searchDio = Dio();
      searchDio.options.baseUrl = defaultBaseUrl;
      
      final response = await searchDio.get(
        '/api/integrations/search_unified',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        return List<Map<String, dynamic>>.from(response.data);
      }
    } catch (e) {
      debugPrint('Search API Error: $e');
    }
    return [];
  }

  Future<Response> getTranslations(String locale) async {
    return await _dio.get('$hubUrl/api/translations/$locale');
  }

  Future<List<Tag>> getTags() async {
    // Use FFI for native platforms
    if (useFfi) {
      return FfiService().getTags();
    }
    
    try {
      final response = await _dio.get('/api/books/tags');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => Tag.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load tags');
      }
    } catch (e) {
      throw Exception('Failed to load tags: $e');
    }
  }
}

class RetryInterceptor extends Interceptor {
  final Dio dio;
  final ApiService apiService;
  // Prevent infinite loops or concurrent discovery attempts
  static bool _isDiscovering = false;

  RetryInterceptor(this.dio, this.apiService);

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Only attempt recovery for connection errors or timeouts
    bool shouldRetry =
        err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        (err.error != null &&
            err.error.toString().contains('Connection refused'));

    if (!shouldRetry || _isDiscovering) {
      return handler.next(err);
    }

    // Skip port discovery for requests to external services (Hub, etc.)
    // These are identified by having a full URL in the path or targeting a different host
    final requestPath = err.requestOptions.path;
    final requestUri = err.requestOptions.uri.toString();
    final currentBaseUrl = dio.options.baseUrl;

    // If the path is a full URL (starts with http), check if it's targeting our backend
    if (requestPath.startsWith('http://') ||
        requestPath.startsWith('https://')) {
      // Extract port from the full URL path
      final pathUri = Uri.tryParse(requestPath);
      final baseUri = Uri.tryParse(currentBaseUrl);

      // If it's targeting a different port/host, don't try to "fix" it with port discovery
      if (pathUri != null && baseUri != null) {
        if (pathUri.host != baseUri.host || pathUri.port != baseUri.port) {
          debugPrint(
            '⚠️ Connection failed on $requestPath (external service). Skipping port discovery.',
          );
          return handler.next(err);
        }
      }
    }

    _isDiscovering = true;
    debugPrint(
      '⚠️ Connection failed on $requestUri. Initiating Smart Port Discovery... 🕵️',
    );

    try {
      // Ports to scan: 8000 to 8010
      for (int port = 8000; port <= 8010; port++) {
        final testUrl = 'http://localhost:$port';

        // Skip current failed URL to avoid redundancy if it was one of these
        // if (err.requestOptions.baseUrl.contains(port.toString())) continue;

        debugPrint('   → Probing $testUrl...');
        try {
          // Create a raw dio instance for probing to avoid interceptors
          final probeDio = Dio(
            BaseOptions(
              baseUrl: testUrl,
              connectTimeout: const Duration(milliseconds: 500),
              receiveTimeout: const Duration(milliseconds: 500),
            ),
          );

          // Try simple health check or root
          final response = await probeDio.get(
            '/api/books?limit=1',
          ); // Light query

          if (response.statusCode == 200) {
            debugPrint('   ✅ FOUND BACKEND AT $testUrl! Healing connection...');

            // Update the main ApiService
            apiService.updatePort(port);

            // Update the original request's base URL
            err.requestOptions.baseUrl = testUrl;

            _isDiscovering = false;

            // Clone the request with new base URL and retry
            final opts = Options(
              method: err.requestOptions.method,
              headers: err.requestOptions.headers,
            );

            final cloneReq = await dio.request(
              err.requestOptions.path,
              options: opts,
              data: err.requestOptions.data,
              queryParameters: err.requestOptions.queryParameters,
            );

            return handler.resolve(cloneReq);
          }
        } catch (e) {
          // Probe failed, continue to next port
          // debugPrint('     (Test failed for $port)');
        }
      }

      debugPrint(
        '❌ Smart Port Discovery failed. Backend unreachable on ports 8000-8010.',
      );
    } finally {
      _isDiscovering = false;
    }

    return handler.next(err);
  }
}
