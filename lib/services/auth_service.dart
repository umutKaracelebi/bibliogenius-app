import 'package:flutter_secure_storage/flutter_secure_storage.dart';


abstract class SecureStorageInterface {
  Future<void> write({required String key, required String? value});
  Future<String?> read({required String key});
  Future<void> delete({required String key});
}

class RealSecureStorage implements SecureStorageInterface {
  final _storage = const FlutterSecureStorage();
  @override
  Future<void> write({required String key, required String? value}) => _storage.write(key: key, value: value);
  @override
  Future<String?> read({required String key}) => _storage.read(key: key);
  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}

class MockSecureStorage implements SecureStorageInterface {
  final Map<String, String> _data = {};
  @override
  Future<void> write({required String key, required String? value}) async => _data[key] = value!;
  @override
  Future<String?> read({required String key}) async => _data[key];
  @override
  Future<void> delete({required String key}) async => _data.remove(key);
}

class AuthService {
  static SecureStorageInterface storage = RealSecureStorage();
  
  static const _tokenKey = 'auth_token';
  static const _usernameKey = 'username';
  static const _userIdKey = 'user_id';
  static const _libraryIdKey = 'library_id';

  Future<void> saveToken(String token) async {
    await storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await storage.read(key: _tokenKey);
  }

  Future<void> saveUsername(String username) async {
    await storage.write(key: _usernameKey, value: username);
  }

  Future<String?> getUsername() async {
    return await storage.read(key: _usernameKey);
  }

  Future<void> saveUserId(int id) async {
    await storage.write(key: _userIdKey, value: id.toString());
  }

  Future<int?> getUserId() async {
    final str = await storage.read(key: _userIdKey);
    return str != null ? int.tryParse(str) : null;
  }

  Future<void> saveLibraryId(int id) async {
    await storage.write(key: _libraryIdKey, value: id.toString());
  }

  Future<int?> getLibraryId() async {
    final str = await storage.read(key: _libraryIdKey);
    return str != null ? int.tryParse(str) : null;
  }

  Future<void> logout() async {
    await storage.delete(key: _tokenKey);
    await storage.delete(key: _usernameKey);
    await storage.delete(key: _userIdKey);
    await storage.delete(key: _libraryIdKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }
}
