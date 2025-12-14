// Stub implementation for platforms where FFI is not available
// This file is used instead of frb.dart on iOS

import 'dart:async';

/// Initialize the FFI backend - stub version
Future<String> initBackend({required String dbPath}) async {
  throw UnsupportedError('FFI not available on this platform - use HTTP mode');
}

/// Get all books - stub version
Future<List<dynamic>> getBooks({required int libraryId}) async {
  throw UnsupportedError('FFI not available on this platform - use HTTP mode');
}

/// Add a book - stub version
Future<dynamic> addBook({
  required int libraryId,
  required String title,
  String? author,
  String? isbn,
  String? publisher,
  int? publicationYear,
  String? summary,
  String? coverUrl,
  String? readingStatus,
}) async {
  throw UnsupportedError('FFI not available on this platform - use HTTP mode');
}

/// Get a single book - stub version
Future<dynamic> getBook({required int bookId}) async {
  throw UnsupportedError('FFI not available on this platform - use HTTP mode');
}

/// Update a book - stub version
Future<String> updateBook({
  required int bookId,
  String? title,
  String? author,
  String? isbn,
  String? publisher,
  int? publicationYear,
  String? summary,
  String? coverUrl,
  String? readingStatus,
}) async {
  throw UnsupportedError('FFI not available on this platform - use HTTP mode');
}

/// Delete a book - stub version
Future<String> deleteBook({required int bookId}) async {
  throw UnsupportedError('FFI not available on this platform - use HTTP mode');
}

/// Get contacts - stub version
Future<List<dynamic>> getContacts({required int libraryId}) async {
  throw UnsupportedError('FFI not available on this platform - use HTTP mode');
}
