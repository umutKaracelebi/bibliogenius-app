import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';

class BookUrlHelper {
  /// Extract the source URL from the book's source_data
  static String? getUrl(Map<String, dynamic> bookData) {
    // If source_data is missing or empty, return null
    if (bookData['source_data'] == null) return null;

    try {
      final sourceDataStr = bookData['source_data'];
      // Handle case where source_data might already be parsed (though usually it's a string from backend)
      final Map<String, dynamic> sourceData = sourceDataStr is String
          ? jsonDecode(sourceDataStr)
          : Map<String, dynamic>.from(sourceDataStr);

      final source = sourceData['source'] as String?;

      if (source == 'inventaire') {
        final uri = sourceData['uri'] as String?;
        if (uri != null && uri.isNotEmpty) {
          if (uri.startsWith('http')) return uri;
          return 'https://inventaire.io/entity/$uri';
        }
        return null;
      } else if (source == 'bnf') {
        return sourceData['bnf_uri'] as String?;
      } else if (source == 'openlibrary' || source == null) {
        // key is usually like "/works/OL12345W"
        final key = sourceData['key'] as String?;
        if (key != null && key.isNotEmpty) {
          return 'https://openlibrary.org$key';
        }
      }
    } catch (e) {
      // json decode error or type error
      return null;
    }
    return null;
  }

  /// Check if internet is available
  static Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none);
  }
}
