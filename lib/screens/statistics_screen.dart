import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../services/translation_service.dart';
import '../models/gamification_status.dart';
import '../models/book.dart';
import '../models/contact.dart';
import '../widgets/genie_app_bar.dart';
import '../theme/app_design.dart';
import '../widgets/gamification_widgets.dart';
import '../providers/theme_provider.dart';
import 'package:intl/intl.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with TickerProviderStateMixin {
  List<Book> _books = [];
  List<dynamic> _loans = [];
  Map<int, Contact> _contactsMap = {};
  GamificationStatus? _userStatus;
  Map<String, dynamic>? _salesStats;
  bool _isLoading = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // late AnimationController _pulseController; removed
  // late Animation<double> _pulseAnimation; removed

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _fetchData();
  }

  @override
  void dispose() {
    _animController.dispose();
    // _pulseController.dispose() removed
    super.dispose();
  }

  Future<void> _fetchData() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final books = await api.getBooks();

      // Fetch loans
      List<dynamic> loans = [];
      try {
        final loansRes = await api.getLoans();
        if (loansRes.statusCode == 200) {
          loans = loansRes.data['loans'] ?? loansRes.data ?? [];
        }
      } catch (e) {
        debugPrint('Error fetching loans: $e');
      }

      GamificationStatus? status;
      try {
        final statusRes = await api.getUserStatus();
        if (statusRes.statusCode == 200) {
          status = GamificationStatus.fromJson(statusRes.data);
        }
      } catch (e) {
        debugPrint('Error fetching gamification stats: $e');
      }

      // Fetch contacts for names
      Map<int, Contact> contactsMap = {};
      try {
        final contactsRes = await api.getContacts();
        if (contactsRes.statusCode == 200) {
          final List<dynamic> list = contactsRes.data['contacts'] ?? [];
          for (var json in list) {
            final c = Contact.fromJson(json);
            if (c.id != null) {
              contactsMap[c.id!] = c;
            }
          }
        }
      } catch (e) {}

      Map<String, dynamic>? salesStats;
      if (Provider.of<ThemeProvider>(context, listen: false).isBookseller) {
        try {
          final statsRes = await api.getSalesStatistics();
          if (statsRes.statusCode == 200) {
            salesStats = statsRes.data;
          }
        } catch (e) {
          debugPrint('Error fetching sales stats: $e');
        }
      }

      if (mounted) {
        setState(() {
          _books = books;
          _loans = loans;
          _contactsMap = contactsMap;
          _userStatus = status;
          _salesStats = salesStats;
          _isLoading = false;
        });
        _animController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final bool isMobile = width <= 600;

    return Scaffold(
      appBar: GenieAppBar(
        title: TranslationService.translate(context, 'library_insights'),
        leading: isMobile
            ? IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              )
            : null,
        automaticallyImplyLeading: false,
        showQuickActions: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _books.isEmpty
          ? _buildEmptyState()
          : FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryCards(),
                    if (_salesStats != null) ...[
                      const SizedBox(height: 32),
                      _buildSectionTitle(
                        TranslationService.translate(
                          context,
                          'sales_statistics',
                        ),
                        Icons.monetization_on,
                        AppDesign.successGradient,
                      ),
                      const SizedBox(height: 16),
                      _buildSalesStatisticsSection(),
                    ],
                    const SizedBox(height: 32),
                    if (_userStatus != null &&
                        Provider.of<ThemeProvider>(
                          context,
                        ).gamificationEnabled) ...[
                      _buildSectionTitle(
                        TranslationService.translate(context, 'your_progress'),
                        Icons.emoji_events,
                        AppDesign.primaryGradient,
                      ),
                      const SizedBox(height: 16),
                      _buildGamificationSection(),
                      const SizedBox(height: 32),
                    ],
                    _buildSectionTitle(
                      TranslationService.translate(context, 'reading_habits'),
                      Icons.pie_chart,
                      AppDesign.primaryGradient,
                    ),
                    const SizedBox(height: 16),
                    _buildStatusPieChart(),
                    const SizedBox(height: 32),
                    _buildSectionTitle(
                      TranslationService.translate(context, 'top_authors'),
                      Icons.person,
                      AppDesign.successGradient,
                    ),
                    const SizedBox(height: 16),
                    _buildTopAuthorsChart(),
                    const SizedBox(height: 32),
                    _buildSectionTitle(
                      TranslationService.translate(
                        context,
                        'publication_timeline',
                      ),
                      Icons.timeline,
                      AppDesign.oceanGradient,
                    ),
                    const SizedBox(height: 16),
                    _buildPublicationYearChart(),
                    const SizedBox(height: 32),
                    // Loan Statistics Section
                    _buildSectionTitle(
                      TranslationService.translate(context, 'loan_statistics'),
                      Icons.swap_horiz,
                      AppDesign.accentGradient,
                    ),
                    const SizedBox(height: 16),
                    _buildLoanStatisticsSection(),
                    // Borrowed Statistics Section - hidden for librarians
                    if (!Provider.of<ThemeProvider>(
                      context,
                      listen: false,
                    ).isLibrarian) ...[
                      const SizedBox(height: 32),
                      _buildSectionTitle(
                        TranslationService.translate(
                          context,
                          'borrowed_statistics',
                        ),
                        Icons.arrow_downward,
                        AppDesign.oceanGradient,
                      ),
                      const SizedBox(height: 16),
                      _buildBorrowedStatisticsSection(),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.analytics_outlined,
              size: 64,
              color: Color(0xFF6366F1),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            TranslationService.translate(context, 'no_books_analyze'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'Add books to see your reading statistics',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Gradient gradient) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    final totalBooks = _books.length;
    final readBooks = _books.where((b) => b.readingStatus == 'read').length;
    final borrowedBooks = _books.where((b) => !b.owned).length;

    final uniqueAuthors = _books
        .where((b) => b.author != null && b.author!.isNotEmpty)
        .map((b) => b.author!)
        .toSet()
        .length;

    final completionRate = totalBooks > 0
        ? (readBooks / totalBooks * 100).toStringAsFixed(0)
        : '0';

    final booksWithYears = _books
        .where((b) => b.publicationYear != null && b.publicationYear! > 1800)
        .toList();
    final oldestYear = booksWithYears.isEmpty
        ? null
        : booksWithYears
              .map((b) => b.publicationYear!)
              .reduce((a, b) => a < b ? a : b);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                TranslationService.translate(context, 'stat_total_books'),
                totalBooks.toString(),
                Icons.library_books,
                AppDesign.primaryGradient,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                TranslationService.translate(context, 'stat_read'),
                readBooks.toString(),
                Icons.check_circle,
                AppDesign.successGradient,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                TranslationService.translate(context, 'stat_borrowed'),
                borrowedBooks.toString(),
                Icons.people,
                AppDesign.accentGradient,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                TranslationService.translate(context, 'stat_unique_authors'),
                uniqueAuthors.toString(),
                Icons.person_outline,
                AppDesign.warningGradient,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                TranslationService.translate(context, 'stat_completion'),
                "$completionRate%",
                Icons.trending_up,
                AppDesign.oceanGradient,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                TranslationService.translate(context, 'stat_oldest_book'),
                oldestYear?.toString() ?? "N/A",
                Icons.history,
                AppDesign.darkGradient,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Gradient gradient,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppDesign.radiusMedium),
        boxShadow: AppDesign.subtleShadow,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPieChart() {
    final statusCounts = <String, int>{};
    for (var book in _books) {
      final status = book.readingStatus ?? 'unknown';
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }

    final colors = {
      'read': const Color(0xFF10B981),
      'reading': const Color(0xFF0EA5E9),
      'to_read': const Color(0xFFF59E0B),
      'wanted': const Color(0xFFEC4899),
      'owned': const Color(0xFF607D8B),
      'borrowed': const Color(0xFF8B5CF6),
      'unknown': Colors.grey,
    };

    final List<PieChartSectionData> sections = [];
    statusCounts.forEach((status, count) {
      final color = colors[status] ?? Colors.grey;
      final percentage = (count / _books.length * 100).toStringAsFixed(0);
      sections.add(
        PieChartSectionData(
          color: color,
          value: count.toDouble(),
          title: '$percentage%',
          radius: 70,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    });

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppDesign.radiusLarge),
        boxShadow: AppDesign.cardShadow,
      ),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 50,
                sectionsSpace: 3,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: statusCounts.entries.map((e) {
              final color = colors[e.key] ?? Colors.grey;
              final label = _formatStatusLabel(e.key);
              return _buildLegendItem(color, label, e.value);
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _formatStatusLabel(String status) {
    switch (status) {
      case 'read':
        return TranslationService.translate(context, 'reading_status_read');
      case 'reading':
        return TranslationService.translate(context, 'reading_status_reading');
      case 'to_read':
        return TranslationService.translate(context, 'reading_status_to_read');
      case 'wanted':
      case 'wanting':
        return TranslationService.translate(context, 'reading_status_wanting');
      case 'owned':
        return TranslationService.translate(context, 'owned_status');
      case 'lent':
        return TranslationService.translate(context, 'reading_status_lent');
      case 'borrowed':
        return TranslationService.translate(context, 'reading_status_borrowed');
      default:
        return status.replaceAll('_', ' ');
    }
  }

  Widget _buildLegendItem(Color color, String label, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ($count)',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildTopAuthorsChart() {
    final authorCounts = <String, int>{};
    for (var book in _books) {
      if (book.author != null && book.author!.isNotEmpty) {
        authorCounts[book.author!] = (authorCounts[book.author!] ?? 0) + 1;
      }
    }

    var sortedAuthors = authorCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sortedAuthors.length > 5) {
      sortedAuthors = sortedAuthors.sublist(0, 5);
    }

    if (sortedAuthors.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppDesign.radiusLarge),
          boxShadow: AppDesign.cardShadow,
        ),
        child: const Center(child: Text('No author data available')),
      );
    }

    return Container(
      height: 280,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppDesign.radiusLarge),
        boxShadow: AppDesign.cardShadow,
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: sortedAuthors.first.value.toDouble() + 1,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => const Color(0xFF1E293B),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${sortedAuthors[groupIndex].key}\n',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  children: [
                    TextSpan(
                      text: '${rod.toY.toInt()} books',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  if (value.toInt() >= sortedAuthors.length) {
                    return const SizedBox.shrink();
                  }
                  final author = sortedAuthors[value.toInt()].key;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      author.length > 10
                          ? '${author.substring(0, 8)}...'
                          : author,
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
                reservedSize: 40,
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: sortedAuthors.asMap().entries.map((e) {
            final gradient = AppDesign.featureGradient(e.key);
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.value.toDouble(),
                  gradient: gradient,
                  width: 24,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPublicationYearChart() {
    final yearCounts = <int, int>{};
    for (var book in _books) {
      if (book.publicationYear != null && book.publicationYear! > 1800) {
        final decade = (book.publicationYear! ~/ 10) * 10;
        yearCounts[decade] = (yearCounts[decade] ?? 0) + 1;
      }
    }

    final sortedYears = yearCounts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (sortedYears.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppDesign.radiusLarge),
          boxShadow: AppDesign.cardShadow,
        ),
        child: Center(
          child: Text(
            TranslationService.translate(context, 'no_pub_year_data'),
          ),
        ),
      );
    }

    return Container(
      height: 280,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppDesign.radiusLarge),
        boxShadow: AppDesign.cardShadow,
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.black.withValues(alpha: 0.5),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < sortedYears.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        sortedYears[index].key.toString(),
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
                interval: 1,
                reservedSize: 30,
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: sortedYears.asMap().entries.map((e) {
                return FlSpot(e.key.toDouble(), e.value.value.toDouble());
              }).toList(),
              isCurved: true,
              gradient: AppDesign.oceanGradient,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 5,
                    color: const Color(0xFF0EA5E9),
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0EA5E9).withValues(alpha: 0.3),
                    const Color(0xFF0EA5E9).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => const Color(0xFF1E293B),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final year = sortedYears[spot.x.toInt()].key;
                  return LineTooltipItem(
                    '${year}s\n',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    children: [
                      TextSpan(
                        text: '${spot.y.toInt()} books',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGamificationSection() {
    if (_userStatus == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppDesign.radiusLarge),
        boxShadow: AppDesign.cardShadow,
      ),
      child: Column(
        children: [
          // Badge display at top
          // Badge display at top
          CurrentBadgeWidget(statusLevel: _userStatus!.statusLevel),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildStreakCard(
                    _userStatus!.streak.current,
                    TranslationService.translate(context, 'current_streak'),
                    Icons.local_fire_department,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStreakCard(
                    _userStatus!.streak.longest,
                    TranslationService.translate(context, 'best_streak'),
                    Icons.emoji_events_outlined,
                    Colors.amber,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          BadgeCollectionWidget(statusLevel: _userStatus!.statusLevel),
          const SizedBox(height: 24),
          const Divider(height: 1, indent: 24, endIndent: 24),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final collectors = _buildCircularTrack(
                  context,
                  TranslationService.translate(context, 'track_collector'),
                  _userStatus!.collector,
                  Icons.collections_bookmark,
                  const Color(0xFFD4A855), // Bronze instead of blue
                );
                final reader = _buildCircularTrack(
                  context,
                  TranslationService.translate(context, 'track_reader'),
                  _userStatus!.reader,
                  Icons.menu_book,
                  Colors.green,
                );
                final lender = _buildCircularTrack(
                  context,
                  TranslationService.translate(context, 'track_lender'),
                  _userStatus!.lender,
                  Icons.volunteer_activism,
                  Colors.orange,
                );
                final cataloguer = _buildCircularTrack(
                  context,
                  TranslationService.translate(context, 'track_cataloguer'),
                  _userStatus!.cataloguer,
                  Icons.list_alt,
                  const Color(0xFF8B4513), // Bronze instead of purple
                );

                // Use 2x2 grid for narrow screens (< 400px)
                if (constraints.maxWidth < 400) {
                  return Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [collectors, reader],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [lender, cataloguer],
                      ),
                    ],
                  );
                }
                // Use Row for wide screens
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [collectors, reader, lender, cataloguer],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard(int count, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularTrack(
    BuildContext context,
    String title,
    TrackProgress track,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: () => showTrackLevelInfo(
          context,
          trackName: title,
          track: track,
          icon: icon,
          color: color,
        ),
        child: Column(
          children: [
            SizedBox(
              width: 70,
              height: 70,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 6,
                      color: color.withValues(alpha: 0.1),
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      value: track.progress,
                      strokeWidth: 6,
                      color: color,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Icon(icon, color: color, size: 28),
                  if (track.level > 0)
                    Positioned(
                      top: 0,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          track.level.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title.split(' ').last,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // Show progress intelligently: if current >= nextThreshold, show level completed
            Text(
              track.isMaxLevel
                  ? '${track.current} ✓'
                  : track.current >= track.nextThreshold
                  ? '${track.current}/${track.nextThreshold} ✓'
                  : '${track.current}/${track.nextThreshold}',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoanStatisticsSection() {
    // Calculate loan statistics
    final totalLoans = _loans.length;
    final activeLoans = _loans.where((l) => l['return_date'] == null).length;
    final returnedLoans = _loans.where((l) => l['return_date'] != null).length;

    // Calculate average loan duration (for returned loans)
    double avgDuration = 0;
    final returnedWithDates = _loans
        .where((l) => l['return_date'] != null && l['loan_date'] != null)
        .toList();

    if (returnedWithDates.isNotEmpty) {
      int totalDays = 0;
      for (var loan in returnedWithDates) {
        try {
          final loanDate = DateTime.parse(loan['loan_date']);
          final returnDate = DateTime.parse(loan['return_date']);
          totalDays += returnDate.difference(loanDate).inDays;
        } catch (_) {}
      }
      avgDuration = totalDays / returnedWithDates.length;
    }

    // Top borrowers (contacts)
    final borrowerCounts = <String, int>{};
    for (var loan in _loans) {
      String contactName = 'Unknown';
      final contactId = loan['contact_id'];

      if (contactId != null && _contactsMap.containsKey(contactId)) {
        final contact = _contactsMap[contactId]!;
        contactName = contact.fullName;
      } else {
        contactName =
            loan['contact_name'] ?? loan['contact']?['name'] ?? 'Unknown';
      }

      borrowerCounts[contactName] = (borrowerCounts[contactName] ?? 0) + 1;
    }
    var topBorrowers = borrowerCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (topBorrowers.length > 5) topBorrowers = topBorrowers.sublist(0, 5);

    // Most lent books
    final bookCounts = <String, int>{};
    for (var loan in _loans) {
      final bookTitle =
          loan['book_title'] ?? loan['book']?['title'] ?? 'Unknown';
      bookCounts[bookTitle] = (bookCounts[bookTitle] ?? 0) + 1;
    }
    var mostLentBooks = bookCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (mostLentBooks.length > 5) mostLentBooks = mostLentBooks.sublist(0, 5);

    // Return rate
    final returnRate = totalLoans > 0
        ? (returnedLoans / totalLoans * 100).toStringAsFixed(0)
        : '0';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppDesign.radiusLarge),
        boxShadow: AppDesign.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary stats row
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  TranslationService.translate(context, 'total_loans'),
                  totalLoans.toString(),
                  Icons.swap_horiz,
                  const Color(0xFF8B4513), // Bronze instead of purple
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMiniStat(
                  TranslationService.translate(context, 'active_loans'),
                  activeLoans.toString(),
                  Icons.arrow_upward,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMiniStat(
                  TranslationService.translate(context, 'return_rate'),
                  '$returnRate%',
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMiniStat(
                  TranslationService.translate(context, 'avg_duration'),
                  '${avgDuration.toStringAsFixed(0)}j',
                  Icons.timer,
                  const Color(0xFFD4A855), // Bronze instead of blue
                ),
              ),
            ],
          ),

          if (topBorrowers.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              TranslationService.translate(context, 'top_borrowers'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ...topBorrowers.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 18,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.key,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B4513).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${e.value} ${TranslationService.translate(context, 'loans_label')}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8B4513),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (mostLentBooks.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              TranslationService.translate(context, 'most_lent_books'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ...mostLentBooks.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.menu_book, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.key,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4A855).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${e.value}x',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFD4A855),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniStat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildBorrowedStatisticsSection() {
    // Get borrowed books from library
    final borrowedBooks = _books.where((b) => !b.owned).toList();
    final totalBorrowed = borrowedBooks.length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppDesign.radiusLarge),
        boxShadow: AppDesign.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary stat
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  TranslationService.translate(context, 'books_borrowed'),
                  totalBorrowed.toString(),
                  Icons.arrow_downward,
                  Colors.teal,
                ),
              ),
            ],
          ),

          if (borrowedBooks.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              TranslationService.translate(context, 'borrowed_books_list'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ...borrowedBooks
                .take(5)
                .map(
                  (book) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.menu_book,
                          size: 18,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                book.title,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (book.author != null)
                                Text(
                                  book.author!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ] else ...[
            const SizedBox(height: 16),
            Center(
              child: Text(
                TranslationService.translate(context, 'no_borrowed_books'),
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSalesStatisticsSection() {
    if (_salesStats == null) return const SizedBox.shrink();

    final totalRevenue =
        (_salesStats!['total_revenue'] as num?)?.toDouble() ?? 0.0;
    final totalSales = (_salesStats!['total_sales'] as num?)?.toInt() ?? 0;
    final avgPrice = (_salesStats!['average_price'] as num?)?.toDouble() ?? 0.0;

    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '€');

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                TranslationService.translate(context, 'total_revenue'),
                currencyFormat.format(totalRevenue),
                Icons.euro,
                AppDesign.successGradient,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                TranslationService.translate(context, 'sales_count'),
                totalSales.toString(),
                Icons.shopping_cart,
                AppDesign.primaryGradient,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                TranslationService.translate(context, 'average_price'),
                currencyFormat.format(avgPrice),
                Icons.price_check,
                AppDesign.oceanGradient,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
