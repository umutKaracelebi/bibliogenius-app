import 'package:flutter/material.dart';
import '../widgets/genie_app_bar.dart';
import '../widgets/cached_book_cover.dart';
import '../widgets/plus_one_animation.dart';
import '../widgets/work_edition_card.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/translation_service.dart';
import '../providers/theme_provider.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_design.dart';
import '../utils/global_keys.dart';

class ExternalSearchScreen extends StatefulWidget {
  const ExternalSearchScreen({super.key});

  @override
  State<ExternalSearchScreen> createState() => _ExternalSearchScreenState();
}

class _ExternalSearchScreenState extends State<ExternalSearchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _subjectController = TextEditingController();

  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _groupedWorks = [];
  bool _isSearching = false;
  String? _error;
  bool _booksAdded = false;
  bool _showAdvancedFilters = false; // Collapsed by default on mobile

  // Source filter (upstream - before search)
  String?
  _upstreamSource; // null = all sources, "inventaire", "bnf", "openlibrary"
  static const _sourceOptions = [
    {'value': null, 'label': 'Toutes les sources'},
    {'value': 'inventaire', 'label': 'Inventaire.io'},
    {'value': 'openlibrary', 'label': 'Open Library'},
    {'value': 'bnf', 'label': 'data.bnf.fr'},
  ];
  Set<String> _availableSources =
      {}; // Populated from search results for post-filtering

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  /// Normalize a title for grouping purposes
  String _normalizeTitle(String title) {
    return title
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
  }

  /// Group search results by work (title + author combination)
  List<Map<String, dynamic>> _groupResultsByWork(
    List<Map<String, dynamic>> results,
  ) {
    final Map<String, Map<String, dynamic>> workMap = {};

    for (final book in results) {
      final title = book['title'] as String? ?? '';
      final author = book['author'] as String? ?? '';
      final normalizedTitle = _normalizeTitle(title);
      final normalizedAuthor = author.toLowerCase().trim();

      // Create a key from normalized title and author
      final workKey = '$normalizedTitle|$normalizedAuthor';

      if (workMap.containsKey(workKey)) {
        // Add to existing work's editions
        (workMap[workKey]!['editions'] as List).add(book);
      } else {
        // Create new work entry
        workMap[workKey] = {
          'work_id': workKey,
          'title': title,
          'author': author.isNotEmpty ? author : null,
          'editions': [book],
        };
      }
    }

    // Sort editions within each work by publication year (newest first)
    for (final work in workMap.values) {
      final editions = work['editions'] as List<Map<String, dynamic>>;
      editions.sort((a, b) {
        final yearA = a['publication_year'] as int?;
        final yearB = b['publication_year'] as int?;
        if (yearA == null && yearB == null) return 0;
        if (yearA == null) return 1;
        if (yearB == null) return -1;
        return yearB.compareTo(yearA);
      });
    }

    return workMap.values.toList();
  }

  Future<void> _search() async {
    if (_titleController.text.isEmpty &&
        _authorController.text.isEmpty &&
        _subjectController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            TranslationService.translate(context, 'enter_search_term'),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _error = null;
      _searchResults = [];
      _groupedWorks = [];
    });

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      // Get user's language for relevance boosting
      final userLang = Localizations.localeOf(context).languageCode;

      // Use unified search (Inventaire + OpenLibrary + BNF)
      final results = await api.searchBooks(
        title: _titleController.text,
        author: _authorController.text,
        subject: _subjectController.text,
        lang: userLang, // Boost results in user's language
        source: _upstreamSource, // Filter to specific source(s)
      );

      // Extract available sources from results
      final sources = results
          .map((r) => r['source'] as String?)
          .where((s) => s != null && s.isNotEmpty)
          .cast<String>()
          .toSet();

      setState(() {
        _searchResults = results;
        _groupedWorks = _groupResultsByWork(results);
        _availableSources = sources;
        // Debug: Print grouping info
        debugPrint('🔍 Search returned ${results.length} results');
        debugPrint('📚 Grouped into ${_groupedWorks.length} works');
        debugPrint('🗂️ Sources: $sources');
        for (final work in _groupedWorks) {
          final editions = work['editions'] as List;
          debugPrint('  - "${work['title']}": ${editions.length} edition(s)');
        }
      });
    } catch (e) {
      setState(() {
        _error =
            '${TranslationService.translate(context, 'search_failed')}: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _addBook(Map<String, dynamic> doc) async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final isbn = doc['isbn'] as String?;

      // Check if ISBN already exists in library
      if (isbn != null && isbn.isNotEmpty) {
        final existingBook = await api.findBookByIsbn(isbn);
        if (existingBook != null && mounted) {
          // Show duplicate dialog
          final action = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      TranslationService.translate(
                        context,
                        'isbn_already_exists',
                      ),
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${existingBook.title}${existingBook.author != null ? '\n${existingBook.author}' : ''}',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'cancel'),
                  child: Text(TranslationService.translate(context, 'cancel')),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'view'),
                  icon: const Icon(Icons.visibility),
                  label: Text(
                    TranslationService.translate(context, 'view_existing'),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'copy'),
                  icon: const Icon(Icons.add),
                  label: Text(
                    TranslationService.translate(context, 'add_copy'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );

          if (action == 'view' && mounted) {
            context.push('/books/${existingBook.id}');
          } else if (action == 'copy' && mounted) {
            await api.createCopy({
              'book_id': existingBook.id,
              'status': 'available',
            });
            _booksAdded = true;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  TranslationService.translate(context, 'copy_added'),
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
          return; // Don't create duplicate
        }
      }

      // Map unified search result (Book DTO) to create payload
      final bookData = {
        'title': doc['title'],
        'author': doc['author'], // Already a string in DTO
        // publication_year is int in DTO
        'publication_year': doc['publication_year'],
        'publisher': doc['publisher'],
        'isbn': doc['isbn'],
        'summary': doc['summary'],
        'reading_status': 'to_read',
        'cover_url': doc['cover_url'],
      };

      await api.createBook(bookData);

      // Mark as modified so we can refresh the list on return
      _booksAdded = true;

      if (mounted) {
        // Mario Bros-style +1 animation! 🎮
        PlusOneAnimation.show(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '"${doc['title']}" ${TranslationService.translate(context, 'added_to_library')}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${TranslationService.translate(context, 'failed_add_book')}: $e',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final theme = Provider.of<ThemeProvider>(context);
    final useEditionBrowser = theme.editionBrowserEnabled;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        context.pop(_booksAdded);
      },
      child: Scaffold(
        appBar: GenieAppBar(
          title: TranslationService.translate(context, 'external_search_title'),
          leading: isMobile
              ? IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () {
                    GlobalKeys.rootScaffoldKey.currentState?.openDrawer();
                  },
                )
              : IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.pop(_booksAdded),
                ),
          automaticallyImplyLeading: false,
        ),
        extendBodyBehindAppBar: true,
        body: Container(
          decoration: BoxDecoration(
            gradient: AppDesign.pageGradientForTheme(theme.themeStyle),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Compact search bar - always visible
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Form(
                    key: _formKey,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              hintText: TranslationService.translate(
                                context,
                                'search_placeholder',
                              ),
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              isDense: true,
                            ),
                            textInputAction: TextInputAction.search,
                            onFieldSubmitted: (_) => _search(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Filter toggle button
                        IconButton(
                          icon: Icon(
                            _showAdvancedFilters
                                ? Icons.filter_list_off
                                : Icons.filter_list,
                            color: _showAdvancedFilters
                                ? Theme.of(context).primaryColor
                                : null,
                          ),
                          tooltip: TranslationService.translate(
                            context,
                            'advanced_filters',
                          ),
                          onPressed: () {
                            setState(() {
                              _showAdvancedFilters = !_showAdvancedFilters;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        // Search button
                        FilledButton(
                          onPressed: _isSearching ? null : _search,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          child: _isSearching
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.search),
                        ),
                      ],
                    ),
                  ),
                ),
                // Source filter - always visible (compact horizontal row)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _sourceOptions.map((option) {
                        final isSelected = _upstreamSource == option['value'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(option['label'] as String),
                            selected: isSelected,
                            onSelected: (_) {
                              setState(
                                () => _upstreamSource =
                                    option['value'] as String?,
                              );
                            },
                            selectedColor: Theme.of(context).primaryColor,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : null,
                              fontSize: 12,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                // Collapsible advanced filters
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _authorController,
                          decoration: InputDecoration(
                            labelText: TranslationService.translate(
                              context,
                              'author_label',
                            ),
                            prefixIcon: const Icon(Icons.person, size: 20),
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            isDense: true,
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _subjectController,
                          decoration: InputDecoration(
                            labelText: TranslationService.translate(
                              context,
                              'subject_label',
                            ),
                            prefixIcon: const Icon(Icons.category, size: 20),
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            isDense: true,
                          ),
                          onFieldSubmitted: (_) => _search(),
                        ),
                      ],
                    ),
                  ),
                  crossFadeState: _showAdvancedFilters
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                Expanded(
                  child: useEditionBrowser
                      ? _buildGroupedView()
                      : _buildFlatListView(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Grouped view with edition cards (Gleeph-style)
  Widget _buildGroupedView() {
    if (_groupedWorks.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      itemCount: _groupedWorks.length,
      itemBuilder: (context, index) {
        final work = _groupedWorks[index];
        final editions = List<Map<String, dynamic>>.from(
          work['editions'] as List,
        );

        return WorkEditionCard(
          workId: work['work_id'] as String,
          title: work['title'] as String,
          author: work['author'] as String?,
          editions: editions,
          onAddBook: _addBook,
        );
      },
    );
  }

  /// Classic flat list view
  Widget _buildFlatListView() {
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final book = _searchResults[index];

        return ListTile(
          leading: CompactBookCover(imageUrl: book['cover_url'], size: 50),
          title: Text(
            book['title'] ??
                TranslationService.translate(context, 'unknown_title'),
          ),
          subtitle: Text(
            book['author'] ??
                TranslationService.translate(context, 'unknown_author'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _addBook(book),
          ),
          onTap: () {
            // Show details?
          },
        );
      },
    );
  }
}
