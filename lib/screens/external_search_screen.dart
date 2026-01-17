import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/genie_app_bar.dart';

import '../widgets/plus_one_animation.dart';
import '../widgets/work_edition_card.dart';
import '../widgets/search_result_card.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/translation_service.dart';
import '../providers/theme_provider.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_design.dart';
import '../utils/global_keys.dart';
import '../utils/book_url_helper.dart';
import 'web_view_screen.dart';

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

  // Dynamic source options based on enabled sources in profile
  List<Map<String, dynamic>> _sourceOptions = [];
  bool _sourcesLoaded = false;

  // Language filter (defaults to user's language)
  String? _selectedLanguage;
  static const _languageOptions = [
    {'value': null, 'label': 'Toutes les langues', 'labelKey': 'all_languages'},
    {'value': 'fr', 'label': 'Français'},
    {'value': 'en', 'label': 'English'},
    {'value': 'es', 'label': 'Español'},
    {'value': 'de', 'label': 'Deutsch'},
    {'value': 'it', 'label': 'Italiano'},
    {'value': 'pt', 'label': 'Português'},
    {'value': 'nl', 'label': 'Nederlands'},
    {'value': 'ru', 'label': 'Русский'},
    {'value': 'ja', 'label': '日本語'},
    {'value': 'zh', 'label': '中文'},
  ];

  Set<String> _availableSources =
      {}; // Populated from search results for post-filtering

  @override
  void initState() {
    super.initState();
    _loadEnabledSources();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize language filter to user's language (only once)
    if (_selectedLanguage == null) {
      final userLang = Localizations.localeOf(context).languageCode;
      // Check if user's language is in our options
      final hasUserLang = _languageOptions.any(
        (opt) => opt['value'] == userLang,
      );
      _selectedLanguage = hasUserLang ? userLang : null;
    }
  }

  Future<void> _loadEnabledSources() async {
    final api = Provider.of<ApiService>(context, listen: false);

    // Default: all sources enabled except BNF (beta)
    bool inventaireEnabled = true;
    bool openLibraryEnabled = true;
    bool bnfEnabled = false; // BNF is beta, disabled by default
    bool googleBooksEnabled = false; // Disabled by default

    try {
      // Get user status which contains fallback_preferences
      final statusRes = await api.getUserStatus();
      if (statusRes.statusCode == 200 && statusRes.data != null) {
        final config = statusRes.data['config'] ?? {};
        final prefs = config['fallback_preferences'] ?? {};

        if (prefs.containsKey('inventaire')) {
          inventaireEnabled = prefs['inventaire'] == true;
        }
        if (prefs.containsKey('openlibrary')) {
          openLibraryEnabled = prefs['openlibrary'] == true;
        }
        if (prefs.containsKey('bnf')) {
          bnfEnabled = prefs['bnf'] == true;
        }

        // Check enabled modules for Google Books
        final modules = config['enabled_modules'];
        // Could be List<String> or comma-separated string
        if (modules is List) {
          googleBooksEnabled = modules.contains('enable_google_books');
        } else if (modules is String) {
          googleBooksEnabled = modules.contains('enable_google_books');
        } else if (prefs.containsKey('google_books')) {
          // Fallback to legacy pref if needed
          googleBooksEnabled = prefs['google_books'] == true;
        }
      }
    } catch (e) {
      // Fallback: try reading from SharedPreferences directly (FFI mode)
      try {
        final prefs = await SharedPreferences.getInstance();
        final fallbackStr = prefs.getString('ffi_fallback_preferences');
        if (fallbackStr != null) {
          final fallbackPrefs = jsonDecode(fallbackStr) as Map<String, dynamic>;
          if (fallbackPrefs.containsKey('inventaire')) {
            inventaireEnabled = fallbackPrefs['inventaire'] == true;
          }
          if (fallbackPrefs.containsKey('openlibrary')) {
            openLibraryEnabled = fallbackPrefs['openlibrary'] == true;
          }
          if (fallbackPrefs.containsKey('bnf')) {
            bnfEnabled = fallbackPrefs['bnf'] == true;
          }
        }
      } catch (_) {
        // Use defaults
      }
    }

    // Build source options list based on enabled sources
    final options = <Map<String, dynamic>>[
      {'value': null, 'label': 'Toutes les sources'},
    ];

    if (inventaireEnabled) {
      options.add({'value': 'inventaire', 'label': 'Inventaire.io'});
    }
    if (openLibraryEnabled) {
      options.add({'value': 'openlibrary', 'label': 'Open Library'});
    }
    if (bnfEnabled) {
      options.add({'value': 'bnf', 'label': 'data.bnf.fr'});
    }
    if (googleBooksEnabled) {
      options.add({'value': 'google_books', 'label': 'Google Books'});
    }

    if (mounted) {
      setState(() {
        _sourceOptions = options;
        _sourcesLoaded = true;
      });
    }
  }

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

  /// Check if a book's language matches the user's preferred language
  /// Handles various language code formats (2-letter, 3-letter, full names)
  bool _langMatches(String bookLang, String userLang) {
    if (bookLang.isEmpty || userLang.isEmpty) return false;

    final b = bookLang.toLowerCase();
    final u = userLang.toLowerCase();

    if (b == u) return true;

    // Common language code mappings
    const langMap = {
      'fr': ['fre', 'fra', 'french', 'français'],
      'en': ['eng', 'english'],
      'es': ['spa', 'spanish', 'español'],
      'de': ['ger', 'deu', 'german', 'deutsch'],
      'it': ['ita', 'italian', 'italiano'],
      'pt': ['por', 'portuguese', 'português'],
      'nl': ['dut', 'nld', 'dutch', 'nederlands'],
      'ru': ['rus', 'russian'],
      'ja': ['jpn', 'japanese'],
      'zh': ['chi', 'zho', 'chinese'],
    };

    // Check if both codes map to the same language
    for (final entry in langMap.entries) {
      final codes = [entry.key, ...entry.value];
      if (codes.contains(b) && codes.contains(u)) {
        return true;
      }
    }

    return false;
  }

  /// Calculate title relevance score (how well title matches search query)
  int _titleRelevanceScore(String title, String searchQuery) {
    if (searchQuery.isEmpty) return 0;

    final normalizedTitle = _normalizeTitle(title);
    final normalizedQuery = _normalizeTitle(searchQuery);

    // Exact match
    if (normalizedTitle == normalizedQuery) return 1000;

    // Title starts with query (e.g., "Martin Eden" starts with "Martin Eden")
    if (normalizedTitle.startsWith(normalizedQuery)) return 800;

    // Query is contained in title as a complete phrase
    if (normalizedTitle.contains(normalizedQuery)) return 600;

    // All query words are in title
    final queryWords = normalizedQuery
        .split(' ')
        .where((w) => w.length > 2)
        .toSet();
    final titleWords = normalizedTitle.split(' ').toSet();
    if (queryWords.isNotEmpty &&
        queryWords.every((w) => titleWords.any((t) => t.contains(w)))) {
      return 400;
    }

    // Some query words match
    final matchingWords = queryWords
        .where((w) => titleWords.any((t) => t.contains(w)))
        .length;
    if (matchingWords > 0) {
      return (matchingWords * 100) ~/ queryWords.length;
    }

    return 0;
  }

  /// Group search results by work (title + author combination)
  List<Map<String, dynamic>> _groupResultsByWork(
    List<Map<String, dynamic>> results,
    String searchQuery,
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

    // Sort editions within each work using a quality score
    // Score: language match (100) + cover (30) + publisher (20) + ISBN (10)
    final userLang = _selectedLanguage?.toLowerCase() ?? '';

    int editionScore(Map<String, dynamic> edition) {
      int score = 0;

      // Language match is top priority
      if (userLang.isNotEmpty) {
        final lang = (edition['language'] as String?)?.toLowerCase() ?? '';
        if (_langMatches(lang, userLang)) {
          score += 100;
        } else if (lang.isNotEmpty) {
          score -= 50; // Penalty for explicit non-matching language
        }
      }

      // Metadata completeness
      if ((edition['cover_url'] as String?)?.isNotEmpty == true) score += 30;
      if ((edition['isbn'] as String?)?.isNotEmpty == true) score += 10;

      // Publisher scoring: reward good publishers, penalize self-publishing
      final publisher =
          (edition['publisher'] as String?)?.toLowerCase().trim() ?? '';
      if (publisher.isNotEmpty) {
        // Heavy penalty for self-publishing platforms (low metadata quality)
        if (publisher.contains('createspace') ||
            publisher.contains('independently published') ||
            publisher.contains('autopublié') ||
            publisher.contains('auto-édition') ||
            publisher.contains('lulu.com') ||
            publisher.contains('kindle direct')) {
          score -= 150; // Strong penalty to push after real publishers
        } else {
          score += 20; // Bonus for having a legitimate publisher
        }
      }

      // De-prioritize Google Books (tie-breaker for same quality)
      if ((edition['source'] as String?) == 'Google') score -= 25;

      return score;
    }

    // Helper to create a unique key for deduplication
    String editionKey(Map<String, dynamic> edition) {
      final title = (edition['title'] as String?)?.toLowerCase().trim() ?? '';
      final cover = (edition['cover_url'] as String?) ?? '';
      final publisher =
          (edition['publisher'] as String?)?.toLowerCase().trim() ?? '';
      final year = edition['publication_year']?.toString() ?? '';
      // Deduplicate based on visual attributes (what the user sees)
      // Ignoring ISBN here ensures that an edition with ISBN and one without
      // are considered duplicates if they look the same.
      return '$title|$cover|$publisher|$year';
    }

    for (final work in workMap.values) {
      final editions = (work['editions'] as List).cast<Map<String, dynamic>>();

      // Sort first
      editions.sort((a, b) {
        final scoreA = editionScore(a);
        final scoreB = editionScore(b);

        // Higher score comes first
        if (scoreA != scoreB) return scoreB.compareTo(scoreA);

        // Tie-breaker: publication year (newest first)
        final yearA = a['publication_year'] as int?;
        final yearB = b['publication_year'] as int?;
        if (yearA == null && yearB == null) return 0;
        if (yearA == null) return 1;
        if (yearB == null) return -1;
        return yearB.compareTo(yearA);
      });

      // Then deduplicate: keep first occurrence (best quality) of each unique edition
      final seenKeys = <String>{};
      editions.removeWhere((edition) {
        final key = editionKey(edition);
        if (seenKeys.contains(key)) {
          return true; // Remove duplicate
        }
        seenKeys.add(key);
        return false; // Keep first occurrence
      });
    }

    // Sort works by: 1) title relevance, 2) number of editions (popularity), 3) quality score
    final worksList = workMap.values.toList();
    worksList.sort((a, b) {
      final titleA = a['title'] as String? ?? '';
      final titleB = b['title'] as String? ?? '';
      final editionsA = (a['editions'] as List).cast<Map<String, dynamic>>();
      final editionsB = (b['editions'] as List).cast<Map<String, dynamic>>();

      // FIRST: Title relevance is the most important criterion
      final titleScoreA = _titleRelevanceScore(titleA, searchQuery);
      final titleScoreB = _titleRelevanceScore(titleB, searchQuery);

      if (titleScoreA != titleScoreB) {
        return titleScoreB.compareTo(
          titleScoreA,
        ); // Higher title relevance first
      }

      // SECOND: Number of editions (popularity indicator)
      // More editions = more popular/important book
      final editionCountA = editionsA.length;
      final editionCountB = editionsB.length;

      if (editionCountA != editionCountB) {
        return editionCountB.compareTo(editionCountA); // More editions first
      }

      // THIRD: Compare by best edition's quality score (language + metadata)
      if (editionsA.isEmpty || editionsB.isEmpty) return 0;

      final qualityScoreA = editionScore(editionsA.first);
      final qualityScoreB = editionScore(editionsB.first);

      return qualityScoreB.compareTo(qualityScoreA); // Higher quality first
    });

    return worksList;
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
      // Language filter logic:
      // - If user selected a specific language -> use that (strict filter)
      // - If user selected "All languages" (null) -> no filter (show all)
      // - Default on first load: user's language is pre-selected
      final langFilter = _selectedLanguage; // null means "all languages"

      // Use unified search (Inventaire + OpenLibrary + BNF)
      final results = await api.searchBooks(
        title: _titleController.text,
        author: _authorController.text,
        subject: _subjectController.text,
        lang: langFilter, // Filter/boost by language (null = no filter)
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
        // Use title search query for relevance sorting
        final searchQuery = _titleController.text;
        _groupedWorks = _groupResultsByWork(results, searchQuery);
        _availableSources = sources;
        // Debug: Print grouping info
        debugPrint('🔍 Search returned ${results.length} results');
        debugPrint('📚 Grouped into ${_groupedWorks.length} works');
        debugPrint('🗂️ Sources: $sources');
        for (final work in _groupedWorks) {
          final editions = work['editions'] as List;
          debugPrint('  - "${work['title']}": ${editions.length} edition(s)');
          for (final ed in editions) {
            debugPrint('    > Publisher: ${ed['publisher']}');
          }
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
      debugPrint('🔍 _addBook called with doc: $doc');
      final isbn = doc['isbn'] as String?;

      if (isbn == null || isbn.isEmpty) {
        debugPrint('⚠️ WARNING: Adding book with NULL or EMPTY ISBN!');
      } else {
        debugPrint('✅ ISBN found in doc: "$isbn"');
      }

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

      debugPrint(
        '📚 Creating book with ISBN: ${doc['isbn']} | Title: ${doc['title']}',
      );
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

  Future<void> _openUrl(Map<String, dynamic> bookData) async {
    final url = BookUrlHelper.getUrl(bookData);
    if (url == null) return;

    final isOnline = await BookUrlHelper.isOnline();
    if (!isOnline && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No internet connection')));
      return;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WebViewScreen(
            url: url,
            title: bookData['title'] ?? 'Book Details',
          ),
        ),
      );
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
                // Source filter - only visible when at least 2 sources are enabled
                // (length > 2 because "Toutes les sources" is always included)
                if (_sourcesLoaded && _sourceOptions.length > 2)
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
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
                        const SizedBox(height: 8),
                        // Language filter dropdown
                        DropdownButtonFormField<String?>(
                          value: _selectedLanguage,
                          decoration: InputDecoration(
                            labelText: TranslationService.translate(
                              context,
                              'language_filter',
                            ),
                            prefixIcon: const Icon(Icons.language, size: 20),
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            isDense: true,
                          ),
                          items: _languageOptions.map((option) {
                            return DropdownMenuItem<String?>(
                              value: option['value'] as String?,
                              child: Text(option['label'] as String),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedLanguage = value);
                          },
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
          onOpenUrl: _openUrl,
        );
      },
    );
  }

  Widget _buildFlatListView() {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final book = _searchResults[index];
        return SearchResultCard(
          book: book,
          onAdd: () => _addBook(book),
          onOpenUrl: () => _openUrl(book),
        );
      },
    );
  }
} // End State
