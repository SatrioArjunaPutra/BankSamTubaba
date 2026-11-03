import 'package:dio/dio.dart';

import '../storage/token_storage.dart';
import 'api_exception.dart';

/// Hasil daftar berhalaman: data + info halaman dari "meta".
class Halaman<T> {
  Halaman(this.items, {required this.halaman, required this.halamanTerakhir, required this.total});

  final List<T> items;
  final int halaman;
  final int halamanTerakhir;
  final int total;

  bool get adaBerikutnya => halaman < halamanTerakhir;
}

/// Klien HTTP ke /api/v1: header Bearer otomatis, error menjadi
/// [ApiException], dan 401 memanggil [onSesiBerakhir] (logout otomatis).
class ApiClient {
  ApiClient({
    required String baseUrl,
    required this.tokenStorage,
    HttpClientAdapter? adapter,
  }) : dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Accept': 'application/json'},
        )) {
    if (adapter != null) dio.httpClientAdapter = adapter;

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await tokenStorage.baca();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (e, handler) async {
        if (e.response?.statusCode == 401 && e.requestOptions.headers.containsKey('Authorization')) {
          await tokenStorage.hapus();
          onSesiBerakhir?.call();
        }
        handler.next(e);
      },
    ));
  }

  final Dio dio;
  final TokenStorage tokenStorage;
  void Function()? onSesiBerakhir;

  /// Body JSON lengkap ({status, pesan, data, meta?}).
  Future<Map<String, dynamic>> _kirim(Future<Response<dynamic>> Function() aksi) async {
    try {
      final res = await aksi();
      return (res.data as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw ApiException.dariDio(e);
    }
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) =>
      _kirim(() => dio.get(path, queryParameters: _bersihkan(query)));

  Future<Map<String, dynamic>> post(String path, {Object? data}) => _kirim(() => dio.post(path, data: data));

  Future<Map<String, dynamic>> put(String path, {Object? data}) => _kirim(() => dio.put(path, data: data));

  Future<Map<String, dynamic>> patch(String path, {Object? data}) => _kirim(() => dio.patch(path, data: data));

  Future<Map<String, dynamic>> delete(String path) => _kirim(() => dio.delete(path));

  /// GET daftar berhalaman (20/halaman) dan ubah tiap item dengan [dari].
  Future<Halaman<T>> daftar<T>(
    String path,
    T Function(Map<String, dynamic>) dari, {
    Map<String, dynamic>? query,
    int halaman = 1,
  }) async {
    final body = await get(path, query: {...?query, 'page': halaman});
    final meta = (body['meta'] as Map?) ?? const {};
    final items = (body['data'] as List).map((e) => dari((e as Map).cast<String, dynamic>())).toList();
    return Halaman(
      items,
      halaman: (meta['current_page'] as num?)?.toInt() ?? 1,
      halamanTerakhir: (meta['last_page'] as num?)?.toInt() ?? 1,
      total: (meta['total'] as num?)?.toInt() ?? items.length,
    );
  }

  /// GET yang "data"-nya list (tanpa paginasi).
  Future<List<T>> list<T>(String path, T Function(Map<String, dynamic>) dari, {Map<String, dynamic>? query}) async {
    final body = await get(path, query: query);
    return (body['data'] as List).map((e) => dari((e as Map).cast<String, dynamic>())).toList();
  }

  static Map<String, dynamic>? _bersihkan(Map<String, dynamic>? query) =>
      query == null ? null : (Map.of(query)..removeWhere((_, v) => v == null || v == ''));
}
