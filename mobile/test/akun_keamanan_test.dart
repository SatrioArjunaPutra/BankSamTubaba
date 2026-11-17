import 'package:bank_sampah_tubaba/core/api/api_client.dart';
import 'package:bank_sampah_tubaba/core/api/mock_backend.dart';
import 'package:bank_sampah_tubaba/core/komponen_ui.dart';
import 'package:bank_sampah_tubaba/core/models/user.dart';
import 'package:bank_sampah_tubaba/core/providers.dart';
import 'package:bank_sampah_tubaba/core/router.dart';
import 'package:bank_sampah_tubaba/core/storage/token_storage.dart';
import 'package:bank_sampah_tubaba/features/warga/warga_shell.dart';
import 'package:bank_sampah_tubaba/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Klien API terpisah yang memakai backend palsu yang sama dengan aplikasi.
Future<ApiClient> _klien(
  MockBackend mock,
  String email, {
  String password = 'password',
  String perangkat = 'Browser',
}) async {
  final api = ApiClient(
    baseUrl: 'http://mock/api/v1',
    tokenStorage: MemoryTokenStorage(),
    adapter: mock,
  );
  final body = await api.post(
    '/auth/login',
    data: {'email': email, 'password': password, 'device_name': perangkat},
  );
  await api.tokenStorage.simpan('${(body['data'] as Map)['token']}');
  return api;
}

Future<void> _bukaAplikasi(WidgetTester tester, MockBackend mock) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final storage = MemoryTokenStorage();
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        tokenStorageProvider.overrideWithValue(storage),
        apiClientProvider.overrideWith(
          (ref) => ApiClient(
            baseUrl: 'http://mock/api/v1',
            tokenStorage: storage,
            adapter: mock,
          ),
        ),
      ],
      child: const AplikasiBankSampah(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _masuk(
  WidgetTester tester,
  String email, {
  String password = 'password',
  String? peran,
}) async {
  if (peran != null) {
    await tester.tap(
      find.descendant(
        of: find.byType(SegmenReferensi<bool>),
        matching: find.text('Bank Sampah'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(peran));
    await tester.pumpAndSettle();
  }
  await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Password'),
    password,
  );
  final masuk = find.widgetWithText(FilledButton, 'Masuk');
  await tester.ensureVisible(masuk);
  await tester.tap(masuk);
  await tester.pumpAndSettle();
}

Future<void> _bukaMenuProfil(WidgetTester tester, String menu) async {
  await tester.tap(find.byTooltip('Profil'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text(menu),
    200,
    scrollable: find
        .descendant(
          of: find.byType(ProfilWarga),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await _ketuk(tester, find.text(menu));
}

Future<void> _ketuk(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test(
    'akun dengan password sementara hanya boleh membuka halaman ganti password',
    () {
      const user = User(
        id: 1,
        name: 'Siti',
        email: 's@x.id',
        role: Role.warga,
        harusGantiPassword: true,
      );
      expect(arahkan(const AsyncData(user), '/warga'), '/akun/password');
      expect(
        arahkan(const AsyncData(user), '/akun/perangkat'),
        '/akun/password',
      );
      expect(arahkan(const AsyncData(user), '/akun/password'), isNull);
    },
  );

  testWidgets(
    'pengelola mereset password nasabah dan melihat password sementara',
    (tester) async {
      await _bukaAplikasi(tester, MockBackend());
      await _masuk(tester, 'operator@demo.id', peran: 'Pengelola');

      await tester.tap(find.byTooltip('Nasabah'));
      await tester.pumpAndSettle();
      await _ketuk(tester, find.byTooltip('Pilihan untuk Siti Warga'));
      await _ketuk(tester, find.text('Reset password'));
      expect(find.text('Reset password Siti Warga?'), findsOneWidget);
      await _ketuk(tester, find.widgetWithText(FilledButton, 'Reset'));

      expect(find.text('Password sementara'), findsOneWidget);
      expect(find.text('sementara8'), findsOneWidget);
      await _ketuk(tester, find.widgetWithText(FilledButton, 'Selesai'));
      expect(find.text('sementara8'), findsNothing);
    },
  );

  testWidgets(
    'warga dengan password sementara wajib membuat password baru dulu',
    (tester) async {
      final mock = MockBackend();
      await tester.runAsync(() async {
        final operator = await _klien(mock, 'operator@demo.id');
        await operator.post('/bs/nasabah/1/reset-password');
      });

      await _bukaAplikasi(tester, mock);
      await _masuk(tester, 'warga@demo.id', password: 'sementara8');

      expect(find.text('Buat password baru'), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password sementara'),
        'sementara8',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password baru (min. 8)'),
        'sandi-baru-siti',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ulangi password baru'),
        'sandi-baru-siti',
      );
      await _ketuk(tester, find.widgetWithText(FilledButton, 'Simpan'));

      expect(find.text('Saldo tabungan'), findsOneWidget);
    },
  );

  testWidgets('perangkat lain bisa dikeluarkan dari menu Perangkat aktif', (
    tester,
  ) async {
    final mock = MockBackend();
    final browser = (await tester.runAsync(
      () => _klien(mock, 'warga@demo.id'),
    ))!;
    await _bukaAplikasi(tester, mock);
    await _masuk(tester, 'warga@demo.id');

    await _bukaMenuProfil(tester, 'Perangkat aktif');
    expect(find.text('Perangkat ini'), findsOneWidget);
    expect(find.text('Browser'), findsOneWidget);

    await _ketuk(tester, find.byTooltip('Keluarkan Browser'));
    await _ketuk(tester, find.widgetWithText(FilledButton, 'Keluarkan'));
    expect(find.text('Browser'), findsNothing);
    expect(find.text('Perangkat ini'), findsOneWidget);

    // Sesi browser yang dikeluarkan tidak bisa dipakai lagi
    final ditolak = await tester.runAsync(() async {
      try {
        await browser.get('/me');
        return false;
      } catch (_) {
        return true;
      }
    });
    expect(ditolak, isTrue);
  });

  testWidgets('hapus akun ditolak bila masih ada saldo', (tester) async {
    await _bukaAplikasi(tester, MockBackend());
    await _masuk(tester, 'warga@demo.id');

    await _bukaMenuProfil(tester, 'Hapus akun');
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'password',
    );
    await _ketuk(tester, find.widgetWithText(FilledButton, 'Hapus akun saya'));
    await _ketuk(tester, find.widgetWithText(FilledButton, 'Hapus akun'));

    expect(find.textContaining('Saldo Anda masih'), findsOneWidget);
    expect(find.text('Hapus akun'), findsWidgets);
  });

  testWidgets(
    'warga tanpa saldo bisa menghapus akunnya lalu tidak bisa masuk lagi',
    (tester) async {
      final mock = MockBackend();
      final api = ApiClient(
        baseUrl: 'http://mock/api/v1',
        tokenStorage: MemoryTokenStorage(),
        adapter: mock,
      );
      await tester.runAsync(
        () => api.post(
          '/auth/register',
          data: {
            'name': 'Rina Baru',
            'email': 'rina@demo.id',
            'phone': '081299990000',
            'password': 'rahasia123',
            'password_confirmation': 'rahasia123',
            'alamat': 'Jl. Kenanga',
            'lat': -4.49,
            'lng': 105.07,
          },
        ),
      );

      await _bukaAplikasi(tester, mock);
      await _masuk(tester, 'rina@demo.id', password: 'rahasia123');
      await _bukaMenuProfil(tester, 'Hapus akun');
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        'rahasia123',
      );
      await _ketuk(
        tester,
        find.widgetWithText(FilledButton, 'Hapus akun saya'),
      );
      await _ketuk(tester, find.widgetWithText(FilledButton, 'Hapus akun'));

      expect(find.text('Masuk sebagai'), findsOneWidget);
      await _masuk(tester, 'rina@demo.id', password: 'rahasia123');
      expect(find.text('Email atau password salah.'), findsOneWidget);
    },
  );

  testWidgets('Lupa password menjelaskan reset lewat petugas sesuai peran', (
    tester,
  ) async {
    await _bukaAplikasi(tester, MockBackend());

    await _ketuk(tester, find.text('Lupa password?'));
    expect(
      find.textContaining('Datangi bank sampah tempat kamu menabung'),
      findsOneWidget,
    );
    await _ketuk(tester, find.text('Mengerti'));

    await tester.tap(
      find.descendant(
        of: find.byType(SegmenReferensi<bool>),
        matching: find.text('Bank Sampah'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bentor'));
    await tester.pumpAndSettle();
    await _ketuk(tester, find.text('Lupa password?'));
    expect(
      find.textContaining('Minta pengelola bank sampahmu'),
      findsOneWidget,
    );
  });

  testWidgets('tarik saldo meminta password dan menolak password salah', (
    tester,
  ) async {
    await _bukaAplikasi(tester, MockBackend());
    await _masuk(tester, 'warga@demo.id');

    await _ketuk(tester, find.widgetWithText(FilledButton, 'Tarik saldo'));
    if (find.byIcon(Icons.radio_button_checked).evaluate().isEmpty) {
      await _ketuk(tester, find.byIcon(Icons.radio_button_off).first);
    }
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.prefixText == 'Rp ',
      ),
      '1000',
    );
    final ajukanDiDialog = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Ajukan'),
    );

    await _ketuk(tester, find.widgetWithText(FilledButton, 'Ajukan'));
    expect(find.text('Konfirmasi penarikan'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'salah-sekali',
    );
    await _ketuk(tester, ajukanDiDialog);
    expect(find.text('Password salah.'), findsOneWidget);

    await _ketuk(tester, find.widgetWithText(FilledButton, 'Ajukan'));
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'password',
    );
    await _ketuk(tester, ajukanDiDialog);
    expect(find.textContaining('Penarikan diajukan'), findsOneWidget);
  });
}
