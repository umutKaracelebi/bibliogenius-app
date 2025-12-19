import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/copy.dart';
import '../services/translation_service.dart';

class BookCopiesScreen extends StatefulWidget {
  final int bookId;
  final String bookTitle;

  const BookCopiesScreen({
    super.key,
    required this.bookId,
    required this.bookTitle,
  });

  @override
  State<BookCopiesScreen> createState() => _BookCopiesScreenState();
}

class _BookCopiesScreenState extends State<BookCopiesScreen> {
  List<Copy> _copies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCopies();
  }

  Future<void> _fetchCopies() async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    try {
      final response = await apiService.getBookCopies(widget.bookId);
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['copies'];
        setState(() {
          _copies = data.map((json) => Copy.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addCopy() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddCopyDialog(),
    );

    if (result != null) {
      final apiService = Provider.of<ApiService>(context, listen: false);
      try {
        await apiService.createCopy({
          'book_id': widget.bookId,
          'library_id': 1, // Default library
          ...result,
        });
        _fetchCopies(); // Refresh list
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${TranslationService.translate(context, 'error_adding_copy')}: $e',
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteCopy(int copyId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(TranslationService.translate(context, 'delete_copy_title')),
        content: Text(
          TranslationService.translate(context, 'delete_copy_confirm'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(TranslationService.translate(context, 'cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              TranslationService.translate(context, 'delete_copy_btn'),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final apiService = Provider.of<ApiService>(context, listen: false);
      try {
        await apiService.deleteCopy(copyId);
        _fetchCopies(); // Refresh list
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${TranslationService.translate(context, 'error_deleting_copy')}: $e',
              ),
            ),
          );
        }
      }
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildCopySubtitle(BuildContext context, String? notes) {
    if (notes == null || notes.isEmpty) {
      return Text('No notes');
    }

    final regex = RegExp(r"Emprunté de (.+) jusqu'au (.+)");
    final match = regex.firstMatch(notes);

    if (match != null) {
      final lenderName = match.group(1) ?? 'Unknown Library';
      final rawDate = match.group(2) ?? '';
      final formattedDate = _formatDate(rawDate);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${TranslationService.translate(context, 'borrowed_from_label')}: $lenderName'),
          Text('${TranslationService.translate(context, 'due_date_label')}: $formattedDate'),
        ],
      );
    }

    return Text(notes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${TranslationService.translate(context, 'copies_title')} "${widget.bookTitle}"',
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _copies.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.library_books_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      TranslationService.translate(context, 'no_copies'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      TranslationService.translate(context, 'copies_explanation'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _addCopy,
                      key: const Key('addCopyButtonEmpty'),
                      icon: const Icon(Icons.add),
                      label: Text(TranslationService.translate(context, 'add_copy_title')),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              itemCount: _copies.length,
              itemBuilder: (context, index) {
                final copy = _copies[index];
                return ListTile(
                  leading: Icon(
                    copy.isTemporary ? Icons.schedule : Icons.book,
                    color: copy.isTemporary ? Colors.orange : null,
                  ),
                  title: Row(
                    children: [
                      Text(
                        '${TranslationService.translate(context, 'copy_number')} ${copy.id}',
                      ),
                      const SizedBox(width: 8),
                      _StatusBadge(status: copy.status),
                    ],
                  ),
                  subtitle: _buildCopySubtitle(context, copy.notes),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteCopy(copy.id!),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        key: const Key('addCopyFab'),
        onPressed: _addCopy,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AddCopyDialog extends StatefulWidget {
  @override
  State<_AddCopyDialog> createState() => _AddCopyDialogState();
}

class _AddCopyDialogState extends State<_AddCopyDialog> {
  final _notesController = TextEditingController();
  final _dateController = TextEditingController();
  String _selectedStatus = 'available';
  bool _isTemporary = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(TranslationService.translate(context, 'add_copy_title')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _dateController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: TranslationService.translate(context, 'acquisition_date'),
                hintText: 'YYYY-MM-DD',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      _dateController.text = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                    }
                  },
                ),
              ),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  _dateController.text = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              decoration: InputDecoration(labelText: TranslationService.translate(context, 'copy_status')),
              items: [
                DropdownMenuItem(
                  value: 'available',
                  child: Text(
                    TranslationService.translate(context, 'status_available'),
                  ),
                ),
                DropdownMenuItem(
                  value: 'borrowed',
                  child: Text(
                    TranslationService.translate(context, 'status_borrowed'),
                  ),
                ),
                DropdownMenuItem(
                  value: 'lost',
                  child: Text(
                    TranslationService.translate(context, 'status_lost'),
                  ),
                ),
                DropdownMenuItem(
                  value: 'damaged',
                  child: Text(
                    TranslationService.translate(context, 'status_damaged'),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: Text(
                TranslationService.translate(context, 'is_temporary_copy'),
              ),
              value: _isTemporary,
              onChanged: (value) {
                setState(() {
                  _isTemporary = value!;
                });
              },
            ),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(labelText: TranslationService.translate(context, 'notes_label')),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(TranslationService.translate(context, 'cancel')),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop({
              'acquisition_date': _dateController.text.isEmpty
                  ? null
                  : _dateController.text,
              'notes': _notesController.text.isEmpty
                  ? null
                  : _notesController.text,
              'status': _selectedStatus,
              'is_temporary': _isTemporary,
            });
          },
          key: const Key('saveCopyButton'),
          child: Text(TranslationService.translate(context, 'add_peer_btn')),
        ),
      ],
    );
  }
}

// Status badge widget
class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case 'available':
        color = Colors.green;
        label = TranslationService.translate(context, 'status_available');
        break;
      case 'borrowed':
        color = Colors.blue;
        label = TranslationService.translate(context, 'status_checked_out');
        break;
      case 'wanted':
        color = Colors.purple;
        label = TranslationService.translate(context, 'status_wanted');
        break;
      case 'lost':
        color = Colors.red;
        label = TranslationService.translate(context, 'status_lost');
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
