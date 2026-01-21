import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/api_service.dart';
import '../../services/collection_import_service.dart';
import '../../services/translation_service.dart';

/// Screen for importing a shared .bibliogenius.yml file.
class ImportSharedListScreen extends StatefulWidget {
  final String? initialYamlContent;

  const ImportSharedListScreen({Key? key, this.initialYamlContent})
    : super(key: key);

  @override
  State<ImportSharedListScreen> createState() => _ImportSharedListScreenState();
}

class _ImportSharedListScreenState extends State<ImportSharedListScreen> {
  String? _yamlContent;
  Map<String, dynamic>? _preview;
  String? _validationError;
  bool _isImporting = false;
  String _selectedStatus = 'wanting';

  @override
  void initState() {
    super.initState();
    if (widget.initialYamlContent != null) {
      _processYaml(widget.initialYamlContent!);
    }
  }

  void _processYaml(String content) {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final importService = CollectionImportService(apiService);

    final error = importService.validateYaml(content);
    final preview = importService.getPreview(content);

    setState(() {
      _yamlContent = content;
      _validationError = error;
      _preview = preview;
    });
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['yml', 'yaml', 'bibliogenius'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        String content;

        if (file.bytes != null) {
          content = String.fromCharCodes(file.bytes!);
        } else if (file.path != null) {
          content = await File(file.path!).readAsString();
        } else {
          throw Exception('Could not read file');
        }

        _processYaml(content);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error reading file: $e')));
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && data!.text!.isNotEmpty) {
        _processYaml(data.text!);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Clipboard is empty')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error reading clipboard: $e')));
      }
    }
  }

  Future<void> _importCollection() async {
    if (_yamlContent == null || _validationError != null) return;

    setState(() {
      _isImporting = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final importService = CollectionImportService(apiService);

      final result = await importService.importFromYaml(
        _yamlContent!,
        readingStatus: _selectedStatus == 'owned' ? 'to_read' : _selectedStatus,
        markAsOwned: _selectedStatus != 'wanting',
      );

      if (mounted) {
        String message =
            'Collection "${result.collection?.name ?? "Unknown"}" created with ${result.successCount} books.';
        if (result.errorCount > 0) {
          message += ' ${result.errorCount} could not be imported.';
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));

        Navigator.pop(context, true); // Return success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Shared List')),
      body: _isImporting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Importing collection...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Source selection
                  if (_yamlContent == null) ...[
                    const Text(
                      'Choose a source:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Pick file button
                    OutlinedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.file_open),
                      label: const Text('Select .bibliogenius.yml file'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Paste button
                    OutlinedButton.icon(
                      onPressed: _pasteFromClipboard,
                      icon: const Icon(Icons.paste),
                      label: const Text('Paste from clipboard'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Info card
                    Card(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Supported formats',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              '• .bibliogenius.yml files\n'
                              '• .yaml or .yml files\n'
                              '• YAML content from clipboard',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Preview
                  if (_yamlContent != null) ...[
                    if (_validationError != null)
                      Card(
                        color: Colors.red.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.error, color: Colors.red),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _validationError!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_preview != null) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _preview!['title'] ?? 'Untitled',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              if (_preview!['description'] != null) ...[
                                const SizedBox(height: 8),
                                Text(_preview!['description']),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.book, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_preview!['bookCount']} books',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge,
                                  ),
                                ],
                              ),
                              if (_preview!['contributor'] != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.person, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'By ${_preview!['contributor']}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Status selection
                      const Text(
                        'Book status after import:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'owned',
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  TranslationService.translate(
                                    context,
                                    'status_owned',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'to_read',
                            child: Row(
                              children: [
                                const Icon(Icons.bookmark_border, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  TranslationService.translate(
                                    context,
                                    'status_to_read',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'wanting',
                            child: Row(
                              children: [
                                const Icon(Icons.favorite_border, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  TranslationService.translate(
                                    context,
                                    'status_wanted',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedStatus = val ?? 'wanting';
                          });
                        },
                      ),

                      const SizedBox(height: 24),

                      // Import button
                      FilledButton.icon(
                        onPressed: _importCollection,
                        icon: const Icon(Icons.download),
                        label: const Text('Import Collection'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Cancel/Choose different file
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _yamlContent = null;
                            _preview = null;
                            _validationError = null;
                          });
                        },
                        child: const Text('Choose a different file'),
                      ),
                    ],
                  ],
                ],
              ),
            ),
    );
  }
}
