import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart'; // Import DioException
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/translation_service.dart';
import '../theme/app_design.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeIn));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _animController.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _onLoginSuccess(String token, String username) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);

    await authService.saveToken(token);
    await authService.saveUsername(username);

    // Fetch user context
    try {
      final meResponse = await apiService.getMe();
      if (meResponse.statusCode == 200) {
        final data = meResponse.data;
        await authService.saveUserId(data['user_id']);
        await authService.saveLibraryId(data['library_id']);
      }
    } catch (e) {
      debugPrint('Failed to fetch user context: $e');
    }

    if (mounted) {
      context.go('/books');
    }
  }

  Future<void> _showMfaDialog(String username, String password) async {
    final codeController = TextEditingController();
    String? errorText;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(TranslationService.translate(context, 'two_factor_auth') ?? 'Two-Factor Authentication'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               Text(TranslationService.translate(context, 'enter_mfa_code') ?? 'Enter the 6-digit code from your authenticator app.'),
               const SizedBox(height: 16),
               TextField(
                 controller: codeController,
                 keyboardType: TextInputType.number,
                 maxLength: 6,
                 autofocus: true,
                 decoration: InputDecoration(
                   labelText: 'Code',
                   errorText: errorText,
                   border: const OutlineInputBorder(),
                 ),
               ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Cancel login
              child: Text(TranslationService.translate(context, 'cancel') ?? 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                setState(() => errorText = null);
                final code = codeController.text.trim();
                if (code.length != 6) {
                   setState(() => errorText = 'Invalid code length');
                   return;
                }
                
                final apiService = Provider.of<ApiService>(context, listen: false);
                try {
                  final response = await apiService.loginMfa(username, password, code);
                  if (response.statusCode == 200) {
                     Navigator.pop(context); // Close dialog
                     _onLoginSuccess(response.data['token'], username);
                  } else {
                     setState(() => errorText = 'Invalid code');
                  }
                } catch (e) {
                   setState(() => errorText = 'Verification failed');
                }
              },
              child: Text(TranslationService.translate(context, 'verify') ?? 'Verify'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      final response = await apiService.login(
        _usernameController.text,
        _passwordController.text,
      );

      if (response.statusCode == 200) {
        await _onLoginSuccess(response.data['token'], _usernameController.text);
      } else {
        setState(() {
          _errorMessage = 'Invalid credentials';
        });
      }
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 403 && e.response?.data['error'] == 'mfa_required') {
          // MFA Required
          if (mounted) {
             setState(() => _isLoading = false); // Stop loading indicator on main screen
             _showMfaDialog(_usernameController.text, _passwordController.text);
             return; 
          }
      }
      
      setState(() {
        _errorMessage = 'Login failed: ${e is DioException ? e.message : e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showServerSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final controller = TextEditingController(
          text: Provider.of<ApiService>(context, listen: false).baseUrl,
        );
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.dns, color: Color(0xFF6366F1)),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Server Settings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: 'Server URL',
                    hintText: 'http://localhost:8000',
                    prefixIcon: const Icon(Icons.link),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final authService = Provider.of<AuthService>(
                            context,
                            listen: false,
                          );
                          final apiService = Provider.of<ApiService>(
                            context,
                            listen: false,
                          );
                          final navigator = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);

                          await authService.logout();
                          apiService.setBaseUrl(controller.text);
                          navigator.pop();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Server changed to ${controller.text}',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppDesign.primaryGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_stories,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'BiblioGenius',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Login Card
                      Container(
                        constraints: const BoxConstraints(maxWidth: 400),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: AppDesign.elevatedShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              TranslationService.translate(
                                context,
                                'login_title',
                              ),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sign in to access your library',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Error message
                            if (_errorMessage != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.red[200]!),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.red[700],
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: TextStyle(
                                          color: Colors.red[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            TextField(
                              key: const Key('usernameField'),
                              controller: _usernameController,
                              focusNode: _usernameFocus,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => _passwordFocus.requestFocus(),
                              decoration: InputDecoration(
                                labelText: 'Username',
                                prefixIcon: const Icon(Icons.person_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey[300]!,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF6366F1),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Password field
                            TextField(
                              key: const Key('passwordField'),
                              controller: _passwordController,
                              focusNode: _passwordFocus,
                              obscureText: _obscurePassword,
                              onSubmitted: (_) => _login(),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                  onPressed: () {
                                    setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    );
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey[300]!,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF6366F1),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Login button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                key: const Key('loginButton'),
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6366F1),
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: const Color(
                                    0xFF6366F1,
                                  ).withValues(alpha: 0.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : Text(
                                        TranslationService.translate(
                                          context,
                                          'login_btn',
                                        ),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // New setup link
                            Center(
                              child: TextButton(
                                onPressed: () => context.go('/setup'),
                                child: Text(
                                  TranslationService.translate(
                                    context,
                                    'new_server_setup',
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFF6366F1),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Server settings button
                      TextButton.icon(
                        onPressed: _showServerSettings,
                        icon: const Icon(
                          Icons.settings,
                          color: Colors.white70,
                          size: 18,
                        ),
                        label: const Text(
                          'Server Settings',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
