import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../services/translation_service.dart';
import '../providers/theme_provider.dart';
import '../utils/book_status.dart';
import '../models/book.dart';
import '../services/open_library_service.dart';
import '../services/search_cache.dart';
import '../widgets/plus_one_animation.dart';
import '../widgets/cached_book_cover.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'scan_screen.dart';

class AddBookScreen extends StatefulWidget {
  final String? isbn;
  const AddBookScreen({super.key, this.isbn});

  @override
  State<AddBookScreen> createState() => _AddBookScreenState();
}

class _AddBookScreenState extends State<AddBookScreen> {
  final _formKey = GlobalKey<FormState>();
  final _openLibraryService = OpenLibraryService();
  final _searchCache = SearchCache();
  final _titleController = TextEditingController();
  final _publisherController = TextEditingController();
  final _publicationYearController = TextEditingController();
  final _isbnController = TextEditingController();
  final _summaryController = TextEditingController();
  final _authorController = TextEditingController();
  String? _readingStatus; // Initialized in didChangeDependencies
  String? _coverUrl;
  List<dynamic>? _authorsData;
  bool _isFetchingDetails = false;
  bool _isSaving = false;
  String? _lastLookedUpIsbn; // Prevent duplicate lookups
  final List<String> _selectedTags = [];
  final List<String> _authors = []; // Multiple authors support
  late TextEditingController _tagsController;
  final FocusNode _titleFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.isbn != null) {
      _isbnController.text = widget.isbn!;
      _fetchBookDetails(widget.isbn!);
    }
    _isbnController.addListener(_onIsbnChanged);
    _tagsController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize _readingStatus with correct default based on profile type
    if (_readingStatus == null) {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      _readingStatus = getDefaultStatus(themeProvider.isLibrarian);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _publisherController.dispose();
    _publicationYearController.dispose();
    _isbnController.dispose();
    _summaryController.dispose();
    _titleFocusNode.dispose();
    // _tagsController is managed by Autocomplete
    super.dispose();
  }

  void _onIsbnChanged() {
    final isbn = _isbnController.text.replaceAll(RegExp(r'[^0-9X]'), '');

    // Reset last lookup if ISBN changed significantly (not just adding digits)
    if (_lastLookedUpIsbn != null && !isbn.startsWith(_lastLookedUpIsbn!)) {
      _lastLookedUpIsbn = null;
    }

    // Only lookup if valid length, not currently fetching, and not already looked up
    if ((isbn.length == 10 || isbn.length == 13) &&
        !_isFetchingDetails &&
        isbn != _lastLookedUpIsbn) {
      _fetchBookDetails(isbn);
    }
  }

  Future<void> _fetchBookDetails(String isbn) async {
    _lastLookedUpIsbn = isbn; // Prevent duplicate lookups
    setState(() => _isFetchingDetails = true);
    try {
      // Use backend (Inventaire with OpenLibrary cover enrichment)
      final api = Provider.of<ApiService>(context, listen: false);
      final bookData = await api.lookupBook(isbn);

      if (bookData != null && mounted) {
        setState(() {
          if (_titleController.text.isEmpty)
            _titleController.text = bookData['title'] ?? '';

          // Handle authors
          _authors.clear();
          if (bookData['authors'] != null && bookData['authors'] is List) {
            _authors.addAll(List<String>.from(bookData['authors']));
          } else if (bookData['author'] != null) {
            _authors.add(bookData['author']);
          }
          // Also set text controller for fallback/display if needed
          _authorController.text = _authors.join(', ');

          if (_publisherController.text.isEmpty)
            _publisherController.text = bookData['publisher'] ?? '';
          if (_publicationYearController.text.isEmpty)
            _publicationYearController.text =
                bookData['year']?.toString() ?? '';
          if (_summaryController.text.isEmpty)
            _summaryController.text = bookData['summary'] ?? '';
          if (_coverUrl == null && bookData['cover_url'] != null) {
            _coverUrl = bookData['cover_url'];
          }
          if (bookData['authors_data'] != null) {
            _authorsData = bookData['authors_data'];
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              TranslationService.translate(context, 'book_details_found'),
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              TranslationService.translate(context, 'book_not_found') ??
                  'Book not found in database',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error fetching ISBN: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              TranslationService.translate(context, 'error_fetching_isbn') ??
                  'Error looking up ISBN. Please enter details manually.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isFetchingDetails = false);
    }
  }

  Future<void> _saveBook() async {
    if (!_formKey.currentState!.validate()) return;

    // Check for pending author
    if (_authorController.text.trim().isNotEmpty) {
      final pendingRaw = _authorController.text;
      // Only add if it's not already joined string of all authors (avoid duplication)
      if (pendingRaw != _authors.join(', ')) {
        final pending = pendingRaw.trim();
        if (!_authors.contains(pending)) {
          _authors.add(pending);
        }
      }
    }

    setState(() => _isSaving = true);

    final apiService = Provider.of<ApiService>(context, listen: false);
    final book = Book(
      title: _titleController.text,
      author: _authors.isNotEmpty
          ? _authors.join(', ')
          : _authorController.text,
      publisher: _publisherController.text,
      publicationYear: int.tryParse(_publicationYearController.text),
      isbn: _isbnController.text,
      readingStatus: _readingStatus,
      summary: _summaryController.text,
      coverUrl: _coverUrl,
      subjects: _selectedTags.isNotEmpty ? _selectedTags : null,
    );

    try {
      await apiService.createBook(book.toJson());
      if (mounted) {
        // Mario Bros-style +1 animation! 🎮
        PlusOneAnimation.show(context);

        // Small delay to let animation be visible before navigation
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) {
          context.pop(true); // Return true to indicate success
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${TranslationService.translate(context, 'error_saving_book')}: $e',
            ),
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(TranslationService.translate(context, 'add_book_title')),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/search/external'),
            icon: Icon(
              Icons.search,
              color: Theme.of(context).appBarTheme.foregroundColor,
            ),
            label: Text(
              TranslationService.translate(context, 'btn_search_online'),
              style: TextStyle(
                color: Theme.of(context).appBarTheme.foregroundColor,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0, left: 8.0),
            child: _isSaving
                ? Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).appBarTheme.foregroundColor,
                      ),
                    ),
                  )
                : TextButton(
                    onPressed: _saveBook,
                    key: const Key('saveBookButton'),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      foregroundColor: Theme.of(
                        context,
                      ).appBarTheme.foregroundColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    child: Text(
                      TranslationService.translate(context, 'save_book') ??
                          'Save',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.library_add,
                  size: 32,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 12),
                Text(
                  TranslationService.translate(context, 'add_new_book'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 32),

            // Title
            _buildLabel(TranslationService.translate(context, 'title_label')),
            LayoutBuilder(
              builder: (context, constraints) {
                return RawAutocomplete<Map<String, dynamic>>(
                  textEditingController: _titleController,
                  focusNode: _titleFocusNode,
                  optionsBuilder: (TextEditingValue textEditingValue) async {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<Map<String, dynamic>>.empty();
                    }

                    // Check cache first
                    final cached = _searchCache.get(textEditingValue.text);
                    if (cached != null) {
                      return cached;
                    }

                    // Use OpenLibrary for title search (better relevance, covers, authors)
                    // Inventaire search is too basic (missing authors) for autocomplete
                    final results = await _openLibraryService.searchBooks(
                      textEditingValue.text,
                    );

                    // Filter out "Independently Published" (POD/self-published reprints)
                    // These pollute results with low-quality editions of public domain works
                    final filteredResults = results.where((book) {
                      final publisher = book.toMap()['publisher'] as String?;
                      return publisher != 'Independently Published';
                    }).toList();

                    final resultMaps = filteredResults
                        .map((book) => book.toMap())
                        .toList();

                    // Cache the results
                    _searchCache.set(textEditingValue.text, resultMaps);

                    return resultMaps;
                  },
                  displayStringForOption: (option) => option['title'] ?? '',
                  onSelected: (Map<String, dynamic> selection) {
                    setState(() {
                      if (selection['title'] != null)
                        _titleController.text = selection['title'];
                      if (selection['author'] != null)
                        _authorController.text = selection['author'];
                      if (selection['isbn'] != null)
                        _isbnController.text = selection['isbn'];
                      if (selection['publisher'] != null)
                        _publisherController.text = selection['publisher'];
                      if (selection['publication_year'] != null)
                        _publicationYearController.text =
                            selection['publication_year'].toString();
                      if (selection['summary'] != null)
                        _summaryController.text = selection['summary'];
                      if (selection['cover_url'] != null)
                        _coverUrl = selection['cover_url'];
                    });
                  },
                  fieldViewBuilder:
                      (
                        context,
                        textEditingController,
                        focusNode,
                        onFieldSubmitted,
                      ) {
                        return TextFormField(
                          controller: textEditingController,
                          key: const Key('titleField'),
                          focusNode: focusNode,
                          decoration: _buildInputDecoration(
                            hint: TranslationService.translate(
                              context,
                              'enter_book_title',
                            ),
                            suffixIcon: const Icon(Icons.search),
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? TranslationService.translate(
                                  context,
                                  'enter_title_error',
                                )
                              : null,
                        );
                      },
                  optionsViewBuilder: (context, onSelected, options) {
                    final themeProvider = Provider.of<ThemeProvider>(
                      context,
                      listen: false,
                    );
                    final isJuniorReader = themeProvider.isKid;

                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4.0,
                        child: SizedBox(
                          width: constraints.maxWidth,
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (BuildContext context, int index) {
                              final option = options.elementAt(index);
                              final cover = option['cover_url'] as String?;
                              final author = option['author'] as String?;
                              final publisher = option['publisher'] as String?;

                              // For adults: show "Author • Publisher"
                              // For kids: show just "Author" (simpler)
                              String subtitle = author ?? '';
                              if (!isJuniorReader &&
                                  publisher != null &&
                                  publisher.isNotEmpty) {
                                if (subtitle.isNotEmpty) {
                                  subtitle += ' • $publisher';
                                } else {
                                  subtitle = publisher;
                                }
                              }

                              return ListTile(
                                leading: CompactBookCover(
                                  imageUrl: cover,
                                  size: 40,
                                ),
                                title: Text(option['title'] ?? ''),
                                subtitle: subtitle.isNotEmpty
                                    ? Text(
                                        subtitle,
                                        style: const TextStyle(fontSize: 12),
                                      )
                                    : null,
                                onTap: () => onSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 24),

            // Author
            _buildLabel(TranslationService.translate(context, 'author_label')),
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                return const Iterable<
                  String
                >.empty(); // No autocomplete for now, just manual
              },
              fieldViewBuilder:
                  (
                    context,
                    textEditingController,
                    focusNode,
                    onFieldSubmitted,
                  ) {
                    // Keep reference to controller for manual adding
                    if (_authorController != textEditingController) {
                      // If we are replacing the controller, we should copy the text if any
                      // But usually Autocomplete creates its own.
                      // Let's just use the one provided by Autocomplete for the input
                    }
                    return TextFormField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      decoration: _buildInputDecoration(
                        hint: TranslationService.translate(
                          context,
                          'author_hint',
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            if (textEditingController.text.trim().isNotEmpty) {
                              setState(() {
                                final val = textEditingController.text.trim();
                                if (!_authors.contains(val)) {
                                  _authors.add(val);
                                }
                                textEditingController.clear();
                              });
                            }
                          },
                        ),
                      ),
                      onFieldSubmitted: (String value) {
                        final trimmed = value.trim();
                        if (trimmed.isNotEmpty) {
                          setState(() {
                            if (!_authors.contains(trimmed)) {
                              _authors.add(trimmed);
                            }
                            textEditingController.clear();
                          });
                          // Keep focus for next entry
                          focusNode.requestFocus();
                        }
                      },
                    );
                  },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _authors.map((author) {
                return Chip(
                  label: Text(author),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () {
                    setState(() {
                      _authors.remove(author);
                    });
                  },
                );
              }).toList(),
            ),
            if (_authorsData != null && _authorsData!.isNotEmpty) ...[
              const SizedBox(height: 16),
              ..._authorsData!.map((author) {
                if (author is! Map) return const SizedBox.shrink();
                final name = author['name'] as String? ?? '';
                final bio = author['bio'] as String?;
                final imageUrl = author['image_url'] as String?;
                final birth = author['birth_year'] as String?;
                final death = author['death_year'] as String?;

                String lifeSpan = '';
                if (birth != null) lifeSpan += birth;
                if (death != null) {
                  lifeSpan += ' - $death';
                } else if (birth != null)
                  lifeSpan += ' - Present';

                if (bio == null && imageUrl == null && lifeSpan.isEmpty)
                  return const SizedBox.shrink();

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (imageUrl != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(40),
                              child: CachedNetworkImage(
                                imageUrl: imageUrl,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) =>
                                    const Icon(Icons.person, size: 40),
                              ),
                            ),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (lifeSpan.isNotEmpty)
                                Text(
                                  lifeSpan,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              if (bio != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  bio,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
            const SizedBox(height: 24),

            _buildLabel(TranslationService.translate(context, 'isbn_label')),
            TextFormField(
              key: const Key('isbnField'),
              controller: _isbnController,
              decoration: _buildInputDecoration(
                hint: TranslationService.translate(
                  context,
                  'enter_isbn_autofill',
                ),
                prefixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () async {
                    final result = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ScanScreen(),
                      ),
                    );
                    if (result != null && result.isNotEmpty) {
                      _isbnController.text = result;
                      _fetchBookDetails(result);
                    }
                  },
                  tooltip: TranslationService.translate(
                    context,
                    'scan_isbn_title',
                  ),
                ),
                suffixIcon: _isFetchingDetails
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () =>
                            _fetchBookDetails(_isbnController.text),
                        tooltip: TranslationService.translate(
                          context,
                          'lookup_isbn',
                        ),
                      ),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),

            // Publisher & Year
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel(
                        TranslationService.translate(
                          context,
                          'publisher_label',
                        ),
                      ),
                      TextFormField(
                        controller: _publisherController,
                        key: const Key('publisherField'),
                        decoration: _buildInputDecoration(
                          hint: TranslationService.translate(
                            context,
                            'publisher_hint',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel(
                        TranslationService.translate(context, 'year_label'),
                      ),
                      TextFormField(
                        controller: _publicationYearController,
                        key: const Key('yearField'),
                        decoration: _buildInputDecoration(
                          hint: TranslationService.translate(
                            context,
                            'year_hint',
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Summary
            _buildLabel(TranslationService.translate(context, 'summary_label')),
            TextFormField(
              key: const Key('summaryField'),
              controller: _summaryController,
              decoration: _buildInputDecoration(
                hint: TranslationService.translate(context, 'summary_hint'),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 24),

            // Status
            _buildLabel(TranslationService.translate(context, 'status_label')),
            Builder(
              builder: (context) {
                final themeProvider = Provider.of<ThemeProvider>(
                  context,
                  listen: false,
                );
                final isLibrarian = themeProvider.isLibrarian;
                final statusOptions = getStatusOptions(context, isLibrarian);

                // Ensure current value is valid for this mode
                final validValue =
                    statusOptions.any((s) => s.value == _readingStatus)
                    ? _readingStatus
                    : statusOptions.first.value;
                if (validValue != _readingStatus) {
                  // Update in next frame to avoid setState during build
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _readingStatus = validValue);
                  });
                }

                return DropdownButtonFormField<String>(
                  value: validValue,
                  decoration: _buildInputDecoration(),
                  items: statusOptions.map((status) {
                    return DropdownMenuItem<String>(
                      value: status.value,
                      child: Row(
                        children: [
                          Icon(status.icon, size: 20, color: status.color),
                          const SizedBox(width: 12),
                          Text(status.label),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _readingStatus = value),
                );
              },
            ),
            const SizedBox(height: 24),

            // Tags
            _buildLabel(TranslationService.translate(context, 'tags')),
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) async {
                if (textEditingValue.text == '') {
                  return const Iterable<String>.empty();
                }

                try {
                  final api = Provider.of<ApiService>(context, listen: false);
                  final tags = await api.getTags();
                  final tagNames = tags.map((t) => t.name).toList();

                  return tagNames.where((String option) {
                    return option.toLowerCase().contains(
                          textEditingValue.text.toLowerCase(),
                        ) &&
                        !_selectedTags.contains(option);
                  });
                } catch (e) {
                  return const Iterable<String>.empty();
                }
              },
              onSelected: (String selection) {
                setState(() {
                  final trimmed = selection.trim();
                  if (trimmed.isNotEmpty && !_selectedTags.contains(trimmed)) {
                    _selectedTags.add(trimmed);
                  }
                  _tagsController.clear();
                });
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                    _tagsController = controller;
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: _buildInputDecoration(
                        hint: TranslationService.translate(
                          context,
                          'add_tag_hint',
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            if (controller.text.trim().isNotEmpty) {
                              setState(() {
                                final val = controller.text.trim();
                                if (!_selectedTags.contains(val)) {
                                  _selectedTags.add(val);
                                }
                                controller.clear();
                              });
                            }
                          },
                        ),
                      ),
                      onFieldSubmitted: (String value) {
                        final trimmed = value.trim();
                        if (trimmed.isNotEmpty) {
                          setState(() {
                            if (!_selectedTags.contains(trimmed)) {
                              _selectedTags.add(trimmed);
                            }
                            controller.clear();
                          });
                          focusNode.requestFocus();
                        }
                      },
                    );
                  },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedTags.map((tag) {
                return Chip(
                  label: Text(tag),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () {
                    setState(() {
                      _selectedTags.remove(tag);
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // Save Button moved to AppBar
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    String? hint,
    Widget? suffixIcon,
    Widget? prefixIcon,
  }) {
    final borderColor = Theme.of(context).colorScheme.outline;
    return InputDecoration(
      hintText: hint,
      suffixIcon: suffixIcon,
      prefixIcon: prefixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
      ),
      filled: true,
      fillColor: null, // Uses theme InputDecorationTheme
    );
  }
}
