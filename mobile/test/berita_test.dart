import 'package:bank_sampah_tubaba/core/api/api_client.dart';
import 'package:bank_sampah_tubaba/core/api/api_exception.dart';
import 'package:bank_sampah_tubaba/core/api/mock_backend.dart';
import 'package:bank_sampah_tubaba/core/format.dart';
import 'package:bank_sampah_tubaba/core/models/berita.dart';
import 'package:bank_sampah_tubaba/core/storage/token_storage.dart';
import 'package:bank_sampah_tubaba/core/theme.dart';
import 'package:bank_sampah_tubaba/features/berita/berita_pages.dart';
import 'package:bank_sampah_tubaba/features/berita/berita_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

BeritaRepository _repoMock() => BeritaRepository(
  ApiClient(
    baseUrl: 'http://mock/api/v1',
    tokenStorage: MemoryTokenStorage(),
    adapter: MockBackend(),
  ),
);

Berita _berita(int id, {String? isi}) => Berita(
  id: id,
  judul: 'Artikel $id dengan judul yang cukup panjang sampai lebih dari satu baris pada layar kecil',
  ringkasan: 'Ringkasan',
  isi: isi,
  kategori: 'pengumuman',
  foto: null,
  diterbitkanAt: DateTime.utc(2026, 11, 2),
  dibaca: 1200,
);

class _RepoPalsu implements BeritaRepository {
  _RepoPalsu({this.daftarBerita = const [], this.gagal = false, this.isi});

  final List<Berita> daftarBerita;
  final bool gagal;
  final String? isi;

  @override
  Future<Halaman<Berita>> daftar({String? q, int halaman = 1}) async {
    if (gagal) throw ApiException('Gagal memuat berita.');
    return Halaman(daftarBerita, halaman: halaman, halamanTerakhir: halaman, total: daftarBerita.length);
  }

  @override
  Future<Berita> detail(int id) async => _berita(id, isi: isi);
}

Widget _layar(Widget isi, BeritaRepository repo) => ProviderScope(
  overrides: [beritaRepositoryProvider.overrideWithValue(repo)],
  child: MaterialApp(theme: TemaAplikasi.terang(), home: isi),
);

void _layar360(WidgetTester tester) {
  tester.view.physicalSize = const Size(720, 1280);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('uraiIsiBerita', () {
    test('memisahkan paragraf, subjudul, dan kutipan seperti web', () {
      final blok = uraiIsiBerita(
        'Baris satu\nBaris dua\n\n## Subjudul\n\n> Kutipan satu\n> Kutipan dua\n\nPenutup',
      );

      expect(blok.map((b) => b.jenis), [
        JenisBlokBerita.paragraf,
        JenisBlokBerita.subjudul,
        JenisBlokBerita.kutipan,
        JenisBlokBerita.paragraf,
      ]);
      expect(blok[0].teks, 'Baris satu\nBaris dua');
      expect(blok[1].teks, 'Subjudul');
      expect(blok[2].teks, 'Kutipan satu\nKutipan dua');
    });

    test('isi kosong tidak menghasilkan blok', () {
      expect(uraiIsiBerita(null), isEmpty);
      expect(uraiIsiBerita(' \n\r\n '), isEmpty);
    });
  });

  group('repository', () {
    test('daftar tanpa isi, pencarian, dan detail menambah dibaca', () async {
      final repo = _repoMock();

      final semua = await repo.daftar();
      expect(semua.items, isNotEmpty);
      expect(semua.items.first.isi, isNull);

      final cari = await repo.daftar(q: 'DONASI');
      expect(cari.items, hasLength(1));
      expect(cari.items.single.judul, contains('Donasi'));

      final id = semua.items.first.id;
      final pertama = await repo.detail(id);
      final kedua = await repo.detail(id);
      expect(pertama.isi, isNotEmpty);
      expect(kedua.dibaca, pertama.dibaca + 1);
    });

    test('artikel yang tidak ada ditolak 404', () async {
      await expectLater(
        _repoMock().detail(9999),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
      );
    });
  });

  group('tampilan', () {
    testWidgets('beranda hanya menampilkan tiga artikel terbaru', (tester) async {
      _layar360(tester);
      final repo = _RepoPalsu(daftarBerita: [for (var i = 1; i <= 5; i++) _berita(i)]);
      await tester.pumpWidget(
        _layar(const Scaffold(body: SingleChildScrollView(child: BeritaBeranda())), repo),
      );
      await tester.pumpAndSettle();

      expect(find.text('Berita terbaru'), findsOneWidget);
      expect(find.byType(KartuBeritaRingkas), findsNWidgets(3));
      expect(find.byType(KartuBerita), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('kartu beranda muat untuk huruf besar dan bisa digeser', (tester) async {
      _layar360(tester);
      final repo = _RepoPalsu(daftarBerita: [for (var i = 1; i <= 3; i++) _berita(i)]);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(360, 800), textScaler: TextScaler.linear(1.4)),
          child: _layar(const Scaffold(body: SingleChildScrollView(child: BeritaBeranda())), repo),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final kartu = find.byType(KartuBeritaRingkas);
      final awal = tester.getTopLeft(kartu.first).dx;
      await tester.drag(find.byType(ListView).last, const Offset(-120, 0));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(kartu.first).dx, lessThan(awal));
    });

    test('waktu terbit ditulis ringkas', () {
      final kini = DateTime(2026, 11, 3, 10);
      expect(waktuLalu(null, sekarang: kini), '-');
      expect(waktuLalu(DateTime(2026, 11, 3, 8), sekarang: kini), 'Hari ini');
      expect(waktuLalu(DateTime(2026, 11, 2, 23), sekarang: kini), 'Kemarin');
      expect(waktuLalu(DateTime(2026, 10, 29), sekarang: kini), '5 hari lalu');
      expect(waktuLalu(DateTime(2026, 10, 20), sekarang: kini), '2 minggu lalu');
      expect(waktuLalu(DateTime(2026, 9, 1), sekarang: kini), isNot(contains('lalu')));
    });

    testWidgets('beranda menyembunyikan bagian bila belum ada artikel', (tester) async {
      await tester.pumpWidget(
        _layar(const Scaffold(body: BeritaBeranda()), _RepoPalsu()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Berita terbaru'), findsNothing);
    });

    testWidgets('kegagalan memuat hanya tampil di bagian berita', (tester) async {
      await tester.pumpWidget(
        _layar(
          const Scaffold(
            body: SingleChildScrollView(
              child: Column(children: [Text('Saldo tabungan'), BeritaBeranda()]),
            ),
          ),
          _RepoPalsu(gagal: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Saldo tabungan'), findsOneWidget);
      expect(find.text('Berita terbaru'), findsOneWidget);
      expect(find.textContaining('Gagal memuat berita'), findsOneWidget);
    });

    testWidgets('artikel menampilkan subjudul dan kutipan tanpa meluap di HP kecil', (tester) async {
      _layar360(tester);
      await tester.pumpWidget(
        _layar(
          const DetailBeritaPage(id: 1),
          _RepoPalsu(isi: 'Pembuka artikel\n\n## Subjudul artikel\n\n> Kutipan artikel\n\nPenutup artikel'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Subjudul artikel'), findsOneWidget);
      expect(find.text('Kutipan artikel'), findsOneWidget);
      expect(find.text('Penutup artikel'), findsOneWidget);
      expect(find.textContaining('1.200 dibaca'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
