import 'package:bank_sampah_tubaba/core/api/api_client.dart';
import 'package:bank_sampah_tubaba/core/api/api_exception.dart';
import 'package:bank_sampah_tubaba/core/api/mock_backend.dart';
import 'package:bank_sampah_tubaba/core/storage/token_storage.dart';
import 'package:bank_sampah_tubaba/features/preloved/preloved_pages.dart';
import 'package:bank_sampah_tubaba/features/preloved/preloved_repository.dart';
import 'package:bank_sampah_tubaba/features/preloved/preloved_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<PrelovedRepository> _masuk(MockBackend mock, String email) async {
  final storage = MemoryTokenStorage();
  final api = ApiClient(baseUrl: 'http://mock/api/v1', tokenStorage: storage, adapter: mock);
  final login = await api.post('/auth/login', data: {'email': email, 'password': 'password'});
  await storage.simpan(login['data']['token'] as String);
  return PrelovedRepository(api);
}

Future<void> _pasang(WidgetTester tester, PrelovedRepository repo, Widget halaman) async {
  tester.view.physicalSize = const Size(780, 1600);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [prelovedRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(home: halaman),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test('favorit hanya untuk barang orang lain dan tersimpan sekali', () async {
    final mock = MockBackend();
    final warga = await _masuk(mock, 'warga@demo.id');
    final barang = (await warga.daftar()).items.firstWhere((b) => !b.milikSaya);
    final milikSendiri = (await warga.milikSaya()).items.first;

    final disimpan = await warga.favorit(barang.id, simpan: true);
    expect(disimpan.difavoritkan, isTrue);
    expect((await warga.favorit(barang.id, simpan: true)).jumlahFavorit, 1);
    expect((await warga.favoritSaya()).items.map((b) => b.id), [barang.id]);

    await expectLater(warga.favorit(milikSendiri.id, simpan: true), throwsA(isA<ApiException>()));

    expect((await warga.favorit(barang.id, simpan: false)).difavoritkan, isFalse);
    expect((await warga.favoritSaya()).items, isEmpty);
  });

  test('urutan termurah dan termahal mengikuti harga', () async {
    final warga = await _masuk(MockBackend(), 'warga@demo.id');
    final murah = (await warga.daftar(urut: 'termurah')).items.map((b) => b.harga).toList();
    final mahal = (await warga.daftar(urut: 'termahal')).items.map((b) => b.harga).toList();

    expect(murah, [...murah]..sort());
    expect(mahal, [...murah.reversed]);
  });

  testWidgets('tombol hati di kartu menyimpan barang dan muncul di halaman favorit', (tester) async {
    final repo = await tester.runAsync(() => _masuk(MockBackend(), 'warga@demo.id'));
    final barang = (await tester.runAsync(() => repo!.daftar()))!.items.firstWhere((b) => !b.milikSaya);

    final semantik = tester.ensureSemantics();
    await _pasang(tester, repo!, Scaffold(body: SizedBox(width: 200, height: 320, child: KartuBarang(barang: barang))));
    expect(find.bySemanticsLabel(RegExp('Simpan ke favorit')), findsOneWidget);
    semantik.dispose();

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    await _pasang(tester, repo, const FavoritPage());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text(barang.judul), findsOneWidget);
  });

  testWidgets('halaman cari dengan urutan termurah menaruh barang termurah di depan', (tester) async {
    final repo = await tester.runAsync(() => _masuk(MockBackend(), 'warga@demo.id'));
    final termurah = (await tester.runAsync(() => repo!.daftar(urut: 'termurah')))!.items.first;

    await _pasang(tester, repo!, const CariBarangPage(urut: 'termurah'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    expect(find.text('Termurah'), findsOneWidget);
    expect(find.text(termurah.judul).first, findsOneWidget);
    final judulPertama = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).whereType<String>().firstWhere((t) => t == termurah.judul, orElse: () => '');
    expect(judulPertama, termurah.judul);
  });
}
