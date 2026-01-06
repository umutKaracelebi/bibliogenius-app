import 'package:flutter/material.dart';
import '../widgets/genie_app_bar.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../services/translation_service.dart';
import '../providers/theme_provider.dart';

/// Screen for managing loans, borrows, and P2P requests
/// Structure:
/// - Demandes (Requests): Incoming/Outgoing/Connections
/// - Prêtés (Lent): Books you lent to others
/// - Empruntés (Borrowed): Books you borrowed from others (hidden if canBorrowBooks=false)
class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen>
    with TickerProviderStateMixin {
  Timer? _refreshTimer;
  late TabController _mainTabController;
  late TabController _requestsTabController;
  bool _isLoading = false;

  // Requests data
  List<dynamic> _incomingRequests = [];
  List<dynamic> _outgoingRequests = [];
  List<dynamic> _connectionRequests = [];

  // Loans data
  List<dynamic> _activeLoans = []; // Books I lent to others
  List<dynamic> _borrowedBooks = []; // Books I borrowed from others

  @override
  void initState() {
    super.initState();
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final tabCount = themeProvider.canBorrowBooks ? 3 : 2;
    _mainTabController = TabController(length: tabCount, vsync: this);
    _requestsTabController = TabController(length: 3, vsync: this);
    _fetchAllData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _fetchAllData(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _mainTabController.dispose();
    _requestsTabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      // Fetch requests
      final inRes = await api.getIncomingRequests();
      final outRes = await api.getOutgoingRequests();
      final connRes = await api.getPendingPeers();

      // Fetch active loans (books I lent)
      final loansRes = await api.getLoans(status: 'active');

      List<dynamic> borrowedBooks = [];
      try {
        final borrowedRes = await api.getLoans(status: 'borrowed');
        borrowedBooks = borrowedRes.data['loans'] ?? [];
      } catch (e) {
        debugPrint('Could not fetch borrowed books: $e');
      }

      if (mounted) {
        setState(() {
          _incomingRequests = inRes.data;
          _outgoingRequests = outRes.data;
          _connectionRequests = connRes.data['requests'] ?? [];
          _activeLoans = loansRes.data['loans'] ?? [];
          _borrowedBooks = borrowedBooks;
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "${TranslationService.translate(context, 'snack_error_fetching')}: $e",
            ),
          ),
        );
      }
    } finally {
      if (mounted && !silent) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateRequestStatus(String id, String status) async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      await api.updateRequestStatus(id, status);
      _fetchAllData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_getFriendlyErrorMessage(e))));
      }
    }
  }

  Future<void> _returnLoan(int loanId) async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      await api.returnLoan(loanId);
      _fetchAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              TranslationService.translate(context, 'snack_loan_returned'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_getFriendlyErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final bool isMobile = width <= 600;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final canBorrow = themeProvider.canBorrowBooks;

    return Scaffold(
      appBar: GenieAppBar(
        title: TranslationService.translate(context, 'loans_menu'),
        leading: isMobile
            ? IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              )
            : null,
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _mainTabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              key: const Key('requestsTab'),
              icon: const Icon(Icons.mail_outline),
              text: TranslationService.translate(context, 'tab_requests'),
            ),
            Tab(
              key: const Key('lentTab'),
              icon: const Icon(Icons.arrow_upward),
              text: TranslationService.translate(context, 'tab_lent'),
            ),
            if (canBorrow)
              Tab(
                key: const Key('borrowedTab'),
                icon: const Icon(Icons.arrow_downward),
                text: TranslationService.translate(context, 'tab_borrowed'),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchAllData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _mainTabController,
              children: [
                _buildRequestsTab(),
                _buildLentTab(),
                if (canBorrow) _buildBorrowedTab(),
              ],
            ),
    );
  }

  /// Requests tab with nested tabs (Incoming/Outgoing/Connections)
  Widget _buildRequestsTab() {
    return Column(
      children: [
        Material(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          child: TabBar(
            controller: _requestsTabController,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: [
              Tab(
                text:
                    '${TranslationService.translate(context, 'tab_received')} (${_incomingRequests.length})',
              ),
              Tab(
                text:
                    '${TranslationService.translate(context, 'tab_sent')} (${_outgoingRequests.length})',
              ),
              Tab(
                text:
                    '${TranslationService.translate(context, 'tab_connections')} (${_connectionRequests.length})',
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _requestsTabController,
            children: [
              RefreshIndicator(
                onRefresh: _fetchAllData,
                child: _buildIncomingList(),
              ),
              RefreshIndicator(
                onRefresh: _fetchAllData,
                child: _buildOutgoingList(),
              ),
              RefreshIndicator(
                onRefresh: _fetchAllData,
                child: _buildConnectionList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Lent tab - books I lent to others
  Widget _buildLentTab() {
    if (_activeLoans.isEmpty) {
      return _buildEmptyState(
        TranslationService.translate(context, 'empty_no_loans'),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchAllData,
      child: ListView.builder(
        itemCount: _activeLoans.length,
        itemBuilder: (context, index) {
          final loan = _activeLoans[index];
          return _buildLoanTile(loan);
        },
      ),
    );
  }

  Widget _buildLoanTile(Map<String, dynamic> loan) {
    final bookTitle = loan['book_title'] ?? 'Unknown';
    final contactName = loan['contact_name'] ?? 'Unknown';
    final loanDate = loan['loan_date'] ?? '';
    final dueDate = loan['due_date'] ?? '';
    final loanId = loan['id'] as int;

    final isOverdue =
        dueDate.isNotEmpty &&
        DateTime.tryParse(dueDate)?.isBefore(DateTime.now()) == true;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isOverdue ? Colors.red : Colors.green,
          child: Icon(
            isOverdue ? Icons.warning : Icons.book,
            color: Colors.white,
          ),
        ),
        title: Text(
          bookTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${TranslationService.translate(context, 'lent_to')}: $contactName',
            ),
            if (loanDate.isNotEmpty)
              Text(
                '${TranslationService.translate(context, 'loan_date')}: ${_formatDate(loanDate)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            if (dueDate.isNotEmpty)
              Text(
                '${TranslationService.translate(context, 'due_date')}: ${_formatDate(dueDate)}',
                style: TextStyle(
                  color: isOverdue ? Colors.red : Colors.grey[600],
                  fontSize: 12,
                  fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                ),
              ),
          ],
        ),
        trailing: FilledButton.icon(
          onPressed: () => _returnLoan(loanId),
          icon: const Icon(Icons.check, size: 18),
          label: Text(TranslationService.translate(context, 'mark_returned')),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
        isThreeLine: true,
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  /// Borrowed tab - books I borrowed from others
  Widget _buildBorrowedTab() {
    if (_borrowedBooks.isEmpty) {
      return _buildEmptyState(
        TranslationService.translate(context, 'empty_no_borrowed'),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchAllData,
      child: ListView.builder(
        itemCount: _borrowedBooks.length,
        itemBuilder: (context, index) {
          final book = _borrowedBooks[index];
          return ListTile(
            title: Text(book['title'] ?? 'Unknown'),
            subtitle: Text(book['from_library'] ?? ''),
          );
        },
      ),
    );
  }

  // === Request list builders (from original) ===

  Widget _buildIncomingList() {
    if (_incomingRequests.isEmpty) {
      return _buildEmptyState(
        TranslationService.translate(context, 'empty_no_incoming'),
      );
    }
    return ListView.builder(
      itemCount: _incomingRequests.length,
      itemBuilder: (context, index) {
        return _buildRequestTile(_incomingRequests[index], isIncoming: true);
      },
    );
  }

  Widget _buildOutgoingList() {
    if (_outgoingRequests.isEmpty) {
      return _buildEmptyState(
        TranslationService.translate(context, 'empty_no_outgoing'),
      );
    }
    return ListView.builder(
      itemCount: _outgoingRequests.length,
      itemBuilder: (context, index) {
        return _buildRequestTile(_outgoingRequests[index], isIncoming: false);
      },
    );
  }

  Widget _buildConnectionList() {
    if (_connectionRequests.isEmpty) {
      return _buildEmptyState(
        TranslationService.translate(context, 'empty_no_connections'),
      );
    }
    return ListView.builder(
      itemCount: _connectionRequests.length,
      itemBuilder: (context, index) {
        return _buildConnectionTile(_connectionRequests[index]);
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestTile(
    Map<String, dynamic> req, {
    required bool isIncoming,
  }) {
    final title = req['book_title'] ?? 'Unknown';
    final peerName = req['peer_name'] ?? 'Unknown';
    final status = req['status'] ?? 'pending';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(status),
          child: const Icon(Icons.book, color: Colors.white),
        ),
        title: Text(title),
        subtitle: Text(
          isIncoming
              ? '${TranslationService.translate(context, 'request_from')}: $peerName'
              : '${TranslationService.translate(context, 'request_to')}: $peerName',
        ),
        trailing: _buildStatusChip(status),
        onTap: () => _showRequestActions(req, isIncoming: isIncoming),
      ),
    );
  }

  Widget _buildConnectionTile(Map<String, dynamic> peer) {
    final name = peer['name'] ?? 'Unknown';
    final url = peer['url'] ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person_add)),
        title: Text(name),
        subtitle: Text(url),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: () => _acceptConnection(peer),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () => _rejectConnection(peer),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  Widget _buildStatusChip(String status) {
    return Chip(
      label: Text(
        TranslationService.translate(context, 'status_$status'),
        style: const TextStyle(fontSize: 12, color: Colors.white),
      ),
      backgroundColor: _getStatusColor(status),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  void _showRequestActions(
    Map<String, dynamic> req, {
    required bool isIncoming,
  }) {
    final id = req['id']?.toString() ?? '';
    final status = req['status'] ?? 'pending';

    if (status != 'pending') return;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isIncoming) ...[
              ListTile(
                leading: const Icon(Icons.check, color: Colors.green),
                title: Text(
                  TranslationService.translate(context, 'action_approve'),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _updateRequestStatus(id, 'accepted');
                },
              ),
              ListTile(
                leading: const Icon(Icons.close, color: Colors.red),
                title: Text(
                  TranslationService.translate(context, 'action_reject'),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _updateRequestStatus(id, 'rejected');
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(
                  TranslationService.translate(context, 'action_cancel'),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteRequest(id);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _deleteRequest(String id) async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      await api.deleteRequest(id);
      _fetchAllData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_getFriendlyErrorMessage(e))));
      }
    }
  }

  Future<void> _acceptConnection(Map<String, dynamic> peer) async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      await api.updatePeerStatus(peer['id'], 'active');
      _fetchAllData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_getFriendlyErrorMessage(e))));
      }
    }
  }

  Future<void> _rejectConnection(Map<String, dynamic> peer) async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      await api.updatePeerStatus(peer['id'], 'rejected');
      _fetchAllData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_getFriendlyErrorMessage(e))));
      }
    }
  }

  String _getFriendlyErrorMessage(Object error) {
    if (error is DioException) {
      if (error.response?.statusCode == 409) {
        return TranslationService.translate(context, 'error_409_conflict');
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return TranslationService.translate(context, 'error_peer_timeout');
      }
      if (error.type == DioExceptionType.connectionError) {
        return TranslationService.translate(context, 'error_peer_offline');
      }
      return error.response?.data?['error']?.toString() ??
          error.message ??
          error.toString();
    }
    return error.toString();
  }
}

// Keep old class name for backward compatibility with routing
class BorrowRequestsScreen extends LoansScreen {
  const BorrowRequestsScreen({super.key});
}
