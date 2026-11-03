import 'package:bank_sampah_tubaba/core/api/api_client.dart';
import 'package:bank_sampah_tubaba/core/api/api_exception.dart';
import 'package:bank_sampah_tubaba/core/api/mock_backend.dart';
import 'package:bank_sampah_tubaba/core/models/bank_sampah.dart';
import 'package:bank_sampah_tubaba/core/models/transaksi.dart';
import 'package:bank_sampah_tubaba/core/models/user.dart';
import 'package:bank_sampah_tubaba/core/repositories.dart';
import 'package:bank_sampah_tubaba/core/storage/token_storage.dart';
import 'package:bank_sampah_tubaba/core/theme.dart';
import 'package:bank_sampah_tubaba/features/auth/auth_controller.dart';
import 'package:bank_sampah_tubaba/features/bank_sampah/bs_providers.dart';
import 'package:bank_sampah_tubaba/features/bank_sampah/catat_setoran_page.dart';
import 'package:bank_sampah_tubaba/features/bank_sampah/permintaan_setoran.dart';
import 'package:bank_sampah_tubaba/features/warga/warga_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

const _bentor = User(
  id: 4,
  name: 'Pak Bentor',
  email: 'bentor@test.id',
  role: Role.bentor,
  bankSampah: RingkasBank(id: 1, kode: 'BS-DEMO-01', nama: 'Bank uji'),
);
const _tugas = Penjemputan(
  id: 8,
  status: 'diambil',
  alamat: 'Alamat uji',
  lat: -4.58,
  lng: 105.13,
  warga: Kontak(id: 2, name: 'Budi'),
);

class _Auth extends AuthController {
  @override
  Future<User?> build() async => _bentor;
}

class _RepoBentor implements BentorRepository {
  final tugasId = <int>[];
  final tipe = <String>[];
  final permintaan = <String?>[];

  @override
  Future<(Setoran, double)> catatSetoranTugas({
    required int tugasId,
    required String tipe,
    required List<(int jenisId, double beratKg)> items,
    String? requestId,
  }) async {
    this.tugasId.add(tugasId);
    this.tipe.add(tipe);
    permintaan.add(requestId);
    return (
      const Setoran(
        id: 10,
        tipe: 'jual',
        totalKg: 2,
        totalNilai: 6000,
        createdAt: null,
      ),
      6000.0,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RepoOperator implements BankSampahRepository {
  int dipanggil = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    dipanggil++;
    return super.noSuchMethod(invocation);
  }
}

Future<(ApiClient, MemoryTokenStorage)> _masuk(String email) async {
  final storage = MemoryTokenStorage();
  final api = ApiClient(
    baseUrl: 'http://mock/api/v1',
    tokenStorage: storage,
    adapter: _mock,
  );
  final login = await api.post(
    '/auth/login',
    data: {'email': email, 'password': 'password'},
  );
  await storage.simpan(login['data']['token'] as String);
  return (api, storage);
}

late MockBackend _mock;

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));
  setUp(() => _mock = MockBackend());

  Future<Penjemputan> tugasDiambil(BentorRepository repo) async {
    var t = (await repo.tugas(status: 'dijadwalkan,menuju,diambil')).items.first;
    if (t.status == 'dijadwalkan') t = await repo.ubahStatusTugas(t.id, 'menuju');
    if (t.status == 'menuju') t = await repo.ubahStatusTugas(t.id, 'diambil');
    return t;
  }

  test('alur mock: bentor menimbang, kirim ulang aman, operator membatalkan', () async {
    final (apiBentor, _) = await _masuk('bentor@demo.id');
    final (apiOperator, _) = await _masuk('operator@demo.id');
    final bentor = BentorRepository(apiBentor);
    final operator = BankSampahRepository(apiOperator);
    final tugas = await tugasDiambil(bentor);
    const id = '94dc7ac7-a3fa-4d20-aacb-2825ec10b1d4';

    final sebelum = (await operator.setoran()).total;
    final a = await bentor.catatSetoranTugas(
      tugasId: tugas.id,
      tipe: 'jual',
      items: [(6, 2)],
      requestId: id,
    );
    final ulang = await bentor.catatSetoranTugas(
      tugasId: tugas.id,
      tipe: 'jual',
      items: [(6, 2)],
      requestId: id,
    );
    expect(ulang.$1.id, a.$1.id);
    expect(ulang.$2, a.$2);
    expect((await operator.setoran()).total, sebelum + 1);

    // Tugas sudah selesai: timbang baru ditolak
    await expectLater(
      bentor.catatSetoranTugas(tugasId: tugas.id, tipe: 'jual', items: [(6, 1)]),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 422)),
    );

    final batal = await operator.batalkanSetoran(a.$1.id, 'Salah timbang');
    expect(batal.dibatalkan, isTrue);
    expect(batal.alasanBatal, 'Salah timbang');
    await expectLater(
      operator.batalkanSetoran(a.$1.id, 'Salah timbang'),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 422)),
    );
    final riwayat = (await operator.setoran()).items.first;
    expect(riwayat.dibatalkan, isTrue);

    apiBentor.dio.close(force: true);
    apiOperator.dio.close(force: true);
  });

  testWidgets('bentor mengirim hasil timbang ke tugasnya, bukan rute operator', (tester) async {
    final repo = _RepoBentor();
    final operator = _RepoOperator();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => context.push('/timbang'),
                child: const Text('Mulai'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/timbang',
          builder: (_, _) => const CatatSetoranPage(penjemputan: _tugas, olehBentor: true),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_Auth.new),
          penyimpananSetoranProvider.overrideWithValue(PenyimpananSetoranMemori()),
          bentorRepositoryProvider.overrideWithValue(repo),
          bankSampahRepositoryProvider.overrideWithValue(operator),
          hargaBankProvider(1).overrideWith(
            (ref) async => [const Harga(jenisSampahId: 1, nama: 'Plastik', hargaPerKg: 3000)],
          ),
        ],
        child: Consumer(
          builder: (context, ref, _) => ref.watch(authProvider).hasValue
              ? MaterialApp.router(theme: TemaAplikasi.terang(), routerConfig: router)
              : const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mulai'));
    await tester.pumpAndSettle();

    expect(find.text('Timbang sampah'), findsOneWidget);
    expect(find.textContaining('Budi'), findsWidgets);
    expect(find.text('Ganti'), findsNothing);

    await tester.enterText(find.byType(TextFormField).first, '2');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
    await tester.pumpAndSettle();

    expect(repo.tugasId, [8]);
    expect(repo.tipe, ['jual']);
    expect(repo.permintaan.single, isNotNull);
    expect(operator.dipanggil, 0);
    expect(find.text('Mulai'), findsOneWidget);
  });

  testWidgets('riwayat menandai setoran batal; tombol batal hanya untuk yang berlaku', (tester) async {
    final batal = Setoran(
      id: 1,
      tipe: 'jual',
      totalKg: 2,
      totalNilai: 6000,
      createdAt: null,
      dibatalkanAt: DateTime(2026, 11, 2),
      alasanBatal: 'Salah timbang',
    );
    const berlaku = Setoran(id: 2, tipe: 'jual', totalKg: 2, totalNilai: 6000, createdAt: null);
    await tester.pumpWidget(
      MaterialApp(
        theme: TemaAplikasi.terang(),
        home: Scaffold(
          body: ListView(
            children: [
              KartuSetoran(setoran: batal, onBatalkan: () {}),
              KartuSetoran(setoran: berlaku, onBatalkan: () {}),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Dibatalkan'), findsOneWidget);

    await tester.tap(find.text('Dibatalkan'));
    await tester.pumpAndSettle();
    expect(find.text('Salah timbang'), findsOneWidget);
    expect(find.text('Batalkan setoran'), findsNothing);

    await tester.tap(find.text('+Rp 6.000').first);
    await tester.pumpAndSettle();
    expect(find.text('Batalkan setoran'), findsOneWidget);
  });
}
