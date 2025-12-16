import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/contact.dart';
import '../services/translation_service.dart';
import '../services/api_service.dart';
import '../providers/theme_provider.dart';
import 'add_contact_screen.dart';
import 'scan_screen.dart';

class ContactDetailsScreen extends StatefulWidget {
  final Contact contact;

  const ContactDetailsScreen({super.key, required this.contact});

  @override
  State<ContactDetailsScreen> createState() => _ContactDetailsScreenState();
}

class _ContactDetailsScreenState extends State<ContactDetailsScreen> {
  late Contact _contact;

  @override
  void initState() {
    super.initState();
    _contact = widget.contact;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          TranslationService.translate(context, 'contact_details_title') ??
              'Contact Details',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddContactScreen(contact: _contact),
                ),
              );

              if (result == true && mounted) {
                // Refresh contact details
                try {
                  final apiService = Provider.of<ApiService>(context, listen: false);
                  final response = await apiService.getContact(_contact.id!);
                  if (response.statusCode == 200 && response.data != null) {
                    setState(() {
                      // Handle both response formats (with or without 'contact' key)
                      if (response.data['contact'] != null) {
                        _contact = Contact.fromJson(response.data['contact']);
                      } else {
                        _contact = Contact.fromJson(response.data);
                      }
                    });
                  }
                } catch (e) {
                  debugPrint('Error refreshing contact: $e');
                }
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundColor: _contact.type == 'borrower'
                  ? Colors.blue
                  : Colors.purple,
              child: Icon(
                _contact.type == 'borrower'
                    ? Icons.person
                    : Icons.library_books,
                size: 50,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              _contact.fullName,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              if (!Provider.of<ThemeProvider>(context).isLibrarian) ...[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _borrowFromContact(context),
                    icon: const Icon(Icons.book_outlined),
                    label: Text(
                      TranslationService.translate(
                            context,
                            'borrow_from_contact',
                          ) ??
                          'Borrow a book',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _lendToContact(context),
                  icon: const Icon(Icons.handshake_outlined),
                  label: Text(
                    TranslationService.translate(context, 'lend_to_contact') ??
                        'Lend a book',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.purple,
                    side: const BorderSide(color: Colors.purple),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          _buildInfoCard(
            context,
            TranslationService.translate(context, 'contact_type_label'),
            _contact.type == 'borrower'
                ? TranslationService.translate(context, 'role_borrower')
                : TranslationService.translate(context, 'role_library'),
          ),
          if (_contact.firstName != null && _contact.firstName!.isNotEmpty)
            _buildInfoCard(
              context,
              TranslationService.translate(context, 'contact_first_name_label') ??
                  'First Name',
              _contact.firstName!,
            ),
          _buildInfoCard(
            context,
            TranslationService.translate(context, 'contact_name_label'),
            _contact.name,
          ),
          if (_contact.email != null)
            _buildInfoCard(
              context,
              TranslationService.translate(context, 'contact_email_label'),
              _contact.email!,
            ),
          if (_contact.phone != null)
            _buildInfoCard(
              context,
              TranslationService.translate(context, 'contact_phone_label'),
              _contact.phone!,
            ),
          if (_contact.formattedAddress.isNotEmpty)
            _buildInfoCard(
              context,
              TranslationService.translate(context, 'contact_address_label'),
              _contact.formattedAddress,
            ),
          if (_contact.notes != null)
            _buildInfoCard(
              context,
              TranslationService.translate(context, 'contact_notes_label'),
              _contact.notes!,
            ),
          _buildInfoCard(
            context,
            TranslationService.translate(context, 'status_label'),
            _contact.isActive
                ? TranslationService.translate(context, 'status_active')
                : TranslationService.translate(context, 'status_inactive'),
            valueColor: _contact.isActive ? Colors.green : Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 16, color: valueColor)),
          ],
        ),
      ),
    );
  }

  Future<void> _borrowFromContact(BuildContext context) async {
    // Show dialog to add a book that was borrowed from this contact
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _BorrowBookDialog(contact: _contact),
    );

    if (result == null || !context.mounted) return;

    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      // Create the book with borrowed status
      final bookData = {
        'title': result['title'],
        'author': result['author'],
        'isbn': result['isbn'],
        'reading_status': 'borrowed',
      };

      final response = await apiService.createBook(bookData);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${TranslationService.translate(context, 'book_borrowed_from') ?? 'Book borrowed from'} ${_contact.displayName}',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _lendToContact(BuildContext context) async {
    // Navigate to book list to select a book to lend
    context.push('/books?action=select_for_loan&contact_id=${_contact.id}');
  }
}

class _BorrowBookDialog extends StatefulWidget {
  final Contact contact;

  const _BorrowBookDialog({required this.contact});

  @override
  State<_BorrowBookDialog> createState() => _BorrowBookDialogState();
}

class _BorrowBookDialogState extends State<_BorrowBookDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _isbnController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _isbnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        TranslationService.translate(context, 'borrow_book_title') ??
            'Borrow a Book',
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${TranslationService.translate(context, 'borrowing_from') ?? 'Borrowing from'} ${widget.contact.displayName}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText:
                      TranslationService.translate(context, 'title_label') ??
                      'Title',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return TranslationService.translate(
                          context,
                          'title_required',
                        ) ??
                        'Title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _authorController,
                decoration: InputDecoration(
                  labelText:
                      TranslationService.translate(context, 'author_label') ??
                      'Author',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _isbnController,
                decoration: InputDecoration(
                  labelText: 'ISBN',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: () async {
                      // Navigate to scan screen and get result
                      final result = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ScanScreen(),
                        ),
                      );
                      if (result != null && result.isNotEmpty) {
                        _isbnController.text = result;
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            TranslationService.translate(context, 'cancel') ?? 'Cancel',
          ),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop({
                'title': _titleController.text,
                'author': _authorController.text.isEmpty
                    ? null
                    : _authorController.text,
                'isbn': _isbnController.text.isEmpty
                    ? null
                    : _isbnController.text,
              });
            }
          },
          child: Text(
            TranslationService.translate(context, 'borrow_btn') ?? 'Borrow',
          ),
        ),
      ],
    );
  }
}
