import 'dart:io';

import 'package:bank_sampah_tubaba/core/models/operasional.dart';
import 'package:bank_sampah_tubaba/core/models/preloved.dart';
import 'package:bank_sampah_tubaba/core/theme.dart';
import 'package:bank_sampah_tubaba/core/widgets.dart';
import 'package:bank_sampah_tubaba/features/bank_sampah/bs_providers.dart';
import 'package:bank_sampah_tubaba/features/bank_sampah/bs_shell.dart';
import 'package:bank_sampah_tubaba/features/preloved/chat_pages.dart';
import 'package:bank_sampah_tubaba/features/preloved/preloved_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// HP kecil: 360x640 dp (720x1280 px, kepadatan 2,0) seperti emulator uji.
void _layar360(WidgetTester tester, {double tinggiKeyboardDp = 0}) {
  tester.view.physicalSize = const Size(720, 1280);
  tester.view.devicePixelRatio = 2.0;
  tester.view.viewInsets = FakeViewPadding(bottom: tinggiKeyboardDp * 2);
  addTearDown(tester.view.reset);
}

class _RepoChatKosong implements PrelovedRepository {
  @override
  Future<List<PesanChat>> pesan(int percakapanId, {int? afterId}) async => [];

  @override
  Future<void> tandaiDibaca(int percakapanId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _percakapan = Percakapan.dariJson({
  'id': 1,
  'peran_saya': 'pembeli',
  'barang': {
    'id': 7,
    'judul': 'Meja belajar kayu jati dengan laci dua susun',
    'harga': 150000,
    'status': 'tersedia',
    'foto': null,
  },
  'lawan_bicara': {'id': 2, 'name': 'Budi Warga', 'phone': null},
});

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets(
    'dashboard operator tidak overflow di 360 dp dengan huruf sistem 130%',
    (tester) async {
      _layar360(tester);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      const ringkas = RingkasSetoran(
        jumlah: 128,
        totalKg: 1234.75,
        kgDonasi: 56.5,
        totalNilai: 12500000,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            permintaanBaruBsProvider.overrideWith((ref) async => []),
            dashboardBsProvider.overrideWith(
              (ref) async => const DashboardBank(
                hariIni: ringkas,
                bulanIni: ringkas,
                jemputDiajukan: 12,
                jemputBerjalan: 7,
                penarikanDiajukan: 15,
                totalPenarikanDiajukan: 2750000,
                jumlahNasabah: 1250,
                totalSaldoNasabah: 98765000,
              ),
            ),
          ],
          child: MaterialApp(
            theme: TemaAplikasi.terang(),
            home: Scaffold(body: BerandaBs(keTab: (_) {})),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Dashboard baru memiliki hero dan aksi cepat sebelum kartu ringkasan.
      await tester.scrollUntilVisible(find.text('Penarikan menunggu'), 100);
      expect(find.text('Penarikan menunggu'), findsOneWidget);
      // Kartu terakhir bisa digulir hingga terlihat utuh (tidak terpotong)
      await tester.scrollUntilVisible(find.text('1.250 nasabah'), 100);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ruang chat kosong dengan keyboard terbuka tidak overflow', (
    tester,
  ) async {
    _layar360(tester, tinggiKeyboardDp: 300);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prelovedRepositoryProvider.overrideWithValue(_RepoChatKosong()),
        ],
        child: MaterialApp(
          theme: TemaAplikasi.terang(),
          home: RuangChatPage(percakapan: _percakapan),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Mulai percakapan'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Hentikan timer polling sebelum test selesai
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('formulir di bottom sheet tidak overflow saat keyboard terbuka', (
    tester,
  ) async {
    _layar360(tester, tinggiKeyboardDp: 300);

    await tester.pumpWidget(
      MaterialApp(
        theme: TemaAplikasi.terang(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => tampilkanSheet<void>(
                  context,
                  (_) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Catat penjualan ke pengepul'),
                        for (final label in [
                          'Nama pengepul',
                          'Jenis sampah',
                          'Berat',
                          'Harga/kg',
                        ])
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: TextField(
                              decoration: InputDecoration(labelText: label),
                            ),
                          ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () {},
                          child: const Text('Simpan'),
                        ),
                      ],
                    ),
                  ),
                ),
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Tombol terakhir bisa digulir hingga terlihat DI ATAS keyboard (640 − 300 dp)
    await tester.dragUntilVisible(
      find.text('Simpan'),
      find.byType(SingleChildScrollView).last,
      const Offset(0, -100),
    );
    expect(tester.getRect(find.text('Simpan')).bottom, lessThanOrEqualTo(340));
    expect(tester.takeException(), isNull);
  });

  test(
    'bottom sheet & dialog lewat helper terpusat (aman dari bilah sistem)',
    () {
      final pelanggaran = <String>[];
      for (final f
          in Directory('lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        final jalur = f.path.replaceAll(r'\', '/');
        if (jalur.endsWith('lib/core/widgets.dart')) continue;
        final isi = f.readAsStringSync();
        if (isi.contains('showModalBottomSheet(') ||
            isi.contains('showModalBottomSheet<')) {
          pelanggaran.add(
            '$jalur: showModalBottomSheet → pakai tampilkanSheet',
          );
        }
        if (isi.contains('AlertDialog(')) {
          pelanggaran.add('$jalur: AlertDialog → pakai DialogAplikasi');
        }
      }
      expect(pelanggaran, isEmpty);
    },
  );
}
