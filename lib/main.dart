import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/sync_service.dart';
import 'services/translation_service.dart';
import 'services/mdns_service.dart';
import 'services/ffi_service.dart';
import 'utils/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/theme_provider.dart';
import 'audio/audio_module.dart'; // Audio module (decoupled)
import 'screens/login_screen.dart';
import 'screens/book_list_screen.dart';
import 'screens/add_book_screen.dart';
import 'screens/book_copies_screen.dart';
import 'screens/book_details_screen.dart';
import 'screens/edit_book_screen.dart';
import 'screens/add_contact_screen.dart';
import 'screens/contact_details_screen.dart';
import 'models/book.dart';
import 'models/contact.dart';
import 'screens/scan_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/setup_screen.dart';

import 'screens/borrow_requests_screen.dart';
import 'screens/peer_book_list_screen.dart';
import 'screens/shelf_management_screen.dart';
import 'screens/search_peer_screen.dart';
import 'screens/genie_chat_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/help_screen.dart';
import 'screens/network_search_screen.dart';
import 'screens/onboarding_tour_screen.dart';
import 'screens/shelves_screen.dart';
import 'screens/network_screen.dart';
import 'screens/feedback_screen.dart';

import 'screens/link_device_screen.dart';
import 'screens/collection/collection_list_screen.dart'; // Collection module
import 'screens/collection/import_from_search_screen.dart';
import 'services/wizard_service.dart';
import 'widgets/scaffold_with_nav.dart';

import 'package:flutter/gestures.dart';

// FFI imports for native platforms
import 'src/rust/frb_generated.dart';
import 'src/rust/api/frb.dart' as frb;

import 'screens/collection/collection_detail_screen.dart';
import 'models/collection.dart';

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };
}

void main([List<String>? args]) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Custom error widget to display errors visibly for debugging
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.red.shade50,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '⚠️ Error',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  details.exception.toString(),
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                Text(
                  details.stack?.toString() ?? 'No stack trace',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.black54,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('No .env file found, using default configuration');
  }
  await TranslationService.loadFromCache();
  final themeProvider = ThemeProvider();

  // Load settings early so library name is available for mDNS
  try {
    await themeProvider.loadSettings();
    // Initialize feature flags
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('enableHierarchicalTags')) {
      AppConstants.enableHierarchicalTags =
          prefs.getBool('enableHierarchicalTags') ?? true;
    }
  } catch (e) {
    debugPrint('Error loading settings early: $e');
  }

  // Initialize FFI for native platforms
  bool useFfi = false;

  if (!kIsWeb) {
    // FFI enabled for all native platforms (macOS, iOS, Android, Linux, Windows)
    try {
      debugPrint('FFI: Starting RustLib.init()...');
      // Initialize Flutter-Rust bridge
      // On iOS/macOS, the library is statically linked, so use DynamicLibrary.process()
      // On Android/Linux/Windows, load the dynamic library from the bundle
      if (Platform.isIOS || Platform.isMacOS) {
        debugPrint('FFI: Using DynamicLibrary.process() for iOS/macOS...');
        await RustLib.init(
          externalLibrary: ExternalLibrary.process(iKnowHowToUseIt: true),
        );
      } else {
        await RustLib.init();
      }
      debugPrint('FFI: RustLib.init() succeeded');

      // Get database path
      debugPrint('FFI: Getting application documents directory...');
      final appDocDir = await getApplicationDocumentsDirectory();
      final dbPath = '${appDocDir.path}/bibliogenius.db';
      debugPrint('FFI: Database path: $dbPath');

      // Initialize Rust backend with database
      debugPrint('FFI: Calling initBackend...');
      final result = await frb.initBackend(dbPath: dbPath);
      debugPrint('FFI Backend initialized: $result');
      useFfi = true;
      debugPrint('FFI: useFfi set to TRUE');

      int httpPort = 8000;
      try {
        final startedPort = await FfiService().startServer(8000);
        if (startedPort != null) {
          httpPort = startedPort;
          ApiService.setHttpPort(httpPort); // Store the actual port globally
          debugPrint('FFI: HTTP server confirmed running on port $httpPort');
        }
      } catch (e) {
        debugPrint('FFI: Failed to start HTTP server: $e');
      }

      // Auto-initialize mDNS for local network discovery (Native Bonjour)
      // This makes the app discoverable on the local WiFi network
      // Only start if user has enabled network discovery in settings
      if (themeProvider.networkDiscoveryEnabled) {
        try {
          final authService = AuthService();
          final libraryUuid = await authService.getOrCreateLibraryUuid();
          final libraryName = themeProvider.libraryName.isNotEmpty
              ? themeProvider.libraryName
              : 'BiblioGenius Library';
          await MdnsService.startAnnouncing(
            libraryName,
            httpPort,
            libraryId: libraryUuid,
          );
          await MdnsService.startDiscovery();
        } catch (mdnsError) {
          debugPrint('mDNS: Init failed (non-blocking): $mdnsError');
        }
      } else {
        debugPrint('mDNS: Disabled by user preference');
      }
    } catch (e, stackTrace) {
      debugPrint('FFI initialization failed: $e');
      debugPrint('FFI stack trace: $stackTrace');
      // FFI initialization failed, will fall back to configured HTTP URL or default
    }
  }

  // Settings already loaded earlier, no need to call again

  runApp(MyApp(themeProvider: themeProvider, useFfi: useFfi));
}

class MyApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  final bool useFfi;

  const MyApp({super.key, required this.themeProvider, required this.useFfi});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    // Determine base URL for HTTP mode (web or fallback)
    String baseUrl = dotenv.env['API_BASE_URL'] ?? '';

    if (useFfi) {
      // FFI mode: no HTTP needed for local operations
      baseUrl = 'ffi://local'; // Placeholder, ApiService will detect FFI mode
      debugPrint('Using FFI mode for local database operations');
    } else if (baseUrl.isNotEmpty) {
      debugPrint('Using API_BASE_URL from .env: $baseUrl');
    } else {
      baseUrl = ApiService.defaultBaseUrl;
      debugPrint('Using Default Backend URL: $baseUrl');
    }

    final apiService = ApiService(
      authService,
      baseUrl: baseUrl,
      useFfi: useFfi,
    );

    Widget app = MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        Provider<AuthService>.value(value: authService),
        Provider<ApiService>.value(value: apiService),
        Provider<SyncService>(create: (_) => SyncService(apiService)),
        // Audio module (decoupled, can be removed without breaking the app)
        ChangeNotifierProvider<AudioProvider>(create: (_) => AudioProvider()),
      ],
      child: const AppRouter(),
    );

    return app;
  }
}

class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    _router = GoRouter(
      initialLocation: '/dashboard',
      refreshListenable: themeProvider,
      redirect: (context, state) async {
        final isSetup = themeProvider.isSetupComplete;
        final isSetupRoute = state.uri.path == '/setup';
        final isOnboardingRoute = state.uri.path == '/onboarding';
        final isLoginRoute = state.uri.path == '/login';

        // 1. Setup check - if not setup complete, only allow /setup route
        if (!isSetup && !isSetupRoute) return '/setup';

        // 2. If currently on setup route, skip all other checks (allow wizard to complete)
        if (isSetupRoute) return null;

        // 3. Auth check (only for non-setup routes)
        final authService = Provider.of<AuthService>(context, listen: false);
        final isLoggedIn = await authService.isLoggedIn();

        if (!isLoggedIn) {
          if (isLoginRoute) return null; // Allow access to login
          if (isOnboardingRoute) return null; // Allow onboarding
          return '/login';
        }

        // 3. Logged in user trying to access login
        if (isLoggedIn && isLoginRoute) {
          return '/dashboard';
        }

        // 4. Onboarding check (only if logged in or allowed)
        if (isLoggedIn && state.uri.path == '/dashboard') {
          // Check if user has seen tour only if going to dashboard root?
          // Original logic checked it when redirecting FROM setup.
          final hasSeenTour = await WizardService.hasSeenOnboardingTour();
          if (!hasSeenTour) return '/onboarding';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/setup',
          builder: (context, state) => const SetupScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingTourScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/genie-chat',
          builder: (context, state) => const GenieChatScreen(),
        ),
        GoRoute(
          path: '/shelves-management',
          builder: (context, state) => const ShelfManagementScreen(),
        ),
        ShellRoute(
          builder: (context, state, child) {
            return ScaffoldWithNav(child: child);
          },
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardScreen(),
            ),
            GoRoute(
              path: '/books',
              builder: (context, state) => const BookListScreen(),
              routes: [
                GoRoute(
                  path: 'add',
                  builder: (context, state) {
                    final extra = state.extra as Map<String, dynamic>?;
                    final queryParams = state.uri.queryParameters;

                    final isbn = extra?['isbn'] ?? queryParams['isbn'];

                    final collectionIdStr =
                        extra?['collectionId']?.toString() ??
                        queryParams['collectionId'];
                    final preSelectedCollectionId = collectionIdStr != null
                        ? int.tryParse(collectionIdStr)
                        : null;

                    final preSelectedShelfId =
                        extra?['shelfId'] ?? queryParams['shelfId'];

                    return AddBookScreen(
                      isbn: isbn,
                      preSelectedCollectionId: preSelectedCollectionId,
                      preSelectedShelfId: preSelectedShelfId,
                    );
                  },
                ),
                GoRoute(
                  path: ':id',
                  builder: (context, state) {
                    final bookId =
                        int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                    Book? book;
                    if (state.extra is Book) {
                      book = state.extra as Book;
                    } else if (state.extra is Map<String, dynamic>) {
                      book = Book.fromJson(state.extra as Map<String, dynamic>);
                    }
                    return BookDetailsScreen(bookId: bookId, book: book);
                  },
                ),
                GoRoute(
                  path: ':id/edit',
                  builder: (context, state) {
                    Book? book;
                    if (state.extra is Book) {
                      book = state.extra as Book;
                    } else if (state.extra is Map<String, dynamic>) {
                      book = Book.fromJson(state.extra as Map<String, dynamic>);
                    }
                    /* WARNING: EditBookScreen currently REQUIRES a Book object. 
                       If deep linking support is needed here, EditBookScreen must also be refactored 
                       to fetch by ID, similar to BookDetailsScreen. 
                       For now, this remains a risk if navigated to directly without extra. */
                    if (book == null) {
                      // Fallback or error screen could be returned here ideally
                      // For now we assume typical navigation flow or let it throw/show error
                      // But to prevent hard crash let's redirect or show details if possible?
                      // Actually EditBookScreen constructor requires 'book'.
                      throw Exception(
                        'Direct navigation to edit not fully supported without object properly passed yet. Please go via details.',
                      );
                    }
                    return EditBookScreen(book: book);
                  },
                ),
                GoRoute(
                  path: ':id/copies',
                  builder: (context, state) {
                    final bookId =
                        int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                    final extra = state.extra as Map<String, dynamic>?;
                    final bookTitle = extra?['bookTitle'] as String? ?? '';
                    return BookCopiesScreen(
                      bookId: bookId,
                      bookTitle: bookTitle,
                    );
                  },
                ),
              ],
            ),
            // External search - inside ShellRoute for hamburger menu access
            GoRoute(
              path: '/search/external',
              builder: (context, state) => const ImportFromSearchScreen(),
            ),
            GoRoute(
              path: '/network',
              builder: (context, state) => const NetworkScreen(),
              routes: [
                GoRoute(
                  path: 'contact/:id',
                  builder: (context, state) {
                    final contact = state.extra as Contact?;
                    if (contact != null) {
                      return ContactDetailsScreen(contact: contact);
                    }
                    return const NetworkScreen();
                  },
                ),
              ],
            ),
            GoRoute(
              path: '/contacts',
              redirect: (context, state) {
                if (state.uri.path == '/contacts') {
                  return '/network';
                }
                return null;
              },
              builder: (context, state) => const NetworkScreen(),
              routes: [
                GoRoute(
                  path: 'add',
                  builder: (context, state) => const AddContactScreen(),
                ),
                GoRoute(
                  path: ':id',
                  builder: (context, state) {
                    final contact = state.extra as Contact?;
                    if (contact != null) {
                      return ContactDetailsScreen(contact: contact);
                    }
                    return const NetworkScreen();
                  },
                ),
              ],
            ),
            GoRoute(
              path: '/scan',
              builder: (context, state) {
                // Support batch mode with pre-selected destination
                final shelfId = state.uri.queryParameters['shelfId'];
                final shelfName = state.uri.queryParameters['shelfName'];
                final collectionIdStr =
                    state.uri.queryParameters['collectionId'];
                final collectionName =
                    state.uri.queryParameters['collectionName'];
                final batch = state.uri.queryParameters['batch'] == 'true';

                return ScanScreen(
                  preSelectedShelfId: shelfId,
                  preSelectedShelfName: shelfName,
                  preSelectedCollectionId: collectionIdStr != null
                      ? int.tryParse(collectionIdStr)
                      : null,
                  preSelectedCollectionName: collectionName,
                  batchMode: batch,
                );
              },
            ),
            GoRoute(path: '/p2p', redirect: (context, state) => '/network'),
            GoRoute(
              path: '/requests',
              builder: (context, state) => const BorrowRequestsScreen(),
            ),
            GoRoute(
              path: '/profile',
              builder: (context, state) {
                final action = state.uri.queryParameters['action'];
                return ProfileScreen(initialAction: action);
              },
              routes: [
                GoRoute(
                  path: 'link-device',
                  builder: (context, state) => const LinkDeviceScreen(),
                ),
              ],
            ),
            GoRoute(
              path: '/peers',
              builder: (context, state) =>
                  const NetworkScreen(), // Fallback to network
              routes: [
                GoRoute(
                  path: ':id/books',
                  builder: (context, state) {
                    final peer = state.extra as Map<String, dynamic>;
                    return PeerBookListScreen(
                      peerId: peer['id'],
                      peerName: peer['name'],
                      peerUrl: peer['url'],
                    );
                  },
                ),
                GoRoute(
                  path: 'search',
                  builder: (context, state) => const SearchPeerScreen(),
                ),
              ],
            ),
            GoRoute(
              path: '/statistics',
              builder: (context, state) => const StatisticsScreen(),
            ),
            GoRoute(
              path: '/help',
              builder: (context, state) => const HelpScreen(),
            ),
            GoRoute(
              path: '/network-search',
              builder: (context, state) => const NetworkSearchScreen(),
            ),
            GoRoute(
              path: '/shelves',
              builder: (context, state) => const ShelvesScreen(),
            ),
            GoRoute(
              path: '/feedback',
              builder: (context, state) => const FeedbackScreen(),
            ),
            GoRoute(
              path: '/collections',
              builder: (context, state) => const CollectionListScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) {
                    final collection = state.extra as Collection;
                    return CollectionDetailScreen(collection: collection);
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp.router(
      // Force complete widget tree rebuild when theme changes to avoid
      // TextStyle.lerp errors with AnimatedDefaultTextStyle during transitions
      key: ValueKey(themeProvider.themeStyle),
      title: 'BiblioGenius',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.themeData,
      // Disable theme animation to prevent TextStyle.lerp errors when switching between
      // themes with different inherit values (e.g., Sorbonne vs Default)
      themeAnimationDuration: Duration.zero,
      themeAnimationStyle: AnimationStyle.noAnimation,
      locale: themeProvider.locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('fr'),
        Locale('es'),
        Locale('de'),
      ],
      scrollBehavior: AppScrollBehavior(),
      routerConfig: _router,
    );
  }
}
