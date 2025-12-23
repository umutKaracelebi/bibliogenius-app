/// Native mDNS Service using Bonsoir
///
/// This service handles Bonjour/mDNS discovery on iOS, macOS, and other platforms
/// using native platform APIs for reliable local network discovery.
library;

import 'dart:async';
import 'dart:io';
import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';

/// Service type for BiblioGenius mDNS announcements
const String kServiceType = '_bibliogenius._tcp';

/// Discovered peer on the local network
class DiscoveredPeer {
  final String name;
  final String host;
  final int port;
  final List<String> addresses;
  final String? libraryId;
  final DateTime discoveredAt;

  DiscoveredPeer({
    required this.name,
    required this.host,
    required this.port,
    required this.addresses,
    this.libraryId,
    required this.discoveredAt,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'host': host,
    'port': port,
    'addresses': addresses,
    'library_id': libraryId,
    'discovered_at': discoveredAt.toIso8601String(),
  };
}

/// Native mDNS service for local network discovery
class MdnsService {
  static BonsoirBroadcast? _broadcast;
  static BonsoirDiscovery? _discovery;
  static final Map<String, DiscoveredPeer> _peers = {};
  static StreamSubscription? _discoverySubscription;
  static bool _isRunning = false;
  static String? _ownServiceName;
  static String? _ownIp; // Our own IP for filtering

  /// Check if mDNS service is active
  static bool get isActive => _isRunning;

  /// Get discovered peers (excluding own service)
  static List<DiscoveredPeer> get peers => _peers.values.toList();

  /// Check if an IP address is a link-local address (169.254.x.x)
  /// These addresses are auto-assigned when DHCP fails and are not routable
  static bool _isLinkLocalAddress(String ip) {
    return ip.startsWith('169.254.');
  }

  /// Try to get a valid LAN IP from network interfaces
  /// Returns the first non-link-local, non-loopback IPv4 address found
  static Future<String?> _getValidLanIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      // Priority 1: WiFi interfaces (en0, wlan0)
      for (final interface in interfaces) {
        final name = interface.name.toLowerCase();
        if (name.startsWith('en') || name.startsWith('wlan')) {
          for (final address in interface.addresses) {
            final ip = address.address;
            if (!address.isLoopback && !_isLinkLocalAddress(ip)) {
              debugPrint(
                '🔍 mDNS: Found WiFi IP $ip on ${interface.name} (Priority)',
              );
              return ip;
            }
          }
        }
      }

      // Priority 2: Other valid interfaces (fallback), excluding known cellular
      for (final interface in interfaces) {
        final name = interface.name.toLowerCase();
        // Skip cellular interfaces commonly found on mobile
        if (name.startsWith('pdp_ip') ||
            name.startsWith('rmnet') ||
            name.startsWith('ccmni')) {
          continue;
        }

        for (final address in interface.addresses) {
          final ip = address.address;
          if (!address.isLoopback && !_isLinkLocalAddress(ip)) {
            debugPrint('🔍 mDNS: Found fallback IP $ip on ${interface.name}');
            return ip;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ mDNS: Error listing network interfaces - $e');
    }
    return null;
  }

  /// Start announcing this library on the network
  static Future<bool> startAnnouncing(
    String libraryName,
    int port, {
    String? libraryId,
  }) async {
    try {
      // Clean name for mDNS - keep Unicode letters, numbers, spaces, hyphens
      // Note: mDNS/Bonjour supports UTF-8 names, so we preserve accented chars
      final safeName = libraryName.replaceAll(
        RegExp(r'[^\p{L}\p{N}\s-]', unicode: true),
        '',
      );
      _ownServiceName = safeName;

      // Get local IP to include in attributes for reliable peer discovery
      // Filter out link-local addresses (169.254.x.x) as they're not routable
      String? localIp;
      try {
        final info = NetworkInfo();
        // Try WiFi IP first
        String? wifiIp = await info.getWifiIP();
        if (wifiIp != null && !_isLinkLocalAddress(wifiIp)) {
          localIp = wifiIp;
        }
        // If WiFi IP is link-local or null, try getting wired IP (on macOS/desktop)
        if (localIp == null) {
          // Fallback: get IP from network interfaces
          localIp = await _getValidLanIp();
        }
        if (localIp == null) {
          debugPrint(
            '⚠️ mDNS: No valid LAN IP found (only link-local available)',
          );
        }
      } catch (e) {
        debugPrint('⚠️ mDNS: Could not get local IP - $e');
      }

      final attributes = <String, String>{};
      if (libraryId != null) attributes['library_id'] = libraryId;
      if (localIp != null) {
        attributes['ip'] = localIp;
        _ownIp = localIp; // Store our IP for filtering
      }

      final service = BonsoirService(
        name: safeName,
        type: kServiceType,
        port: port,
        attributes: attributes,
      );

      _broadcast = BonsoirBroadcast(service: service);
      await _broadcast!.initialize();
      await _broadcast!.start();
      _isRunning = true;

      debugPrint(
        '📡 mDNS: Broadcasting "$safeName" on port $port (IP: $localIp)',
      );
      return true;
    } catch (e) {
      debugPrint('❌ mDNS: Failed to start broadcasting - $e');
      return false;
    }
  }

  /// Start discovering other libraries on the network
  static Future<bool> startDiscovery() async {
    try {
      // Stop any existing discovery first to avoid duplicates
      await stopDiscovery();

      // Clear cached peers to start fresh
      _peers.clear();
      debugPrint('🧹 mDNS: Cleared peer cache before discovery');

      _discovery = BonsoirDiscovery(type: kServiceType);
      await _discovery!.initialize();
      debugPrint('🔍 mDNS: Discovery initialized for type: $kServiceType');
      debugPrint('🔍 mDNS: Own service name to filter: $_ownServiceName');

      _discoverySubscription = _discovery!.eventStream?.listen(
        (event) {
          debugPrint('📡 mDNS: Received event: ${event.runtimeType}');
          // Handle service found - add immediately as workaround for macOS sandbox
          // (ServiceResolvedEvent doesn\'t fire reliably in Flutter sandbox)
          if (event is BonsoirDiscoveryServiceFoundEvent) {
            final service = event.service;

            // Get peer IP from attributes
            final peerIp = service.attributes['ip'];

            // Skip our own service by IP (more reliable than name)
            if (_ownIp != null && peerIp == _ownIp) {
              debugPrint(
                '🔇 mDNS: Skipping own service by IP: ${service.name} ($peerIp)',
              );
              return;
            }

            // Also skip by name as fallback (handle Bonjour auto-suffix like "(2)")
            final cleanServiceName = service.name.replaceAll(
              RegExp(r'\s*\(\d+\)$'),
              '',
            );
            if (_ownServiceName != null &&
                cleanServiceName == _ownServiceName &&
                peerIp == null) {
              debugPrint(
                '🔇 mDNS: Skipping own service by name (no IP): ${service.name}',
              );
              return;
            }

            // Prefer IP from attributes (reliable), fallback to hostname guess
            final ipFromAttrs = service.attributes['ip'];
            String host;
            if (ipFromAttrs != null &&
                ipFromAttrs.isNotEmpty &&
                !_isLinkLocalAddress(ipFromAttrs)) {
              host = ipFromAttrs;
              debugPrint('📚 mDNS: Using IP from attributes: $host');
            } else {
              if (ipFromAttrs != null && _isLinkLocalAddress(ipFromAttrs)) {
                debugPrint(
                  '⚠️ mDNS: Peer advertised link-local IP ($ipFromAttrs), trying hostname fallback',
                );
              }
              // Fallback: Generate hostname from service name (less reliable)
              final hostGuess = service.name
                  .toLowerCase()
                  .replaceAll(RegExp(r'[^a-z0-9]'), '-')
                  .replaceAll(RegExp(r'-+'), '-')
                  .replaceAll(RegExp(r'-$'), ''); // Remove trailing dash
              host = '$hostGuess.local';
              debugPrint(
                '⚠️ mDNS: No valid IP in attributes, guessing hostname: $host',
              );
            }

            // Use actual port from service (default to 8000 if not available)
            final actualPort = service.port > 0 ? service.port : 8000;

            // Strip Bonjour auto-suffix like "(2)", "(3)" from conflicting names
            final cleanName = service.name.replaceAll(
              RegExp(r'\s*\(\d+\)$'),
              '',
            );

            // Use host:port as key to deduplicate same library announced multiple times
            final peerKey = '$host:$actualPort';

            final peer = DiscoveredPeer(
              name: cleanName,
              host: host,
              port: actualPort,
              addresses: [host],
              libraryId: service.attributes['library_id'],
              discoveredAt: DateTime.now(),
            );

            _peers[peerKey] = peer;
            debugPrint('📚 mDNS: Discovered "$cleanName" at $peerKey');
          }
          // Handle service resolved (preferred if it fires)
          else if (event is BonsoirDiscoveryServiceResolvedEvent) {
            final service = event.service;

            // Skip our own service (also handle Bonjour auto-suffix)
            // Strip Bonjour auto-suffix first
            final cleanName = service.name.replaceAll(
              RegExp(r'\s*\(\d+\)$'),
              '',
            );
            if (_ownServiceName != null && cleanName == _ownServiceName) {
              debugPrint(
                '🔇 mDNS: Skipping own resolved service: ${service.name}',
              );
              return;
            }

            final resolvedHost = service.host ?? 'unknown';
            final peerKey = '$resolvedHost:${service.port}';

            // Update/add with resolved info (more accurate)
            final peer = DiscoveredPeer(
              name: cleanName,
              host: resolvedHost,
              port: service.port,
              addresses: service.host != null ? [service.host!] : [],
              libraryId: service.attributes['library_id'],
              discoveredAt: DateTime.now(),
            );

            _peers[peerKey] = peer;
            debugPrint('📚 mDNS: Resolved "$cleanName" at $peerKey');
          }
          // Handle service lost
          else if (event is BonsoirDiscoveryServiceLostEvent) {
            final service = event.service;
            // Try to find and remove by matching name (since we don't have the key)
            final keysToRemove = _peers.entries
                .where(
                  (e) =>
                      e.value.name ==
                      service.name.replaceAll(RegExp(r'\s*\(\d+\)$'), ''),
                )
                .map((e) => e.key)
                .toList();
            for (final key in keysToRemove) {
              _peers.remove(key);
              debugPrint('👋 mDNS: Lost "${service.name}" (key: $key)');
            }
          }
        },
        onError: (error) {
          debugPrint('❌ mDNS: Error in discovery stream - $error');
          // Handle stream errors (like defunct connection) gracefully
          // We don't want to crash the app, just log and maybe cleanup
          // If needed, we could implement a retry mechanism here
          stopDiscovery();
        },
      );

      await _discovery!.start();
      debugPrint('🔍 mDNS: Discovery started');
      return true;
    } catch (e) {
      debugPrint('❌ mDNS: Failed to start discovery - $e');
      return false;
    }
  }

  /// Get peers as JSON-compatible maps (for API compatibility)
  static List<Map<String, dynamic>> getPeersJson() {
    return _peers.values.map((p) => p.toJson()).toList();
  }

  /// Stop discovery only (keep broadcast running)
  static Future<void> stopDiscovery() async {
    try {
      await _discoverySubscription?.cancel();
      _discoverySubscription = null;
      await _discovery?.stop();
      _discovery = null;
      debugPrint('🔍 mDNS: Discovery stopped');
    } catch (e) {
      debugPrint('⚠️ mDNS: Error stopping discovery - $e');
    }
  }

  /// Stop mDNS service completely
  static Future<void> stop() async {
    try {
      await stopDiscovery();
      await _broadcast?.stop();
      _broadcast = null;
      _peers.clear();
      _isRunning = false;
      debugPrint('📡 mDNS: Service stopped');
    } catch (e) {
      debugPrint('⚠️ mDNS: Error stopping - $e');
    }
  }
}
