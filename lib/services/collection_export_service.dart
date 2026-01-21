import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/collection.dart';
import 'api_service.dart';

/// Service for exporting and sharing collections as YAML files.
class CollectionExportService {
  final ApiService _apiService;

  CollectionExportService(this._apiService);

  /// Export a collection to a shareable YAML format.
  /// Returns the YAML content as a string.
  Future<String> exportToYaml(
    Collection collection,
    List<dynamic> collectionBooks, {
    String? contributorName,
  }) async {
    final buffer = StringBuffer();

    // Header comment
    buffer.writeln('# BiblioGenius Curated List');
    buffer.writeln('# Exported: ${DateTime.now().toIso8601String()}');
    buffer.writeln('');

    // Metadata
    buffer.writeln('id: ${_sanitizeId(collection.name)}');
    buffer.writeln('version: 1');
    buffer.writeln('');

    // Title (single language for user export)
    buffer.writeln('title: "${_escapeYaml(collection.name)}"');

    if (collection.description != null && collection.description!.isNotEmpty) {
      buffer.writeln('description: "${_escapeYaml(collection.description!)}"');
    }
    buffer.writeln('');

    // Contributor
    if (contributorName != null && contributorName.isNotEmpty) {
      buffer.writeln('contributor: "${_escapeYaml(contributorName)}"');
    }
    buffer.writeln('');

    // Books (ISBN list)
    buffer.writeln('books:');
    for (final book in collectionBooks) {
      final isbn = book['isbn'] as String?;
      final title = book['title'] as String? ?? 'Unknown';
      final author = book['author'] as String? ?? 'Unknown';

      if (isbn != null && isbn.isNotEmpty) {
        // Include note with title/author for reference
        final note = '$title - $author';
        buffer.writeln('  - isbn: "$isbn"');
        buffer.writeln('    note: "${_escapeYaml(note)}"');
      }
    }

    return buffer.toString();
  }

  /// Share a collection via the system share sheet.
  Future<void> shareCollection(
    Collection collection, {
    String? contributorName,
  }) async {
    // Fetch books first
    final books = await _apiService.getCollectionBooks(collection.id);
    final yaml = await exportToYaml(
      collection,
      books,
      contributorName: contributorName,
    );

    if (kIsWeb) {
      // On web, just share the text directly
      await Share.share(yaml, subject: 'BiblioGenius: ${collection.name}');
    } else {
      // On mobile/desktop, create a temp file and share it
      final tempDir = await getTemporaryDirectory();
      final fileName = '${_sanitizeId(collection.name)}.bibliogenius.yml';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(yaml);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'BiblioGenius: ${collection.name}',
        text: 'Liste de lecture "${collection.name}" (${books.length} livres)',
      );
    }
  }

  /// Save a collection to a local file.
  Future<String> saveToFile(
    Collection collection, {
    String? contributorName,
    String? customPath,
  }) async {
    final books = await _apiService.getCollectionBooks(collection.id);
    final yaml = await exportToYaml(
      collection,
      books,
      contributorName: contributorName,
    );

    final directory = customPath != null
        ? Directory(customPath)
        : await getApplicationDocumentsDirectory();

    final fileName = '${_sanitizeId(collection.name)}.bibliogenius.yml';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(yaml);

    return file.path;
  }

  /// Generate a sanitized ID from a collection name.
  String _sanitizeId(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  /// Escape special characters for YAML strings.
  String _escapeYaml(String value) {
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n');
  }
}
