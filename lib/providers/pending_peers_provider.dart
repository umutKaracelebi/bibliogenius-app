import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/api_service.dart';

/// Tracks the count of pending peer connection requests.
/// Used to display a badge on the Network tab.
class PendingPeersProvider extends ChangeNotifier {
  final ApiService _apiService;
  int _pendingCount = 0;
  Timer? _refreshTimer;

  PendingPeersProvider(this._apiService) {
    refresh();
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => refresh(),
    );
  }

  int get pendingCount => _pendingCount;

  Future<void> refresh() async {
    try {
      final response = await _apiService.getPendingPeers();
      final requests = response.data['requests'] as List? ?? [];
      final newCount = requests.length;
      if (newCount != _pendingCount) {
        _pendingCount = newCount;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('PendingPeersProvider: Error fetching pending peers: $e');
    }
  }

  void decrement() {
    if (_pendingCount > 0) {
      _pendingCount--;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
