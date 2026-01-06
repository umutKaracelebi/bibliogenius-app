import '../../models/collection.dart';
import '../../models/collection_book.dart';
import '../../services/api_service.dart';
import '../../services/translation_service.dart';
import '../../widgets/cached_book_cover.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';

class CollectionDetailScreen extends StatefulWidget {
  final Collection collection;

  const CollectionDetailScreen({Key? key, required this.collection})
    : super(key: key);

  @override
  _CollectionDetailScreenState createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  late Future<List<CollectionBook>> _booksFuture;

  @override
  void initState() {
    super.initState();
    _refreshBooks();
  }

  void _refreshBooks() {
    setState(() {
      _booksFuture = Provider.of<ApiService>(context, listen: false)
          .getCollectionBooks(widget.collection.id)
          .then(
            (list) =>
                list.map((item) => CollectionBook.fromJson(item)).toList(),
          );
    });
  }

  Future<void> _deleteCollection() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Collection?'),
        content: Text(
          'Are you sure you want to delete "${widget.collection.name}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      try {
        await Provider.of<ApiService>(
          context,
          listen: false,
        ).deleteCollection(widget.collection.id);
        if (mounted) {
          context.pop(); // Go back to list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting collection: $e')),
          );
        }
      }
    }
  }

  Future<void> _importBooks() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'json', 'txt'],
      );

      if (result != null) {
        final platformFile = result.files.single;
        dynamic fileSource;
        if (platformFile.bytes != null) {
          fileSource = platformFile.bytes;
        } else if (platformFile.path != null) {
          fileSource = platformFile.path;
        } else {
          throw Exception('No file content found');
        }

        if (!mounted) return;

        bool importAsOwned = false;
        final shouldImport = await showDialog<bool>(
          context: context,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: const Text('Import Books'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Selected file: ${platformFile.name}'),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        title: Text(
                          TranslationService.translate(context, 'status_owned'),
                        ),
                        subtitle: const Text('Add to library copies'),
                        value: importAsOwned,
                        onChanged: (val) {
                          setState(() => importAsOwned = val ?? false);
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        TranslationService.translate(context, 'action_cancel'),
                      ),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Import'),
                    ),
                  ],
                );
              },
            );
          },
        );

        if (shouldImport != true) return;

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Importing books...')));
        }

        final response = await Provider.of<ApiService>(context, listen: false)
            .importCollectionBooks(
              widget.collection.id,
              fileSource,
              filename: platformFile.name,
              importAsOwned: importAsOwned,
            );

        if (response.statusCode == 200) {
          final data = response.data;
          final imported = data['imported'] ?? 0;
          final errors = data['errors']; // Optional list of errors

          if (mounted) {
            String msg = 'Successfully imported $imported books.';
            if (errors != null && (errors as List).isNotEmpty) {
              msg += ' ${errors.length} skipped.';
            }
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(msg)));
          }
          _refreshBooks();
        } else {
          throw Exception('Failed to import: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error importing books: $e')));
      }
    }
  }

  Future<void> _removeBook(CollectionBook book) async {
    try {
      await Provider.of<ApiService>(
        context,
        listen: false,
      ).removeBookFromCollection(widget.collection.id, book.bookId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed "${book.title}" from collection')),
      );
      _refreshBooks();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error removing book: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.collection.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _importBooks,
            tooltip: 'Import Books',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteCollection,
            tooltip: 'Delete Collection',
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.collection.description != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                widget.collection.description!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: FutureBuilder<List<CollectionBook>>(
              future: _booksFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('No books in this collection yet.'),
                  );
                }

                final books = snapshot.data!;
                return ListView.builder(
                  itemCount: books.length,
                  itemBuilder: (context, index) {
                    final book = books[index];
                    return Dismissible(
                      key: Key('collection_book_${book.bookId}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Remove Book?'),
                            content: Text(
                              'Remove "${book.title}" from this collection?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Remove'),
                              ),
                            ],
                          ),
                        );
                      },
                      onDismissed: (direction) {
                        _removeBook(book);
                      },
                      child: ListTile(
                        leading: CachedBookCover(
                          imageUrl: book.coverUrl,
                          width: 40,
                          height: 60,
                        ),
                        title: Text(
                          book.title,
                          style: TextStyle(
                            decoration: book.isOwned
                                ? null
                                : TextDecoration.none, // Maybe strike? No.
                            color: book.isOwned ? null : Colors.grey,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (book.author != null) Text(book.author!),
                            Text(
                              '${TranslationService.translate(context, 'added_date_label')} ${DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(book.addedAt)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        trailing: InkWell(
                          onTap: () => _toggleBookStatus(book),
                          borderRadius: BorderRadius.circular(12),
                          child: book.isOwned
                              ? Tooltip(
                                  message:
                                      '${TranslationService.translate(context, 'status_owned')} (Tap to toggle)',
                                  child: const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    ),
                                  ),
                                )
                              : Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    TranslationService.translate(
                                      context,
                                      'status_wanted',
                                    ),
                                    style: const TextStyle(
                                      color: Colors.orange,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                        ),
                        onTap: () {
                          // Navigate to book details
                          context.push('/books/${book.bookId}');
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBookStatus(CollectionBook book) async {
    try {
      final newStatus = !book.isOwned;
      final api = Provider.of<ApiService>(context, listen: false);

      // 1. Update the book's owned status
      await api.updateBook(book.bookId, {'owned': newStatus});

      // 2. If becoming owned, check/create copy
      if (newStatus) {
        final copiesRes = await api.getBookCopies(book.bookId);
        final List copies = copiesRes.data['copies'] ?? [];

        if (copies.isEmpty) {
          await api.createCopy({
            'book_id': book.bookId,
            'library_id': 1, // Default library
            'status': 'available',
            'is_temporary': false,
          });
          if (mounted) {
            // Optional: Show specific message about copy creation or just rely on generic status update
            // Ideally we just inform the user that it's now owned.
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Marked "${book.title}" as ${newStatus ? 'Owned' : 'Wanted'}',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
        _refreshBooks();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating status: $e')));
      }
    }
  }
}
