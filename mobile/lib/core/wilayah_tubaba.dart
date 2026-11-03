import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show compute, kDebugMode;
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

/// Kotak yang memuat seluruh Tubaba, untuk kamera awal peta.
const batasTubaba = [LatLng(-4.7270, 104.9270), LatLng(-4.1380, 105.2550)];

/// Sama dengan normalisasiWilayah di web, agar nama "Kec. X" dan "X" dianggap sama.
String normalisasiWilayah(String nama) => nama
    .toLowerCase()
    .replaceAll(RegExp(r'\b(desa|tiyuh|kelurahan|kecamatan|kec)\b'), '')
    .replaceAll(RegExp(r'[^a-z0-9]'), '');

const _warnaKepadatan = [Color(0xFFCFE8E3), Color(0xFF97CFC5), Color(0xFF5CAB9F), Color(0xFF2C8177)];

/// Warna kecamatan menurut jumlah bank sampah, sama dengan peta panel DLH.
Color warnaKepadatan(int jumlah, int maks) {
  if (jumlah <= 0 || maks <= 0) return const Color(0xFFEDF5F3);
  final tingkat = (jumlah / maks * _warnaKepadatan.length).ceil().clamp(1, _warnaKepadatan.length);
  return _warnaKepadatan[tingkat - 1];
}

class PoligonWilayah {
  const PoligonWilayah(this.luar, this.lubang);

  final List<LatLng> luar;
  final List<List<LatLng>> lubang;
}

class Wilayah {
  const Wilayah({required this.nama, required this.kecamatan, required this.bagian});

  final String nama;
  final String? kecamatan;
  final List<PoligonWilayah> bagian;

  List<LatLng> get semuaTitik => [for (final b in bagian) ...b.luar];
}

/// Batas administrasi dari berkas yang sama dengan peta panel DLH (sumber BIG).
class DataWilayah {
  const DataWilayah({required this.kabupaten, required this.kecamatan, required this.desa});

  factory DataWilayah.dariGeoJson({
    required String kabupaten,
    required String kecamatan,
    required String desa,
  }) => DataWilayah(
    kabupaten: _urai(kabupaten),
    kecamatan: _urai(kecamatan),
    desa: _urai(desa),
  );

  final List<Wilayah> kabupaten;
  final List<Wilayah> kecamatan;
  final List<Wilayah> desa;

  Wilayah? cariDesa(String tiyuh, String kecamatanBank) {
    final namaDesa = normalisasiWilayah(tiyuh);
    final namaKec = normalisasiWilayah(kecamatanBank);
    for (final d in desa) {
      if (normalisasiWilayah(d.nama) == namaDesa && normalisasiWilayah(d.kecamatan ?? '') == namaKec) return d;
    }
    return null;
  }

  static List<Wilayah> _urai(String teks) {
    final data = jsonDecode(teks) as Map<String, dynamic>;
    return [
      for (final f in (data['features'] as List).cast<Map<String, dynamic>>())
        Wilayah(
          nama: '${f['properties']['nama']}',
          kecamatan: f['properties']['kecamatan'] as String?,
          bagian: _bagian((f['geometry'] as Map).cast()),
        ),
    ];
  }

  static List<PoligonWilayah> _bagian(Map<String, dynamic> geometri) {
    final koordinat = geometri['coordinates'] as List;
    final poligon = geometri['type'] == 'MultiPolygon' ? koordinat : [koordinat];
    return [
      for (final p in poligon.cast<List>())
        PoligonWilayah(_cincin(p.first as List), [for (final l in p.skip(1)) _cincin(l as List)]),
    ];
  }

  // GeoJSON menyimpan urutan bujur lalu lintang
  static List<LatLng> _cincin(List titik) => [
    for (final t in titik.cast<List>()) LatLng((t[1] as num).toDouble(), (t[0] as num).toDouble()),
  ];
}

Future<DataWilayah> muatWilayahTubaba() async {
  Future<String> baca(String level) async =>
      utf8.decode((await rootBundle.load('assets/geo/tubaba-$level.geojson')).buffer.asUint8List());
  final teks = (await baca('kabupaten'), await baca('kecamatan'), await baca('desa'));
  // Di luar mode debug (termasuk test) diurai di isolate, agar layar tidak tersendat saat peta dibuka
  return kDebugMode ? _uraiWilayah(teks) : compute(_uraiWilayah, teks);
}

DataWilayah _uraiWilayah((String, String, String) teks) => DataWilayah.dariGeoJson(
  kabupaten: teks.$1,
  kecamatan: teks.$2,
  desa: teks.$3,
);
