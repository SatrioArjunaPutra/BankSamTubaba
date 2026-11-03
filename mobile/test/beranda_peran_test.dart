import 'dart:io';

import 'package:bank_sampah_tubaba/core/api/api_client.dart';
import 'package:bank_sampah_tubaba/core/api/mock_backend.dart';
import 'package:bank_sampah_tubaba/core/providers.dart';
import 'package:bank_sampah_tubaba/core/storage/token_storage.dart';
import 'package:bank_sampah_tubaba/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Beranda tiap peran pada HP paling sempit yang didukung.
void _layar320(WidgetTester tester) {
  tester.view.physicalSize = const Size(640, 1280);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
}

Future<void> _masuk(WidgetTester tester, String email, String peran) async {
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
  await tester.tap(find.text(peran));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
  await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'password');
  await tester.ensureVisible(find.widgetWithText(FilledButton, 'Masuk'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    // Font asli agar lebar teks sama seperti di HP
    final loader = FontLoader('Plus Jakarta Sans')
      ..addFont(Future.value(ByteData.sublistView(File('assets/fonts/PlusJakartaSans.ttf').readAsBytesSync())));
    await loader.load();
  });

  testWidgets('warga melihat saldo, keterangan poin, dan navigasi berlabel', (tester) async {
    _layar320(tester);
    await _masuk(tester, 'warga@demo.id', 'Warga');

    expect(find.text('Saldo tabungan'), findsOneWidget);
    expect(find.text('1 poin = 1 rupiah'), findsOneWidget);
    expect(find.text('Tarik saldo'), findsOneWidget);
    expect(find.byTooltip('Pesan jemput sampah'), findsOneWidget);
    expect(find.text('Riwayat'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keterangan poin hanya untuk warga', (tester) async {
    _layar320(tester);
    await _masuk(tester, 'operator@demo.id', 'Bank sampah');

    expect(find.text('Sampah masuk hari ini'), findsOneWidget);
    expect(find.text('1 poin = 1 rupiah'), findsNothing);
    expect(find.byTooltip('Catat setoran'), findsOneWidget);
    expect(find.text('Catat'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bentor melihat ringkasan tugas tanpa meluap', (tester) async {
    _layar320(tester);
    await _masuk(tester, 'bentor@demo.id', 'Bentor');

    expect(find.text('Tugas aktif'), findsOneWidget);
    expect(find.text('Kapasitas'), findsOneWidget);
    expect(find.text('Armada'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
