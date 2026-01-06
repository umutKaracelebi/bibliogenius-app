import 'package:flutter/material.dart';
import '../widgets/genie_app_bar.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'dart:convert';
import '../models/contact.dart';
import '../models/network_member.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/translation_service.dart';
// ThemeProvider import removed - not used in this screen
import 'package:mobile_scanner/mobile_scanner.dart';
import '../utils/app_constants.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../services/mdns_service.dart';

/// Filter options for the network list
enum NetworkFilter { all, libraries, contacts }

/// Unified screen displaying both Contacts and Network Libraries (Peers)
/// Replaces the separate ContactsScreen and PeerListScreen
class NetworkScreen extends StatefulWidget {
  const NetworkScreen({super.key});

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen>
    with SingleTickerProviderStateMixin {
  /// Feature flag to disable P2P features (mDNS, peers, QR) for alpha stability
  // Using AppConstants.enableP2PFeatures instead

  late TabController _tabController;

  // Unified list state
  List<NetworkMember> _members = [];
  List<Map<String, dynamic>> _localPeers = []; // mDNS discovered peers
  bool _isLoading = true;
  bool _mdnsActive = false;
  bool _isWifiConnected = true; // Default to true to avoid flashing warning
  NetworkFilter _filter = NetworkFilter.all;
  Timer? _refreshTimer;
  Map<int, bool> _peerConnectivity = {}; // Track online status per peer ID
  Map<String, bool?> _mdnsPeerConnectivity =
      {}; // Track mDNS peer connectivity by URL

  // QR State
  String? _localIp;
  String? _libraryName;
  bool _isLoadingQR = true;
  String? _qrData;
  MobileScannerController cameraController = MobileScannerController();

  @override
  void initState() {
    super.initState();
    // When P2P disabled, only show contacts tab (no Share/Scan tabs)
    _tabController = TabController(
      length: AppConstants.enableP2PFeatures ? 3 : 1,
      vsync: this,
    );
    _loadAllMembers();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && _tabController.index == 0) _loadAllMembers(silent: true);
    });
    if (AppConstants.enableP2PFeatures) _initQRData();
    _checkWifiStatus();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    cameraController.dispose();
    super.dispose();
  }

  Future<void> _checkWifiStatus() async {
    try {
      final info = NetworkInfo();
      final wifiIp = await info.getWifiIP();
      if (mounted) {
        setState(() {
          _isWifiConnected = wifiIp != null;
        });
      }
    } catch (e) {
      debugPrint('Error checking WiFi status: $e');
    }
  }

  /// Load both contacts and peers, merge into unified list
  Future<void> _loadAllMembers({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    final api = Provider.of<ApiService>(context, listen: false);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final libraryId = await authService.getLibraryId() ?? 1;

      // When P2P disabled, only load contacts
      if (!AppConstants.enableP2PFeatures) {
        final contactsRes = await api.getContacts(libraryId: libraryId);
        final List<dynamic> contactsJson = contactsRes.data['contacts'] ?? [];
        final contacts = contactsJson
            .map((json) => Contact.fromJson(json))
            .map((c) => NetworkMember.fromContact(c))
            .toList();

        contacts.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

        if (mounted) {
          setState(() {
            _members = contacts;
            _localPeers = [];
            _mdnsActive = false;
            _isLoading = false;
          });
        }
        return;
      }

      // P2P enabled: full loading logic
      // Fetch config to exclude own library from peers
      String? myUrl;
      try {
        final configRes = await api.getLibraryConfig();
        myUrl = configRes.data['default_uri'] as String?;
      } catch (e) {
        debugPrint('Could not get library config: $e');
      }

      // Fetch contacts and peers in parallel
      final results = await Future.wait([
        api.getContacts(libraryId: libraryId),
        api.getPeers(),
      ]);

      final contactsRes = results[0];
      final peersRes = results[1];

      // Parse contacts
      final List<dynamic> contactsJson = contactsRes.data['contacts'] ?? [];
      final contacts = contactsJson
          .map((json) => Contact.fromJson(json))
          .map((c) => NetworkMember.fromContact(c))
          .toList();

      // Parse peers (exclude own library)
      final List<dynamic> peersJson = (peersRes.data['data'] ?? []) as List;
      final peers = peersJson
          .where((peer) => myUrl == null || peer['url'] != myUrl)
          .map((p) => NetworkMember.fromPeer(p))
          .toList();

      // Fetch mDNS discovered peers (local network)
      List<Map<String, dynamic>> localPeers = [];
      bool mdnsActive = false;
      String? myLibraryName;
      try {
        final configRes = await api.getLibraryConfig();
        myLibraryName = configRes.data['library_name'] as String?;
      } catch (e) {
        debugPrint('Could not get library name: $e');
      }
      try {
        final localRes = await api.getLocalPeers();
        if (localRes.statusCode == 200) {
          final List<dynamic> localJson = localRes.data['peers'] ?? [];

          // Build a set of NAMES from connected peers for fast lookup (IPs may differ!)
          final connectedPeerNames = peersJson
              .map((p) => (p['name'] as String?)?.toLowerCase())
              .whereType<String>()
              .toSet();

          // Auto-update URLs for PENDING peers if mDNS discovers a new IP
          // Security: Only pending peers are updated, connected peers are not touched
          for (final mdnsPeer in localJson) {
            final mdnsName = (mdnsPeer['name'] as String?)?.toLowerCase();
            final mdnsAddresses =
                (mdnsPeer['addresses'] as List<dynamic>?)?.cast<String>() ?? [];
            final mdnsPort = mdnsPeer['port'] ?? 8000;
            if (mdnsName == null || mdnsAddresses.isEmpty) continue;

            // Find matching peer in database by name
            final dbPeer = peersJson.firstWhere(
              (p) => (p['name'] as String?)?.toLowerCase() == mdnsName,
              orElse: () => null,
            );

            if (dbPeer != null) {
              final dbUrl = dbPeer['url'] as String?;
              final dbStatus = dbPeer['status'] as String?;
              final peerId = dbPeer['id'];
              final newUrl = 'http://${mdnsAddresses.first}:$mdnsPort';

              // Only update if pending AND URL is different
              if (dbStatus == 'pending' && dbUrl != newUrl && peerId != null) {
                debugPrint(
                  '🔄 mDNS: Updating pending peer "$mdnsName" URL from $dbUrl to $newUrl',
                );
                try {
                  await api.updatePeerUrl(peerId as int, newUrl);
                  // Update local copy for this session
                  dbPeer['url'] = newUrl;
                } catch (e) {
                  debugPrint('⚠️ mDNS: Failed to update peer URL: $e');
                }
              }
            }
          }

          // Filter out own library by name AND already-connected peers by NAME
          localPeers = localJson.cast<Map<String, dynamic>>().where((peer) {
            final peerName = peer['name'] as String?;
            // Filter out own library
            if (peerName != null &&
                myLibraryName != null &&
                peerName == myLibraryName) {
              debugPrint('🔇 Filtering out own library from mDNS: $peerName');
              return false;
            }
            // Filter out peers already connected (by name, since IPs can differ)
            if (peerName != null &&
                connectedPeerNames.contains(peerName.toLowerCase())) {
              debugPrint(
                '🔇 Filtering out already-connected peer from mDNS: $peerName',
              );
              return false;
            }
            return true;
          }).toList();
          mdnsActive = localRes.data['mdns_active'] ?? false;
        }
      } catch (e) {
        debugPrint('Could not fetch local peers (mDNS): $e');
      }

      // Deduplicate: filter out local contacts of type 'library' if they match a connected peer by name
      final peerNames = peers.map((p) => p.name.toLowerCase()).toSet();
      final dedupedContacts = contacts.where((c) {
        // Keep all borrowers, only filter library-type contacts
        if (c.type == NetworkMemberType.borrower) return true;
        // Filter out if a peer with the same name exists
        return !peerNames.contains(c.name.toLowerCase());
      }).toList();

      // Merge and sort: network libraries first, then local contacts
      final allMembers = [...peers, ...dedupedContacts];
      allMembers.sort((a, b) {
        // Network first
        if (a.source != b.source) {
          return a.source == NetworkMemberSource.network ? -1 : 1;
        }
        // Then alphabetically
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      if (mounted) {
        setState(() {
          _members = allMembers;
          _localPeers = localPeers;
          _mdnsActive = mdnsActive;
          _isLoading = false;
        });
        // Check connectivity for network peers in parallel
        // _checkPeersConnectivity(allMembers); // Reverted
        // Check connectivity for mDNS peers
        _checkMdnsPeersConnectivity(localPeers);
      }
    } catch (e) {
      debugPrint('Error loading network members: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Get filtered list based on current filter
  List<NetworkMember> get _filteredMembers {
    switch (_filter) {
      case NetworkFilter.all:
        return _members;
      case NetworkFilter.libraries:
        return _members
            .where(
              (m) =>
                  m.source == NetworkMemberSource.network ||
                  m.type == NetworkMemberType.library,
            )
            .toList();
      case NetworkFilter.contacts:
        return _members
            .where((m) => m.source == NetworkMemberSource.local)
            .toList();
    }
  }

  /// Check connectivity for mDNS discovered peers
  Future<void> _checkMdnsPeersConnectivity(
    List<Map<String, dynamic>> peers,
  ) async {
    final api = Provider.of<ApiService>(context, listen: false);

    for (final peer in peers) {
      final addresses =
          (peer['addresses'] as List<dynamic>?)?.cast<String>() ?? [];
      final port = peer['port'] ?? 8000;
      if (addresses.isEmpty) continue;

      final url = 'http://${addresses.first}:$port';

      // Check connectivity in parallel (don't await each one)
      api.checkPeerConnectivity(url, timeoutMs: 2000).then((isOnline) {
        if (mounted) {
          setState(() {
            _mdnsPeerConnectivity[url] = isOnline;
          });
        }
      });
    }
  }

  // --- Actions ---

  Future<void> _deleteMember(NetworkMember member) async {
    final api = Provider.of<ApiService>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          member.source == NetworkMemberSource.network
              ? TranslationService.translate(
                  context,
                  'dialog_remove_library_title',
                )
              : TranslationService.translate(context, 'delete_contact_title'),
        ),
        content: Text(
          '${TranslationService.translate(context, 'confirm_delete')} ${member.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(TranslationService.translate(context, 'cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(
              TranslationService.translate(context, 'delete_contact_btn'),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (member.source == NetworkMemberSource.network) {
          await api.deletePeer(member.id);
        } else {
          await api.deleteContact(member.id);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                TranslationService.translate(context, 'contact_deleted'),
              ),
            ),
          );
          _loadAllMembers();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _syncPeer(NetworkMember member) async {
    if (member.source != NetworkMemberSource.network || member.url == null) {
      return;
    }
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      await api.syncPeer(member.url!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              TranslationService.translate(context, 'sync_started'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Sync error: $e')));
      }
    }
  }

  // --- QR Logic ---

  Future<void> _initQRData() async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final info = NetworkInfo();

    try {
      try {
        _localIp = await info.getWifiIP();
      } catch (e) {
        _localIp = 'localhost';
      }
      _localIp ??= '127.0.0.1';

      try {
        final response = await apiService.getLibraryConfig();
        if (response.statusCode == 200) {
          _libraryName = response.data['library_name'];
        }
      } catch (e) {
        debugPrint("Error getting config: $e");
      }
      if (!mounted) return;
      _libraryName ??= TranslationService.translate(
        context,
        'my_library_title',
      );

      if (_localIp != null && _libraryName != null) {
        final data = {
          "name": _libraryName,
          "url": "http://$_localIp:${ApiService.httpPort}",
        };
        _qrData = jsonEncode(data);
      }
    } catch (e) {
      // Ignore
    } finally {
      if (mounted) setState(() => _isLoadingQR = false);
    }
  }

  void _onDetect(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        try {
          final data = jsonDecode(barcode.rawValue!);
          if (data['name'] != null && data['url'] != null) {
            _connect(data['name'], data['url']);
            break;
          }
        } catch (e) {
          // invalid json
        }
      }
    }
  }

  Future<void> _connect(String name, String url) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.connectPeer(name, url);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "${TranslationService.translate(context, 'connected_to')} $name!",
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        _tabController.animateTo(0);
        _loadAllMembers();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "${TranslationService.translate(context, 'connection_failed')}: $e",
            ),
          ),
        );
      }
    }
  }

  void _showManualConnectionDialog() {
    final nameController = TextEditingController();
    final urlController = TextEditingController(text: 'http://localhost:8001');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          bool isLoading = false;

          Future<void> handleConnect() async {
            if (nameController.text.isEmpty || urlController.text.isEmpty) {
              return;
            }

            setState(() => isLoading = true);

            // Capture context-dependent objects before async gap
            final messenger = ScaffoldMessenger.of(dialogContext);
            final navigator = Navigator.of(dialogContext);
            final connectedToText = TranslationService.translate(
              dialogContext,
              'connected_to',
            );
            final connectionFailedText = TranslationService.translate(
              dialogContext,
              'connection_failed',
            );
            final apiService = Provider.of<ApiService>(context, listen: false);
            final libraryName = nameController.text;

            try {
              await apiService.connectPeer(libraryName, urlController.text);

              if (!mounted) return;
              navigator.pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Text('$connectedToText $libraryName!'),
                  duration: const Duration(seconds: 2),
                ),
              );
              _loadAllMembers();
            } catch (e) {
              setState(() => isLoading = false);
              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(
                  content: Text('$connectionFailedText: $e'),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }

          return AlertDialog(
            title: Text(
              TranslationService.translate(context, 'manual_connection_title'),
            ),
            content: isLoading
                ? const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        key: const Key('manualConnectNameField'),
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: TranslationService.translate(
                            context,
                            'library_name',
                          ),
                        ),
                        enabled: !isLoading,
                      ),
                      TextField(
                        key: const Key('manualConnectUrlField'),
                        controller: urlController,
                        decoration: InputDecoration(
                          labelText: TranslationService.translate(
                            context,
                            'library_url',
                          ),
                        ),
                        enabled: !isLoading,
                      ),
                    ],
                  ),
            actions: isLoading
                ? []
                : [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(
                        TranslationService.translate(context, 'cancel'),
                      ),
                    ),
                    TextButton(
                      key: const Key('manualConnectConfirmBtn'),
                      onPressed: handleConnect,
                      child: Text(
                        TranslationService.translate(context, 'connect'),
                      ),
                    ),
                  ],
          );
        },
      ),
    );
  }
  // --- Build Methods ---

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final bool isMobile = width <= 600;

    return Scaffold(
      appBar: GenieAppBar(
        title: TranslationService.translate(context, 'nav_network'),
        leading: isMobile
            ? IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              )
            : null,
        automaticallyImplyLeading: false,
        actions: [
          if (AppConstants.enableP2PFeatures) ...[
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              tooltip: TranslationService.translate(
                context,
                'network_search_title',
              ),
              onPressed: () => context.push('/network-search'),
            ),
            IconButton(
              icon: const Icon(Icons.keyboard, color: Colors.white),
              tooltip: TranslationService.translate(
                context,
                'manual_connection_btn',
              ),
              onPressed: _showManualConnectionDialog,
              key: const Key('manualConnectBtn'),
            ),
          ],
        ],
        // Only show TabBar when P2P features enabled
        bottom: AppConstants.enableP2PFeatures
            ? TabBar(
                controller: _tabController,
                indicatorColor: Theme.of(
                  context,
                ).buttonTheme.colorScheme?.onPrimary,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(
                    icon: const Icon(Icons.list),
                    text: TranslationService.translate(context, 'tab_list'),
                  ),
                  Tab(
                    icon: const Icon(Icons.qr_code_scanner),
                    text: TranslationService.translate(
                      context,
                      'tab_scan_code',
                    ),
                  ),
                  Tab(
                    icon: const Icon(Icons.qr_code),
                    text: TranslationService.translate(
                      context,
                      'tab_share_code',
                    ),
                  ),
                ],
              )
            : null,
      ),
      body: AppConstants.enableP2PFeatures
          ? TabBarView(
              controller: _tabController,
              children: [_buildMemberList(), _buildScanTab(), _buildShareTab()],
            )
          : _buildMemberList(),
      floatingActionButton:
          (!AppConstants.enableP2PFeatures || _tabController.index == 0)
          ? FloatingActionButton(
              onPressed: () async {
                await context.push('/contacts/add');
                _loadAllMembers();
              },
              tooltip: TranslationService.translate(context, 'add_contact'),
              child: const Icon(Icons.person_add),
            )
          : null,
    );
  }

  Widget _buildFilterChips() {
    if (!AppConstants.enableP2PFeatures) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            label: Text(
              TranslationService.translate(context, 'filter_all_contacts'),
            ),
            selected: _filter == NetworkFilter.all,
            onSelected: (selected) {
              if (selected) setState(() => _filter = NetworkFilter.all);
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(
              TranslationService.translate(context, 'filter_libraries'),
            ),
            selected: _filter == NetworkFilter.libraries,
            onSelected: (selected) {
              if (selected) setState(() => _filter = NetworkFilter.libraries);
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(
              TranslationService.translate(context, 'filter_contacts_only'),
            ),
            selected: _filter == NetworkFilter.contacts,
            onSelected: (selected) {
              if (selected) setState(() => _filter = NetworkFilter.contacts);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMemberList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filteredMembers;

    // Always show filter chips, even when empty
    return Column(
      children: [
        _buildFilterChips(),
        // Local Network Discovery Section (mDNS) - only show when P2P enabled
        if (AppConstants.enableP2PFeatures) _buildLocalNetworkSection(),
        if (filtered.isEmpty && _localPeers.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 80,
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      TranslationService.translate(
                        context,
                        'no_network_members',
                      ),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      TranslationService.translate(
                        context,
                        'add_contact_or_scan_help',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadAllMembers,
              child: ListView.builder(
                key: const Key('networkMemberList'),
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: filtered.length,
                itemBuilder: (context, index) =>
                    _buildMemberCard(filtered[index]),
              ),
            ),
          ),
      ],
    );
  }

  /// Build the Local Network Discovery section (mDNS)
  Widget _buildLocalNetworkSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.teal.withValues(alpha: 0.1),
            Colors.cyan.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
      ),
      child: ExpansionTile(
        leading: Icon(
          Icons.wifi_tethering,
          color: _mdnsActive ? Colors.teal : Colors.grey,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                TranslationService.translate(context, 'local_network_title'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            // Rescan button
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: 'Rescan',
              onPressed: () async {
                debugPrint('🔄 Manual mDNS rescan triggered');
                await MdnsService.stopDiscovery();
                await MdnsService.startDiscovery();
                await Future.delayed(const Duration(seconds: 2));
                _loadAllMembers();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Rescanning... ${MdnsService.peers.length} peers found',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
        subtitle: Text(
          _mdnsActive
              ? (_localPeers.isEmpty
                    ? TranslationService.translate(
                        context,
                        'no_local_libraries_found',
                      )
                    : '${_localPeers.length} ${TranslationService.translate(context, 'libraries_found')}')
              : 'mDNS inactive',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        initiallyExpanded: true, // Always expanded for debugging
        children: [
          // Debug info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'mDNS: ${_mdnsActive ? "Actif" : "Inactif"} | Peers bruts: ${MdnsService.peers.length} | Filtrés: ${_localPeers.length}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
                fontFamily: 'monospace',
              ),
            ),
          ),

          // WiFi Warning
          if (!_isWifiConnected)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off, color: Colors.amber),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          TranslationService.translate(
                                    context,
                                    'wifi_required_title',
                                  ) ==
                                  'wifi_required_title'
                              ? 'WiFi connection recommended'
                              : TranslationService.translate(
                                  context,
                                  'wifi_required_title',
                                ),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                        Text(
                          TranslationService.translate(
                                    context,
                                    'wifi_required_message',
                                  ) ==
                                  'wifi_required_message'
                              ? 'Please connect to the same WiFi network to discover other libraries.'
                              : TranslationService.translate(
                                  context,
                                  'wifi_required_message',
                                ),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (_localPeers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                TranslationService.translate(context, 'local_discovery_help'),
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            )
          else
            ..._localPeers.map((peer) => _buildLocalPeerTile(peer)).toList(),
        ],
      ),
    );
  }

  /// Build a tile for a locally discovered peer
  Widget _buildLocalPeerTile(Map<String, dynamic> peer) {
    final name = peer['name'] ?? 'Unknown Library';
    final addresses =
        (peer['addresses'] as List<dynamic>?)?.cast<String>() ?? [];
    final port = peer['port'] ?? 8000;
    final address = addresses.isNotEmpty ? addresses.first : '?';
    final url = 'http://$address:$port';

    // Find if this peer is already a member
    final existingMember = _members.firstWhere(
      (m) => m.url == url,
      orElse: () => NetworkMember(
        id: -1,
        name: '',
        type: NetworkMemberType.library,
        source: NetworkMemberSource.local,
      ),
    );

    final bool isConnected =
        existingMember.id != -1 && existingMember.status == 'connected';
    final bool isPending =
        existingMember.id != -1 && existingMember.isPending == true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isConnected
                  ? Colors.green.withAlpha(26)
                  : (isPending
                        ? Colors.orange.withAlpha(26)
                        : Colors.teal.withAlpha(26)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isConnected
                  ? Icons.cloud_done_rounded
                  : (isPending
                        ? Icons.hourglass_top_rounded
                        : Icons.library_books),
              color: isConnected
                  ? Colors.green
                  : (isPending ? Colors.orange : Colors.teal),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$address:$port',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : Colors.grey[600],
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Show connectivity status
                Builder(
                  builder: (context) {
                    final isOnline = _mdnsPeerConnectivity[url];
                    final isChecking = isOnline == null;
                    final statusText = isChecking
                        ? 'CHECKING...'
                        : (isOnline
                              ? TranslationService.translate(
                                  context,
                                  'status_active',
                                )
                              : TranslationService.translate(
                                  context,
                                  'status_offline',
                                ));
                    final statusColor = isChecking
                        ? Colors.grey
                        : (isOnline ? Colors.green : Colors.grey);

                    return Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(26),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusText.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Browse button - disabled if peer is offline
          Builder(
            builder: (context) {
              final isOnline = _mdnsPeerConnectivity[url] ?? false;
              return ElevatedButton.icon(
                onPressed: isOnline
                    ? () {
                        debugPrint('📚 Browse mDNS peer: name=$name, url=$url');
                        context.push(
                          '/peers/0/books',
                          extra: {'id': 0, 'name': name, 'url': url},
                        );
                      }
                    : null,
                icon: const Icon(Icons.auto_stories_rounded, size: 14),
                label: const Text('Browse', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOnline ? Colors.indigo : Colors.grey[400],
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  disabledForegroundColor: Colors.grey[500],
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Connect to a locally discovered peer (sends connection request)
  Future<void> _connectToLocalPeer(String name, String url) async {
    final api = Provider.of<ApiService>(context, listen: false);

    // Show loading dialog (non-blocking)
    unawaited(
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(ctx).cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(TranslationService.translate(ctx, 'sending_request')),
              ],
            ),
          ),
        ),
      ),
    );

    // Small delay to ensure dialog is rendered
    await Future.delayed(const Duration(milliseconds: 50));

    try {
      final response = await api.connectLocalPeer(name, url);
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();

        // Check if the request was successful
        if (response.statusCode == 200 || response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                TranslationService.translate(
                  context,
                  'connection_request_sent',
                ).replaceAll('{name}', name),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: TranslationService.translate(context, 'view_requests'),
                textColor: Colors.white,
                onPressed: () {
                  // Navigate to Requests screen
                  context.go('/requests');
                },
              ),
            ),
          );
          // Refresh the network list
          _loadAllMembers();
        } else {
          // Request failed at the remote end
          final error = response.data?['error'] ?? 'Unknown error';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${TranslationService.translate(context, 'connection_failed')}: $error',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${TranslationService.translate(context, 'connection_failed')}: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildMemberCard(NetworkMember member) {
    final isNetwork = member.source == NetworkMemberSource.network;
    final isPending = member.isPending;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Determine icon and color
    IconData icon;
    Color iconColor;
    Color bgColor;

    if (isNetwork) {
      icon = isPending ? Icons.hourglass_top_rounded : Icons.public_rounded;
      iconColor = isPending ? Colors.orange : Colors.indigo;
      bgColor = isPending ? Colors.orange : Colors.indigo;
    } else if (member.type == NetworkMemberType.borrower) {
      icon = Icons.person_rounded;
      iconColor = Colors.blue;
      bgColor = Colors.blue;
    } else {
      icon = Icons.library_books_rounded;
      iconColor = Colors.purple;
      bgColor = Colors.purple;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(13) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
        border: Border.all(
          color: isDark
              ? Colors.white.withAlpha(26)
              : Colors.grey.withAlpha(26),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor.withAlpha(26),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  member.displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isPending ? Colors.grey : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  member.secondaryInfo,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!isPending && isNetwork) ...[
                  const SizedBox(height: 6),
                  Builder(
                    builder: (context) {
                      // Check actual connectivity status
                      final isOnline = _peerConnectivity[member.id];
                      final isChecking = isOnline == null;
                      final statusText = isChecking
                          ? 'CHECKING...'
                          : (isOnline
                                ? TranslationService.translate(
                                    context,
                                    'status_active',
                                  )
                                : TranslationService.translate(
                                    context,
                                    'status_offline',
                                  ));
                      final statusColor = isChecking
                          ? Colors.grey
                          : (isOnline ? Colors.green : Colors.grey);

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withAlpha(26),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusText.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      );
                    },
                  ),
                ],
                if (isPending) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(26),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'PENDING',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!isPending && isNetwork)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Builder(
                  builder: (context) {
                    final isOnline = _peerConnectivity[member.id] ?? false;
                    return ElevatedButton(
                      onPressed: isOnline ? () => _onMemberTap(member) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOnline
                            ? Colors.indigo
                            : Colors.grey[400],
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Browse',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                  tooltip: TranslationService.translate(
                    context,
                    'tooltip_remove_library',
                  ),
                  onPressed: () => _deleteMember(member),
                ),
              ],
            )
          else
            _buildMemberActions(member),
        ],
      ),
    );
  }

  Widget _buildMemberActions(NetworkMember member) {
    if (member.source == NetworkMemberSource.network) {
      if (member.isPending) {
        return IconButton(
          icon: const Icon(Icons.cancel_outlined, color: Colors.orange),
          tooltip: TranslationService.translate(
            context,
            'tooltip_cancel_request',
          ),
          onPressed: () => _deleteMember(member),
        );
      } else {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.sync, color: Colors.indigo),
              tooltip: TranslationService.translate(context, 'tooltip_sync'),
              onPressed: () => _syncPeer(member),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: TranslationService.translate(
                context,
                'tooltip_remove_library',
              ),
              onPressed: () => _deleteMember(member),
            ),
          ],
        );
      }
    } else {
      // Local contact
      return IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        tooltip: TranslationService.translate(context, 'delete_contact_btn'),
        onPressed: () => _deleteMember(member),
      );
    }
  }

  void _onMemberTap(NetworkMember member) {
    debugPrint(
      '👆 _onMemberTap: ${member.name}, source=${member.source}, url=${member.url}, status=${member.status}',
    );
    if (member.source == NetworkMemberSource.network) {
      if (member.isPending) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              TranslationService.translate(context, 'library_not_accepted'),
            ),
          ),
        );
      } else {
        // Validate URL before navigating
        if (member.url == null || member.url!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Peer URL is missing'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        // Navigate to peer's book list
        debugPrint(
          '📚 Navigating to peer books: id=${member.id}, name=${member.name}, url=${member.url}',
        );
        context.push(
          '/peers/${member.id}/books',
          extra: {'id': member.id, 'name': member.name, 'url': member.url},
        );
      }
    } else {
      // Navigate to contact details
      context.push('/contacts/${member.id}', extra: member.toContact());
    }
  }

  Widget _buildShareTab() {
    if (_isLoadingQR) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_qrData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              TranslationService.translate(context, 'qr_error'),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              "IP: ${_localIp ?? 'Unknown'}",
              style: const TextStyle(color: Colors.grey),
            ),
            Text(
              "Name: ${_libraryName ?? 'Unknown'}",
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initQRData,
              child: Text(TranslationService.translate(context, 'retry')),
            ),
          ],
        ),
      );
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  QrImageView(
                    data: _qrData!,
                    version: QrVersions.auto,
                    size: 240.0,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _libraryName!,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  if (_qrData != null)
                    Text(
                      (jsonDecode(_qrData!)['url'] as String).replaceAll(
                        'http://',
                        '',
                      ),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        fontFamily: 'Courier',
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Text(
              TranslationService.translate(context, 'share_code_instruction'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanTab() {
    return Stack(
      children: [
        MobileScanner(
          controller: cameraController,
          onDetect: _onDetect,
          errorBuilder: (context, error, child) {
            // Handle camera errors gracefully instead of black screen
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.camera_alt, size: 80, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      TranslationService.translate(context, 'camera_error') ??
                          'Camera Error',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.errorDetails?.message ?? error.errorCode.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _tabController.animateTo(0),
                      icon: const Icon(Icons.arrow_back),
                      label: Text(
                        TranslationService.translate(context, 'back') ?? 'Back',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        Container(
          decoration: ShapeDecoration(
            shape: QrScannerOverlayShape(
              borderColor: Theme.of(context).primaryColor,
              borderRadius: 10,
              borderLength: 30,
              borderWidth: 10,
              cutOutSize: 300,
            ),
          ),
        ),
        // Back button at the top left
        Positioned(
          top: 40,
          left: 16,
          child: CircleAvatar(
            backgroundColor: Colors.black54,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => _tabController.animateTo(0),
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                color: Colors.white,
                icon: const Icon(Icons.flash_on, size: 32),
                iconSize: 32.0,
                onPressed: () => cameraController.toggleTorch(),
              ),
              const SizedBox(width: 40),
              IconButton(
                color: Colors.white,
                icon: const Icon(Icons.flip_camera_ios, size: 32),
                iconSize: 32.0,
                onPressed: () => cameraController.switchCamera(),
              ),
            ],
          ),
        ),
        Positioned(
          top: 40,
          left: 70,
          right: 16,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                TranslationService.translate(context, 'scan_instruction'),
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Helper class for overlay shape
class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 10.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top)
        ..lineTo(rect.right, rect.top);
    }

    return getLeftTopPath(rect);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;
    final borderOffset = borderWidth / 2;
    final localCutOutSize = cutOutSize;
    final localBorderLength = borderLength;
    final localBorderRadius = borderRadius;

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final cutOutRect = Rect.fromLTWH(
      rect.left + width / 2 - localCutOutSize / 2 + borderOffset,
      rect.top + height / 2 - localCutOutSize / 2 + borderOffset,
      localCutOutSize - borderOffset * 2,
      localCutOutSize - borderOffset * 2,
    );

    canvas
      ..saveLayer(rect, backgroundPaint)
      ..drawRect(rect, backgroundPaint)
      ..drawRRect(
        RRect.fromRectAndRadius(cutOutRect, Radius.circular(localBorderRadius)),
        Paint()..blendMode = BlendMode.clear,
      )
      ..restore();

    final path = Path();
    path.moveTo(cutOutRect.left, cutOutRect.top + localBorderLength);
    path.lineTo(cutOutRect.left, cutOutRect.top + localBorderRadius);
    path.quadraticBezierTo(
      cutOutRect.left,
      cutOutRect.top,
      cutOutRect.left + localBorderRadius,
      cutOutRect.top,
    );
    path.lineTo(cutOutRect.left + localBorderLength, cutOutRect.top);

    path.moveTo(cutOutRect.right, cutOutRect.top + localBorderLength);
    path.lineTo(cutOutRect.right, cutOutRect.top + localBorderRadius);
    path.quadraticBezierTo(
      cutOutRect.right,
      cutOutRect.top,
      cutOutRect.right - localBorderRadius,
      cutOutRect.top,
    );
    path.lineTo(cutOutRect.right - localBorderLength, cutOutRect.top);

    path.moveTo(cutOutRect.right, cutOutRect.bottom - localBorderLength);
    path.lineTo(cutOutRect.right, cutOutRect.bottom - localBorderRadius);
    path.quadraticBezierTo(
      cutOutRect.right,
      cutOutRect.bottom,
      cutOutRect.right - localBorderRadius,
      cutOutRect.bottom,
    );
    path.lineTo(cutOutRect.right - localBorderLength, cutOutRect.bottom);

    path.moveTo(cutOutRect.left, cutOutRect.bottom - localBorderLength);
    path.lineTo(cutOutRect.left, cutOutRect.bottom - localBorderRadius);
    path.quadraticBezierTo(
      cutOutRect.left,
      cutOutRect.bottom,
      cutOutRect.left + localBorderRadius,
      cutOutRect.bottom,
    );
    path.lineTo(cutOutRect.left + localBorderLength, cutOutRect.bottom);

    canvas.drawPath(path, borderPaint);
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth * t,
      overlayColor: overlayColor,
    );
  }
}
