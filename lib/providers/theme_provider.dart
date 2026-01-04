import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/avatars.dart';
import '../models/avatar_config.dart';
import '../services/api_service.dart';
import '../themes/base/theme_registry.dart';

class ThemeProvider with ChangeNotifier {
  Color _bannerColor = Colors.blue;
  bool _isSetupComplete = false;

  Color get bannerColor => _bannerColor;
  bool get isSetupComplete => _isSetupComplete;
  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  String _themeStyle = 'default';
  String get themeStyle => _themeStyle;

  String _currentAvatarId = 'individual';
  String get currentAvatarId => _currentAvatarId;

  AvatarConfig? _avatarConfig;
  AvatarConfig? get avatarConfig => _avatarConfig;

  // Profile type: 'librarian', 'individual', 'kid', 'bookseller'
  String _profileType = 'individual';
  String get profileType => _profileType;
  bool get isLibrarian =>
      _profileType == 'librarian' || _profileType == 'professional';
  bool get isBookseller =>
      _profileType == 'bookseller'; // New Bookseller profile
  bool get isKid => _profileType == 'kid';
  bool get hasReadingStatus =>
      _profileType == 'individual' || _profileType == 'kid';

  // New: Bookseller-specific modules
  bool get hasCommerce => isBookseller; // Commerce module (pricing) active
  bool get hasSales => isBookseller; // Sales/transactions module active
  bool get hasLoans =>
      !isBookseller; // Loans disabled by default for booksellers

  // Borrowing capability: disabled by default for librarians (they lend, not borrow)
  // Also disabled for booksellers (they sell, not borrow)
  bool _canBorrowBooks = true;
  bool get canBorrowBooks => _canBorrowBooks;

  // Gamification: disabled by default for librarians and booksellers
  bool _gamificationEnabled = true;
  bool get gamificationEnabled =>
      _gamificationEnabled && !isLibrarian && !isBookseller;

  ThemeData get themeData {
    // Initialize registry if needed
    ThemeRegistry.initialize();

    // Get theme from registry, fallback to default
    final theme = ThemeRegistry.get(_themeStyle) ?? ThemeRegistry.defaultTheme;
    return theme.buildTheme(accentColor: _bannerColor);
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt('bannerColor');
    if (colorValue != null) {
      _bannerColor = Color(colorValue);
    }
    _isSetupComplete = prefs.getBool('isSetupComplete') ?? false;
    _themeStyle = prefs.getString('themeStyle') ?? 'default';

    final languageCode = prefs.getString('languageCode');
    if (languageCode != null) {
      _locale = Locale(languageCode);
    } else {
      // Auto-detect system language on first launch
      final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
      final supportedLanguages = ['en', 'fr'];
      if (supportedLanguages.contains(systemLocale.languageCode)) {
        _locale = Locale(systemLocale.languageCode);
      } else {
        _locale = const Locale('en'); // Fallback to English
      }
    }

    _currentAvatarId = prefs.getString('avatarId') ?? 'individual';
    _profileType = prefs.getString('profileType') ?? 'individual';

    // Load borrowing capability setting (default based on profile type)
    final savedCanBorrow = prefs.getBool('canBorrowBooks');
    if (savedCanBorrow != null) {
      _canBorrowBooks = savedCanBorrow;
    } else {
      // Default: disabled for librarians (they lend, not borrow), enabled for others
      _canBorrowBooks = !isLibrarian;
    }

    // Load gamification setting (default based on profile type)
    final savedGamification = prefs.getBool('gamificationEnabled');
    if (savedGamification != null) {
      _gamificationEnabled = savedGamification;
    } else {
      // Default: disabled for librarians, enabled for others
      _gamificationEnabled = !isLibrarian;
    }

    final avatarConfigJson = prefs.getString('avatarConfig');
    if (avatarConfigJson != null) {
      try {
        _avatarConfig = AvatarConfig.fromJson(jsonDecode(avatarConfigJson));
      } catch (e) {
        debugPrint('Error loading avatar config: $e');
      }
    } else {
      _avatarConfig = AvatarConfig.defaultConfig;
    }

    _libraryName = prefs.getString('libraryName') ?? 'My Library';

    // If local pref is false, check with backend (in case it's a new device/browser)
    if (!_isSetupComplete) {
      try {
        // We need ApiService here, but it's not injected.
        // We'll rely on the caller to check or pass it, or we can't do it here easily without refactoring.
        // Actually, let's just default to false here, and let the UI handle the check.
        // Better yet, let's allow passing an optional checker callback or similar.
        // For now, let's leave it as is and fix it in main.dart or a splash screen.
      } catch (e) {
        // ignore
      }
    }
    notifyListeners();
  }

  Future<void> setBannerColor(Color color) async {
    _bannerColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bannerColor', color.value);
    notifyListeners();
  }

  Future<void> setThemeStyle(String style) async {
    _themeStyle = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeStyle', style);
    notifyListeners();
  }

  Future<void> setCanBorrowBooks(bool enabled) async {
    _canBorrowBooks = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('canBorrowBooks', enabled);
    notifyListeners();
  }

  Future<void> setGamificationEnabled(bool enabled) async {
    _gamificationEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('gamificationEnabled', enabled);
    notifyListeners();
  }

  Future<void> setProfileType(String type, {ApiService? apiService}) async {
    _profileType = type;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profileType', type);

    // Reset borrowing capability to profile-based default if not explicitly set
    final savedCanBorrow = prefs.getBool('canBorrowBooks');
    if (savedCanBorrow == null) {
      _canBorrowBooks = !isLibrarian;
    }

    notifyListeners();

    if (apiService != null) {
      try {
        await apiService.updateProfile(
          profileType: type,
          avatarConfig: _avatarConfig?.toJson(),
        );
      } catch (e) {
        debugPrint('Error syncing profile type: $e');
      }
    }
  }

  Future<void> setAvatarConfig(
    AvatarConfig config, {
    ApiService? apiService,
  }) async {
    _avatarConfig = config;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('avatarConfig', jsonEncode(config.toJson()));
    notifyListeners();

    if (apiService != null) {
      try {
        await apiService.updateProfile(
          profileType: _profileType,
          avatarConfig: config.toJson(),
        );
      } catch (e) {
        debugPrint('Error syncing avatar config: $e');
      }
    }
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', locale.languageCode);
    notifyListeners();
  }

  Future<void> setAvatarId(String avatarId) async {
    _currentAvatarId = avatarId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('avatarId', avatarId);

    // Auto-set theme color based on avatar
    final avatar = availableAvatars.firstWhere(
      (a) => a.id == avatarId,
      orElse: () => availableAvatars.first,
    );
    await setBannerColor(avatar.themeColor);

    notifyListeners();
  }

  /// Complete setup and apply all settings in one batch to avoid multiple rebuilds
  Future<void> completeSetupWithSettings({
    required String profileType,
    required AvatarConfig avatarConfig,
    required String libraryName,
    ApiService? apiService,
  }) async {
    // Apply all settings without notifying listeners individually
    _profileType = profileType;
    _avatarConfig = avatarConfig;
    _libraryName = libraryName;
    _isSetupComplete = true;

    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profileType', profileType);
    await prefs.setString('avatarConfig', jsonEncode(avatarConfig.toJson()));
    await prefs.setString('libraryName', libraryName);
    await prefs.setBool('isSetupComplete', true);

    // Sync with backend if ApiService provided
    if (apiService != null) {
      try {
        await apiService.updateProfile(
          profileType: profileType,
          avatarConfig: avatarConfig.toJson(),
        );
      } catch (e) {
        debugPrint('Error syncing profile during setup: $e');
      }
    }

    // Single notification at the end
    notifyListeners();
  }

  Future<void> completeSetup() async {
    _isSetupComplete = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isSetupComplete', true);
    notifyListeners();
  }

  Future<void> resetSetup() async {
    _isSetupComplete = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isSetupComplete');
    resetSetupState();
    notifyListeners();
  }

  // Library Name
  String _libraryName = 'My Library';
  String get libraryName => _libraryName;

  Future<void> setLibraryName(String name, {ApiService? apiService}) async {
    if (_libraryName == name) return;
    _libraryName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('libraryName', name);
    notifyListeners();

    // Sync with backend if ApiService provided
    if (apiService != null) {
      try {
        // We only update the name here, keeping other fields as is usually requires fetching them first
        // But for this simplified call, we assume the caller handles full update or we just update local state
        // In this architecture, usually screens call API then update Provider.
        // We'll leave the API call to the caller (ProfileScreen/Dashboard) for now to avoid circular dependencies or incomplete data updates.
      } catch (e) {
        debugPrint('Error syncing library name: $e');
      }
    }
  }

  // Setup Wizard State
  int _setupStep = 0;
  int get setupStep => _setupStep;
  String _setupLibraryName = 'My Library';
  String get setupLibraryName => _setupLibraryName;
  String _setupProfileType = 'individual';
  String get setupProfileType => _setupProfileType;
  AvatarConfig _setupAvatarConfig = AvatarConfig.defaultConfig;
  AvatarConfig get setupAvatarConfig => _setupAvatarConfig;
  bool _setupImportDemo = false;
  bool get setupImportDemo => _setupImportDemo;

  void setSetupStep(int step) {
    _setupStep = step;
    notifyListeners();
  }

  void setSetupLibraryName(String name) {
    _setupLibraryName = name;
    notifyListeners();
  }

  void setSetupProfileType(String type) {
    _setupProfileType = type;
    notifyListeners();
  }

  void setSetupAvatarConfig(AvatarConfig config) {
    _setupAvatarConfig = config;
    notifyListeners();
  }

  void setSetupImportDemo(bool import) {
    _setupImportDemo = import;
    notifyListeners();
  }

  void resetSetupState() {
    _setupStep = 0;
    _setupLibraryName = 'My Library';
    _setupProfileType = 'individual';
    _setupAvatarConfig = AvatarConfig.defaultConfig;
    _setupImportDemo = false;
    notifyListeners();
  }
}
