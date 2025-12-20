import 'package:flutter/material.dart';
import '../widgets/genie_app_bar.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import '../services/translation_service.dart';
import '../models/book.dart';
import '../widgets/bookshelf_view.dart';
import '../widgets/book_cover_grid.dart';
import '../widgets/premium_book_card.dart';
import '../theme/app_design.dart';
import '../providers/theme_provider.dart';
import '../utils/avatars.dart';

enum ViewMode {
  coverGrid, // Netflix style
  spineShelf, // Original bookshelf
  list, // Simple list
}

class BookListScreen extends StatefulWidget {
  final String? initialSearchQuery;

  const BookListScreen({super.key, this.initialSearchQuery});

  @override
  State<BookListScreen> createState() => _BookListScreenState();
}

class _BookListScreenState extends State<BookListScreen> {
  List<Book> _books = [];
  List<Book> _filteredBooks = [];

  // Filter state
  String? _selectedStatus;
  String? _tagFilter;

  bool _isLoading = true;
  ViewMode _viewMode = ViewMode.coverGrid; // Default to cover grid
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isReordering = false;
  String? _libraryName; // Store library name for title

  final GlobalKey _addKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _viewKey = GlobalKey();
  final GlobalKey _scanKey = GlobalKey();
  final GlobalKey _externalSearchKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialSearchQuery ?? '';
    if (_searchQuery.isNotEmpty) {
      _isSearching = true;
    }
    _fetchBooks();
    // Trigger background sync
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SyncService>(context, listen: false).syncAllPeers();
      _checkWizard();

      // Initialize filters from query params
      final state = GoRouterState.of(context);
      if (state.uri.queryParameters.containsKey('tag')) {
        setState(() {
          _tagFilter = state.uri.queryParameters['tag'];
          _filterBooks();
        });
      }
    });
  }

  Future<void> _checkWizard() async {
    // Temporarily disabled - use main onboarding tour instead
    /*
    final hasSeen = await WizardService.hasSeenBooksWizard();
    if (!hasSeen && mounted) {
      WizardService.showBooksTutorial(
        context: context,
        addKey: _addKey,
        searchKey: _searchKey,
        viewKey: _viewKey,
        scanKey: _scanKey,
        externalSearchKey: _externalSearchKey,
      );
    }
    */
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Banner always shows translated "My Library"
    dynamic titleWidget = _isSearching
        ? _buildSearchField() // Use custom search field with autocomplete
        : TranslationService.translate(context, 'my_library_title');

    if (_isReordering) {
      titleWidget = Text(
        TranslationService.translate(context, 'reordering_shelf') ??
            'Reordering Shelf...',
        style: const TextStyle(color: Colors.white, fontSize: 18),
      );
    }

    final width = MediaQuery.of(context).size.width;
    final bool isMobile = width <= 600;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GenieAppBar(
        title: titleWidget,
        // subtitle: _libraryName, // Handled by ThemeProvider
        leading: isMobile
            ? IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              )
            : null,
        automaticallyImplyLeading: false,
        actions: [
          if (_isReordering) ...[
            IconButton(
              icon: const Icon(Icons.sort_by_alpha, color: Colors.white),
              tooltip: 'Sort A→Z by Author',
              onPressed: _autoSortByAuthor,
            ),
            IconButton(
              icon: const Icon(Icons.check, color: Colors.white),
              tooltip: 'Save Order',
              onPressed: _saveOrder,
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              tooltip: 'Cancel',
              onPressed: () {
                setState(() {
                  _isReordering = false;
                  _fetchBooks(); // Reset to original order
                });
              },
            ),
          ] else ...[
            // Reorder Button (Only when Tag Filter is Active)
            if (_tagFilter != null && !_isSearching)
              IconButton(
                icon: const Icon(Icons.sort, color: Colors.white),
                tooltip: 'Reorder Shelf',
                onPressed: () {
                  setState(() {
                    _isReordering = true;
                    _viewMode = ViewMode.list; // Force list view for reordering
                  });
                },
              ),

            IconButton(
              key: const Key('bookSearchButton'),
              icon: Icon(
                _isSearching ? Icons.close : Icons.search,
                color: Colors.white,
              ),
              tooltip: TranslationService.translate(
                context,
                _isSearching ? 'cancel' : 'search_books',
              ),
              onPressed: () {
                setState(() {
                  if (_isSearching) {
                    _isSearching = false;
                    _searchController.clear();
                    _filterBooks();
                  } else {
                    _isSearching = true;
                  }
                });
              },
            ),
          ], // End else

          if (!_isSearching && !_isReordering) ...[
            IconButton(
              key: _viewKey,
              icon: Icon(_getViewIcon(_viewMode), color: Colors.white),
              tooltip: TranslationService.translate(
                context,
                'action_change_view',
              ),
              onPressed: () {
                setState(() {
                  _viewMode = _getNextViewMode(_viewMode);
                });
              },
            ),
            IconButton(
              key: _scanKey,
              icon: const Icon(Icons.camera_alt, color: Colors.white),
              tooltip: TranslationService.translate(context, 'scan_isbn_title'),
              onPressed: () async {
                final isbn = await context.push<String>('/scan');
                if (isbn != null && mounted) {
                  context.push('/books/add', extra: {'isbn': isbn});
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: TranslationService.translate(context, 'action_refresh'),
              onPressed: _fetchBooks,
            ),
            IconButton(
              key: _externalSearchKey,
              icon: const Icon(Icons.public, color: Colors.white),
              tooltip: TranslationService.translate(
                context,
                'btn_search_online',
              ),
              onPressed: () async {
                final result = await context.push('/search/external');
                if (result == true) {
                  _fetchBooks();
                }
              },
            ),
          ],
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppDesign.pageGradientForTheme(
            Provider.of<ThemeProvider>(context).themeStyle,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // _buildHeader(context), // Header removed, avatar now in AppBar
              _buildFilterBar(),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.black54,
                          ),
                        ),
                      )
                    : _buildBody(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('addBookButton'),
        onPressed: () async {
          final result = await context.push('/books/add');
          if (result == true) {
            _fetchBooks(); // Refresh if book was added
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  bool _showBorrowedConfig = true; // Store config value

  Future<void> _fetchBooks() async {
    setState(() => _isLoading = true);
    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      debugPrint(
        'Fetching books with status: $_selectedStatus, tag: $_tagFilter, search: $_searchQuery',
      );
      // Fetch all books initially, filtering will happen locally
      final books = await apiService.getBooks();

      final configRes = await apiService.getLibraryConfig();
      String? libraryName;
      if (configRes.statusCode == 200) {
        _showBorrowedConfig = configRes.data['show_borrowed_books'] != false;
        libraryName = configRes.data['library_name'] as String?;
        if (libraryName != null) {
          Provider.of<ThemeProvider>(
            context,
            listen: false,
          ).setLibraryName(libraryName);
        }
      }

      if (mounted) {
        setState(() {
          _books = books; // Store ALL books, filtering happens in _filterBooks
          _libraryName = libraryName;
          _filterBooks(); // Apply filters after fetching all books
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint('Error loading books: $e');
      }
    }
  }

  // Triggered when filters change or search query changes
  void _filterBooks() {
    List<Book> tempBooks = List.from(_books);

    // Apply "show borrowed" config logic:
    // If config says hide borrowed books, ONLY hide them if the user hasn't explicitly asked to see them.
    if (!_showBorrowedConfig && _selectedStatus != 'borrowed') {
      tempBooks = tempBooks
          .where((b) => b.readingStatus != 'borrowed')
          .toList();
    }

    // Apply status filter
    if (_selectedStatus != null) {
      tempBooks = tempBooks
          .where((book) => book.readingStatus == _selectedStatus)
          .toList();
    }

    // Apply tag filter
    if (_tagFilter != null) {
      final filterLower = _tagFilter!.toLowerCase();
      tempBooks = tempBooks.where((book) {
        final bookTags =
            book.subjects?.map((s) => s.toLowerCase()).toSet() ?? {};
        return bookTags.contains(filterLower);
      }).toList();
    }

    // Apply search query filter
    if (_searchQuery.isNotEmpty) {
      tempBooks = tempBooks
          .where(
            (book) =>
                book.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (book.author?.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ??
                    false),
          )
          .toList();
    }

    setState(() {
      _filteredBooks = tempBooks;
    });
  }

  void _showTagFilterDialog() async {
    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      final tags = await apiService.getTags();

      if (!mounted) return;

      if (tags.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(TranslationService.translate(context, 'no_tags')),
          ),
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  TranslationService.translate(context, 'filter_by_tag'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tags.map((tag) {
                    return ActionChip(
                      label: Text('${tag.name} (${tag.count})'),
                      avatar: const Icon(Icons.label, size: 16),
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          _tagFilter = tag.name;
                          _filterBooks();
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      );
    } catch (e) {
      debugPrint('Error loading tags: $e');
    }
  }

  // _fetchSuggestions is removed as Autocomplete now works directly on _allBooks

  Widget _buildSearchField() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppDesign.subtleShadow,
      ),
      child: Autocomplete<Book>(
        displayStringForOption: (Book option) => option.title,
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return const Iterable<Book>.empty();
          }
          return _books.where((Book book) {
            return book.title.toLowerCase().contains(
                  textEditingValue.text.toLowerCase(),
                ) ||
                (book.author?.toLowerCase().contains(
                      textEditingValue.text.toLowerCase(),
                    ) ??
                    false);
          });
        },
        onSelected: (Book selection) {
          if (selection.id == null) return;
          context.push('/books/${selection.id}', extra: selection);
        },
        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
          // Sync internal _searchQuery with Autocomplete's controller
          if (_searchQuery != textEditingController.text) {
            textEditingController.text = _searchQuery;
          }

          // Assuming GenieAppBar is defined elsewhere and this is part of a Scaffold's appBar property
          // This part of the change seems to be misplaced based on the provided context.
          // I will integrate the subtitle part into the _buildHeader function as it's the closest
          // logical place for displaying library name in a header/appBar-like context within the provided snippet.
          // If GenieAppBar is used in the Scaffold, the subtitle should be added there.
          // Given the instruction, I'm assuming the user wants to add `subtitle: _libraryName` to an existing GenieAppBar.
          // Since the GenieAppBar itself is not in the provided content, I'll assume it's part of the Scaffold
          // that wraps this content, and the user wants to add the subtitle to it.
          // As I cannot modify the Scaffold directly, I will make a note here.

          return TextField(
            controller: textEditingController,
            focusNode: focusNode,
            style: const TextStyle(color: Colors.black87),
            decoration: InputDecoration(
              hintText: TranslationService.translate(context, 'search_books'),
              hintStyle: const TextStyle(color: Colors.black38),
              prefixIcon: const Icon(Icons.search, color: Colors.black54),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 15,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _filterBooks(); // Trigger filter on search query change
              });
            },
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4.0,
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 200,
                  maxWidth: 300,
                ), // Adjust width as needed
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Book option = options.elementAt(index);
                    return InkWell(
                      onTap: () => onSelected(option),
                      child: ListTile(
                        leading: option.coverUrl != null
                            ? Image.network(
                                option.coverUrl!,
                                width: 30,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.book, size: 30),
                              )
                            : const Icon(
                                Icons.book,
                                size: 30,
                                color: Colors.grey,
                              ),
                        title: Text(
                          option.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          option.author ?? 'Unknown',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Header removed - Avatar is now in GenieAppBar

  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          // View Mode Toggles
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                _buildViewModeToggle(Icons.grid_view, ViewMode.coverGrid),
                _buildViewModeToggle(Icons.shelves, ViewMode.spineShelf),
                _buildViewModeToggle(Icons.list, ViewMode.list),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Tag Filter (if active)
          if (_tagFilter != null) ...[
            _buildFilterPill(
              status: 'tag_filter', // A dummy status to identify this pill
              label: '#$_tagFilter',
              isClearAction: true,
            ),
            const SizedBox(width: 8),
          ],

          // Tag Filter Button (to select a tag)
          if (_tagFilter == null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ScaleOnTap(
                onTap: () => _showTagFilterDialog(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.label_outline,
                        size: 16,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        TranslationService.translate(context, 'tags'),
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Status Filters
          _buildFilterPill(
            status: null,
            label: TranslationService.translate(context, 'filter_all'),
          ),
          _buildFilterPill(
            status: 'reading',
            label: TranslationService.translate(
              context,
              'reading_status_reading',
            ),
          ),
          _buildFilterPill(
            status: 'to_read',
            label: TranslationService.translate(
              context,
              'reading_status_to_read',
            ),
          ),
          _buildFilterPill(
            status: 'wanting',
            label: TranslationService.translate(
              context,
              'reading_status_wanting',
            ),
          ),
          _buildFilterPill(
            status: 'read',
            label: TranslationService.translate(context, 'reading_status_read'),
          ),
          // Note: lent/borrowed filters removed - these are now copy-level concepts
          // Users can view loan status via copy management
        ],
      ),
    );
  }

  Widget _buildViewModeToggle(IconData icon, ViewMode mode) {
    final bool isSelected = _viewMode == mode;
    return ScaleOnTap(
      onTap: () {
        setState(() {
          _viewMode = mode;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.black54,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildFilterPill({
    required String? status,
    required String label,
    bool isClearAction = false,
  }) {
    final bool isSelected = _selectedStatus == status;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ScaleOnTap(
        onTap: () {
          if (isClearAction) {
            setState(() {
              _tagFilter = null;
              _filterBooks();
            });
          } else {
            setState(() {
              _selectedStatus = isSelected ? null : status;
              _filterBooks();
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isClearAction
                ? Colors.redAccent.withOpacity(0.8)
                : (isSelected 
                    ? Theme.of(context).primaryColor 
                    : isDarkTheme 
                        ? Theme.of(context).cardColor.withOpacity(0.8)
                        : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : isDarkTheme 
                      ? Theme.of(context).colorScheme.outline
                      : Colors.grey.withOpacity(0.3),
              width: isDarkTheme ? 1.5 : 1.0,
            ),
            boxShadow: isSelected && !isClearAction
                ? [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isClearAction) ...[
                const Icon(Icons.close, size: 16, color: Colors.white),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: isClearAction
                      ? Colors.white
                      : (isSelected 
                          ? Colors.white 
                          : Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black54),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onBookTap(Book book) async {
    if (book.id == null) return;
    final result = await context.push('/books/${book.id}', extra: book);
    if (result == true) {
      _fetchBooks();
    }
  }

  ViewMode _getNextViewMode(ViewMode current) {
    switch (current) {
      case ViewMode.coverGrid:
        return ViewMode.spineShelf;
      case ViewMode.spineShelf:
        return ViewMode.list;
      case ViewMode.list:
        return ViewMode.coverGrid;
    }
  }

  IconData _getViewIcon(ViewMode mode) {
    switch (mode) {
      case ViewMode.coverGrid:
        return Icons.grid_view;
      case ViewMode.spineShelf:
        return Icons.shelves;
      case ViewMode.list:
        return Icons.list;
    }
  }

  Widget _buildBody() {
    if (_filteredBooks.isEmpty && !_isLoading) {
      return RefreshIndicator(
        onRefresh: _fetchBooks,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 64,
                    color: Colors.grey.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    TranslationService.translate(context, 'no_books_found'),
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    switch (_viewMode) {
      case ViewMode.coverGrid:
        return RefreshIndicator(
          onRefresh: _fetchBooks,
          child: BookCoverGrid(books: _filteredBooks, onBookTap: _onBookTap),
        );
      case ViewMode.spineShelf:
        return RefreshIndicator(
          onRefresh: _fetchBooks,
          child: BookshelfView(books: _filteredBooks, onBookTap: _onBookTap),
        );
      case ViewMode.list:
        return RefreshIndicator(
          onRefresh: _fetchBooks,
          child: _buildListView(),
        );
    }
  }

  Widget _buildListView() {
    if (_isReordering) {
      return ReorderableListView.builder(
        itemCount: _filteredBooks.length,
        padding: const EdgeInsets.all(16),
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (oldIndex < newIndex) {
              newIndex -= 1;
            }
            final Book item = _filteredBooks.removeAt(oldIndex);
            _filteredBooks.insert(newIndex, item);
          });
        },
        itemBuilder: (context, index) {
          final book = _filteredBooks[index];
          return Card(
            key: ValueKey(book.id ?? index), // Ensure stable key
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              contentPadding: const EdgeInsets.all(8),
              leading: book.coverUrl != null
                  ? Image.network(
                      book.coverUrl!,
                      width: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.book),
                    )
                  : const Icon(Icons.book, size: 40, color: Colors.grey),
              title: Text(book.title),
              subtitle: Text(book.author ?? 'Unknown'),
              trailing: ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle),
              ),
            ),
          );
        },
      );
    }

    return ListView.builder(
      itemCount: _filteredBooks.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final book = _filteredBooks[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: PremiumBookCard(
            book: book,
            isHero: true, // Use hero layout (horizontal) for list items
            width: double.infinity,
          ),
        );
      },
    );
  }

  Future<void> _saveOrder() async {
    setState(() => _isLoading = true);
    final apiService = Provider.of<ApiService>(context, listen: false);
    try {
      final ids = _filteredBooks.map((b) => b.id!).toList();
      await apiService.reorderBooks(ids);

      setState(() {
        _isReordering = false;
        _isLoading = false;
      });
      // Don't call _fetchBooks() here - it would reload with global order
      // and lose the tag-filtered order we just saved
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Shelf order saved!')));
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving order: $e')));
    }
  }

  void _autoSortByAuthor() {
    setState(() {
      _filteredBooks.sort((a, b) {
        // Sort by author (null-safe), then by title if same author
        final authorA = (a.author ?? '').toLowerCase();
        final authorB = (b.author ?? '').toLowerCase();
        final authorCompare = authorA.compareTo(authorB);
        if (authorCompare != 0) return authorCompare;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sorted by author A→Z. Click ✓ to save.'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
