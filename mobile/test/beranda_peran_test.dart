import 'dart:io';

import 'package:bank_sampah_tubaba/core/api/api_client.dart';
import 'package:bank_sampah_tubaba/core/api/mock_backend.dart';
import 'package:bank_sampah_tubaba/core/komponen_ui.dart';
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
  if (peran != 'Warga') {
    // Pengelola dan Bentor berada di bawah pilihan "Bank Sampah".
    await tester.tap(find.descendant(
      of: find.byType(SegmenReferensi<bool>),
      matching: find.text('Bank Sampah'),
    ));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text(peran));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
  await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'password');
  await tester.ensureVisible(find.widgetWithText(FilledButton, 'Masuk'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
  await tester.pumpAndSettle();
}

/// Keterangan di bawah saldo warga: jumlah bank tempat saldo tersimpan, atau ajakan menabung.
final _keteranganSaldo = find.byWidgetPredicate(
  (w) => w is Text && RegExp(r'^(Di \d+ bank sampah|Ayo mulai menabung)$').hasMatch(w.data ?? ''),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    // Font asli agar lebar teks sama seperti di HP
    final loader = FontLoader('Plus Jakarta Sans')
      ..addFont(Future.value(ByteData.sublistView(File('assets/fonts/PlusJakartaSans.ttf').readAsBytesSync())));
    await loader.load();
  });

  testWidgets('warga melihat saldo, keterangan saldo, dan navigasi berlabel', (tester) async {
    _layar320(tester);
    await _masuk(tester, 'warga@demo.id', 'Warga');

    expect(find.text('Saldo tabungan'), findsOneWidget);
    expect(_keteranganSaldo, findsOneWidget);
    expect(find.text('1 poin = 1 rupiah'), findsNothing);
    // Alur di header berlabel, bukan deret ikon tanpa arti
    for (final langkah in ['Pilah', 'Timbang', 'Tabung']) {
      expect(find.text(langkah), findsOneWidget);
    }
    // Menu tidak mengulang tujuan yang sudah ada di kotak cari atau navigasi bawah
    for (final menu in ['Cara setor', 'Donasi', 'Status jemput', 'Harga sampah']) {
      expect(find.text(menu), findsOneWidget);
    }
    expect(find.text('Setor'), findsNothing);
    expect(find.text('Tarik saldo'), findsOneWidget);
    expect(find.byTooltip('Pesan jemput sampah'), findsOneWidget);
    expect(find.text('Riwayat'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keterangan saldo hanya untuk warga', (tester) async {
    _layar320(tester);
    await _masuk(tester, 'operator@demo.id', 'Pengelola');

    expect(find.text('Sampah masuk hari ini'), findsOneWidget);
    expect(_keteranganSaldo, findsNothing);
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

  testWidgets('Cara setor membuka panduan dengan jalan pintas', (tester) async {
    _layar320(tester);
    await _masuk(tester, 'warga@demo.id', 'Warga');

    await tester.tap(find.text('Cara setor'));
    await tester.pumpAndSettle();
    expect(find.text('Cara menabung sampah'), findsOneWidget);
    for (final langkah in ['Pilah dari rumah', 'Bawa atau minta jemput', 'Ditimbang petugas', 'Tarik saldo']) {
      expect(find.text(langkah), findsWidgets);
    }
    expect(find.widgetWithText(OutlinedButton, 'Cari bank sampah terdekat'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Cari bank sampah terdekat'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cari bank sampah terdekat'));
    await tester.pumpAndSettle();
    expect(find.text('Cara menabung sampah'), findsNothing);
  });

  testWidgets('tiap menu beranda jadi tombol tersendiri bagi pembaca layar', (tester) async {
    final semantik = tester.ensureSemantics();
    _layar320(tester);
    await _masuk(tester, 'warga@demo.id', 'Warga');

    for (final menu in ['Cara setor', 'Donasi', 'Status jemput', 'Harga sampah']) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(menu)),
        isSemantics(label: menu, isButton: true, hasTapAction: true),
      );
    }
    semantik.dispose();
  });

  testWidgets('Harga sampah menggulir ke daftar harga di beranda', (tester) async {
    _layar320(tester);
    await _masuk(tester, 'warga@demo.id', 'Warga');

    final judul = find.text('Harga sampah hari ini');
    final tinggiLayar = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(tester.getTopLeft(judul).dy, greaterThan(tinggiLayar));

    await tester.tap(find.text('Harga sampah'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(judul).dy, inInclusiveRange(0, tinggiLayar / 2));
  });
}
