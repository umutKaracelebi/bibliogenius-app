import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:app/screens/setup_screen.dart';
import 'package:app/providers/theme_provider.dart';
import 'package:app/services/api_service.dart';
import 'package:app/services/auth_service.dart';
import 'package:app/themes/base/theme_registry.dart';

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
  Future<Response> updateProfile({
    String? profileType,
    Map<String, dynamic>? avatarConfig,
  }) async {
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
    expect(find.text('Welcome to BiblioGenius!'), findsAtLeastNWidgets(1));
    expect(find.text('Next'), findsWidgets);

    // Tap Next
    final nextBtn0 = find.byKey(const Key('setupNextButton_0'));
    await tester.ensureVisible(nextBtn0);
    await tester.tap(nextBtn0);
    await tester.pumpAndSettle();

    // ------------------------------------------------------------------
    // Step 1: Library Info
    // ------------------------------------------------------------------
    expect(find.text('Library Name'), findsOneWidget);

    // Enter Library Name
    await tester.enterText(find.byType(TextField).first, 'Test Library');
    await tester.pumpAndSettle();

    // Tap Next
    final nextBtn1 = find.byKey(const Key('setupNextButton_1'));
    await tester.ensureVisible(nextBtn1);
    await tester.tap(nextBtn1);
    // Use pump instead of pumpAndSettle to avoid timeouts if there are infinite animations
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // ------------------------------------------------------------------
    // Step 2: Avatar (Customizer)
    // ------------------------------------------------------------------
    // Just verify we are on the avatar step (looking for title or widget)
    // SetupScreen uses dynamic translation for title, let's verify next button
    final nextBtn2 = find.byKey(const Key('setupNextButton_2'));
    await tester.ensureVisible(nextBtn2);
    await tester.tap(nextBtn2);
    await tester.pumpAndSettle();

    // ------------------------------------------------------------------
    // Step 3: Demo Content
    // ------------------------------------------------------------------
    expect(find.text('Start with some books?'), findsOneWidget);
    // Select "No, start empty"
    await tester.tap(find.text('No, start empty'));
    await tester.pumpAndSettle();

    final nextBtn3 = find.byKey(const Key('setupNextButton_3'));
    await tester.ensureVisible(nextBtn3);
    await tester.tap(nextBtn3);
    await tester.pumpAndSettle();

    // ------------------------------------------------------------------
    // Step 4: Language & Theme
    // ------------------------------------------------------------------
    expect(find.text('Select Language'), findsOneWidget);
    final nextBtn4 = find.byKey(const Key('setupNextButton_4'));
    await tester.ensureVisible(nextBtn4);
    await tester.tap(nextBtn4);
    await tester.pumpAndSettle();

    // ------------------------------------------------------------------
    // Step 5: Credentials
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

    // Tap Next (should fail)
    final nextBtn5 = find.byKey(const Key('setupNextButton_5'));
    await tester.ensureVisible(nextBtn5);
    await tester.tap(nextBtn5);
    await tester.pumpAndSettle();

    // Check for error message
    expect(find.text('Passwords do not match'), findsOneWidget);

    // Fix Password
    await tester.enterText(
      find.byKey(const Key('setupConfirmPasswordField')),
      'password123',
    );
    await tester.pump();

    // Tap Next (should succeed)
    await tester.ensureVisible(nextBtn5);
    await tester.tap(nextBtn5);
    await tester.pumpAndSettle();

    // ------------------------------------------------------------------
    // Step 6: Finish
    // ------------------------------------------------------------------
    expect(find.text('Ready to Go!'), findsOneWidget);
    expect(
      find.text('Finish'),
      findsWidgets,
    ); // Might be multiple if stepper renders all

    // Tap Finish
    final nextBtn6 = find.byKey(const Key('setupNextButton_6'));
    await tester.ensureVisible(nextBtn6);
    await tester.tap(nextBtn6);

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
