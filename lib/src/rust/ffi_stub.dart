// Stub implementation of FFI for platforms where Rust library is not available (iOS)
// This prevents the app from crashing by providing no-op implementations

import 'dart:async';

/// Stub for RustLib that does nothing
class RustLib {
  static Future<void> init({dynamic externalLibrary}) async {
    // No-op - Rust library not available on this platform
  }
}

/// Stub for ExternalLibrary
class ExternalLibrary {
  static dynamic process({bool iKnowHowToUseIt = false}) {
    return null;
  }
}

/// Stub FFI functions that throw if called
Future<String> initBackend({required String dbPath}) async {
  throw UnsupportedError('FFI not available on this platform');
}

Future<List<dynamic>> getBooks({required int libraryId}) async {
  throw UnsupportedError('FFI not available on this platform');
}

// Add more stub functions as needed
