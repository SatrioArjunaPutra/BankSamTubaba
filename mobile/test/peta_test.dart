import 'dart:io';

import 'package:bank_sampah_tubaba/core/api/api_client.dart';
import 'package:bank_sampah_tubaba/core/api/mock_backend.dart';
import 'package:bank_sampah_tubaba/core/peta.dart';
import 'package:bank_sampah_tubaba/core/providers.dart';
import 'package:bank_sampah_tubaba/core/storage/token_storage.dart';
import 'package:bank_sampah_tubaba/core/wilayah_tubaba.dart';
import 'package:bank_sampah_tubaba/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show MapController;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latlong2/latlong.dart';

bool _dalam(LatLng t, List<LatLng> poligon) {
  var di = false;
  for (var i = 0, j = poligon.length - 1; i < poligon.length; j = i++) {
    final a = poligon[i], b = poligon[j];
    if ((a.longitude > t.longitude) != (b.longitude > t.longitude) &&
        t.latitude < (b.latitude - a.latitude) * (t.longitude - a.longitude) / (b.longitude - a.longitude) + a.latitude) {
      di = !di;
    }
  }
  return di;
}

TitikPeta _t(double x, {bool terpilih = false}) =>
    TitikPeta(titik: LatLng(0, x), label: '$x', terpilih: terpilih);

void main() {
  // Setiap derajat dibuat satu piksel agar jarak mudah dibaca
  Offset keLayar(LatLng t) => Offset(t.longitude, t.latitude);

  test('titik berdekatan digabung, titik berjauhan terpisah', () {
    final hasil = kelompokkanTitik([_t(0), _t(10), _t(100)], keLayar);

    expect(hasil.map((k) => k.length), [2, 1]);
  });

  test('titik terpilih tidak ikut digabung dan digambar paling akhir', () {
    final hasil = kelompokkanTitik([_t(0, terpilih: true), _t(10), _t(20)], keLayar);

    expect(hasil.map((k) => k.length), [2, 1]);
    expect(hasil.last.single.terpilih, isTrue);
  });

  DataWilayah wilayah() => DataWilayah.dariGeoJson(
    kabupaten: File('assets/geo/tubaba-kabupaten.geojson').readAsStringSync(),
    kecamatan: File('assets/geo/tubaba-kecamatan.geojson').readAsStringSync(),
    desa: File('assets/geo/tubaba-desa.geojson').readAsStringSync(),
  );

  for (final interaktif in [true, false]) {
    testWidgets('tombol zoom mengubah kamera, peta ${interaktif ? 'bebas' : 'terkunci'}', (tester) async {
      final peta = MapController();
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [bankPerKecamatanProvider.overrideWith((ref) async => const {})],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 240,
                child: PetaOsm(
                  controller: peta,
                  pusat: const LatLng(-4.495, 105.075),
                  zoom: 15,
                  interaktif: interaktif,
                  kontrolZoom: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byTooltip('Perbesar'));
      await tester.pump();
      expect(peta.camera.zoom, 16);

      await tester.tap(find.byTooltip('Perkecil'));
      await tester.tap(find.byTooltip('Perkecil'));
      await tester.pump();
      expect(peta.camera.zoom, 14);
      await tester.pump(const Duration(seconds: 1));
    });
  }

  test('batas tiyuh dicari menurut nama tiyuh dan kecamatan', () {
    final w = wilayah();
    expect(w.kecamatan, hasLength(9));
    expect(w.cariDesa('Panaragan', 'Tulang Bawang Tengah')?.nama, 'Panaragan');
    expect(w.cariDesa('Tiyuh PANARAGAN JAYA UTAMA', 'Kec. Tulang Bawang Tengah')?.nama, 'Panaragan Jaya Utama');
    expect(w.cariDesa('Panaragan', 'Tumijajar'), isNull);
    expect(w.cariDesa('Tidak Ada', 'Tumijajar'), isNull);
  });

  test('warna kecamatan mengikuti skala panel DLH', () {
    expect(warnaKepadatan(0, 16), const Color(0xFFEDF5F3));
    expect(warnaKepadatan(1, 16), const Color(0xFFCFE8E3));
    expect(warnaKepadatan(16, 16), const Color(0xFF2C8177));
  });

  testWidgets('operator melihat bank miliknya, bukan titik contoh tetap', (tester) async {
    await initializeDateFormatting('id_ID');
    tester.view.physicalSize = const Size(780, 1800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    final storage = MemoryTokenStorage();
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          tokenStorageProvider.overrideWithValue(storage),
          apiClientProvider.overrideWith(
            (ref) => ApiClient(baseUrl: 'http://mock/api/v1', tokenStorage: storage, adapter: MockBackend()),
          ),
        ],
        child: const AplikasiBankSampah(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bank sampah'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'operator@demo.id');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'password');
    await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Peta wilayah'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Peta wilayah'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    // Lapisan peta memuat jumlah bank per kecamatan setelah halamannya tampil
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Bank Sampah Demo Panaragan'), findsOneWidget);
    expect(find.textContaining('Bank Sampah 1 Panaragan'), findsNothing);
    expect(find.textContaining('TPS'), findsNothing);
    expect(find.text('Tiyuh Panaragan'), findsOneWidget);
    expect(find.textContaining('Warna tua'), findsOneWidget);
    expect(find.textContaining('Titik jemput ('), findsOneWidget);
  });

  test('titik demo Panaragan berada di dalam batas tiyuhnya', () {
    final w = wilayah();
    final tiyuh = w.cariDesa('Panaragan', 'Tulang Bawang Tengah')!;
    const demo = LatLng(-4.495, 105.075);
    expect(tiyuh.bagian.any((b) => _dalam(demo, b.luar)), isTrue);
    expect(w.kabupaten.first.bagian.any((b) => _dalam(demo, b.luar)), isTrue);
    // Titik lama yang keliru tetap terdeteksi di luar tiyuh
    expect(tiyuh.bagian.any((b) => _dalam(const LatLng(-4.585, 105.132), b.luar)), isFalse);
  });
}
