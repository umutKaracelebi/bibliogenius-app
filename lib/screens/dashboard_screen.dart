import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../widgets/genie_app_bar.dart';
import '../services/api_service.dart';
import '../services/translation_service.dart';
import '../models/book.dart';
import '../models/gamification_status.dart';
// import 'genie_chat_screen.dart'; // Removed as we use route string
import '../providers/theme_provider.dart';
import '../services/wizard_service.dart';
import '../widgets/premium_book_card.dart';
import '../services/quote_service.dart';
import '../models/quote.dart';
import '../theme/app_design.dart';
import '../services/backup_reminder_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  Quote? _dailyQuote;
  String? _userName;
  String? _lastLocale;
  final Map<String, dynamic> _stats = {};
  List<Book> _recentBooks = [];
  List<Book> _readingListBooks = [];
  Book? _heroBook;
  GamificationStatus? _gamificationStatus;
  String? _libraryName;

  final GlobalKey _addKey = GlobalKey(debugLabel: 'dashboard_add');
  final GlobalKey _searchKey = GlobalKey(debugLabel: 'dashboard_search');
  final GlobalKey _statsKey = GlobalKey(debugLabel: 'dashboard_stats');
  final GlobalKey _menuKey = GlobalKey(debugLabel: 'dashboard_menu');

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    // Verify locale changes on startup/init
    // Removed redundant _fetchDashboardData call in postFrameCallback
    // Add delay to ensure layout is complete and stable before showing wizard
    Future.delayed(const Duration(seconds: 1), _checkWizard);
    _checkBackupReminder();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentLocale = themeProvider.locale.languageCode;
    if (_lastLocale != null && _lastLocale != currentLocale) {
      _lastLocale = currentLocale;
      _fetchQuote();
    }
  }

  void _checkBackupReminder() async {
    if (await BackupReminderService.shouldShowReminder()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          BackupReminderService.showReminderDialog(context);
        }
      });
    }
  }

  void _checkWizard() async {
    // DISABLED: Dashboard spotlight wizard disabled for alpha release
    // to avoid UI issues during theme transitions
    return;
    
    /*
    if (!mounted) return;
    
    // Skip wizard completely for Kid profile
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    if (themeProvider.isKid) return;

    if (!await WizardService.hasSeenDashboardWizard()) {
      if (mounted) {
         WizardService.showDashboardWizard(
          context: context,
          addKey: _addKey,
          searchKey: _searchKey,
          statsKey: _statsKey,
          menuKey: _menuKey,
          onFinish: () {},
        );
      }
    }
    */
  }

  Future<void> _fetchDashboardData() async {
    final api = Provider.of<ApiService>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    // Background fetch of translations
    TranslationService.fetchTranslations(context);

    setState(() => _isLoading = true);

    try {
      try {
        print('Dashboard: Fetching books...');
        var books = await api.getBooks();
        print('Dashboard: Books fetched. Count: ${books.length}');

        print('Dashboard: Fetching config...');
        final configRes = await api.getLibraryConfig();
        print('Dashboard: Config fetched. Status: ${configRes.statusCode}');

        if (configRes.statusCode == 200) {
          final config = configRes.data;
          if (config['show_borrowed_books'] != true) {
            books = books.where((b) => b.readingStatus != 'borrowed').toList();
          }
          // Store library name
          final name = config['library_name'] ?? config['name'];
          if (name != null) {
            themeProvider.setLibraryName(name);
          }
          if (mounted) {
            setState(() {
              _libraryName = name;
            });
          }
        }

        if (mounted) {
          setState(() {
            _stats['total_books'] = books.length;
            _stats['borrowed_count'] = books
                .where((b) => !b.owned)
                .length;

            final readingListCandidates = books
                .where((b) => ['reading', 'to_read'].contains(b.readingStatus))
                .toList();

            readingListCandidates.sort((a, b) {
              if (a.readingStatus == 'reading' && b.readingStatus != 'reading')
                return -1;
              if (a.readingStatus != 'reading' && b.readingStatus == 'reading')
                return 1;
              return 0;
            });

            _readingListBooks = readingListCandidates.take(10).toList();

            final readingListIds = _readingListBooks.map((b) => b.id).toSet();

            final recentCandidates = books
                .where((b) => !readingListIds.contains(b.id))
                .toList();
            recentCandidates.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));

            _recentBooks = recentCandidates.take(10).toList();

            _heroBook = _readingListBooks.isNotEmpty
                ? _readingListBooks.first
                : (_recentBooks.isNotEmpty ? _recentBooks.first : null);
            if (_heroBook != null) {
              _readingListBooks.removeWhere((book) => book.id == _heroBook!.id);
              _recentBooks.removeWhere((book) => book.id == _heroBook!.id);
            }
          });
        }
      } catch (e) {
        debugPrint('Error fetching books: $e');
      }

      try {
        print('Dashboard: Fetching contacts...');
        final contactsRes = await api.getContacts();
        print('Dashboard: Contacts fetched.');
        if (contactsRes.statusCode == 200) {
          final List<dynamic> contactsData = contactsRes.data['contacts'];
          if (mounted) {
            setState(() {
              _stats['contacts_count'] = contactsData.length;
            });
          }
        }
      } catch (e) {
        debugPrint('Error fetching contacts: $e');
      }

      try {
        print('Dashboard: Fetching user status...');
        final statusRes = await api.getUserStatus();
        print('Dashboard: User status fetched.');
        if (statusRes.statusCode == 200) {
          final statusData = statusRes.data;
          if (mounted) {
            setState(() {
              _stats['active_loans'] = statusData['loans_count'] ?? 0;
              _userName = statusData['name'];
              _gamificationStatus = GamificationStatus.fromJson(statusData);
            });
          }
        }
      } catch (e) {
        debugPrint('Error fetching user status: $e');
      }

      // Fetch quote separate from main data to allow localized refresh
      print('Dashboard: Fetching quote...');
      await _fetchQuote();
      print('Dashboard: Quote fetched.');

      if (mounted) {
        print('Dashboard: Loading complete. Setting _isLoading = false');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching dashboard data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${TranslationService.translate(context, 'error_loading_dashboard')}: $e',
            ),
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchQuote() async {
    try {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      final allBooks = [..._recentBooks, ..._readingListBooks];

      // Even if books are empty, we try to fetch a quote (service handles fallback)
      final quoteService = QuoteService();
      final quote = await quoteService.fetchRandomQuote(
        allBooks,
        locale: themeProvider.locale.languageCode,
      );

      if (mounted) {
        setState(() {
          _dailyQuote = quote;
        });
      }
    } catch (e) {
      debugPrint('Error fetching quote: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isKid = themeProvider.isKid;
    final isLibrarian = themeProvider.isLibrarian;

    debugPrint('DashboardScreen: build called');
    debugPrint(
      'DashboardScreen: isKid=$isKid, isLibrarian=$isLibrarian, isLoading=$_isLoading',
    );
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 600;

    // Greeting logic removed as per user request

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GenieAppBar(
        title: 'BiblioGenius',
        // subtitle: _libraryName, // Handled by ThemeProvider
        leading: isWide
            ? null
            : IconButton(
                key: _menuKey,
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            key: _searchKey,
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              context.push('/books');
            },
          ),
        ],
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () {
      //     context.push('/genie-chat');
      //   },
      //   backgroundColor: Colors.blueAccent,
      //   child: const Icon(Icons.auto_awesome, color: Colors.white),
      // ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppDesign.pageGradientForTheme(
            Provider.of<ThemeProvider>(context).themeStyle,
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchDashboardData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Header with Quote
                        _buildHeader(context),
                        const SizedBox(height: 24),

                        // Stats Row - Full Width
                        Row(
                          key: _statsKey,
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                context,
                                TranslationService.translate(
                                  context,
                                  'my_books',
                                ),
                                (_stats['total_books'] ?? 0).toString(),
                                Icons.menu_book,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Lent books (prêtés) - visible for all
                            Expanded(
                              child: _buildStatCard(
                                context,
                                TranslationService.translate(
                                  context,
                                  'lent_status',
                                ),
                                (_stats['active_loans'] ?? 0).toString(),
                                Icons.arrow_upward,
                                isAccent: true,
                              ),
                            ),
                            // Borrowed books (empruntés) - hidden for librarians
                            if (!themeProvider.isLibrarian) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  context,
                                  TranslationService.translate(
                                    context,
                                    'borrowed_status',
                                  ),
                                  (_stats['borrowed_count'] ?? 0).toString(),
                                  Icons.arrow_downward,
                                ),
                              ),
                            ],
                            if (!isKid) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  context,
                                  themeProvider.isLibrarian
                                      ? TranslationService.translate(
                                          context,
                                          'borrowers',
                                        )
                                      : TranslationService.translate(
                                          context,
                                          'contacts',
                                        ),
                                  (_stats['contacts_count'] ?? 0).toString(),
                                  Icons.people,
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Gamification Mini-Widget
                        if (_gamificationStatus != null && !isKid)
                          _buildGamificationMini(context),

                        const SizedBox(height: 32),

                        // Main Content Container
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isKid) ...[
                              _buildSectionTitle(
                                context,
                                TranslationService.translate(
                                  context,
                                  'quick_actions',
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildKidActionCard(
                                      context,
                                      TranslationService.translate(
                                        context,
                                        'action_scan_barcode',
                                      ),
                                      Icons.qr_code_scanner,
                                      Colors.orange,
                                      () async {
                                        final isbn = await context.push<String>(
                                          '/scan',
                                        );
                                        if (isbn != null && context.mounted) {
                                          context.push(
                                            '/books/add',
                                            extra: {'isbn': isbn},
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildKidActionCard(
                                      context,
                                      TranslationService.translate(
                                        context,
                                        'action_search_online',
                                      ),
                                      Icons.search,
                                      Colors.blue,
                                      () => context.push('/search/external'),
                                      key: const Key('addBookButton'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                            ] else if (_heroBook != null)
                              // Hero Section
                              _buildHeroBook(context, _heroBook!),

                            if (!isKid) ...[
                              _buildSectionTitle(
                                context,
                                TranslationService.translate(
                                  context,
                                  'quick_actions',
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.08,
                                      ),
                                      blurRadius: 15,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: const Color(
                                      0xFF667eea,
                                    ).withValues(alpha: 0.1),
                                    width: 1,
                                  ),
                                ),
                                child: Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    _buildActionButton(
                                      context,
                                      TranslationService.translate(
                                        context,
                                        'action_add_book',
                                      ),
                                      Icons.add,
                                      () => context.push('/books/add'),
                                      isPrimary: true,
                                      key: _addKey,
                                      testKey: const Key('addBookButton'),
                                    ),
                                    _buildActionButton(
                                      context,
                                      TranslationService.translate(
                                        context,
                                        'action_checkout_book',
                                      ),
                                      Icons.upload_file,
                                      () => context.push('/network-search'),
                                    ),
                                    // _buildActionButton(
                                    //   context,
                                    //   TranslationService.translate(
                                    //     context,
                                    //     'ask_genie',
                                    //   ), // Translated
                                    //   Icons.auto_awesome,
                                    //   () => context.push('/genie-chat'),
                                    // ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),
                            ],

                            // Recent Books
                            if (_recentBooks.isNotEmpty) ...[
                              _buildSectionTitle(
                                context,
                                TranslationService.translate(
                                  context,
                                  'recent_books',
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.08,
                                      ),
                                      blurRadius: 15,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: _buildBookList(
                                  context,
                                  _recentBooks,
                                  TranslationService.translate(
                                    context,
                                    'no_recent_books',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                            ],

                            // Reading List
                            if (_readingListBooks.isNotEmpty) ...[
                              _buildSectionTitle(
                                context,
                                TranslationService.translate(
                                  context,
                                  'reading_list',
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.08,
                                      ),
                                      blurRadius: 15,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: _buildBookList(
                                  context,
                                  _readingListBooks,
                                  TranslationService.translate(
                                    context,
                                    'no_reading_list',
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 32),
                            if (!isKid)
                              Center(
                                child: ScaleOnTap(
                                  child: TextButton.icon(
                                    onPressed: () =>
                                        context.push('/statistics'),
                                    icon: const Icon(
                                      Icons.insights,
                                      color: Colors.black54,
                                    ),
                                    label: Text(
                                      TranslationService.translate(
                                        context,
                                        'view_insights',
                                      ),
                                      style: TextStyle(color: Colors.black54),
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 16,
                                      ),
                                      backgroundColor: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                        side: BorderSide(
                                          color: Colors.black.withValues(
                                            alpha: 0.1,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    if (_dailyQuote == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Theme-aware colors - dark wood for Sorbonne, soft pastel for light themes
    final bgColor = isDark ? const Color(0xFF2D1810) : const Color(0xFFF5F0E8);
    final textColor = isDark
        ? const Color(0xFFC4A35A)
        : const Color(0xFF4A3728);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppDesign.radiusLarge),
            border: isDark
                ? Border.all(color: const Color(0xFF5D3A1A), width: 1)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: SizedBox(
        width: double.infinity,
        child: Stack(
          clipBehavior: Clip.hardEdge,
            children: [
              // Decorative background icon
              Positioned(
                right: -20,
                top: -16,
                child: Icon(
                  Icons.format_quote_rounded,
                  size: 120,
                  color: textColor.withValues(alpha: 0.08),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dailyQuote!.text,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                        fontFamily: 'Georgia',
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 16,
                            height: 1,
                            color: textColor.withValues(alpha: 0.3),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _dailyQuote!.author,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

  String _getGreeting(BuildContext context) {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return TranslationService.translate(context, 'greeting_morning');
    } else if (hour < 18) {
      return TranslationService.translate(context, 'greeting_afternoon');
    } else {
      return TranslationService.translate(context, 'greeting_evening');
    }
  }

  Widget _buildGamificationMini(BuildContext context) {
    if (_gamificationStatus == null) return const SizedBox.shrink();

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isSorbonne = themeProvider.themeStyle == 'sorbonne';
    final cardColor = isSorbonne ? const Color(0xFF2D1810) : Colors.white;
    final accentColors = isSorbonne
        ? [const Color(0xFF8B4513), const Color(0xFF5D3A1A)] // Bronze/leather
        : [const Color(0xFF667eea), const Color(0xFF764ba2)]; // Blue-purple

    return GestureDetector(
      onTap: () => context.push('/profile'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppDesign.subtleShadow,
          border: isSorbonne
              ? Border.all(color: const Color(0xFF5D3A1A))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: accentColors),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.emoji_events,
                        color: isSorbonne
                            ? const Color(0xFFC4A35A)
                            : Colors.white,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      TranslationService.translate(context, 'your_progress'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniTrack(
                  context,
                  Icons.collections_bookmark,
                  _gamificationStatus!.collector,
                  Colors.blue,
                  TranslationService.translate(context, 'track_collector'),
                ),
                _buildMiniTrack(
                  context,
                  Icons.menu_book,
                  _gamificationStatus!.reader,
                  Colors.green,
                  TranslationService.translate(context, 'track_reader'),
                ),
                _buildMiniTrack(
                  context,
                  Icons.volunteer_activism,
                  _gamificationStatus!.lender,
                  Colors.orange,
                  TranslationService.translate(context, 'track_lender'),
                ),
                _buildMiniTrack(
                  context,
                  Icons.list_alt,
                  _gamificationStatus!.cataloguer,
                  Colors.purple,
                  TranslationService.translate(context, 'track_cataloguer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniTrack(
    BuildContext context,
    IconData icon,
    TrackProgress track,
    Color color,
    String label,
  ) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                value: track.progress,
                strokeWidth: 4,
                backgroundColor: color.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.1),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            if (track.level > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _getLevelColor(track.level),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      '${track.level}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label.split(' ').last,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 10,
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Color _getLevelColor(int level) {
    switch (level) {
      case 1:
        return const Color(0xFFCD7F32); // Bronze
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFFFD700); // Gold
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    bool isAccent = false,
  }) {
    final isSorbonne =
        Provider.of<ThemeProvider>(context, listen: false).themeStyle ==
        'sorbonne';
    final cardBg = isAccent
        ? Theme.of(context).primaryColor
        : (isSorbonne ? const Color(0xFF2D1810) : Colors.white);
    final borderClr = isAccent
        ? Colors.transparent
        : (isSorbonne
              ? const Color(0xFF5D3A1A)
              : Colors.grey.withValues(alpha: 0.3));
    final iconClr = isAccent
        ? Colors.white
        : (isSorbonne
              ? const Color(0xFFC4A35A)
              : Theme.of(context).primaryColor);
    final valueClr = isAccent
        ? Colors.white
        : (isSorbonne ? const Color(0xFFD4A855) : Colors.black87);
    final labelClr = isAccent
        ? Colors.white70
        : (isSorbonne ? const Color(0xFF8B7355) : Colors.black54);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderClr),
        boxShadow: isAccent
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ]
            : AppDesign.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconClr, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: valueClr,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: labelClr,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    IconData icon = Icons.auto_stories;
    if (title.toLowerCase().contains('recent') ||
        title.toLowerCase().contains('récent')) {
      icon = Icons.history;
    } else if (title.toLowerCase().contains('reading') ||
        title.toLowerCase().contains('lecture')) {
      icon = Icons.bookmark;
    } else if (title.toLowerCase().contains('action')) {
      icon = Icons.bolt;
    }

    final isSorbonne =
        Provider.of<ThemeProvider>(context, listen: false).themeStyle ==
        'sorbonne';
    final accentColors = isSorbonne
        ? [const Color(0xFF8B4513), const Color(0xFF5D3A1A)]
        : [const Color(0xFF667eea), const Color(0xFF764ba2)];
    final iconColor = isSorbonne
        ? const Color(0xFFC4A35A)
        : const Color(0xFF667eea);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: accentColors,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isSorbonne ? const Color(0xFFD4A855) : Colors.black87,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onPressed, {
    bool isPrimary = false,
    Key? key,
    Key? testKey,
  }) {
    final isSorbonne =
        Provider.of<ThemeProvider>(context, listen: false).themeStyle ==
        'sorbonne';
    final btnBg = isPrimary
        ? Theme.of(context).primaryColor
        : (isSorbonne ? const Color(0xFF2D1810) : Colors.white);
    final btnFg = isPrimary
        ? Colors.white
        : (isSorbonne
              ? const Color(0xFFC4A35A)
              : Theme.of(context).primaryColor);

    Widget button = ScaleOnTap(
      child: ElevatedButton.icon(
        key: key,
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: btnBg,
          foregroundColor: btnFg,
          elevation: isPrimary ? 4 : 2,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          shadowColor: Colors.black.withValues(alpha: 0.1),
        ),
      ),
    );

    if (testKey != null) {
      return KeyedSubtree(key: testKey, child: button);
    }
    return button;
  }

  Widget _buildBookList(
    BuildContext context,
    List<Book> books,
    String emptyMessage,
  ) {
    if (books.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: AppDesign.glassDecoration(),
        child: Center(
          child: Text(
            emptyMessage,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ),
      );
    }

    return SizedBox(
      height: 260,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: books.length,
        padding: const EdgeInsets.only(top: 8, bottom: 4, left: 4, right: 4),
        clipBehavior: Clip.none,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: PremiumBookCard(book: books[index]),
          );
        },
      ),
    );
  }

  Widget _buildHeroBook(BuildContext context, Book book) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: SizedBox(
        width: double.infinity,
        height: 300,
        child: PremiumBookCard(
          book: book,
          isHero: true,
          width: double.infinity,
          height: 300,
        ),
      ),
    );
  }

  Widget _buildKidActionCard(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    Key? key,
  }) {
    return ScaleOnTap(
      onTap: onTap,
      child: Container(
        key: key,
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppDesign.subtleShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
