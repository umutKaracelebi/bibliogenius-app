import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/genie_app_bar.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/status_badge.dart';
import '../providers/theme_provider.dart';
import 'package:go_router/go_router.dart';
import '../utils/avatars.dart';
import '../widgets/avatar_customizer.dart';
import '../models/avatar_config.dart';
import '../services/translation_service.dart';
import '../services/demo_service.dart';
import '../models/gamification_status.dart';
import '../widgets/gamification_widgets.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'dart:io' as io;
import 'package:dio/dio.dart' show Response;
import 'dart:convert'; // For base64Decode
import '../themes/base/theme_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_constants.dart';
import '../audio/audio_module.dart'; // Audio module (decoupled)

class ProfileScreen extends StatefulWidget {
  final String? initialAction;

  const ProfileScreen({super.key, this.initialAction});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _userStatus;
  Map<String, dynamic>? _config;
  Map<String, dynamic>? _userInfo;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchStatus();

    // Check for auto-actions (e.g. backup request from dialog)
    if (widget.initialAction == 'backup') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Add a small delay to ensure UI is ready
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _exportData();
        });
      });
    }
  }

  Future<void> _fetchStatus() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final statusRes = await apiService.getUserStatus();
      final configRes = await apiService.getLibraryConfig();
      final meRes = await apiService.getMe();

      if (mounted) {
        // Sync library name
        final name = configRes.data['library_name'] ?? configRes.data['name'];
        if (name != null) {
          Provider.of<ThemeProvider>(
            context,
            listen: false,
          ).setLibraryName(name);
        }

        // Sync profile type
        final profileType = configRes.data['profile_type'];
        if (profileType != null) {
          Provider.of<ThemeProvider>(
            context,
            listen: false,
          ).setProfileType(profileType);
        }

        setState(() {
          _userStatus = statusRes.data;
          _config = configRes.data;
          _userInfo = meRes.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _exportData() async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              TranslationService.translate(context, 'preparing_backup'),
            ),
          ),
        );
      }

      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.exportData();

      if (kIsWeb) {
        // Web export: trigger download directly
        final blob = html.Blob([response.data]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute(
            'download',
            'bibliogenius_backup_${DateTime.now().toIso8601String().split('T')[0]}.json',
          )
          ..click();
        html.Url.revokeObjectUrl(url);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Backup downloaded successfully')),
          );
        }
      } else {
        // Mobile/Desktop export: use share_plus
        final directory = await getTemporaryDirectory();
        final filename =
            'bibliogenius_backup_${DateTime.now().toIso8601String().split('T')[0]}.json';
        final file = io.File('${directory.path}/$filename');
        await file.writeAsBytes(response.data);

        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'My BiblioGenius Backup');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${TranslationService.translate(context, 'export_fail')}: $e',
            ),
          ),
        );
      }
    }
  }

  Future<void> _importBackup() async {
    try {
      // Pick a file (JSON for backup, CSV/TXT for book list)
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'csv', 'txt'],
        withData: kIsWeb,
      );

      if (result == null || result.files.isEmpty) {
        return; // User cancelled
      }

      final file = result.files.first;
      final extension = file.extension?.toLowerCase();

      // If it's a CSV or TXT, redirect to book import
      if (extension == 'csv' || extension == 'txt') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                TranslationService.translate(context, 'importing_books'),
              ),
            ),
          );
        }

        final apiService = Provider.of<ApiService>(context, listen: false);
        late final Response response;

        if (kIsWeb) {
          // On web, bytes are loaded into memory
          if (file.bytes == null) throw Exception('No file data');
          response = await apiService.importBooks(
            file.bytes!,
            filename: file.name,
          );
        } else {
          // On native, use path
          if (file.path == null) throw Exception('No file path');
          response = await apiService.importBooks(file.path!);
        }

        if (mounted) {
          if (response.statusCode == 200) {
            final imported = response.data['imported'];
            // Refresh status to update book counts
            _fetchStatus();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${TranslationService.translate(context, 'import_success')} $imported ${TranslationService.translate(context, 'books')}',
                ),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            throw Exception(response.data['error'] ?? 'Import failed');
          }
        }
        return;
      }

      // JSON Backup Import Logic
      List<int> bytes;
      if (kIsWeb) {
        if (file.bytes == null) throw Exception('Could not read file');
        bytes = file.bytes!;
      } else {
        if (file.path == null) throw Exception('File path is null');
        final ioFile = io.File(file.path!);
        bytes = await ioFile.readAsBytes();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              TranslationService.translate(context, 'importing_backup'),
            ),
          ),
        );
      }

      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.importBackup(bytes);

      if (response.statusCode == 200) {
        final data = response.data;
        final booksCount = data['books_imported'] ?? 0;
        final message = data['message'] ?? 'Import successful';

        if (mounted) {
          // Refresh data after restore (important!)
          _fetchStatus();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$message - $booksCount ${TranslationService.translate(context, 'books_imported')}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception(response.data['error'] ?? 'Import failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${TranslationService.translate(context, 'import_fail')}: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final hasPassword = await authService.hasPasswordSet();

    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    String? errorText;

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            hasPassword
                ? (TranslationService.translate(context, 'change_password') ??
                      'Change Password')
                : (TranslationService.translate(context, 'set_password') ??
                      'Set Password'),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!hasPassword)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      TranslationService.translate(
                            context,
                            'first_time_password',
                          ) ??
                          'Set a password to protect your data',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                if (hasPassword)
                  TextField(
                    controller: currentPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText:
                          TranslationService.translate(
                            context,
                            'current_password',
                          ) ??
                          'Current Password',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                if (hasPassword) const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText:
                        TranslationService.translate(context, 'new_password') ??
                        'New Password',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText:
                        TranslationService.translate(
                          context,
                          'confirm_password',
                        ) ??
                        'Confirm Password',
                    errorText: errorText,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                TranslationService.translate(context, 'cancel') ?? 'Cancel',
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                // Validate
                if (newPasswordController.text.length < 4) {
                  setState(
                    () => errorText =
                        TranslationService.translate(
                          context,
                          'password_too_short',
                        ) ??
                        'Password must be at least 4 characters',
                  );
                  return;
                }
                if (newPasswordController.text !=
                    confirmPasswordController.text) {
                  setState(
                    () => errorText =
                        TranslationService.translate(
                          context,
                          'passwords_dont_match',
                        ) ??
                        'Passwords do not match',
                  );
                  return;
                }

                if (hasPassword) {
                  // Verify old password first
                  final isValid = await authService.verifyPassword(
                    currentPasswordController.text,
                  );
                  if (!isValid) {
                    setState(
                      () => errorText =
                          TranslationService.translate(
                            context,
                            'password_incorrect',
                          ) ??
                          'Incorrect password',
                    );
                    return;
                  }
                  // Change password
                  await authService.changePassword(
                    currentPasswordController.text,
                    newPasswordController.text,
                  );
                } else {
                  // First time setting password
                  await authService.savePassword(newPasswordController.text);
                }

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        TranslationService.translate(
                              context,
                              'password_changed_success',
                            ) ??
                            'Password changed successfully',
                      ),
                    ),
                  );
                }
              },
              child: Text(
                TranslationService.translate(context, 'save') ?? 'Save',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final bool isMobile = width <= 600;

    return Scaffold(
      appBar: GenieAppBar(
        title: TranslationService.translate(context, 'profile'),
        leading: isMobile
            ? IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              )
            : null,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(
                '${TranslationService.translate(context, 'error')}: $_error',
              ),
            )
          : _buildBody(),
    );
  }

  Future<void> _setupMfa() async {
    final apiService = Provider.of<ApiService>(context, listen: false);

    // Check if we're in FFI/local mode where MFA is not supported
    if (apiService.useFfi) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Text(
                TranslationService.translate(context, 'two_factor_auth') ??
                    'Two-Factor Authentication',
              ),
            ],
          ),
          content: Text(
            TranslationService.translate(context, 'mfa_requires_server') ??
                'Two-factor authentication is only available when connected to a remote BiblioGenius server. In local mode, your data is already secured on your device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(TranslationService.translate(context, 'ok') ?? 'OK'),
            ),
          ],
        ),
      );
      return;
    }

    try {
      final response = await apiService.setup2Fa();
      final data = response.data;
      final secret = data['secret'];
      final qrCode = data['qr_code']; // Base64 string

      if (!mounted) return;

      final codeController = TextEditingController();
      String? verifyError;

      await showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(
              TranslationService.translate(context, 'setup_2fa') ?? 'Setup 2FA',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    TranslationService.translate(context, 'scan_qr_code') ??
                        'Scan this QR code with your authenticator app:',
                  ),
                  const SizedBox(height: 16),
                  if (qrCode != null)
                    Image.memory(base64Decode(qrCode), height: 200, width: 200),
                  const SizedBox(height: 16),
                  SelectableText(
                    '${TranslationService.translate(context, 'secret_key') ?? 'Secret Key'}: $secret',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeController,
                    decoration: InputDecoration(
                      labelText:
                          TranslationService.translate(
                            context,
                            'verification_code',
                          ) ??
                          'Verification Code',
                      errorText: verifyError,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  TranslationService.translate(context, 'cancel') ?? 'Cancel',
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  setState(() => verifyError = null);
                  final code = codeController.text.trim();
                  if (code.length != 6) {
                    setState(
                      () => verifyError =
                          TranslationService.translate(
                            context,
                            'invalid_code',
                          ) ??
                          'Invalid code',
                    );
                    return;
                  }

                  try {
                    await apiService.verify2Fa(secret, code);
                    if (mounted) {
                      Navigator.pop(context); // Close dialog
                      _fetchStatus(); // Refresh status
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            TranslationService.translate(
                                  context,
                                  'mfa_enabled_success',
                                ) ??
                                'MFA Enabled Successfully',
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    setState(
                      () => verifyError =
                          TranslationService.translate(
                            context,
                            'verification_failed',
                          ) ??
                          'Verification failed',
                    );
                  }
                },
                child: Text(
                  TranslationService.translate(context, 'verify') ?? 'Verify',
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${TranslationService.translate(context, 'error_initializing_mfa') ?? 'Error initializing MFA'}: $e',
            ),
          ),
        );
      }
    }
  }

  Widget _buildBody() {
    if (_userStatus == null)
      return Center(
        child: Text(TranslationService.translate(context, 'no_data')),
      );

    final level = _userStatus!['level'] as String;
    final loansCount = _userStatus!['loans_count'] as int;
    final editsCount = _userStatus!['edits_count'] as int;
    final progress = (_userStatus!['next_level_progress'] as num).toDouble();

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width > 600 ? 32.0 : 16.0,
        vertical: 16.0,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width > 600
                ? 900
                : double.infinity,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              const SizedBox(height: 20),
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) {
                  final avatar = availableAvatars.firstWhere(
                    (a) => a.id == themeProvider.currentAvatarId,
                    orElse: () => availableAvatars.first,
                  );

                  return Stack(
                    children: [
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: avatar.themeColor,
                            width: 4,
                          ),
                          color: themeProvider.avatarConfig?.style == 'genie'
                              ? Color(
                                  int.parse(
                                    'FF${themeProvider.avatarConfig?.genieBackground ?? "fbbf24"}',
                                    radix: 16,
                                  ),
                                )
                              : Colors.grey[100],
                        ),
                        child: ClipOval(
                          child: (themeProvider.avatarConfig?.isGenie ?? false)
                              ? Image.asset(
                                  themeProvider.avatarConfig?.assetPath ??
                                      'assets/genie_mascot.jpg',
                                  fit: BoxFit.cover,
                                )
                              : CachedNetworkImage(
                                  imageUrl:
                                      themeProvider.avatarConfig?.toUrl(
                                        size: 140,
                                        format: 'png',
                                      ) ??
                                      '',
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) =>
                                      Image.asset(avatar.assetPath),
                                ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () =>
                              _showAvatarPicker(context, themeProvider),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) {
                  return Text(
                    TranslationService.translate(
                      context,
                      themeProvider.profileType,
                    ),
                    style: Theme.of(context).textTheme.headlineMedium,
                  );
                },
              ),
              const SizedBox(height: 8),
              StatusBadge(level: level, size: 32),
              const SizedBox(height: 32),

              // Gamification V3 - Track Progress Card (if enabled)
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) {
                  if (!themeProvider.gamificationEnabled) {
                    return const SizedBox.shrink();
                  }
                  return GamificationSummaryCard(
                    status: GamificationStatus.fromJson(_userStatus!),
                  );
                },
              ),
              const SizedBox(height: 32),

              // Reading Goals Settings
              _buildReadingGoalsSection(),
              const SizedBox(height: 32),
              // Module Management
              Text(
                TranslationService.translate(context, 'modules'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    Consumer<ThemeProvider>(
                      builder: (context, themeProvider, _) {
                        return Column(
                          children: [
                            SwitchListTile(
                              title: Text(
                                TranslationService.translate(
                                  context,
                                  'module_collections',
                                ),
                              ),
                              subtitle: Text(
                                TranslationService.translate(
                                  context,
                                  'module_collections_desc',
                                ),
                              ),
                              secondary: const Icon(Icons.collections_bookmark),
                              value: themeProvider.collectionsEnabled,
                              onChanged: (bool value) {
                                themeProvider.setCollectionsEnabled(value);
                              },
                            ),
                            const Divider(),
                            // Network Discovery Toggle (mDNS)
                            SwitchListTile(
                              secondary: const Icon(Icons.wifi_tethering),
                              title: Text(
                                TranslationService.translate(
                                  context,
                                  'module_network',
                                ),
                              ),
                              subtitle: Text(
                                TranslationService.translate(
                                  context,
                                  'module_network_desc',
                                ),
                              ),
                              value: themeProvider.networkDiscoveryEnabled,
                              onChanged: (value) async {
                                await themeProvider.setNetworkDiscoveryEnabled(
                                  value,
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        TranslationService.translate(
                                              context,
                                              'restart_required_for_changes',
                                            ) ??
                                            'Please restart the app for changes to take full effect',
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                            const Divider(),
                            // Gamification Toggle
                            SwitchListTile(
                              secondary: const Icon(Icons.emoji_events),
                              title: Text(
                                TranslationService.translate(
                                  context,
                                  'module_gamification',
                                ),
                              ),
                              subtitle: Text(
                                TranslationService.translate(
                                  context,
                                  'module_gamification_desc',
                                ),
                              ),
                              value: themeProvider.gamificationEnabled,
                              onChanged: (value) =>
                                  themeProvider.setGamificationEnabled(value),
                            ),
                            const Divider(),
                            // Borrowing Module Toggle
                            SwitchListTile(
                              secondary: const Icon(Icons.swap_horiz),
                              title: Text(
                                TranslationService.translate(
                                  context,
                                  'enable_borrowing_module',
                                ),
                              ),
                              subtitle: Text(
                                TranslationService.translate(
                                  context,
                                  'borrowing_module_desc',
                                ),
                              ),
                              value: themeProvider.canBorrowBooks,
                              onChanged: (value) =>
                                  themeProvider.setCanBorrowBooks(value),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Profile Settings
              Text(
                TranslationService.translate(context, 'profile_settings'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                        TranslationService.translate(context, 'library_name'),
                      ),
                      subtitle: Text(
                        _config?['library_name'] ??
                            _config?['name'] ??
                            'My Library',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          final controller = TextEditingController(
                            text:
                                _config?['library_name'] ??
                                _config?['name'] ??
                                '',
                          );
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(
                                TranslationService.translate(
                                  context,
                                  'edit_library_name',
                                ),
                              ),
                              content: TextField(
                                controller: controller,
                                decoration: InputDecoration(
                                  labelText: TranslationService.translate(
                                    context,
                                    'library_name',
                                  ),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    TranslationService.translate(
                                      context,
                                      'cancel',
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    try {
                                      final api = Provider.of<ApiService>(
                                        context,
                                        listen: false,
                                      );
                                      await api.updateLibraryConfig(
                                        name: controller.text,
                                        description: _config?['description'],
                                        profileType: _config?['profile_type'],
                                        tags: _config?['tags'] != null
                                            ? List<String>.from(
                                                _config!['tags'],
                                              )
                                            : [],
                                        latitude: _config?['latitude'],
                                        longitude: _config?['longitude'],
                                        showBorrowedBooks:
                                            _config?['show_borrowed_books'],
                                        shareLocation:
                                            _config?['share_location'],
                                      );
                                      _fetchStatus();
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              TranslationService.translate(
                                                context,
                                                'library_updated',
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '${TranslationService.translate(context, 'error_updating_library')}: $e',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  child: Text(
                                    TranslationService.translate(
                                      context,
                                      'save',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      title: Text(
                        TranslationService.translate(context, 'profile_type'),
                      ),
                      subtitle: Consumer<ThemeProvider>(
                        builder: (context, themeProvider, _) {
                          return Text(
                            TranslationService.translate(
                                  context,
                                  themeProvider.profileType,
                                ) ??
                                themeProvider.profileType,
                          );
                        },
                      ),
                      trailing: Consumer<ThemeProvider>(
                        builder: (context, themeProvider, _) {
                          // Normalize profile type to match dropdown items
                          String normalizedType = themeProvider.profileType;
                          if (normalizedType == 'individual_reader') {
                            normalizedType = 'individual';
                          } else if (normalizedType == 'professional') {
                            normalizedType = 'librarian';
                          }
                          // Ensure value is one of the valid options
                          if (![
                            'individual',
                            'librarian',
                            'bookseller',
                            'kid',
                          ].contains(normalizedType)) {
                            normalizedType = 'individual';
                          }

                          return SizedBox(
                            width: 130,
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: normalizedType,
                                isExpanded: true,
                                items: [
                                  DropdownMenuItem(
                                    value: 'individual',
                                    child: Text(
                                      TranslationService.translate(
                                        context,
                                        'profile_individual',
                                      ),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'librarian',
                                    child: Text(
                                      TranslationService.translate(
                                        context,
                                        'profile_librarian',
                                      ),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'bookseller',
                                    child: Text(
                                      TranslationService.translate(
                                        context,
                                        'profile_bookseller',
                                      ),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'kid',
                                    child: Text(
                                      TranslationService.translate(
                                        context,
                                        'profile_kid',
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (value) async {
                                  if (value == null) return;
                                  try {
                                    final api = Provider.of<ApiService>(
                                      context,
                                      listen: false,
                                    );

                                    // 1. Update Provider (local state + persistence)
                                    await Provider.of<ThemeProvider>(
                                      context,
                                      listen: false,
                                    ).setProfileType(value, apiService: api);

                                    // 2. Update Library Config on Backend (so it persists remotely)
                                    if (_config != null) {
                                      await api.updateLibraryConfig(
                                        name:
                                            _config!['library_name'] ??
                                            _config!['name'] ??
                                            'My Library',
                                        description: _config?['description'],
                                        profileType: value,
                                        tags: _config?['tags'] != null
                                            ? List<String>.from(
                                                _config!['tags'],
                                              )
                                            : [],
                                        latitude: _config?['latitude'],
                                        longitude: _config?['longitude'],
                                        showBorrowedBooks:
                                            _config?['show_borrowed_books'],
                                        shareLocation:
                                            _config?['share_location'],
                                      );
                                    }

                                    _fetchStatus(); // Refresh to get updated config

                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            TranslationService.translate(
                                              context,
                                              'profile_updated',
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${TranslationService.translate(context, 'error_updating_profile')}: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (Provider.of<ThemeProvider>(context).isBookseller) ...[
                      const Divider(),
                      SwitchListTile(
                        title: Text(
                          TranslationService.translate(
                            context,
                            'commerce_module_label',
                          ),
                        ),
                        subtitle: Text(
                          TranslationService.translate(
                            context,
                            'commerce_module_subtitle',
                          ),
                        ),
                        value: Provider.of<ThemeProvider>(
                          context,
                        ).commerceEnabled,
                        activeColor: Theme.of(context).primaryColor,
                        onChanged: (value) => Provider.of<ThemeProvider>(
                          context,
                          listen: false,
                        ).setCommerceEnabled(value),
                      ),
                    ],
                    if (Provider.of<ThemeProvider>(context).hasCommerce) ...[
                      const Divider(),
                      ListTile(
                        title: Text(
                          TranslationService.translate(
                            context,
                            'currency_label',
                          ),
                        ),
                        subtitle: Consumer<ThemeProvider>(
                          builder: (context, themeProvider, _) {
                            return Text(themeProvider.currency);
                          },
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            String tempCurrency = Provider.of<ThemeProvider>(
                              context,
                              listen: false,
                            ).currency;
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(
                                  TranslationService.translate(
                                    context,
                                    'select_currency',
                                  ),
                                ),
                                content: SizedBox(
                                  width: 300,
                                  child: Autocomplete<String>(
                                    initialValue: TextEditingValue(
                                      text: tempCurrency,
                                    ),
                                    optionsBuilder:
                                        (TextEditingValue textEditingValue) {
                                          const options = [
                                            'EUR',
                                            'USD',
                                            'GBP',
                                            'CAD',
                                            'CHF',
                                            'JPY',
                                            'AUD',
                                            'CNY',
                                            'INR',
                                            'BRL',
                                            'SEK',
                                            'NOK',
                                            'DKK',
                                            'RUB',
                                          ];
                                          if (textEditingValue.text == '') {
                                            return options;
                                          }
                                          return options.where((String option) {
                                            return option
                                                .toLowerCase()
                                                .contains(
                                                  textEditingValue.text
                                                      .toLowerCase(),
                                                );
                                          });
                                        },
                                    onSelected: (String selection) {
                                      tempCurrency = selection;
                                    },
                                    fieldViewBuilder:
                                        (
                                          context,
                                          textEditingController,
                                          focusNode,
                                          onFieldSubmitted,
                                        ) {
                                          return TextField(
                                            controller: textEditingController,
                                            focusNode: focusNode,
                                            decoration: InputDecoration(
                                              labelText:
                                                  TranslationService.translate(
                                                    context,
                                                    'currency_label',
                                                  ),
                                              border:
                                                  const OutlineInputBorder(),
                                            ),
                                            onChanged: (value) {
                                              tempCurrency = value;
                                            },
                                          );
                                        },
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(
                                      TranslationService.translate(
                                        context,
                                        'cancel',
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Provider.of<ThemeProvider>(
                                        context,
                                        listen: false,
                                      ).setCurrency(tempCurrency);
                                      Navigator.pop(context);
                                    },
                                    child: Text(
                                      TranslationService.translate(
                                        context,
                                        'save',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    const Divider(),
                    // Hierarchical Tags Toggle
                    SwitchListTile(
                      title: Text(
                        TranslationService.translate(
                              context,
                              'enable_taxonomy',
                            ) ??
                            'Hierarchical Tags',
                      ),
                      subtitle: Text(
                        TranslationService.translate(
                              context,
                              'enable_taxonomy_subtitle',
                            ) ??
                            'Use "Parent > Child" naming to create sub-tags',
                      ),
                      value: AppConstants.enableHierarchicalTags,
                      onChanged: (bool value) async {
                        setState(() {
                          AppConstants.enableHierarchicalTags = value;
                        });
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('enableHierarchicalTags', value);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                TranslationService.translate(
                                      context,
                                      'restart_required_for_changes',
                                    ) ??
                                    'Please restart the app for changes to take full effect',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.phonelink_setup),
                      title: Text(
                        TranslationService.translate(
                          context,
                          'link_device_menu_title',
                        ),
                      ),
                      subtitle: Text(
                        TranslationService.translate(
                          context,
                          'link_device_menu_subtitle',
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        context.go('/profile/link-device');
                      },
                    ),

                    // TODO: Re-enable when borrowed books list is needed (currently using filters instead)
                    // if (_config?['profile_type'] == 'individual')
                    //   SwitchListTile(
                    //     title: Text(TranslationService.translate(context, 'show_borrowed_books')),
                    //     subtitle: Text(TranslationService.translate(context, 'show_borrowed_subtitle')),
                    //     value: _config?['show_borrowed_books'] ?? false,
                    //     onChanged: (value) async {
                    //       try {
                    //         final api = Provider.of<ApiService>(context, listen: false);
                    //         await api.updateLibraryConfig(
                    //           name: _config!['library_name'] ?? _config!['name'] ?? 'My Library',
                    //           description: _config!['description'],
                    //           tags: _config?['tags'] != null ? List<String>.from(_config!['tags']) : [],
                    //           latitude: _config?['latitude'],
                    //           longitude: _config?['longitude'],
                    //           showBorrowedBooks: value,
                    //           shareLocation: _config!['share_location'],
                    //         );
                    //         _fetchStatus();
                    //       } catch (e) {
                    //         if (mounted) {
                    //           ScaffoldMessenger.of(context).showSnackBar(
                    //             SnackBar(content: Text('${TranslationService.translate(context, 'error_updating_setting')}: $e')),
                    //           );
                    //         }
                    //       }
                    //     },
                    //   ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Profile Type Summary Card
              _buildProfileTypeSummary(),
              const SizedBox(height: 32),

              // Security Settings (MFA)
              Text(
                TranslationService.translate(context, 'security_settings') ??
                    'Security Settings',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.security),
                      title: Text(
                        TranslationService.translate(
                              context,
                              'two_factor_auth',
                            ) ??
                            'Two-Factor Authentication',
                      ),
                      subtitle: Text(
                        (_userInfo?['mfa_enabled'] == true)
                            ? (TranslationService.translate(
                                    context,
                                    'mfa_enabled',
                                  ) ??
                                  'Enabled')
                            : (TranslationService.translate(
                                    context,
                                    'mfa_disabled',
                                  ) ??
                                  'Disabled'),
                        style: TextStyle(
                          color: (_userInfo?['mfa_enabled'] == true)
                              ? Colors.green
                              : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: (_userInfo?['mfa_enabled'] == true)
                          ? null // TODO: Add disable button
                          : ElevatedButton(
                              onPressed: _setupMfa,
                              child: Text(
                                TranslationService.translate(
                                      context,
                                      'enable',
                                    ) ??
                                    'Enable',
                              ),
                            ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.password),
                      title: Text(
                        TranslationService.translate(
                              context,
                              'change_password',
                            ) ??
                            'Change Password',
                      ),
                      trailing: ElevatedButton(
                        onPressed: _showChangePasswordDialog,
                        child: Text(
                          TranslationService.translate(
                                context,
                                'change_password',
                              ) ??
                              'Change',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Audio Module Settings (decoupled - can be removed without breaking the app)
              const AudioSettingsCard(),
              const SizedBox(height: 32),

              // Integrations (MCP for Claude Desktop)
              if (!kIsWeb) _buildMcpIntegrationSection(),

              // Data Management
              Center(
                child: Text(
                  TranslationService.translate(context, 'data_management'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _exportData,
                icon: const Icon(Icons.download),
                label: Text(
                  TranslationService.translate(context, 'export_backup'),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _importBackup,
                icon: const Icon(Icons.upload),
                label: Text(
                  TranslationService.translate(context, 'import_backup'),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              const SizedBox(height: 16),

              // Shelf Management (back-office)
              ElevatedButton.icon(
                onPressed: () => context.push('/shelves-management'),
                icon: const Icon(Icons.folder_special),
                label: Text(
                  TranslationService.translate(context, 'manage_shelves') ??
                      'Manage Shelves',
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['csv', 'txt'],
                      withData: kIsWeb,
                    );
                    if (result != null) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              TranslationService.translate(
                                context,
                                'importing_books',
                              ),
                            ),
                          ),
                        );
                      }
                      final apiService = Provider.of<ApiService>(
                        context,
                        listen: false,
                      );
                      late final Response response;
                      if (kIsWeb) {
                        response = await apiService.importBooks(
                          result.files.single.bytes!,
                          filename: result.files.single.name,
                        );
                      } else {
                        response = await apiService.importBooks(
                          result.files.single.path!,
                        );
                      }
                      if (context.mounted) {
                        if (response.statusCode == 200) {
                          final imported = response.data['imported'];
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${TranslationService.translate(context, 'import_success')} $imported ${TranslationService.translate(context, 'books')}',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${TranslationService.translate(context, 'import_fail')}: ${response.data['error']}',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${TranslationService.translate(context, 'error_picking_file')}: $e',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.upload_file),
                label: Text(
                  TranslationService.translate(context, 'import_csv'),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              const SizedBox(height: 32),

              // App Settings
              Text(
                TranslationService.translate(context, 'app_settings'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.download),
                      title: Text(
                        TranslationService.translate(
                          context,
                          'import_demo_data',
                        ),
                      ),
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(
                              TranslationService.translate(
                                context,
                                'import_demo_data_title',
                              ),
                            ),
                            content: Text(
                              TranslationService.translate(
                                context,
                                'import_demo_data_desc',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text(
                                  TranslationService.translate(
                                    context,
                                    'cancel',
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text(
                                  TranslationService.translate(
                                    context,
                                    'import',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true && context.mounted) {
                          await DemoService.importDemoBooks(context);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  TranslationService.translate(
                                    context,
                                    'demo_data_imported',
                                  ),
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.settings),
                      title: Text(
                        TranslationService.translate(context, 'edit_settings'),
                      ),
                      onTap: () {
                        _showSettingsDialog(context);
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(
                        Icons.delete_forever,
                        color: Colors.red,
                      ),
                      title: Text(
                        TranslationService.translate(context, 'reset_app'),
                        style: const TextStyle(color: Colors.red),
                      ),
                      onTap: () async {
                        final authService = Provider.of<AuthService>(
                          context,
                          listen: false,
                        );
                        final hasPassword = await authService.hasPasswordSet();

                        if (!mounted) return;

                        // Password entry controller and reset type selection
                        final passwordController = TextEditingController();
                        String? errorText;
                        bool resetEntirely =
                            false; // false = standard, true = full reset

                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => StatefulBuilder(
                            builder: (context, setState) => AlertDialog(
                              title: Text(
                                TranslationService.translate(
                                  context,
                                  'reset_app_title',
                                ),
                              ),
                              content: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      TranslationService.translate(
                                        context,
                                        'reset_app_confirmation',
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Reset Type Selection
                                    Text(
                                      TranslationService.translate(
                                            context,
                                            'reset_type_label',
                                          ) ??
                                          'Choose reset type:',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Standard Reset Option
                                    RadioListTile<bool>(
                                      value: false,
                                      groupValue: resetEntirely,
                                      title: Text(
                                        TranslationService.translate(
                                              context,
                                              'reset_type_standard',
                                            ) ??
                                            'Standard Reset',
                                      ),
                                      subtitle: Text(
                                        TranslationService.translate(
                                              context,
                                              'reset_standard_desc',
                                            ) ??
                                            'Clears library data but keeps your login',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      onChanged: (val) =>
                                          setState(() => resetEntirely = val!),
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),

                                    // Reset Entirely Option
                                    RadioListTile<bool>(
                                      value: true,
                                      groupValue: resetEntirely,
                                      title: Text(
                                        TranslationService.translate(
                                              context,
                                              'reset_type_full',
                                            ) ??
                                            'Reset Entirely',
                                        style: const TextStyle(
                                          color: Colors.red,
                                        ),
                                      ),
                                      subtitle: Text(
                                        TranslationService.translate(
                                              context,
                                              'reset_full_desc',
                                            ) ??
                                            'Completely removes all data and credentials',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      onChanged: (val) =>
                                          setState(() => resetEntirely = val!),
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),

                                    // Warning for full reset
                                    if (resetEntirely) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.orange,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.warning,
                                              color: Colors.orange,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                TranslationService.translate(
                                                      context,
                                                      'reset_full_warning',
                                                    ) ??
                                                    'You will need to set a new username and password',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.orange,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    if (hasPassword) ...[
                                      const SizedBox(height: 16),
                                      TextField(
                                        controller: passwordController,
                                        obscureText: true,
                                        decoration: InputDecoration(
                                          labelText:
                                              TranslationService.translate(
                                                context,
                                                'enter_password_to_reset',
                                              ) ??
                                              'Enter your password to confirm',
                                          errorText: errorText,
                                          border: const OutlineInputBorder(),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: Text(
                                    TranslationService.translate(
                                      context,
                                      'cancel',
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    if (hasPassword) {
                                      final isValid = await authService
                                          .verifyPassword(
                                            passwordController.text,
                                          );
                                      if (!isValid) {
                                        setState(
                                          () => errorText =
                                              TranslationService.translate(
                                                context,
                                                'password_incorrect',
                                              ) ??
                                              'Incorrect password',
                                        );
                                        return;
                                      }
                                    }
                                    Navigator.pop(context, true);
                                  },
                                  child: Text(
                                    TranslationService.translate(
                                      context,
                                      'reset_confirm',
                                    ),
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );

                        if (confirmed == true && mounted) {
                          try {
                            // 1. Call backend to wipe data
                            final api = Provider.of<ApiService>(
                              context,
                              listen: false,
                            );
                            await api.resetApp();

                            // 2. Clear local state
                            final themeProvider = Provider.of<ThemeProvider>(
                              context,
                              listen: false,
                            );
                            await themeProvider.resetSetup();

                            // 3. If full reset, also clear credentials
                            if (resetEntirely) {
                              await authService.clearAll();
                              // Also clear SharedPreferences completely for fresh start
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.clear();
                            }

                            if (mounted) {
                              context.go('/setup');
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Reset failed: $e')),
                              );
                            }
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Security Settings (Change Password)
              Text(
                TranslationService.translate(context, 'security') ?? 'Security',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: Text(
                        TranslationService.translate(
                              context,
                              'change_password',
                            ) ??
                            'Change Password',
                      ),
                      subtitle: Text(
                        (TranslationService.translate(
                              context,
                              'manage_login_credentials',
                            ) ??
                            'Manage your login credentials'),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _showChangePasswordDialog,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Logout Button
              OutlinedButton.icon(
                onPressed: () async {
                  final authService = Provider.of<AuthService>(
                    context,
                    listen: false,
                  );
                  // Small delay to ensure any pending theme/UI updates are settled
                  // This prevents 'Failed assertion: _dependents.isEmpty' if theme changed recently
                  await Future.delayed(const Duration(milliseconds: 200));

                  await authService.logout();
                  if (mounted) {
                    context.go('/login');
                  }
                },
                icon: const Icon(Icons.logout),
                label: Text(TranslationService.translate(context, 'logout')),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadingGoalsSection() {
    // Get current goals from status
    final yearlyGoal = _userStatus?['config']?['reading_goal_yearly'] ?? 12;
    final monthlyGoal = _userStatus?['config']?['reading_goal_monthly'] ?? 0;
    final booksRead = _userStatus?['config']?['reading_goal_progress'] ?? 0;
    final yearlyProgress = yearlyGoal > 0
        ? (booksRead / yearlyGoal).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          TranslationService.translate(context, 'reading_goals_title'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),

        // Yearly Goal Card
        _buildGoalCard(
          icon: Icons.calendar_today,
          color: Colors.teal,
          title: TranslationService.translate(context, 'yearly_goal'),
          subtitle:
              '$yearlyGoal ${TranslationService.translate(context, 'books_per_year')}',
          progress: yearlyProgress,
          current: booksRead,
          onEdit: () => _showEditGoalDialog(yearlyGoal, isMonthly: false),
        ),

        // TODO: Monthly goals per month (backlog)
        // Example: "Goal for December 2024: 3 books"
      ],
    );
  }

  Widget _buildGoalCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required double progress,
    required int current,
    required VoidCallback onEdit,
    bool isOptional = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isOptional ? Colors.grey : color,
                          fontSize: 13,
                          fontStyle: isOptional
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: Icon(
                  isOptional ? Icons.add_circle_outline : Icons.edit,
                  color: color,
                ),
                onPressed: onEdit,
              ),
            ],
          ),
          if (!isOptional && progress > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.grey.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress >= 1.0 ? Colors.green : color,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$current ${TranslationService.translate(context, 'books_read')}',
                  style: TextStyle(fontSize: 12, color: color),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: progress >= 1.0 ? Colors.green : color,
                  ),
                ),
              ],
            ),
            if (progress >= 1.0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.celebration,
                      color: Colors.green,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      TranslationService.translate(
                        context,
                        'goal_reached_congrats',
                      ),
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _showEditGoalDialog(
    int currentGoal, {
    required bool isMonthly,
  }) async {
    double sliderValue = currentGoal > 0
        ? currentGoal.toDouble()
        : (isMonthly ? 2.0 : 12.0);
    final color = isMonthly ? Colors.orange : Colors.teal;
    final maxValue = isMonthly ? 20.0 : 100.0;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            TranslationService.translate(
              context,
              isMonthly ? 'edit_monthly_goal' : 'edit_yearly_goal',
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${sliderValue.toInt()} ${TranslationService.translate(context, isMonthly ? 'books_per_month' : 'books_per_year')}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 24),
              Slider(
                value: sliderValue,
                min: isMonthly ? 0 : 1,
                max: maxValue,
                divisions: maxValue.toInt() - (isMonthly ? 0 : 1),
                activeColor: color,
                label:
                    '${sliderValue.toInt()} ${TranslationService.translate(context, 'books')}',
                onChanged: (value) {
                  setState(() => sliderValue = value);
                },
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isMonthly
                        ? '0 (${TranslationService.translate(context, 'disabled')})'
                        : '1 ${TranslationService.translate(context, 'book')}',
                  ),
                  Text(
                    '${maxValue.toInt()} ${TranslationService.translate(context, 'books')}',
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(TranslationService.translate(context, 'cancel')),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _updateReadingGoal(
                  sliderValue.toInt(),
                  isMonthly: isMonthly,
                );
              },
              style: FilledButton.styleFrom(backgroundColor: color),
              child: Text(TranslationService.translate(context, 'save')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateReadingGoal(
    int newGoal, {
    required bool isMonthly,
  }) async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      if (isMonthly) {
        await api.updateGamificationConfig(readingGoalMonthly: newGoal);
      } else {
        await api.updateGamificationConfig(readingGoalYearly: newGoal);
      }
      _fetchStatus(); // Refresh
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              TranslationService.translate(context, 'goal_updated'),
            ),
            backgroundColor: isMonthly ? Colors.orange : Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${TranslationService.translate(context, 'error_updating')}: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildMcpIntegrationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          TranslationService.translate(context, 'integrations') ??
              'Integrations',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.extension,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            TranslationService.translate(
                                  context,
                                  'mcp_integration',
                                ) ??
                                'Claude Desktop (MCP)',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            TranslationService.translate(
                                  context,
                                  'mcp_description',
                                ) ??
                                'Connect your library to Claude AI for intelligent book discussions',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _copyMcpConfig(),
                  icon: const Icon(Icons.copy),
                  label: Text(
                    TranslationService.translate(context, 'copy_mcp_config') ??
                        'Copy Config for Claude Desktop',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  TranslationService.translate(context, 'mcp_instructions') ??
                      'Paste this configuration into your Claude Desktop settings file (claude_desktop_config.json)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Future<void> _copyMcpConfig() async {
    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      // Fetch config from backend with dynamic paths
      final response = await apiService.getMcpConfig();

      if (response.statusCode == 200 && response.data != null) {
        // Use the config_json directly from the response
        final configJson = response.data['config_json'] as String? ?? '{}';

        await Clipboard.setData(ClipboardData(text: configJson));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                TranslationService.translate(context, 'mcp_config_copied') ??
                    'MCP configuration copied to clipboard!',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to fetch MCP config');
      }
    } catch (e) {
      debugPrint('Error fetching MCP config: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching configuration: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildProfileTypeSummary() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final profileType = themeProvider.profileType;

        // Define features and restrictions for each profile type
        Map<String, List<String>> advantages = {};
        Map<String, List<String>> restrictions = {};

        switch (profileType) {
          case 'individual':
          case 'individual_reader':
            advantages = {
              'profile_advantage_borrow': ['✓'],
              'profile_advantage_lend': ['✓'],
              'profile_advantage_wishlist': ['✓'],
            };
            restrictions = {};
            break;
          case 'professional':
          case 'librarian':
            advantages = {
              'profile_advantage_lending': ['✓'],
              'profile_advantage_contacts': ['✓'],
              'profile_advantage_statistics': ['✓'],
            };
            restrictions = {
              'profile_restriction_no_borrow': ['✗'],
            };
            break;
          case 'kid':
            advantages = {
              'profile_advantage_simple_ui': ['✓'],
              'profile_advantage_borrow': ['✓'],
              'profile_advantage_lend': ['✓'],
              'profile_advantage_wishlist': ['✓'],
            };
            restrictions = {
              // No specific restrictions for now, just simplified UI
            };
            break;
          case 'bookseller':
            advantages = {
              'profile_advantage_pricing': ['✓'],
              'profile_advantage_sales': ['✓'],
              'profile_advantage_inventory': ['✓'],
              'profile_advantage_statistics': ['✓'],
            };
            restrictions = {
              'profile_restriction_no_loans': ['✗'],
              'profile_restriction_no_gamification': ['✗'],
            };
            break;
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    TranslationService.translate(context, 'profile_summary'),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    TranslationService.translate(context, profileType),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Advantages
              if (advantages.isNotEmpty) ...[
                ...advantages.keys.map(
                  (key) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 16,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            TranslationService.translate(context, key),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              // Restrictions
              if (restrictions.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...restrictions.keys.map(
                  (key) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.remove_circle,
                          size: 16,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            TranslationService.translate(context, key),
                            style: const TextStyle(fontSize: 13),
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
      },
    );
  }

  void _showAvatarPicker(BuildContext context, ThemeProvider themeProvider) {
    // Create a local copy of the config to avoid updating the provider immediately
    // This allows the user to cancel changes
    AvatarConfig currentConfig =
        themeProvider.avatarConfig ?? AvatarConfig.defaultConfig;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.85,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          TranslationService.translate(
                            context,
                            'customize_avatar',
                          ),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: AvatarCustomizer(
                      initialConfig: currentConfig,
                      onConfigChanged: (newConfig) {
                        setState(() {
                          currentConfig = newConfig;
                        });
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            // Show loading indicator if needed, or just close and update
                            final api = Provider.of<ApiService>(
                              context,
                              listen: false,
                            );
                            await themeProvider.setAvatarConfig(
                              currentConfig,
                              apiService: api,
                            );

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    TranslationService.translate(
                                      context,
                                      'avatar_updated',
                                    ),
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${TranslationService.translate(context, 'error_saving_avatar')}: $e',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        child: Text(
                          TranslationService.translate(context, 'save_changes'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSettingsDialog(BuildContext context) {
    final libraryNameController = TextEditingController(
      text: _config?['library_name'] ?? _config?['name'] ?? '',
    );

    // Capture providers BEFORE showing dialog to avoid context issues
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final outerContext = context; // Keep reference to outer context

    // Use local state to defer changes until Save
    String selectedLocale = themeProvider.locale.languageCode;
    String selectedTheme = themeProvider.themeStyle;
    String selectedProfileType = themeProvider.profileType;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            return AlertDialog(
              title: Text(
                TranslationService.translate(builderContext, 'edit_settings'),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TranslationService.translate(
                        builderContext,
                        'library_name',
                      ),
                    ),
                    TextField(
                      controller: libraryNameController,
                      decoration: InputDecoration(
                        hintText: TranslationService.translate(
                          context,
                          'enter_library_name',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      TranslationService.translate(
                            builderContext,
                            'lang_title',
                          ) ??
                          'Language',
                    ),
                    DropdownButton<String>(
                      value: selectedLocale,
                      isExpanded: true,
                      items: [
                        DropdownMenuItem(
                          value: 'en',
                          child: Text(
                            TranslationService.translate(
                              builderContext,
                              'lang_en',
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'fr',
                          child: Text(
                            TranslationService.translate(
                              builderContext,
                              'lang_fr',
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'es',
                          child: Text(
                            TranslationService.translate(
                              builderContext,
                              'lang_es',
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'de',
                          child: Text(
                            TranslationService.translate(
                              builderContext,
                              'lang_de',
                            ),
                          ),
                        ),
                      ],
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setDialogState(() => selectedLocale = newValue);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      TranslationService.translate(
                            builderContext,
                            'theme_title',
                          ) ??
                          'Theme',
                    ),
                    DropdownButton<String>(
                      value: selectedTheme,
                      isExpanded: true,
                      items: ThemeRegistry.all.map((theme) {
                        return DropdownMenuItem(
                          value: theme.id,
                          child: Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: theme.previewColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  TranslationService.translate(
                                        context,
                                        'theme_${theme.id}',
                                      ) ??
                                      theme.displayName,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setDialogState(() => selectedTheme = newValue);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      TranslationService.translate(
                            builderContext,
                            selectedProfileType,
                          ) ??
                          (selectedProfileType == 'individual'
                              ? 'Particulier'
                              : 'Bibliothèque'),
                      style: Theme.of(builderContext).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(
                        TranslationService.translate(
                              context,
                              'profile_type_label',
                            ) ??
                            'Type de profil',
                      ),
                      trailing: SizedBox(
                        width: 130,
                        child: DropdownButton<String>(
                          value: selectedProfileType,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: [
                            DropdownMenuItem(
                              value: 'individual',
                              child: Text(
                                TranslationService.translate(
                                  context,
                                  'profile_individual',
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'librarian',
                              child: Text(
                                TranslationService.translate(
                                  context,
                                  'profile_librarian',
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'kid',
                              child: Text(
                                TranslationService.translate(
                                  context,
                                  'profile_kid',
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => selectedProfileType = value);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(
                    TranslationService.translate(builderContext, 'cancel'),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    // Capture values before closing dialog
                    final newTheme = selectedTheme;
                    final newLocale = selectedLocale;
                    final newProfileType = selectedProfileType;
                    final libName = libraryNameController.text;

                    // Close dialog FIRST
                    Navigator.pop(dialogContext);

                    // Wait for dialog animation to FULLY complete (default duration ~300ms)
                    await Future.delayed(const Duration(milliseconds: 350));

                    // Now safe to apply theme changes
                    if (newTheme != themeProvider.themeStyle) {
                      themeProvider.setThemeStyle(newTheme);
                    }
                    if (newLocale != themeProvider.locale.languageCode) {
                      themeProvider.setLocale(Locale(newLocale));
                    }
                    if (newProfileType != themeProvider.profileType) {
                      await themeProvider.setProfileType(
                        newProfileType,
                        apiService: apiService,
                      );
                    }

                    // Save library name if changed
                    if (libName.isNotEmpty &&
                        libName !=
                            (_config?['library_name'] ?? _config?['name'])) {
                      try {
                        await apiService.updateLibraryConfig(
                          name: libName,
                          description: _config?['description'],
                          profileType: newProfileType,
                          tags: _config?['tags'] != null
                              ? List<String>.from(_config!['tags'])
                              : [],
                          latitude: _config?['latitude'],
                          longitude: _config?['longitude'],
                          showBorrowedBooks: _config?['show_borrowed_books'],
                          shareLocation: _config?['share_location'],
                        );
                      } catch (e) {
                        debugPrint('Error updating library config: $e');
                      }
                    }

                    // Refresh status
                    _fetchStatus();

                    // Show confirmation using outer context (still valid)
                    if (mounted) {
                      ScaffoldMessenger.of(outerContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            TranslationService.translate(
                                  outerContext,
                                  'settings_saved',
                                ) ??
                                'Settings saved',
                          ),
                        ),
                      );
                    }
                  },
                  child: Text(
                    TranslationService.translate(builderContext, 'save'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
