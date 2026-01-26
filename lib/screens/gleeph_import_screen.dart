import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../theme/app_design.dart';
import '../providers/theme_provider.dart';

/// Represents a book candidate for import
class GleephBookCandidate {
  final String isbn;
  String? title;
  String? author;
  String? coverUrl;
  String? publisher;
  int? year;
  bool isSelected;
  bool isAlreadyInLibrary;
  bool isLoading;
  bool metadataFailed;

  GleephBookCandidate({
    required this.isbn,
    this.title,
    this.author,
    this.coverUrl,
    this.publisher,
    this.year,
    this.isSelected = true,
    this.isAlreadyInLibrary = false,
    this.isLoading = true,
    this.metadataFailed = false,
  });
}

class GleephImportScreen extends StatefulWidget {
  const GleephImportScreen({super.key});

  @override
  State<GleephImportScreen> createState() => _GleephImportScreenState();
}

class _GleephImportScreenState extends State<GleephImportScreen> {
  late final WebViewController _controller;

  // States
  bool _isLoadingPage = true;
  bool _isExtracting = false;
  bool _isResolvingMetadata = false;
  bool _isImporting = false;
  String? _currentUrl;

  // Data
  List<GleephBookCandidate> _candidates = [];
  int _resolvedCount = 0;
  int _importProgress = 0;
  int _importSuccessCount = 0;
  int _importSkippedCount = 0;
  int _importErrorCount = 0;
  String? _currentImportingTitle;

  // View state
  bool _showPreview = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) {
              setState(() {
                _isLoadingPage = true;
                _currentUrl = url;
              });
            }
          },
          onPageFinished: (url) async {
            if (mounted) {
              setState(() {
                _isLoadingPage = false;
              });
              // Get the real URL from JavaScript (SPAs don't update the URL in NavigationDelegate)
              await _updateCurrentUrl();
            }
          },
          onWebResourceError: (error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse('https://gleeph.com'));

    // Start periodic URL check for SPA navigation
    _startUrlMonitor();
  }

  /// Periodically check the actual URL (for SPA navigation detection)
  void _startUrlMonitor() {
    Future.delayed(const Duration(seconds: 2), () async {
      if (!mounted) return;
      await _updateCurrentUrl();
      _startUrlMonitor(); // Continue monitoring
    });
  }

  /// Get the real current URL from the page via JavaScript
  Future<void> _updateCurrentUrl() async {
    try {
      final result = await _controller.runJavaScriptReturningResult('window.location.href');
      String url = result.toString();
      // Clean up the result (remove quotes)
      if (url.startsWith('"') && url.endsWith('"')) {
        url = url.substring(1, url.length - 1);
      }
      if (mounted && url != _currentUrl) {
        setState(() {
          _currentUrl = url;
        });
        debugPrint('Gleeph URL updated: $url');
      }
    } catch (e) {
      debugPrint('Error getting URL: $e');
    }
  }

  /// Check if user appears to be logged in
  Future<bool> _isLoggedIn() async {
    try {
      // Look for common logged-in indicators (profile link, avatar, etc.)
      final result = await _controller.runJavaScriptReturningResult('''
        (function() {
          var profileLinks = document.querySelectorAll('a[href*="/profile"], a[href*="/@"], [class*="avatar"], [class*="user-menu"]');
          return profileLinks.length > 0 ? "true" : "false";
        })()
      ''');
      return result.toString().contains('true');
    } catch (e) {
      return false;
    }
  }

  /// Try to navigate to user's library automatically
  Future<void> _navigateToLibrary() async {
    try {
      // First, try to find and click on profile/library links
      const script = '''
(function() {
  // Common selectors for profile/library links on Gleeph
  var selectors = [
    'a[href*="/shelf/"]',
    'a[href*="/library"]',
    'a[href*="/bibliotheque"]',
    'a[href*="/@"]',
    'a[href*="/profile"]',
    'a[href*="/user/"]',
    '[class*="profile"]',
    '[class*="library"]',
    '[class*="shelf"]'
  ];

  for (var i = 0; i < selectors.length; i++) {
    var el = document.querySelector(selectors[i]);
    if (el && el.click) {
      el.click();
      return "clicked: " + selectors[i];
    }
  }

  // List available navigation links for debugging
  var navLinks = document.querySelectorAll('nav a, header a, [class*="nav"] a');
  var links = [];
  for (var j = 0; j < navLinks.length && j < 10; j++) {
    links.push(navLinks[j].href + " | " + (navLinks[j].textContent || "").trim().substring(0, 30));
  }
  return "no-match, available: " + links.join(" ; ");
})()
''';

      final result = await _controller.runJavaScriptReturningResult(script);
      debugPrint('Navigate to library result: $result');

      if (result.toString().contains('clicked')) {
        _showSnackBar('Navigation vers la bibliothèque...');
        // Wait for page to load
        await Future.delayed(const Duration(seconds: 2));
        await _updateCurrentUrl();
      } else {
        _showSnackBar(
          'Navigation auto impossible. Naviguez manuellement vers votre bibliothèque.',
          isError: true,
        );
        debugPrint('Available links: $result');
      }
    } catch (e) {
      debugPrint('Navigation error: $e');
      _showSnackBar('Erreur de navigation: $e', isError: true);
    }
  }

  /// Click "Load more" buttons if present
  Future<bool> _clickLoadMore() async {
    try {
      const script = '''
(function() {
  var selectors = [
    'button[class*="load"]',
    'button[class*="more"]',
    '[class*="load-more"]',
    '[class*="loadmore"]',
    'button:contains("plus")',
    'button:contains("more")',
    'a[class*="load"]',
    '[class*="pagination"] a:last-child'
  ];

  for (var i = 0; i < selectors.length; i++) {
    try {
      var el = document.querySelector(selectors[i]);
      if (el && el.offsetParent !== null) {
        el.click();
        return "clicked";
      }
    } catch(e) {}
  }
  return "none";
})()
''';

      final result = await _controller.runJavaScriptReturningResult(script);
      return result.toString().contains('clicked');
    } catch (e) {
      return false;
    }
  }

  bool get _isOnLibraryPage {
    final url = _currentUrl?.toLowerCase() ?? '';
    // Debug: print URL to help identify patterns
    debugPrint('Gleeph current URL: $url');

    // Check various URL patterns used by Gleeph
    return url.contains('/library') ||
        url.contains('/profile') ||
        url.contains('/bibliotheque') ||
        url.contains('/ma-bibliotheque') ||
        url.contains('/user/') ||
        url.contains('/shelf') ||
        url.contains('/etagere') ||
        url.contains('/@') ||  // Profile URLs like gleeph.com/@username
        url.contains('/books') ||
        url.contains('/livres') ||
        url.contains('/collection') ||
        // If on gleeph.com but not on home/login pages, likely on a user page
        (url.contains('gleeph.com') &&
         !url.endsWith('gleeph.com') &&
         !url.endsWith('gleeph.com/') &&
         !url.contains('/login') &&
         !url.contains('/signup') &&
         !url.contains('/register') &&
         !url.contains('/search'));
  }

  int get _newBooksCount =>
      _candidates.where((c) => !c.isAlreadyInLibrary && c.isSelected).length;

  int get _duplicatesCount =>
      _candidates.where((c) => c.isAlreadyInLibrary).length;

  /// Extract ISBNs from the current page using JavaScript
  Future<void> _extractIsbns({bool force = false}) async {
    if (!force && !_isOnLibraryPage) {
      // Show dialog offering to force extraction
      final shouldForce = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Page non reconnue'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cette page ne semble pas être une bibliothèque Gleeph.',
              ),
              const SizedBox(height: 8),
              Text(
                'URL: ${_currentUrl ?? "inconnue"}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              const Text(
                'Voulez-vous quand même tenter l\'extraction ?',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Forcer l\'extraction'),
            ),
          ],
        ),
      );

      if (shouldForce != true) return;
    }

    setState(() {
      _isExtracting = true;
      _candidates = [];
      _showPreview = false;
    });

    try {
      // Step 1: Adaptive scrolling with "Load more" button support
      int previousHeight = 0;
      int noChangeCount = 0;
      int scrollCount = 0;
      int loadMoreClicks = 0;
      const maxScrolls = 100; // Safety limit for very large libraries

      while (noChangeCount < 4 && scrollCount < maxScrolls) {
        scrollCount++;

        // Get current page height
        int currentHeight = 0;
        try {
          final heightResult = await _controller.runJavaScriptReturningResult('document.body.scrollHeight');
          currentHeight = int.tryParse(heightResult.toString()) ?? 0;
        } catch (e) {
          debugPrint('Height check error: $e');
        }

        // Check if new content was loaded
        if (currentHeight == previousHeight) {
          noChangeCount++;

          // Try clicking "Load more" button when scrolling doesn't load more
          if (noChangeCount >= 2) {
            final clicked = await _clickLoadMore();
            if (clicked) {
              loadMoreClicks++;
              noChangeCount = 0; // Reset counter, we might have more content
              debugPrint('Clicked "Load more" button ($loadMoreClicks times)');
              await Future.delayed(const Duration(milliseconds: 1000));
              continue;
            }
          }
        } else {
          noChangeCount = 0;
          previousHeight = currentHeight;
        }

        // Scroll to bottom
        try {
          await _controller.runJavaScript('window.scrollTo(0, document.body.scrollHeight)');
        } catch (e) {
          debugPrint('Scroll error: $e');
        }

        // Wait for content to load (longer wait to ensure lazy loading completes)
        await Future.delayed(const Duration(milliseconds: 800));

        // Update UI with progress
        if (mounted && scrollCount % 5 == 0) {
          debugPrint('Scrolling... ($scrollCount scrolls, height: $currentHeight, loadMore: $loadMoreClicks)');
        }
      }

      debugPrint('Scrolling complete after $scrollCount scrolls, $loadMoreClicks "load more" clicks');

      // Scroll back to top
      await _controller.runJavaScript('window.scrollTo(0, 0)');
      await Future.delayed(const Duration(milliseconds: 300));

      // Step 2: Extract ISBNs with a simpler script
      const extractScript = '''
(function() {
  var links = document.querySelectorAll('a[href*="/ean/"]');
  var eans = [];
  for (var i = 0; i < links.length; i++) {
    var href = links[i].href;
    var parts = href.split('/ean/');
    if (parts.length > 1) {
      var ean = parts[1].split('/')[0].split('?')[0];
      if (ean && ean.length === 13 && /^[0-9]+\$/.test(ean)) {
        if (eans.indexOf(ean) === -1) {
          eans.push(ean);
        }
      }
    }
  }
  return JSON.stringify(eans);
})()
''';

      final result = await _controller.runJavaScriptReturningResult(extractScript);

      // Parse result (handle different formats)
      String cleanResult = result.toString();
      if (cleanResult.startsWith('"') && cleanResult.endsWith('"')) {
        cleanResult = cleanResult
            .substring(1, cleanResult.length - 1)
            .replaceAll('\\"', '"');
      }

      final List<dynamic> isbns = jsonDecode(cleanResult);
      final isbnList = isbns.cast<String>().toList();

      if (isbnList.isEmpty) {
        _showSnackBar(
          'Aucun livre trouvé. Assurez-vous d\'être sur votre bibliothèque.',
          isError: true,
        );
        setState(() => _isExtracting = false);
        return;
      }

      // Create candidates
      setState(() {
        _candidates =
            isbnList.map((isbn) => GleephBookCandidate(isbn: isbn)).toList();
        _isExtracting = false;
        _isResolvingMetadata = true;
        _resolvedCount = 0;
      });

      // Resolve metadata and check duplicates
      await _resolveAllMetadata();
    } catch (e) {
      debugPrint('Extraction error: $e');
      _showSnackBar('Erreur lors de l\'extraction: $e', isError: true);
      setState(() => _isExtracting = false);
    }
  }

  /// Resolve metadata for all candidates
  Future<void> _resolveAllMetadata() async {
    final api = Provider.of<ApiService>(context, listen: false);

    // First, get all existing books to check duplicates efficiently
    final existingBooks = await api.getBooks();
    final existingIsbns = existingBooks
        .where((b) => b.isbn != null)
        .map((b) => b.isbn!.replaceAll(RegExp(r'[^0-9X]'), ''))
        .toSet();

    // Process candidates in batches of 5 for better UX
    const batchSize = 5;
    for (var i = 0; i < _candidates.length; i += batchSize) {
      final batch = _candidates.skip(i).take(batchSize).toList();

      await Future.wait(
        batch.map((candidate) => _resolveSingleCandidate(api, candidate, existingIsbns)),
      );

      if (mounted) {
        setState(() {
          _resolvedCount = (_resolvedCount + batch.length).clamp(0, _candidates.length);
        });
      }
    }

    if (mounted) {
      setState(() {
        _isResolvingMetadata = false;
        _showPreview = true;
      });
    }
  }

  /// Resolve metadata for a single candidate
  Future<void> _resolveSingleCandidate(
    ApiService api,
    GleephBookCandidate candidate,
    Set<String> existingIsbns,
  ) async {
    try {
      // Check if already in library
      final cleanIsbn = candidate.isbn.replaceAll(RegExp(r'[^0-9X]'), '');
      if (existingIsbns.contains(cleanIsbn)) {
        candidate.isAlreadyInLibrary = true;
        candidate.isSelected = false;
        candidate.isLoading = false;
        return;
      }

      // Lookup metadata
      final metadata = await api.lookupBook(candidate.isbn);
      if (metadata != null) {
        candidate.title = metadata['title'];
        candidate.author = metadata['author'];
        candidate.coverUrl = metadata['cover_url'];
        candidate.publisher = metadata['publisher'];
        candidate.year = metadata['year'];
      } else {
        candidate.metadataFailed = true;
        candidate.title = 'ISBN: ${candidate.isbn}';
      }
    } catch (e) {
      debugPrint('Metadata lookup failed for ${candidate.isbn}: $e');
      candidate.metadataFailed = true;
      candidate.title = 'ISBN: ${candidate.isbn}';
    } finally {
      candidate.isLoading = false;
    }
  }

  /// Start importing selected books
  Future<void> _startImport() async {
    final selectedCandidates =
        _candidates.where((c) => c.isSelected && !c.isAlreadyInLibrary).toList();

    if (selectedCandidates.isEmpty) {
      _showSnackBar('Aucun livre sélectionné pour l\'import.');
      return;
    }

    setState(() {
      _isImporting = true;
      _importProgress = 0;
      _importSuccessCount = 0;
      _importSkippedCount = 0;
      _importErrorCount = 0;
    });

    final api = Provider.of<ApiService>(context, listen: false);

    for (final candidate in selectedCandidates) {
      if (!mounted) break;

      setState(() {
        _currentImportingTitle = candidate.title ?? candidate.isbn;
      });

      try {
        // Double-check it's not already in library (race condition protection)
        final existing = await api.findBookByIsbn(candidate.isbn);
        if (existing != null) {
          _importSkippedCount++;
          candidate.isAlreadyInLibrary = true;
        } else {
          // Create the book
          final response = await api.createBook({
            'isbn': candidate.isbn,
            'title': candidate.title,
            'author': candidate.author,
            'publisher': candidate.publisher,
            'publication_year': candidate.year,
            'cover_url': candidate.coverUrl,
            'owned': true,
            'reading_status': 'read', // Default for imported library
          });

          if (response.statusCode == 200 || response.statusCode == 201) {
            _importSuccessCount++;
          } else {
            _importErrorCount++;
            debugPrint('Import failed for ${candidate.isbn}: ${response.statusCode}');
          }
        }
      } catch (e) {
        _importErrorCount++;
        debugPrint('Import error for ${candidate.isbn}: $e');
      }

      if (mounted) {
        setState(() {
          _importProgress++;
        });
      }
    }

    if (mounted) {
      setState(() {
        _isImporting = false;
        _currentImportingTitle = null;
      });
      _showImportResults();
    }
  }

  void _showImportResults() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _importSuccessCount > 0 ? Icons.check_circle : Icons.info,
              color: _importSuccessCount > 0 ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 12),
            const Text('Import terminé'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildResultRow(
              Icons.book,
              Colors.green,
              '$_importSuccessCount livre${_importSuccessCount > 1 ? 's' : ''} importé${_importSuccessCount > 1 ? 's' : ''}',
            ),
            if (_importSkippedCount > 0)
              _buildResultRow(
                Icons.skip_next,
                Colors.orange,
                '$_importSkippedCount déjà présent${_importSkippedCount > 1 ? 's' : ''}',
              ),
            if (_importErrorCount > 0)
              _buildResultRow(
                Icons.error_outline,
                Colors.red,
                '$_importErrorCount erreur${_importErrorCount > 1 ? 's' : ''}',
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _showPreview = false;
                _candidates = [];
              });
            },
            child: const Text('Continuer l\'import'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/books');
            },
            child: const Text('Voir ma bibliothèque'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _toggleSelectAll(bool selectAll) {
    setState(() {
      for (final c in _candidates) {
        if (!c.isAlreadyInLibrary) {
          c.isSelected = selectAll;
        }
      }
    });
  }

  Widget _buildWebViewScreen() {
    return Column(
      children: [
        // Instruction banner with current URL for debug
        if (!_isOnLibraryPage && !_isLoadingPage && !_isExtracting)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade400, Colors.orange.shade600],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Connectez-vous, puis accédez à votre bibliothèque.',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _navigateToLibrary,
                      icon: const Icon(Icons.library_books, size: 16),
                      label: const Text('Ma bibliothèque'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.orange.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ou naviguez manuellement',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
                      ),
                    ),
                  ],
                ),
                if (_currentUrl != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'URL: ${_currentUrl!.length > 50 ? '...${_currentUrl!.substring(_currentUrl!.length - 50)}' : _currentUrl}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

        // Ready banner
        if (_isOnLibraryPage && !_isLoadingPage && !_isExtracting)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade400, Colors.green.shade600],
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Page bibliothèque détectée ! Cliquez sur "Extraire" quand prêt.',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

        // WebView
        Expanded(
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),

              // Extraction overlay
              if (_isExtracting)
                _buildOverlay(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 16),
                      const Text(
                        'Analyse de la page en cours...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Scrolling automatique pour charger tous les livres',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),

              // Metadata resolution overlay
              if (_isResolvingMetadata)
                _buildOverlay(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 16),
                      const Text(
                        'Récupération des métadonnées...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_resolvedCount / ${_candidates.length} livres analysés',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 200,
                        child: LinearProgressIndicator(
                          value: _candidates.isEmpty
                              ? 0
                              : _resolvedCount / _candidates.length,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverlay({required Widget child}) {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: child,
        ),
      ),
    );
  }

  Widget _buildPreviewScreen(ThemeProvider themeProvider) {
    final newBooks = _candidates.where((c) => !c.isAlreadyInLibrary).toList();
    final duplicates = _candidates.where((c) => c.isAlreadyInLibrary).toList();

    return Container(
      decoration: BoxDecoration(
        gradient: AppDesign.pageGradientForTheme(themeProvider.themeStyle),
      ),
      child: Column(
        children: [
          // Summary header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.library_add,
                        color: Colors.green,
                        value: _newBooksCount.toString(),
                        label: 'À importer',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.library_books,
                        color: Colors.orange,
                        value: _duplicatesCount.toString(),
                        label: 'Déjà présents',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Select all / Deselect all
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _toggleSelectAll(true),
                      icon: const Icon(Icons.check_box, size: 18),
                      label: const Text('Tout sélectionner'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _toggleSelectAll(false),
                      icon: const Icon(Icons.check_box_outline_blank, size: 18),
                      label: const Text('Tout désélectionner'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Books list
          Expanded(
            child: _isImporting
                ? _buildImportingOverlay()
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      // New books section
                      if (newBooks.isNotEmpty) ...[
                        _buildSectionTitle('Nouveaux livres', Icons.add_circle, Colors.green),
                        ...newBooks.map((c) => _buildBookCard(c)),
                        const SizedBox(height: 16),
                      ],

                      // Duplicates section
                      if (duplicates.isNotEmpty) ...[
                        _buildSectionTitle(
                          'Déjà dans votre bibliothèque',
                          Icons.check_circle,
                          Colors.orange,
                        ),
                        ...duplicates.map((c) => _buildBookCard(c, isDuplicate: true)),
                      ],
                    ],
                  ),
          ),

          // Import button
          if (!_isImporting)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _newBooksCount > 0 ? _startImport : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.file_download),
                    label: Text(
                      _newBooksCount > 0
                          ? 'Importer $_newBooksCount livre${_newBooksCount > 1 ? 's' : ''}'
                          : 'Aucun livre à importer',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImportingOverlay() {
    final progress = _candidates.isEmpty
        ? 0.0
        : _importProgress / _candidates.where((c) => c.isSelected && !c.isAlreadyInLibrary).length;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            const Text(
              'Importation en cours...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            if (_currentImportingTitle != null)
              Text(
                _currentImportingTitle!,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 16),
            Text(
              '$_importProgress / ${_candidates.where((c) => c.isSelected && !c.isAlreadyInLibrary).length}',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white24,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMiniStat(Icons.check, Colors.green, _importSuccessCount),
                const SizedBox(width: 16),
                _buildMiniStat(Icons.skip_next, Colors.orange, _importSkippedCount),
                const SizedBox(width: 16),
                _buildMiniStat(Icons.error_outline, Colors.red, _importErrorCount),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, Color color, int value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 4),
        Text(
          value.toString(),
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookCard(GleephBookCandidate candidate, {bool isDuplicate = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: isDuplicate
            ? null
            : () {
                setState(() {
                  candidate.isSelected = !candidate.isSelected;
                });
              },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Checkbox (only for non-duplicates)
              if (!isDuplicate)
                Checkbox(
                  value: candidate.isSelected,
                  onChanged: (value) {
                    setState(() {
                      candidate.isSelected = value ?? false;
                    });
                  },
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.orange.shade400,
                    size: 24,
                  ),
                ),

              // Cover image
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 45,
                  height: 65,
                  child: candidate.coverUrl != null
                      ? CachedNetworkImage(
                          imageUrl: candidate.coverUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.book, color: Colors.grey),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.book, color: Colors.grey),
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.book, color: Colors.grey),
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // Book info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.title ?? 'Titre inconnu',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDuplicate ? Colors.grey : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (candidate.author != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        candidate.author!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDuplicate
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (candidate.metadataFailed) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber,
                            size: 14,
                            color: Colors.orange.shade400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Métadonnées non trouvées',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange.shade400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // ISBN badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  candidate.isbn.substring(candidate.isbn.length - 4),
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_showPreview ? 'Prévisualisation' : 'Import Gleeph'),
        leading: IconButton(
          icon: Icon(Icons.adaptive.arrow_back),
          onPressed: () {
            if (_showPreview && !_isImporting) {
              setState(() => _showPreview = false);
            } else if (!_isImporting) {
              context.pop();
            }
          },
        ),
        actions: [
          if (_isLoadingPage && !_showPreview)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      body: _showPreview
          ? _buildPreviewScreen(themeProvider)
          : _buildWebViewScreen(),
      floatingActionButton: (!_showPreview &&
              !_isExtracting &&
              !_isResolvingMetadata &&
              !_isLoadingPage)
          ? FloatingActionButton.extended(
              onPressed: _extractIsbns,
              backgroundColor: _isOnLibraryPage ? Colors.green : Colors.grey.shade600,
              icon: Icon(_isOnLibraryPage ? Icons.auto_awesome : Icons.help_outline),
              label: Text(_isOnLibraryPage ? 'Extraire' : 'Naviguez d\'abord'),
            )
          : null,
    );
  }
}
