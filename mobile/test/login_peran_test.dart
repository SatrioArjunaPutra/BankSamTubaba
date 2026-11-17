import 'package:bank_sampah_tubaba/core/api/api_client.dart';
import 'package:bank_sampah_tubaba/core/api/mock_backend.dart';
import 'package:bank_sampah_tubaba/core/komponen_ui.dart';
import 'package:bank_sampah_tubaba/core/providers.dart';
import 'package:bank_sampah_tubaba/core/storage/token_storage.dart';
import 'package:bank_sampah_tubaba/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

final segmenBank = find.descendant(
  of: find.byType(SegmenReferensi<bool>),
  matching: find.text('Bank Sampah'),
);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  Future<MemoryTokenStorage> bukaLogin(WidgetTester tester) async {
    // Ukuran layar HP agar tombol Masuk tetap terlihat saat pilihan petugas terbuka.
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
              adapter: MockBackend(),
            ),
          ),
        ],
        child: const AplikasiBankSampah(),
      ),
    );
    await tester.pumpAndSettle();
    return storage;
  }

  Future<void> isiDanMasuk(WidgetTester tester, String email) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password',
    );
    final masuk = find.widgetWithText(FilledButton, 'Masuk');
    await tester.ensureVisible(masuk);
    await tester.tap(masuk);
    await tester.pumpAndSettle();
  }

  const pesanOperator =
      "Akun ini terdaftar sebagai pengelola bank sampah. Pilih Bank Sampah, lalu Pengelola.";

  testWidgets('akun bank sampah dengan pilihan Warga ditolak tanpa token', (
    tester,
  ) async {
    final storage = await bukaLogin(tester);
    await isiDanMasuk(tester, 'operator@demo.id');

    expect(find.text(pesanOperator), findsOneWidget);
    expect(find.text('Masuk sebagai'), findsOneWidget);
    expect(await storage.baca(), isNull);
  });

  testWidgets('akun warga dengan pilihan Bentor ditolak', (tester) async {
    final storage = await bukaLogin(tester);
    await tester.tap(segmenBank);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bentor'));
    await tester.pumpAndSettle();
    await isiDanMasuk(tester, 'warga@demo.id');

    expect(
      find.text(
        "Akun ini terdaftar sebagai warga. Pilih Warga, lalu coba lagi.",
      ),
      findsOneWidget,
    );
    expect(await storage.baca(), isNull);
  });

  testWidgets('ganti pilihan menghapus pesan, isian tetap, lalu bisa masuk', (
    tester,
  ) async {
    final storage = await bukaLogin(tester);
    await isiDanMasuk(tester, 'operator@demo.id');
    expect(find.text(pesanOperator), findsOneWidget);

    await tester.tap(segmenBank);
    await tester.pumpAndSettle();
    expect(find.text(pesanOperator), findsNothing);
    expect(find.text('operator@demo.id'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Catat setoran'), findsOneWidget);
    expect(await storage.baca(), isNotNull);
  });

  testWidgets(
    'Bank Sampah memisahkan Pengelola dan Bentor tanpa tautan daftar',
    (tester) async {
      await bukaLogin(tester);
      expect(find.text('Pengelola'), findsNothing);
      expect(find.text('Warga baru? Daftar di sini'), findsOneWidget);

      await tester.tap(segmenBank);
      await tester.pumpAndSettle();
      expect(find.text('Pengelola'), findsOneWidget);
      expect(find.text('Bentor'), findsOneWidget);
      expect(find.text('Warga baru? Daftar di sini'), findsNothing);
      expect(
        find.text('Akun petugas dibuat oleh DLH atau pengelola bank sampah.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Warga'));
      await tester.pumpAndSettle();
      expect(find.text('Pengelola'), findsNothing);
    },
  );

  testWidgets('akun bentor masuk lewat Bank Sampah lalu Bentor', (
    tester,
  ) async {
    final storage = await bukaLogin(tester);
    await tester.tap(segmenBank);
    await tester.pumpAndSettle();
    await isiDanMasuk(tester, 'bentor@demo.id');
    expect(
      find.text(
        'Akun ini terdaftar sebagai bentor. Pilih Bank Sampah, lalu Bentor.',
      ),
      findsOneWidget,
    );
    expect(await storage.baca(), isNull);

    await tester.tap(find.text('Bentor'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.pumpAndSettle();
    expect(find.text('Pak Bentor'), findsWidgets);
    expect(await storage.baca(), isNotNull);
  });
}
