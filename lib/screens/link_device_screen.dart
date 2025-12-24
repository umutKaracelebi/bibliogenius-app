import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
// import 'package:qr_flutter/qr_flutter.dart'; // TODO: Implement QR display

class LinkDeviceScreen extends StatefulWidget {
  const LinkDeviceScreen({super.key});

  @override
  State<LinkDeviceScreen> createState() => _LinkDeviceScreenState();
}

class _LinkDeviceScreenState extends State<LinkDeviceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _pairingCode;
  String? _myIp;
  bool _isLoadingSource = false;

  // Target State
  final _codeController = TextEditingController();
  final _ipController = TextEditingController();
  bool _isLoadingTarget = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMyIp();
    });
  }

  Future<void> _loadMyIp() async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    // Get IP from config
    try {
      final res = await apiService.getLibraryConfig();
      if (res.statusCode == 200) {
        final uri = Uri.parse(res.data['default_uri']);
        if (mounted) {
          setState(() {
            _myIp = '${uri.host}:${uri.port}';
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading IP: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    _ipController.dispose();
    super.dispose();
  }

  // --- Source Logic ---

  Future<void> _generateCode() async {
    setState(() => _isLoadingSource = true);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      final uuid = await authService.getOrCreateLibraryUuid();
      // Generate a temporary secret
      final secret = DateTime.now().millisecondsSinceEpoch.toString();

      final res = await apiService.generatePairingCode(
        uuid: uuid,
        secret: secret,
        ip: _myIp ?? 'unknown',
      );

      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            _pairingCode = res.data['code'].toString();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error generating code: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingSource = false);
      }
    }
  }

  // --- Target Logic ---

  Future<void> _linkDevice() async {
    if (_codeController.text.isEmpty || _ipController.text.isEmpty) return;

    setState(() => _isLoadingTarget = true);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      final host = _ipController.text.trim();
      final code = _codeController.text.trim();

      // Verify code with remote
      final res = await apiService.verifyRemotePairingCode(
        host: host,
        code: code,
      );

      if (res.statusCode == 200) {
        final data = res.data;
        final uuid = data['uuid'];
        // final secret = data['secret']; // Not used yet, maybe for future auth

        // Adopt Identity
        await authService.setLibraryUuid(uuid);

        // Trigger initial sync
        await apiService.syncPeer(host);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Device Linked! Library Synchronized.'),
            ),
          );
          context.pop(); // Go back
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Link failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingTarget = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine dark mode from current theme brightness
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Link Devices'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'This Device (Source)'),
            Tab(text: 'Join Library (Target)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildSourceTab(isDark), _buildTargetTab(isDark)],
      ),
    );
  }

  Widget _buildSourceTab(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.phonelink_ring, size: 64, color: Colors.indigo),
            const SizedBox(height: 24),
            const Text(
              'Link another device to this library',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Generate a code and enter it on the other device.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            if (_isLoadingSource)
              const CircularProgressIndicator()
            else if (_pairingCode != null) ...[
              Text(
                _pairingCode!,
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 8),
              const Text('Valid for 5 minutes'),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Host IP to enter:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      _myIp ?? 'Loading...',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              ),
            ] else
              ElevatedButton.icon(
                onPressed: _generateCode,
                icon: const Icon(Icons.vpn_key),
                label: const Text('Generate Code'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetTab(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.input, size: 64, color: Colors.green),
              const SizedBox(height: 24),
              const Text(
                'Join an existing library',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Pairing Code (6 digits)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 2),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ipController,
                decoration: const InputDecoration(
                  labelText: 'Host IP (e.g. 192.168.1.50:8000)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.computer),
                  hintText: '192.168.x.x:8000',
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 32),
              if (_isLoadingTarget)
                const CircularProgressIndicator()
              else
                ElevatedButton.icon(
                  onPressed: _linkDevice,
                  icon: const Icon(Icons.link),
                  label: const Text('Link Device'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              const Text(
                '⚠️ This will replace your current library content.',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
