import 'package:dio/dio.dart';

/// Kesalahan dari API dengan pesan Bahasa Indonesia yang siap ditampilkan.
class ApiException implements Exception {
  ApiException(this.pesan, {this.status, this.errors = const {}});

  final String pesan;
  final int? status;

  /// Pesan validasi pertama per field, mis. {'email': 'Email sudah terdaftar.'}
  final Map<String, String> errors;

  factory ApiException.dariDio(DioException e) {
    final res = e.response;

    if (res == null) {
      return ApiException(
        e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout
            ? 'Server tidak merespons. Coba lagi sebentar lagi.'
            : 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
      );
    }

    final body = res.data is Map ? res.data as Map : const {};
    final errors = <String, String>{};
    if (body['errors'] is Map) {
      (body['errors'] as Map).forEach((k, v) {
        if (v is List && v.isNotEmpty) errors['$k'] = '${v.first}';
      });
    }

    final pesanServer = body['pesan'] is String ? body['pesan'] as String : null;
    final pesan = switch (res.statusCode) {
      401 => pesanServer ?? 'Sesi berakhir. Silakan login kembali.',
      403 => pesanServer ?? 'Anda tidak memiliki akses ke fitur ini.',
      404 => 'Data tidak ditemukan.',
      // Untuk 422 tampilkan pesan validasi pertama agar lebih jelas di HP
      422 => errors.values.firstOrNull ?? pesanServer ?? 'Data yang dikirim tidak valid.',
      429 => pesanServer ?? 'Terlalu banyak permintaan. Coba lagi sebentar lagi.',
      _ => pesanServer ?? 'Terjadi kesalahan pada server.',
    };

    return ApiException(pesan, status: res.statusCode, errors: errors);
  }

  @override
  String toString() => pesan;
}
