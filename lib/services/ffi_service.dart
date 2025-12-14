// FFI Service - Wrapper for Rust FFI calls
// This service provides a clean interface to the Rust backend via FFI
// Used on native platforms (iOS, Android, macOS, Windows, Linux)

import 'package:flutter/foundation.dart';
import '../models/book.dart';
import '../models/contact.dart';
import '../models/tag.dart';
import '../src/rust/api/frb.dart' as frb;
import 'dart:convert';

/// Service that wraps the FFI calls to the Rust backend
/// This is used on native platforms instead of HTTP
class FfiService {
  static final FfiService _instance = FfiService._internal();
  factory FfiService() => _instance;
  FfiService._internal();

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Mark as initialized after RustLib.init() and initBackend() succeed
  void markInitialized() {
    _isInitialized = true;
  }

  /// Health check
  String healthCheck() {
    try {
      return frb.healthCheck();
    } catch (e) {
      debugPrint('FFI healthCheck error: $e');
      return 'ERROR';
    }
  }

  /// Get version
  String getVersion() {
    try {
      return frb.getVersion();
    } catch (e) {
      debugPrint('FFI getVersion error: $e');
      return 'unknown';
    }
  }

  // ============ Books ============

  /// Get all books with optional filters
  Future<List<Book>> getBooks({
    String? status,
    String? title,
    String? tag,
  }) async {
    try {
      final frbBooks = await frb.getAllBooks(
        status: status,
        title: title,
        tag: tag,
      );
      return frbBooks.map(_frbBookToBook).toList();
    } catch (e) {
      debugPrint('FFI getBooks error: $e');
      rethrow;
    }
  }

  /// Get a single book by ID
  Future<Book> getBook(int id) async {
    try {
      final frbBook = await frb.getBookById(id: id);
      return _frbBookToBook(frbBook);
    } catch (e) {
      debugPrint('FFI getBook error: $e');
      rethrow;
    }
  }

  /// Count total books
  Future<int> countBooks() async {
    try {
      final count = await frb.countBooks();
      return count.toInt();
    } catch (e) {
      debugPrint('FFI countBooks error: $e');
      return 0;
    }
  }

  /// Get all tags with counts
  Future<List<Tag>> getTags() async {
    try {
      final tags = await frb.getAllTags();
      return tags.map((t) => Tag(name: t.$1, count: t.$2.toInt())).toList();
    } catch (e) {
      debugPrint('FFI getTags error: $e');
      return [];
    }
  }

  // ============ Contacts ============

  /// Get all contacts with optional filters
  Future<List<Contact>> getContacts({
    int? libraryId,
    String? type,
  }) async {
    try {
      final frbContacts = await frb.getAllContacts(
        libraryId: libraryId,
        contactType: type,
      );
      return frbContacts.map(_frbContactToContact).toList();
    } catch (e) {
      debugPrint('FFI getContacts error: $e');
      rethrow;
    }
  }

  /// Get a single contact by ID
  Future<Contact> getContact(int id) async {
    try {
      final frbContact = await frb.getContactById(id: id);
      return _frbContactToContact(frbContact);
    } catch (e) {
      debugPrint('FFI getContact error: $e');
      rethrow;
    }
  }

  /// Count total contacts
  Future<int> countContacts() async {
    try {
      final count = await frb.countContacts();
      return count.toInt();
    } catch (e) {
      debugPrint('FFI countContacts error: $e');
      return 0;
    }
  }

  // ============ Loans ============

  /// Count active loans
  Future<int> countActiveLoans() async {
    try {
      final count = await frb.countActiveLoans();
      return count.toInt();
    } catch (e) {
      debugPrint('FFI countActiveLoans error: $e');
      return 0;
    }
  }

  /// Return a loan
  Future<void> returnLoan(int id) async {
    try {
      await frb.returnLoan(id: id);
    } catch (e) {
      debugPrint('FFI returnLoan error: $e');
      rethrow;
    }
  }

  // ============ Books Write Operations ============
  
  Future<frb.FrbBook> createBook(frb.FrbBook book) async {
    try {
      return await frb.createBook(book: book);
    } catch (e) {
      debugPrint('FFI createBook error: $e');
      rethrow;
    }
  }

  Future<frb.FrbBook> updateBook(int id, frb.FrbBook book) async {
    try {
      return await frb.updateBook(id: id, book: book);
    } catch (e) {
      debugPrint('FFI updateBook error: $e');
      rethrow;
    }
  }

  Future<void> deleteBook(int id) async {
    try {
      await frb.deleteBook(id: id);
    } catch (e) {
      debugPrint('FFI deleteBook error: $e');
      rethrow;
    }
  }

  // ============ Converters ============

  /// Convert FrbBook to Book model
  Book _frbBookToBook(frb.FrbBook fb) {
    return Book(
      id: fb.id,
      title: fb.title,
      author: fb.author,
      isbn: fb.isbn,
      summary: fb.summary,
      publisher: fb.publisher,
      publicationYear: fb.publicationYear,
      coverUrl: fb.coverUrl, // largeCoverUrl derived from getter
      readingStatus: fb.readingStatus ?? 'to_read',
      userRating: fb.userRating,
      subjects: fb.subjects != null ? _parseSubjects(fb.subjects!) : null,
    );
  }

  /// Convert FrbContact to Contact model
  Contact _frbContactToContact(frb.FrbContact fc) {
    return Contact(
      id: fc.id,
      type: fc.contactType,
      name: fc.name,
      firstName: fc.firstName,
      email: fc.email,
      phone: fc.phone,
      address: fc.address,
      notes: fc.notes,
      isActive: fc.isActive,
      libraryOwnerId: 1, // Default to library 1 for FFI mode
    );
  }

  /// Parse subjects JSON string to list
  List<String>? _parseSubjects(String jsonStr) {
    try {
      if (jsonStr.isEmpty) return null;
      final parsed = jsonDecode(jsonStr);
      if (parsed is List) {
        return parsed.map((e) => e.toString()).toList();
      }
      return null;
    } catch (e) {
      debugPrint('Error parsing subjects JSON: $e');
      return null;
    }
  }
}
