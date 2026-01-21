import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/translation_service.dart';
import '../services/demo_service.dart';
import '../services/mdns_service.dart';
import '../themes/base/theme_registry.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final TextEditingController _libraryNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController(
    text: 'admin',
  );
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    _libraryNameController.text = themeProvider.setupLibraryName;
    _libraryNameController.text = themeProvider.setupLibraryName;
    // Removed listener to prevent rebuilds on every keystroke which causes focus loss
  }

  @override
  void dispose() {
    _libraryNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Map<String, Map<String, String>> get _t => {
    'en': {
      'welcome_title': 'Welcome',
      'welcome_header': 'Welcome to BiblioGenius!',
      'welcome_body':
          'This app helps you manage your personal library, track loans, and connect with other book lovers.',
      'welcome_footer': 'Let\'s get you set up in just a few steps.',
      'library_info_title': 'Library Info',
      'library_name_label': 'Library Name',
      'library_name_hint': 'e.g. The Book Cave',
      'profile_type_label': 'Profile Type',
      'demo_title': 'Demo Content',
      'demo_header': 'Start with some books?',
      'demo_body':
          'We can add a few classic books to your library so you can explore the features immediately.',
      'demo_option_yes': 'Yes, import demo books',
      'demo_option_no': 'No, start empty',
      'lang_title': 'Select Language',
      'lang_label': 'Choose your preferred language:',
      'theme_title': 'Customize Theme',
      'theme_label': 'Choose a color for your app banner:',
      'finish_title': 'Ready to Go!',
      'finish_header': 'You are all set!',
      'finish_body': 'Click "Finish" to start adding books to your library.',
      'btn_next': 'Next',
      'btn_back': 'Back',
      'btn_finish': 'Finish',
      'setup_progress': 'Setting up your library...',
    },
    'fr': {
      'welcome_title': 'Bienvenue',
      'welcome_header': 'Bienvenue sur BiblioGenius !',
      'welcome_body':
          'Gérez votre bibliothèque, suivez vos prêts et connectez-vous avec d\'autres passionnés.',
      'welcome_footer': 'Commençons la configuration.',
      'library_info_title': 'Infos Bibliothèque',
      'library_name_label': 'Nom de la bibliothèque',
      'library_name_hint': 'ex: La Caverne aux Livres',
      'profile_type_label': 'Type de profil',
      'demo_title': 'Contenu Démo',
      'demo_header': 'Commencer avec des livres ?',
      'demo_body':
          'Nous pouvons ajouter quelques classiques pour vous permettre de tester les fonctionnalités.',
      'demo_option_yes': 'Oui, importer des livres démo',
      'demo_option_no': 'Non, commencer vide',
      'lang_title': 'Langue',
      'lang_label': 'Choisissez votre langue :',
      'theme_title': 'Thème',
      'theme_label': 'Choisissez la couleur de la bannière :',
      'finish_title': 'C\'est prêt !',
      'finish_header': 'Tout est configuré !',
      'finish_body': 'Cliquez sur "Terminer" pour commencer.',
      'btn_next': 'Suivant',
      'btn_back': 'Retour',
      'btn_finish': 'Terminer',
      'setup_progress': 'Configuration en cours...',
    },
    'es': {
      'welcome_title': 'Bienvenido',
      'welcome_header': '¡Bienvenido a BiblioGenius!',
      'welcome_body':
          'Gestiona tu biblioteca, sigue tus préstamos y conecta con otros lectores.',
      'welcome_footer': 'Empecemos la configuración.',
      'library_info_title': 'Info Biblioteca',
      'library_name_label': 'Nombre de la biblioteca',
      'library_name_hint': 'ej: La Cueva de los Libros',
      'profile_type_label': 'Tipo de perfil',
      'demo_title': 'Contenido Demo',
      'demo_header': '¿Empezar con libros?',
      'demo_body':
          'Podemos añadir algunos clásicos para que pruebes las funciones.',
      'demo_option_yes': 'Sí, importar libros demo',
      'demo_option_no': 'No, empezar vacío',
      'lang_title': 'Idioma',
      'lang_label': 'Elige tu idioma:',
      'theme_title': 'Tema',
      'theme_label': 'Elige el color del banner:',
      'finish_title': '¡Listo!',
      'finish_header': '¡Todo listo!',
      'finish_body': 'Haz clic en "Terminar" para empezar.',
      'btn_next': 'Siguiente',
      'btn_back': 'Atrás',
      'btn_finish': 'Terminar',
      'setup_progress': 'Configurando...',
    },
    'de': {
      'welcome_title': 'Willkommen',
      'welcome_header': 'Willkommen bei BiblioGenius!',
      'welcome_body':
          'Verwalten Sie Ihre Bibliothek, verfolgen Sie Ausleihen und verbinden Sie sich mit anderen.',
      'welcome_footer': 'Lassen Sie uns beginnen.',
      'library_info_title': 'Bibliotheksinfo',
      'library_name_label': 'Bibliotheksname',
      'library_name_hint': 'z.B. Die Bücherhöhle',
      'profile_type_label': 'Profiltyp',
      'demo_title': 'Demo-Inhalt',
      'demo_header': 'Mit Büchern starten?',
      'demo_body':
          'Wir können einige Klassiker hinzufügen, damit Sie die Funktionen testen können.',
      'demo_option_yes': 'Ja, Demo-Bücher importieren',
      'demo_option_no': 'Nein, leer starten',
      'lang_title': 'Sprache',
      'lang_label': 'Wählen Sie Ihre Sprache:',
      'theme_title': 'Thema',
      'theme_label': 'Wählen Sie eine Bannerfarbe:',
      'finish_title': 'Fertig!',
      'finish_header': 'Alles bereit!',
      'finish_body': 'Klicken Sie auf "Fertigstellen", um zu beginnen.',
      'btn_next': 'Weiter',
      'btn_back': 'Zurück',
      'btn_finish': 'Fertigstellen',
      'setup_progress': 'Einrichtung läuft...',
    },
  };

  @override
  Widget build(BuildContext context) {
    // Ensure themes are initialized
    ThemeRegistry.initialize();

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        // Get locale and step
        final lang = themeProvider.locale.languageCode;
        final strings = _t[lang] ?? _t['en']!;
        final currentStep = themeProvider.setupStep;

        return Scaffold(
          appBar: AppBar(
            title: Text(strings['welcome_header']!),
            automaticallyImplyLeading: false, // Hide back button
          ),
          body: Stepper(
            physics:
                const ClampingScrollPhysics(), // Ensure scrolling works well
            currentStep: currentStep,
            onStepContinue: () {
              debugPrint(
                'Stepper onStepContinue called - currentStep: $currentStep',
              );
              if (currentStep < 4) {
                if (currentStep == 1) {
                  // Save library name when leaving step 1
                  themeProvider.setSetupLibraryName(
                    _libraryNameController.text,
                  );
                }
                // Validate password on credentials step
                if (currentStep == 3) {
                  if (_passwordController.text.isNotEmpty &&
                      _passwordController.text !=
                          _confirmPasswordController.text) {
                    setState(
                      () => _passwordError =
                          TranslationService.translate(
                            context,
                            'passwords_do_not_match',
                          ) ??
                          'Passwords do not match',
                    );
                    return;
                  }
                  setState(() => _passwordError = null);
                }
                themeProvider.setSetupStep(currentStep + 1);
              } else {
                debugPrint('Calling _finishSetup...');
                _finishSetup(context, strings);
              }
            },
            onStepTapped: (step) {
              // Only allow tapping valid past/current steps or next step
              // But strictly prevent jumping way ahead (like from 1 to 6)
              if (step <= themeProvider.setupStep + 1) {
                themeProvider.setSetupStep(step);
              }
            },
            onStepCancel: () {
              if (currentStep > 0) {
                themeProvider.setSetupStep(currentStep - 1);
              }
            },
            controlsBuilder: (context, details) {
              final isLastStep = currentStep == 4;
              return Padding(
                padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
                child: Row(
                  children: [
                    // Using Container + InkWell instead of ElevatedButton to avoid
                    // AnimatedDefaultTextStyle animation issues during theme transitions
                    Material(
                      color: Colors.blue.shade700,
                      elevation: 4,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        key: Key('setupNextButton_${details.stepIndex}'),
                        onTap: () {
                          details.onStepContinue?.call();
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          child: Text(
                            isLastStep
                                ? strings['btn_finish']!
                                : strings['btn_next']!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (currentStep > 0) ...[
                      const SizedBox(width: 16),
                      // Using InkWell + Text instead of TextButton to avoid
                      // AnimatedDefaultTextStyle animation issues during theme transitions
                      InkWell(
                        onTap: details.onStepCancel,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Text(
                            strings['btn_back']!,
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
            steps: [
              // Step 0: Welcome
              Step(
                title: Text(strings['welcome_title']!),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings['welcome_header']!,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(strings['welcome_body']!),
                    const SizedBox(height: 10),
                    Text(strings['welcome_footer']!),
                  ],
                ),
                isActive: currentStep >= 0,
                state: currentStep > 0 ? StepState.complete : StepState.indexed,
              ),
              // Step 1: Profile & Library Info
              Step(
                title: Text(strings['library_info_title']!),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings['library_name_label']!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('setupLibraryNameField'),
                      controller: _libraryNameController,
                      decoration: InputDecoration(
                        hintText: strings['library_name_hint'],
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      TranslationService.translate(
                        context,
                        'profile_usage_question',
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildProfileOption(
                      'librarian',
                      TranslationService.translate(
                        context,
                        'profile_librarian',
                      ),
                      TranslationService.translate(
                        context,
                        'profile_librarian_desc',
                      ),
                      Icons.local_library,
                      themeProvider,
                    ),
                    _buildProfileOption(
                      'bookseller', // New Bookseller profile
                      TranslationService.translate(
                        context,
                        'profile_bookseller',
                      ),
                      TranslationService.translate(
                        context,
                        'profile_bookseller_desc',
                      ),
                      Icons.storefront, // Store icon
                      themeProvider,
                    ),
                    _buildProfileOption(
                      'individual',
                      TranslationService.translate(
                        context,
                        'profile_individual',
                      ),
                      TranslationService.translate(
                        context,
                        'profile_individual_desc',
                      ),
                      Icons.person,
                      themeProvider,
                      key: const Key('setupProfileIndividual'),
                    ),
                    _buildProfileOption(
                      'kid',
                      TranslationService.translate(context, 'profile_kid'),
                      TranslationService.translate(context, 'profile_kid_desc'),
                      Icons.child_care,
                      themeProvider,
                    ),
                  ],
                ),
                isActive: currentStep >= 1,
                state: currentStep > 1 ? StepState.complete : StepState.indexed,
              ),
              // Step 2: Demo Content (was Step 3)
              Step(
                title: Text(strings['demo_title']!),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings['demo_header']!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(strings['demo_body']!),
                    const SizedBox(height: 16),
                    RadioListTile<bool>(
                      title: Text(strings['demo_option_yes']!),
                      value: true,
                      groupValue: themeProvider.setupImportDemo,
                      onChanged: (val) =>
                          themeProvider.setSetupImportDemo(val!),
                    ),
                    RadioListTile<bool>(
                      key: const Key('setupDemoNo'),
                      title: Text(strings['demo_option_no']!),
                      value: false,
                      groupValue: themeProvider.setupImportDemo,
                      onChanged: (val) =>
                          themeProvider.setSetupImportDemo(val!),
                    ),
                  ],
                ),
                isActive: currentStep >= 2,
                state: currentStep > 2 ? StepState.complete : StepState.indexed,
              ),
              // Step 3: Credentials
              Step(
                title: Text(
                  TranslationService.translate(
                        context,
                        'setup_credentials_title',
                      ) ??
                      'Credentials',
                ),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TranslationService.translate(
                            context,
                            'setup_password_optional',
                          ) ??
                          'Optional - Set a password to protect your library',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('setupUsernameField'),
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText:
                            TranslationService.translate(
                              context,
                              'setup_username_label',
                            ) ??
                            'Username',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('setupPasswordField'),
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText:
                            TranslationService.translate(
                              context,
                              'setup_password_label',
                            ) ??
                            'Password',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock),
                        helperText:
                            TranslationService.translate(
                              context,
                              'leave_empty_no_password',
                            ) ??
                            'Leave empty for no password',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('setupConfirmPasswordField'),
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText:
                            TranslationService.translate(
                              context,
                              'setup_confirm_password',
                            ) ??
                            'Confirm Password',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outline),
                        errorText: _passwordError,
                      ),
                    ),
                  ],
                ),
                isActive: currentStep >= 3,
                state: currentStep > 3 ? StepState.complete : StepState.indexed,
              ),
              // Step 4: Finish
              Step(
                title: Text(strings['finish_title']!),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings['finish_header']!,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(strings['finish_body']!),
                  ],
                ),
                isActive: currentStep >= 4,
                state: currentStep == 4
                    ? StepState.complete
                    : StepState.indexed,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _finishSetup(
    BuildContext context,
    Map<String, String> strings,
  ) async {
    debugPrint('_finishSetup: Starting...');

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(child: CircularProgressIndicator()),
    );
    debugPrint('_finishSetup: Dialog shown');

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      debugPrint('_finishSetup: Got services');

      // 1. Setup Backend
      debugPrint('_finishSetup: Calling apiService.setup...');
      await apiService.setup(
        libraryName: themeProvider.setupLibraryName,
        profileType: themeProvider.setupProfileType,
        theme: themeProvider.themeStyle,
      );
      debugPrint('_finishSetup: apiService.setup completed');

      // 2. Import Demo Data if requested
      if (themeProvider.setupImportDemo) {
        debugPrint('_finishSetup: Importing demo data...');
        await DemoService.importDemoBooks(context);
        debugPrint('_finishSetup: Demo data imported');
      }

      debugPrint(
        '_finishSetup: Checking context.mounted (1): ${context.mounted}',
      );
      if (context.mounted) {
        // Close loading dialog FIRST to avoid build scope conflicts
        debugPrint('_finishSetup: Closing dialog...');
        Navigator.of(context).pop();
        debugPrint('_finishSetup: Dialog closed');

        // Wait for dialog animation to finish and frame to settle
        await Future.delayed(const Duration(milliseconds: 350));
        debugPrint('_finishSetup: Delay completed');

        // Only proceed if still mounted after delay
        debugPrint(
          '_finishSetup: Checking context.mounted (2): ${context.mounted}',
        );
        if (!context.mounted) return;

        // Use batch method to apply all settings with single notification
        // This is done AFTER dialog is fully closed to prevent dirty widget errors
        debugPrint('_finishSetup: Calling completeSetupWithSettings...');
        await themeProvider.completeSetupWithSettings(
          profileType: themeProvider.setupProfileType,
          avatarConfig: themeProvider.setupAvatarConfig,
          libraryName: themeProvider.setupLibraryName,
          apiService: apiService,
        );
        debugPrint('_finishSetup: completeSetupWithSettings done');

        if (!context.mounted) return;

        final authService = Provider.of<AuthService>(context, listen: false);

        // Save username from setup (default 'admin' if empty)
        final username = _usernameController.text.trim().isNotEmpty
            ? _usernameController.text.trim()
            : 'admin';
        await authService.saveUsername(username);
        debugPrint('_finishSetup: Username saved: $username');

        // Save password if provided
        if (_passwordController.text.isNotEmpty) {
          await authService.savePassword(_passwordController.text);
          debugPrint('_finishSetup: Password saved');
        }

        // Auto-login the user after setup (no need to go to login page)
        // In local mode, we just need a token to mark the user as logged in
        await authService.saveToken(
          'local-setup-token-${DateTime.now().millisecondsSinceEpoch}',
        );
        debugPrint('_finishSetup: User auto-logged in');

        debugPrint('_finishSetup: COMPLETE - Navigating to dashboard...');

        // Restart mDNS with correct library name (was started with default in main)
        if (themeProvider.networkDiscoveryEnabled) {
          try {
            await MdnsService.stop(); // Stop existing announcement
            final libraryUuid = await authService.getOrCreateLibraryUuid();
            await MdnsService.startAnnouncing(
              themeProvider.libraryName,
              ApiService.httpPort,
              libraryId: libraryUuid,
            );
            await MdnsService.startDiscovery();
            debugPrint(
              '_finishSetup: mDNS restarted with name: ${themeProvider.libraryName}',
            );
          } catch (e) {
            debugPrint('_finishSetup: mDNS restart failed: $e');
          }
        }

        // Navigate directly to dashboard since user is now logged in
        if (context.mounted) {
          GoRouter.of(context).go('/dashboard');
        }
      } else {
        debugPrint(
          '_finishSetup: ERROR - context not mounted after apiService.setup!',
        );
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) Navigator.of(context).pop();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${TranslationService.translate(context, 'setup_failed')}: $e',
            ),
          ),
        );
      }
    }
  }

  Widget _buildProfileOption(
    String value,
    String title,
    String description,
    IconData icon,
    ThemeProvider themeProvider, {
    Key? key,
  }) {
    final isSelected = themeProvider.setupProfileType == value;
    return GestureDetector(
      key: key,
      onTap: () => themeProvider.setSetupProfileType(value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withValues(alpha: 0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 32, color: isSelected ? Colors.blue : Colors.grey),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.blue : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle, color: Colors.blue),
          ],
        ),
      ),
    );
  }
}
