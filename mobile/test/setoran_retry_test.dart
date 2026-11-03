import 'dart:convert';

import 'package:bank_sampah_tubaba/core/api/api_client.dart';
import 'package:bank_sampah_tubaba/core/api/api_exception.dart';
import 'package:bank_sampah_tubaba/core/api/mock_backend.dart';
import 'package:bank_sampah_tubaba/core/storage/token_storage.dart';
import 'package:bank_sampah_tubaba/core/models/bank_sampah.dart';
import 'package:bank_sampah_tubaba/core/models/transaksi.dart';
import 'package:bank_sampah_tubaba/core/models/user.dart';
import 'package:bank_sampah_tubaba/core/repositories.dart';
import 'package:bank_sampah_tubaba/core/theme.dart';
import 'package:bank_sampah_tubaba/features/auth/auth_controller.dart';
import 'package:bank_sampah_tubaba/features/bank_sampah/bs_providers.dart';
import 'package:bank_sampah_tubaba/features/bank_sampah/catat_setoran_page.dart';
import 'package:bank_sampah_tubaba/features/bank_sampah/permintaan_setoran.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

const _operator = User(
  id: 3,
  name: 'Operator',
  email: 'operator@test.id',
  role: Role.bankSampah,
  bankSampah: RingkasBank(id: 1, kode: 'BS-DEMO-01', nama: 'Bank uji'),
);
const _jemput = Penjemputan(
  id: 8,
  status: 'diambil',
  alamat: 'Alamat uji',
  lat: -4.58,
  lng: 105.13,
  warga: Kontak(id: 2, name: 'Budi'),
);

class _Auth extends AuthController {
  @override
  Future<User?> build() async => _operator;
}

/// Server sudah commit, tetapi respons pertama hilang di perjalanan.
class _Repo implements BankSampahRepository {
  final ids = <String?>[];
  final payloads = <List<(int, double)>>[];
  final tersimpan = <String?>{};
  int? galatStatus;
  @override
  Future<(Setoran, double)> catatSetoran({
    required int wargaId,
    required String tipe,
    required List<(int jenisId, double beratKg)> items,
    int? penjemputanId,
    String? catatan,
    String? requestId,
  }) async {
    ids.add(requestId);
    payloads.add(List.of(items));
    if (galatStatus != null) {
      throw ApiException(
        'Validasi gagal',
        status: galatStatus,
        errors: {'items': 'Berat tidak valid'},
      );
    }
    tersimpan.add(requestId);
    if (ids.length == 1) throw ApiException('Respons terputus');
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

class _StorageGagal extends PenyimpananSetoranMemori {
  @override
  Future<void> simpan(PermintaanSetoran data) async =>
      throw StateError('Penyimpanan gagal');
}

Widget _app(PenyimpananSetoran storage, _Repo repo) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => context.push('/catat'),
              child: const Text('Mulai setoran'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/catat',
        builder: (_, _) => const CatatSetoranPage(penjemputan: _jemput),
      ),
    ],
  );
  addTearDown(router.dispose);
  return ProviderScope(
    overrides: [
      authProvider.overrideWith(_Auth.new),
      penyimpananSetoranProvider.overrideWithValue(storage),
      bankSampahRepositoryProvider.overrideWithValue(repo),
      hargaBsProvider.overrideWith(
        (ref) async => [
          const Harga(jenisSampahId: 1, nama: 'Plastik', hargaPerKg: 3000),
        ],
      ),
    ],
    child: Consumer(
      builder: (context, ref, _) {
        if (!ref.watch(authProvider).hasValue) {
          return MaterialApp(
            theme: TemaAplikasi.terang(),
            home: const SizedBox(),
          );
        }
        return MaterialApp.router(
          theme: TemaAplikasi.terang(),
          routerConfig: router,
        );
      },
    ),
  );
}

Future<void> _buka(
  WidgetTester tester,
  PenyimpananSetoran storage,
  _Repo repo,
) async {
  await tester.pumpWidget(_app(storage, repo));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Mulai setoran'));
  await tester.pumpAndSettle();
}

Future<void> _isiDanSimpan(WidgetTester tester) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Berat'), '2');
  await tester.pump();
  await tester.tap(find.widgetWithText(FilledButton, 'Simpan & tambah saldo'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test(
    'repository mengirim ID; mock mengulang hasil tanpa menambah saldo lagi',
    () async {
      final storage = MemoryTokenStorage();
      final api = ApiClient(
        baseUrl: 'http://mock/api/v1',
        tokenStorage: storage,
        adapter: MockBackend(),
      );
      final login = await api.post(
        '/auth/login',
        data: {'email': 'operator@demo.id', 'password': 'password'},
      );
      await storage.simpan(login['data']['token'] as String);
      final repo = BankSampahRepository(api);
      final sebelum = await repo.setoran();
      const id = '94dc7ac7-a3fa-4d20-aacb-2825ec10b1d3';
      final a = await repo.catatSetoran(
        wargaId: 1,
        tipe: 'jual',
        items: [(6, 2)],
        requestId: id,
      );
      final b = await repo.catatSetoran(
        wargaId: 1,
        tipe: 'jual',
        items: [(6, 2)],
        requestId: id,
      );
      expect(a.$1.id, b.$1.id);
      expect(a.$2, 51000);
      expect(b.$2, 51000);
      await expectLater(
        repo.catatSetoran(
          wargaId: 1,
          tipe: 'jual',
          items: [(6, 3)],
          requestId: id,
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.errors.containsKey('request_id'),
            'ID konflik',
            true,
          ),
        ),
      );
      expect((await repo.setoran()).total, sebelum.total + 1);
      api.dio.close(force: true);
    },
  );

  testWidgets(
    'respons hilang: sesudah aplikasi dibuka ulang tetap memakai ID dan rincian yang sama',
    (tester) async {
      final storage = PenyimpananSetoranMemori();
      final repo = _Repo();
      await _buka(tester, storage, repo);
      await _isiDanSimpan(tester);
      expect(find.text('Setoran belum terkonfirmasi'), findsOneWidget);
      final pending = await storage.baca(3, 1);
      expect(pending, isNotNull);
      expect(repo.tersimpan.length, 1);

      await tester.pumpWidget(const SizedBox());
      await _buka(tester, storage, repo);
      expect(find.text('Setoran belum terkonfirmasi'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      await tester.tap(find.text('Cek ulang setoran'));
      await tester.pumpAndSettle();

      expect(repo.ids, [pending!.requestId, pending.requestId]);
      expect(repo.payloads, [
        [(1, 2.0)],
        [(1, 2.0)],
      ]);
      expect(repo.tersimpan.length, 1);
      expect(await storage.baca(3, 1), isNull);
      expect(find.text('Mulai setoran'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('jika penyimpanan perangkat gagal tidak ada request dikirim', (
    tester,
  ) async {
    final repo = _Repo();
    await _buka(tester, _StorageGagal(), repo);
    await _isiDanSimpan(tester);
    expect(repo.ids, isEmpty);
    expect(
      find.textContaining('Belum dapat menyimpan rincian setoran'),
      findsOneWidget,
    );
  });

  testWidgets(
    '422 yang memastikan gagal membuka kembali form untuk diperbaiki',
    (tester) async {
      final storage = PenyimpananSetoranMemori();
      final repo = _Repo()..galatStatus = 422;
      await _buka(tester, storage, repo);
      await _isiDanSimpan(tester);
      expect(await storage.baca(3, 1), isNull);
      expect(repo.tersimpan, isEmpty);
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Setoran belum terkonfirmasi'), findsNothing);
    },
  );

  test(
    'rincian diserialisasi utuh dan penyimpanan terpisah per operator/bank',
    () async {
      final p = PermintaanSetoran(
        requestId: PermintaanSetoran.idBaru(),
        operatorId: 3,
        bankId: 1,
        wargaId: 2,
        namaWarga: 'Budi',
        tipe: 'jual',
        items: [(1, 2.5)],
        penjemputanId: 8,
      );
      final pulih = PermintaanSetoran.dariJson(
        (jsonDecode(jsonEncode(p.toJson())) as Map).cast<String, dynamic>(),
      );
      expect(pulih.toJson(), p.toJson());
      expect(
        p.requestId,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(() => pulih.items.add((2, 1)), throwsUnsupportedError);
      final storage = PenyimpananSetoranMemori();
      await storage.simpan(pulih);
      expect(await storage.baca(3, 1), pulih);
      expect(await storage.baca(4, 1), isNull);
      expect(await storage.baca(3, 2), isNull);
    },
  );
}
