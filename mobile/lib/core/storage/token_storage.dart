import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Penyimpanan token login. Diabstraksikan agar test & mode mock tidak
/// bergantung pada keystore perangkat.
abstract class TokenStorage {
  Future<String?> baca();
  Future<void> simpan(String token);
  Future<void> hapus();
}

class SecureTokenStorage implements TokenStorage {
  static const _kunci = 'token_bank_sampah';
  final _storage = const FlutterSecureStorage();

  @override
  Future<String?> baca() => _storage.read(key: _kunci);

  @override
  Future<void> simpan(String token) => _storage.write(key: _kunci, value: token);

  @override
  Future<void> hapus() => _storage.delete(key: _kunci);
}

class MemoryTokenStorage implements TokenStorage {
  MemoryTokenStorage([this._token]);

  String? _token;

  @override
  Future<String?> baca() async => _token;

  @override
  Future<void> simpan(String token) async => _token = token;

  @override
  Future<void> hapus() async => _token = null;
}
