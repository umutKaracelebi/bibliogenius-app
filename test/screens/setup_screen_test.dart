import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:bibliogenius/screens/setup_screen.dart';
import 'package:bibliogenius/providers/theme_provider.dart';
import 'package:bibliogenius/services/api_service.dart';
import 'package:bibliogenius/services/auth_service.dart';
import 'package:bibliogenius/themes/base/theme_registry.dart';

// ----------------------------------------------------------------------
// Mocks & Fakes
// ----------------------------------------------------------------------

class FakeApiService implements ApiService {
  @override
  final bool useFfi;

  FakeApiService({this.useFfi = false});

  @override
  Future<Response> setup({
    required String libraryName,
    String? libraryDescription,
    required String profileType,
    String? theme,
    double? latitude,
    double? longitude,
    bool? shareLocation,
  }) async {
    // Return a success response mimicking the real API
    return Response(
      requestOptions: RequestOptions(path: '/api/setup'),
      statusCode: 200,
      data: {'success': true, 'user_id': 123, 'library_id': 456},
    );
  }

  // Stub other required members to satisfy the interface or those used in SetupScreen indirectly
  // SetupScreen calls apiService.setup, passing `themeProvider.themeStyle` etc.

  // The 'updateProfile' method might be called by ThemeProvider if we were using the real implementation rigorously,
  // but SetupScreen calls apiService.setup directly.
  // ThemeProvider might call updateProfile in setProfileType, so let's mock it just in case.
  @override
  Future<Response> updateProfile({required Map<String, dynamic> data}) async {
    return Response(
      requestOptions: RequestOptions(path: '/api/profile'),
      statusCode: 200,
      data: {'success': true},
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    // This allows us to implement only the methods we need
    return super.noSuchMethod(invocation);
  }
}

class FakeAuthService implements AuthService {
  String? savedUsername;
  String? savedPassword;

  @override
  Future<void> saveUsername(String username) async {
    savedUsername = username;
  }

  @override
  Future<void> savePassword(String password) async {
    savedPassword = password;
  }

  @override
  Future<void> saveUserId(int id) async {}

  @override
  Future<void> saveLibraryId(int id) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

// ----------------------------------------------------------------------
// Tests
// ----------------------------------------------------------------------

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ThemeRegistry.initialize(); // Ensure themes are ready
  });

  testWidgets('SetupScreen navigation and validation test', (
    WidgetTester tester,
  ) async {
    // 1. Setup Dependencies
    final themeProvider = ThemeProvider();
    final fakeApiService = FakeApiService();
    final fakeAuthService = FakeAuthService();

    // 2. Pump Widget
    // Set a large screen size to avoid layout issues with the Stepper
    // Use 1.0 pixel ratio to avoid confusion with RenderView size
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          Provider<ApiService>.value(value: fakeApiService),
          Provider<AuthService>.value(value: fakeAuthService),
        ],
        child: MaterialApp(home: const SetupScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // ------------------------------------------------------------------
    // Step 0: Welcome
    // ------------------------------------------------------------------
    // Look for the welcome title (translated key: 'onboarding_welcome_title')
    // In test without proper locale setup, translations may return the key or null
    expect(find.byType(Stepper), findsOneWidget);

    // Tap Next
    final nextBtn0 = find.byKey(const Key('setupNextButton_0'));
    await tester.ensureVisible(nextBtn0);
    await tester.tap(nextBtn0);
    await tester.pumpAndSettle();

    // ------------------------------------------------------------------
    // Step 1: Library Info + Profile Selection
    // ------------------------------------------------------------------
    // Enter Library Name (first TextField in the step)
    final libraryNameField = find.byKey(const Key('setupLibraryNameField'));
    expect(libraryNameField, findsOneWidget);
    await tester.enterText(libraryNameField, 'Test Library');
    await tester.pumpAndSettle();

    // Select a profile (individual)
    final individualProfile = find.byKey(const Key('setupProfileIndividual'));
    if (individualProfile.evaluate().isNotEmpty) {
      await tester.tap(individualProfile);
      await tester.pumpAndSettle();
    }

    // Tap Next
    final nextBtn1 = find.byKey(const Key('setupNextButton_1'));
    await tester.ensureVisible(nextBtn1);
    await tester.tap(nextBtn1);
    // Use pump instead of pumpAndSettle to avoid timeouts if there are infinite animations
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // ------------------------------------------------------------------
    // Step 2: Demo Content
    // ------------------------------------------------------------------
    // Select "No, start empty" (the second radio option)
    final demoNoOption = find.byKey(const Key('setupDemoNo'));
    if (demoNoOption.evaluate().isNotEmpty) {
      await tester.tap(demoNoOption);
      await tester.pumpAndSettle();
    }

    final nextBtn2 = find.byKey(const Key('setupNextButton_2'));
    await tester.ensureVisible(nextBtn2);
    await tester.tap(nextBtn2);
    await tester.pumpAndSettle();

    // ------------------------------------------------------------------
    // Step 3: Credentials
    // ------------------------------------------------------------------
    // Verify inputs exist
    expect(find.byKey(const Key('setupUsernameField')), findsOneWidget);
    expect(find.byKey(const Key('setupPasswordField')), findsOneWidget);
    expect(find.byKey(const Key('setupConfirmPasswordField')), findsOneWidget);

    // Test Password Mismatch Validation
    await tester.enterText(
      find.byKey(const Key('setupPasswordField')),
      'password123',
    );
    await tester.enterText(
      find.byKey(const Key('setupConfirmPasswordField')),
      'mismatch',
    );
    await tester.pump();

    // Tap Next (should fail due to password mismatch)
    final nextBtn3 = find.byKey(const Key('setupNextButton_3'));
    await tester.ensureVisible(nextBtn3);
    await tester.tap(nextBtn3);
    await tester.pumpAndSettle();

    // Check for error message (translation key: 'passwords_do_not_match')
    // May show as 'Passwords do not match' or the translation key
    expect(
      find.textContaining('match', skipOffstage: false),
      findsAtLeastNWidgets(1),
    );

    // Fix Password
    await tester.enterText(
      find.byKey(const Key('setupConfirmPasswordField')),
      'password123',
    );
    await tester.pump();

    // Tap Next (should succeed)
    await tester.ensureVisible(nextBtn3);
    await tester.tap(nextBtn3);
    await tester.pumpAndSettle();

    // ------------------------------------------------------------------
    // Step 4: Finish
    // ------------------------------------------------------------------
    // Tap Finish
    final nextBtn4 = find.byKey(const Key('setupNextButton_4'));
    await tester.ensureVisible(nextBtn4);
    await tester.tap(nextBtn4);

    // Wait for the finish logic (async gaps, dialogs)
    await tester.pump(); // Dialog shows
    await tester.pump(const Duration(seconds: 1)); // Async work
    await tester.pumpAndSettle(); // Dialog closes, navigation happens

    // Verify AuthService saved credentials
    // Note: Default username in controller is 'admin' unless changed
    expect(fakeAuthService.savedUsername, 'admin');
    expect(fakeAuthService.savedPassword, 'password123');
  });
}
