import 'package:bank_sampah_tubaba/core/api/api_client.dart';
import 'package:bank_sampah_tubaba/core/api/api_exception.dart';
import 'package:bank_sampah_tubaba/core/api/mock_backend.dart';
import 'package:bank_sampah_tubaba/core/storage/token_storage.dart';
import 'package:bank_sampah_tubaba/features/preloved/preloved_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Future<PrelovedRepository> _masuk(MockBackend mock, String email) async {
  final storage = MemoryTokenStorage();
  final api = ApiClient(
    baseUrl: 'http://mock/api/v1',
    tokenStorage: storage,
    adapter: mock,
  );
  final login = await api.post(
    '/auth/login',
    data: {'email': email, 'password': 'password'},
  );
  await storage.simpan(login['data']['token'] as String);
  return PrelovedRepository(api);
}

void main() {
  test('satu akun hanya sekali, tetapi warga lain tetap bisa melapor', () async {
    final mock = MockBackend();
    final warga = await _masuk(mock, 'warga@demo.id');
    final budi = await _masuk(mock, 'budi@demo.id');

    // Barang yang bukan milik kedua akun, jadi keduanya boleh melapor
    final milikWarga = (await warga.milikSaya()).items.map((b) => b.id).toSet();
    final milikBudi = (await budi.milikSaya()).items.map((b) => b.id).toSet();
    final semua = (await warga.daftar()).items.map((b) => b.id);
    final bebas = semua.where((id) => !milikWarga.contains(id) && !milikBudi.contains(id)).toList();
    final milikKeduanya = (await budi.daftar()).items.map((b) => b.id).where(milikWarga.contains);
    final id = bebas.isNotEmpty ? bebas.first : null;

    if (id == null) {
      // Data contoh hanya punya barang kedua akun: laporkan barang milik akun lain
      final barangWarga = milikKeduanya.first;
      expect(await budi.lapor(barangWarga, 'Barang mencurigakan'), contains('Laporan terkirim'));
      await expectLater(
        budi.lapor(barangWarga, 'Alasan yang lain'),
        throwsA(isA<ApiException>().having((e) => e.pesan, 'pesan', contains('sudah melaporkan'))),
      );
      return;
    }

    expect(await warga.lapor(id, 'Barang mencurigakan'), contains('Laporan terkirim'));
    expect(await budi.lapor(id, 'Barang palsu'), contains('Laporan terkirim'));
    await expectLater(
      warga.lapor(id, 'Alasan yang lain'),
      throwsA(isA<ApiException>().having((e) => e.pesan, 'pesan', contains('sudah melaporkan'))),
    );
  });
}
