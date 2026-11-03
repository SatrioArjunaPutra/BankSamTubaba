import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/models/preloved.dart';
import '../../core/providers.dart';

class PrelovedRepository {
  PrelovedRepository(this._api);
  final ApiClient _api;

  BarangPreloved _barang(Map<String, dynamic> body) => BarangPreloved.dariJson((body['data'] as Map).cast());

  Future<Halaman<BarangPreloved>> daftar({String? q, String? kategori, String? kecamatan, int halaman = 1}) => _api.daftar(
        '/preloved',
        BarangPreloved.dariJson,
        query: {'q': q, 'kategori': kategori, 'kecamatan': kecamatan},
        halaman: halaman,
      );

  Future<Halaman<BarangPreloved>> milikSaya({int halaman = 1}) => _api.daftar('/preloved/saya', BarangPreloved.dariJson, halaman: halaman);

  Future<BarangPreloved> detail(int id) async => _barang(await _api.get('/preloved/$id'));

  /// Buat barang baru (multipart). [foto] = path file lokal, 1–5.
  Future<BarangPreloved> pasang(Map<String, Object> data, List<String> foto) async =>
      _barang(await _api.post('/preloved', data: await _form(data, foto)));

  /// Ubah barang. Jika [foto] tidak kosong, semua foto lama diganti.
  /// Multipart dikirim lewat POST + _method=PATCH (PHP tidak membaca multipart PATCH).
  Future<BarangPreloved> ubah(int id, Map<String, Object> data, List<String> foto) async {
    if (foto.isEmpty) return _barang(await _api.patch('/preloved/$id', data: data));
    return _barang(await _api.post('/preloved/$id', data: await _form({...data, '_method': 'PATCH'}, foto)));
  }

  Future<void> hapus(int id) => _api.delete('/preloved/$id');

  Future<BarangPreloved> tandaiTerjual(int id) async => _barang(await _api.post('/preloved/$id/terjual'));

  Future<String> lapor(int id, String alasan) async => '${(await _api.post('/preloved/$id/lapor', data: {'alasan': alasan}))['pesan']}';

  Future<Percakapan> bukaChat(int barangId) async =>
      Percakapan.dariJson(((await _api.post('/preloved/$barangId/chat'))['data'] as Map).cast());

  Future<Halaman<Percakapan>> daftarChat({int halaman = 1}) => _api.daftar('/chat', Percakapan.dariJson, halaman: halaman);

  /// Tanpa [afterId]: 50 pesan terakhir. Dengan [afterId]: hanya pesan baru (polling).
  Future<List<PesanChat>> pesan(int percakapanId, {int? afterId}) =>
      _api.list('/chat/$percakapanId/pesan', PesanChat.dariJson, query: {'after_id': afterId});

  Future<PesanChat> kirim(int percakapanId, {String? isi, double? tawaranHarga}) async => PesanChat.dariJson(
        ((await _api.post('/chat/$percakapanId/pesan', data: {'isi': ?isi, 'tawaran_harga': ?tawaranHarga}))['data'] as Map).cast(),
      );

  Future<void> tandaiDibaca(int percakapanId) => _api.post('/chat/$percakapanId/baca');

  // Disusun manual agar tiap file dikirim dengan key "foto[]" (Laravel → array)
  static Future<FormData> _form(Map<String, Object> data, List<String> foto) async {
    final form = FormData();
    data.forEach((k, v) => form.fields.add(MapEntry(k, '$v')));
    for (final p in foto) {
      form.files.add(MapEntry('foto[]', await MultipartFile.fromFile(p)));
    }
    return form;
  }
}

final prelovedRepositoryProvider = Provider((ref) => PrelovedRepository(ref.watch(apiClientProvider)));
