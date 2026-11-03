import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/models/user.dart';
import '../../core/providers.dart';

/// Status login. null = belum login. Saat aplikasi dibuka, token tersimpan
/// diperiksa lewat GET /me sebelum menentukan halaman awal.
class AuthController extends AsyncNotifier<User?> {
  ApiClient get _api => ref.read(apiClientProvider);

  @override
  Future<User?> build() async {
    final token = await ref.read(tokenStorageProvider).baca();
    if (token == null) return null;

    try {
      final body = await _api.get('/me');
      return User.dariJson((body['data'] as Map).cast());
    } on ApiException {
      // 401: token sudah dihapus ApiClient. Error jaringan: token disimpan
      // (bisa dipakai lagi saat online), tapi tampilkan login agar tidak macet.
      return null;
    }
  }

  /// [peran] pilihan "Masuk sebagai"; server menolak (403) bila tidak cocok dengan role akun.
  Future<void> login(String email, String password, {required String peran}) async {
    final body = await _api.post('/auth/login', data: {'email': email, 'password': password, 'device_name': 'android', 'role': peran});
    await _simpanSesi(body);
  }

  Future<void> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String alamat,
    required double lat,
    required double lng,
  }) async {
    final body = await _api.post('/auth/register', data: {
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
      'password_confirmation': password,
      'alamat': alamat,
      'lat': lat,
      'lng': lng,
      'device_name': 'android',
    });
    await _simpanSesi(body);
  }

  Future<void> _simpanSesi(Map<String, dynamic> body) async {
    final data = (body['data'] as Map).cast<String, dynamic>();
    await ref.read(tokenStorageProvider).simpan('${data['token']}');
    state = AsyncData(User.dariJson((data['user'] as Map).cast()));
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } on ApiException {
      // Tetap keluar walau server tidak bisa dihubungi
    }
    await ref.read(tokenStorageProvider).hapus();
    state = const AsyncData(null);
  }

  /// Dipanggil ApiClient saat menerima 401.
  void sesiBerakhir() {
    if (state.value != null) state = const AsyncData(null);
  }

  void perbarui(User user) => state = AsyncData(user);
}

final authProvider = AsyncNotifierProvider<AuthController, User?>(AuthController.new);
