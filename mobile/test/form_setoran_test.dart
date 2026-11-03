import 'package:bank_sampah_tubaba/core/models/bank_sampah.dart';
import 'package:bank_sampah_tubaba/core/models/operasional.dart';
import 'package:bank_sampah_tubaba/features/bank_sampah/catat_setoran_page.dart';
import 'package:bank_sampah_tubaba/features/bank_sampah/kalkulator_setoran.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const _harga = [
  Harga(jenisSampahId: 1, nama: 'Plastik', hargaPerKg: 3000),
  Harga(jenisSampahId: 2, nama: 'Kardus', hargaPerKg: 2000),
  Harga(jenisSampahId: 3, nama: 'Logam'), // belum diatur
];
const _hargaPlastik = Harga(
  jenisSampahId: 1,
  nama: 'Plastik',
  hargaPerKg: 3000,
);

final _petaHarga = {for (final h in _harga) h.jenisSampahId: h.hargaPerKg};

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('TotalSetoran', () {
    test('jual: berat × harga bank, koma desimal diterima', () {
      final t = TotalSetoran.hitung(
        [
          BarisSetoran(jenisSampahId: 1, berat: '2,5'),
          BarisSetoran(jenisSampahId: 2, berat: '1.25'),
        ],
        _petaHarga,
        donasi: false,
      );
      expect(t.totalKg, 3.75);
      expect(t.totalNilai, 10000);
      expect(t.tanpaHarga, isEmpty);
    });

    test('tanpa pembulatan float: 0.1 + 0.2 kg tetap 0.3', () {
      final t = TotalSetoran.hitung(
        [
          BarisSetoran(jenisSampahId: 1, berat: '0.1'),
          BarisSetoran(jenisSampahId: 2, berat: '0.2'),
        ],
        _petaHarga,
        donasi: false,
      );
      expect(t.totalKg, 0.3);
      expect(t.totalNilai, 700);
    });

    test('donasi: berat dihitung, nilai 0, jenis tanpa harga boleh', () {
      final t = TotalSetoran.hitung(
        [
          BarisSetoran(jenisSampahId: 1, berat: '4'),
          BarisSetoran(jenisSampahId: 3, berat: '1'),
        ],
        _petaHarga,
        donasi: true,
      );
      expect(t.totalKg, 5);
      expect(t.totalNilai, 0);
      expect(t.tanpaHarga, isEmpty);
    });

    test(
      'jual jenis tanpa harga ditandai; baris kosong/tidak valid diabaikan',
      () {
        final t = TotalSetoran.hitung(
          [
            BarisSetoran(jenisSampahId: 3, berat: '1'),
            BarisSetoran(jenisSampahId: 1, berat: 'abc'),
            BarisSetoran(berat: '9'),
          ],
          _petaHarga,
          donasi: false,
        );
        expect(t.tanpaHarga, [3]);
        expect(t.totalKg, 1);
        expect(t.totalNilai, 0);
      },
    );
  });

  testWidgets('tombol langkah menjaga batas nol dan input dua desimal', (
    tester,
  ) async {
    final baris = [BarisSetoran(jenisSampahId: 1, berat: '0')];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => FormSetoran(
                daftarHarga: const [_hargaPlastik],
                warga: const WargaNasabah(id: 1, name: 'Siti', saldo: 0),
                onPilihWarga: (_) {},
                donasi: false,
                onUbahTipe: (_) {},
                baris: baris,
                onUbah: () => setState(() {}),
                onSimpan: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Kurangi Plastik'));
    await tester.pump();
    expect(baris.single.beratKg, isNull);
    await tester.enterText(find.widgetWithText(TextFormField, 'Berat'), '0,25');
    await tester.pump();
    await tester.tap(find.byTooltip('Tambah Plastik'));
    await tester.pump();
    expect(baris.single.beratKg, .75);
    expect(
      (tester.widget<Text>(find.byKey(const Key('total-nilai')))).data,
      'Rp 2.250',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('form menampilkan total realtime dan beralih ke donasi', (
    tester,
  ) async {
    final baris = [
      BarisSetoran(jenisSampahId: 1),
      BarisSetoran(jenisSampahId: 2),
    ];
    var donasi = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => FormSetoran(
                daftarHarga: _harga,
                warga: const WargaNasabah(id: 1, name: 'Siti', saldo: 0),
                onPilihWarga: (_) {},
                donasi: donasi,
                onUbahTipe: (d) => setState(() => donasi = d),
                baris: baris,
                onUbah: () => setState(() {}),
                onSimpan: () {},
              ),
            ),
          ),
        ),
      ),
    );

    String teks(String key) =>
        (tester.widget<Text>(find.byKey(Key(key)))).data!;
    expect(teks('total-nilai'), 'Rp 0');

    final berat = find.widgetWithText(TextFormField, 'Berat');
    await tester.enterText(berat.at(0), '2,5');
    await tester.enterText(berat.at(1), '1,25');
    await tester.pump();

    expect(teks('total-kg'), '3,75 kg');
    expect(teks('total-nilai'), 'Rp 10.000');

    await tester.tap(find.text('Donasi'));
    await tester.pump();
    expect(teks('total-nilai'), 'Donasi');
    expect(teks('total-kg'), '3,75 kg');
  });
}
