import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/genie_app_bar.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../services/translation_service.dart';

class BorrowRequestsScreen extends StatefulWidget {
  const BorrowRequestsScreen({super.key});

  @override
  State<BorrowRequestsScreen> createState() => _BorrowRequestsScreenState();
}

class _BorrowRequestsScreenState extends State<BorrowRequestsScreen>
    with SingleTickerProviderStateMixin {
  Timer? _refreshTimer;
  late TabController _tabController;
  bool _isLoading = false;
  List<dynamic> _incomingRequests = [];
  List<dynamic> _outgoingRequests = [];
  List<dynamic> _connectionRequests = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchRequests();
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _fetchRequests(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchRequests({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final inRes = await api.getIncomingRequests();
      final outRes = await api.getOutgoingRequests();
      final connRes = await api.getPendingPeers();
      debugPrint('📥 getIncomingRequests response: ${inRes.data}');
      if (mounted) {
        setState(() {
          _incomingRequests = inRes.data;
          _outgoingRequests = outRes.data;
          _connectionRequests = connRes.data['requests'] ?? [];
        });
        debugPrint('📋 _fetchRequests: ${_connectionRequests.length} connection requests');
        debugPrint('📋 _fetchRequests: ${_incomingRequests.length} incoming requests');
        for (var r in _incomingRequests) {
          debugPrint('  📖 Incoming Request: ${r['book_title']} from ${r['peer_name']} status=${r['status']}');
        }
        for (var r in _connectionRequests) {
          debugPrint('  📚 Connection: id=${r['id']}, name="${r['name']}", url=${r['url']}');
        }
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

  Future<void> _updateStatus(String id, String status) async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      await api.updateRequestStatus(id, status);
      _fetchRequests(); // Refresh
    } on DioException catch (e) {
      if (mounted) {
        String errorMessage;
        // Handle 409 Conflict specifically (no available copies)
        if (e.response?.statusCode == 409) {
          final errorData = e.response?.data;
          if (errorData is Map && errorData['error']?.toString().contains('copies') == true) {
            errorMessage = TranslationService.translate(context, 'error_no_available_copies');
          } else {
            errorMessage = errorData?['error']?.toString() ?? 'Conflict: resource unavailable';
          }
        } else {
          errorMessage = e.response?.data?['error']?.toString() ?? e.message ?? 'Unknown error';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "${TranslationService.translate(context, 'snack_error_updating')}: $e",
            ),
          ),
        );
      }
    }
  }

  Future<void> _updatePeerStatus(Map<String, dynamic> peer, String status) async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      await api.updatePeerStatus(peer['id'], status);
      _fetchRequests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "${TranslationService.translate(context, 'snack_connection_updated')}: $status",
            ),
          ),
        );

        // Navigate to peer's library after accepting
        if (status == 'active') {
          context.push('/peers/${peer['id']}/books', extra: {
            'id': peer['id'],
            'name': peer['name'] ?? 'Unknown',
            'url': peer['url'] ?? '',
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating peer status: $e")),
        );
      }
    }
  }

  Future<void> _deleteRequest(String id, {bool isOutgoing = false}) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          TranslationService.translate(context, 'dialog_delete_title'),
        ),
        content: Text(
          TranslationService.translate(context, 'dialog_delete_body'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(TranslationService.translate(context, 'cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              TranslationService.translate(context, 'dialog_delete_confirm'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final api = Provider.of<ApiService>(context, listen: false);
    try {
      if (isOutgoing) {
        await api.deleteOutgoingRequest(id);
      } else {
        await api.deleteRequest(id);
      }
      _fetchRequests(); // Refresh
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error deleting request: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final bool isMobile = width <= 600;

    return Scaffold(
      appBar: GenieAppBar(
        title: TranslationService.translate(context, 'borrow_requests_title'),
        leading: isMobile
            ? IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              )
            : null,
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              key: Key('incomingTab'),
              icon: const Icon(Icons.move_to_inbox),
              text: TranslationService.translate(context, 'tab_incoming'),
            ),
            Tab(
              key: Key('outgoingTab'),
              icon: const Icon(Icons.outbox),
              text: TranslationService.translate(context, 'tab_outgoing'),
            ),
            Tab(
              key: Key('connectionsTab'),
              icon: const Icon(Icons.link),
              text: TranslationService.translate(context, 'tab_connections'),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchRequests,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  onRefresh: _fetchRequests,
                  child: _buildIncomingList(),
                ),
                RefreshIndicator(
                  onRefresh: _fetchRequests,
                  child: _buildOutgoingList(),
                ),
                RefreshIndicator(
                  onRefresh: _fetchRequests,
                  child: _buildConnectionList(),
                ),
              ],
            ),
    );
  }

  Widget _buildIncomingList() {
    if (_incomingRequests.isEmpty) {
      return _buildEmptyState(
        TranslationService.translate(context, 'no_incoming_requests'),
      );
    }
    return ListView.builder(
      key: const Key('incomingRequestsList'),
      itemCount: _incomingRequests.length,
      itemBuilder: (context, index) {
        final req = _incomingRequests[index];
        return _buildRequestTile(req, isIncoming: true);
      },
    );
  }

  Widget _buildOutgoingList() {
    if (_outgoingRequests.isEmpty) {
      return _buildEmptyState(
        TranslationService.translate(context, 'no_outgoing_requests'),
      );
    }
    return ListView.builder(
      itemCount: _outgoingRequests.length,
      itemBuilder: (context, index) {
        final req = _outgoingRequests[index];
        return _buildRequestTile(req, isIncoming: false);
      },
    );
  }

  Widget _buildConnectionList() {
    final incoming = _connectionRequests
        .where((r) => r['direction'] == 'incoming' || r['direction'] == null)
        .toList();
    final outgoing = _connectionRequests
        .where((r) => r['direction'] == 'outgoing')
        .toList();

    if (_connectionRequests.isEmpty) {
      return _buildEmptyState(
        TranslationService.translate(context, 'no_pending_connections'),
      );
    }

    return ListView(
      children: [
        if (incoming.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              TranslationService.translate(context, 'incoming_connections'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
            ),
          ),
          ...incoming.map((req) => _buildConnectionTile(req, isIncoming: true)),
        ],
        if (outgoing.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              TranslationService.translate(context, 'outgoing_connections'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
            ),
          ),
          ...outgoing.map(
            (req) => _buildConnectionTile(req, isIncoming: false),
          ),
        ],
      ],
    );
  }

  Widget _buildConnectionTile(
    Map<String, dynamic> req, {
    required bool isIncoming,
  }) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = (isDark ? Colors.white70 : Colors.black54);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(13) : Colors.grey.withAlpha(13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withAlpha(26) : Colors.grey.withAlpha(26),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isIncoming
                  ? const Color(0xFF8B4513).withAlpha(26)
                  : const Color(0xFF5D3A1A).withAlpha(26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isIncoming ? Icons.link : Icons.send_rounded,
              color: isIncoming ? const Color(0xFFD4A855) : const Color(0xFFA0724A),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          
          // Library Info (Between Icon and Buttons)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  req['name'] ??
                      TranslationService.translate(context, 'unknown_library'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  req['url'] ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: subColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 12),

          // Actions
          if (isIncoming)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _updatePeerStatus(req, 'active'),
                  child: Text(
                    TranslationService.translate(context, 'btn_accept'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red, width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _updatePeerStatus(req, 'rejected'),
                  child: Text(
                    TranslationService.translate(context, 'btn_reject'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF8B6914).withAlpha(26),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF8B6914).withAlpha(51)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFFD4A855)),
                  const SizedBox(width: 6),
                  Text(
                    TranslationService.translate(context, 'status_sent'),
                    style: const TextStyle(
                      color: Color(0xFFD4A855),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox, size: 64, color: Colors.white70),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 18, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestTile(
    Map<String, dynamic> req, {
    required bool isIncoming,
  }) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white70 : Colors.black54;
    
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: CircleAvatar(
            backgroundColor: isIncoming
                ? Colors.orange.withValues(alpha: 0.1)
                : const Color(0xFF8B6914).withValues(alpha: 0.1),
            child: Icon(
              isIncoming ? Icons.download : Icons.upload,
              color: isIncoming ? Colors.orange : const Color(0xFFD4A855),
              size: 20,
            ),
          ),
          title: Text(
            req['book_title'] ??
                TranslationService.translate(context, 'unknown_book'),
            style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isIncoming
                    ? "${TranslationService.translate(context, 'from')}: ${req['peer_name']}"
                    : "${TranslationService.translate(context, 'to')}: ${req['peer_name']}",
                style: TextStyle(color: subColor),
              ),
              const SizedBox(height: 4),
              _buildStatusText(req['status']),
            ],
          ),
          trailing: _buildActionButtons(req, isIncoming: isIncoming),
        ),
        const Divider(height: 1, indent: 72),
      ],
    );
  }

  Widget _buildStatusText(String status) {
    Color color;
    switch (status) {
      case 'pending':
        color = Colors.orange;
        break;
      case 'accepted':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      case 'returned':
        color = const Color(0xFFD4A855); // Bronze instead of blue
        break;
      default:
        color = Colors.grey;
    }
    return Text(
      status.toUpperCase(),
      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
    );
  }

  Widget _buildActionButtons(
    Map<String, dynamic> req, {
    required bool isIncoming,
  }) {
    final status = req['status'];
    final id = req['id'];

    if (isIncoming) {
      if (status == 'pending') {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.check, size: 16),
              label: Text(TranslationService.translate(context, 'btn_accept')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () => _updateStatus(id, 'accepted'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.close, size: 16),
              label: Text(TranslationService.translate(context, 'btn_reject')),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
              onPressed: () => _updateStatus(id, 'rejected'),
            ),
          ],
        );
      } else if (status == 'accepted') {
        return ElevatedButton.icon(
          icon: const Icon(Icons.assignment_return, size: 16),
          label: Text(
            TranslationService.translate(context, 'btn_mark_returned'),
          ),
          onPressed: () => _updateStatus(id, 'returned'),
        );
      }
    } else {
      // Outgoing
      if (status == 'pending') {
        return OutlinedButton.icon(
          icon: const Icon(Icons.cancel, size: 16),
          label: Text(
            TranslationService.translate(context, 'btn_cancel_request'),
          ),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () => _deleteRequest(id, isOutgoing: true),
        );
      }
    }

    // Allow deleting finished/rejected requests to clean up list
    if (['rejected', 'returned', 'cancelled'].contains(status)) {
      return TextButton.icon(
        icon: const Icon(Icons.delete_outline, size: 16),
        label: Text(TranslationService.translate(context, 'btn_remove')),
        style: TextButton.styleFrom(foregroundColor: Colors.grey),
        onPressed: () => _deleteRequest(id, isOutgoing: !isIncoming),
      );
    }

    return const SizedBox.shrink();
  }
}
