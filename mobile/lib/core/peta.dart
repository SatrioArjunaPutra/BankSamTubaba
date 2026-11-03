import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';

import 'repositories.dart';
import 'theme.dart';
import 'widgets.dart';
import 'wilayah_tubaba.dart';

const _warnaGarisWilayah = Color(0xFF0F5C55);

/// Di atas zoom ini warna kecamatan dipudarkan agar jalan tetap terbaca saat menandai rumah.
const _zoomDekat = 12.5;

final wilayahTubabaProvider = FutureProvider<DataWilayah>((ref) => muatWilayahTubaba());

/// Dasar warna kecamatan. Bila gagal dimuat, peta tetap tampil dengan warna terang.
final bankPerKecamatanProvider = FutureProvider<Map<String, int>>((ref) async {
  try {
    return await ref.watch(umumRepositoryProvider).bankPerKecamatan();
  } catch (_) {
    return const {};
  }
});

const pusatTubaba = LatLng(-4.44, 105.13);

/// Alasan GPS tidak menghasilkan lokasi, dengan pesan untuk pengguna.
enum MasalahLokasi {
  gpsMati('GPS di HP mati. Nyalakan Lokasi (GPS), lalu coba lagi.'),
  izinDitolak('Izin lokasi ditolak. Izinkan akses lokasi agar posisi Anda bisa dipakai.'),
  izinDiblokir('Akses lokasi diblokir untuk aplikasi ini. Izinkan Lokasi di Pengaturan aplikasi.'),
  tidakDitemukan('Lokasi belum ditemukan. Coba lagi di tempat terbuka.');

  const MasalahLokasi(this.pesan);

  final String pesan;

  /// Aksi membuka pengaturan HP yang relevan, atau null jika cukup "Coba lagi".
  VoidCallback? get bukaPengaturan => switch (this) {
        gpsMati => Geolocator.openLocationSettings,
        izinDiblokir => Geolocator.openAppSettings,
        _ => null,
      };
}

/// Hasil pencarian GPS: [titik] jika berhasil, selain itu [masalah].
class HasilLokasi {
  const HasilLokasi.dapat(LatLng this.titik) : masalah = null;
  const HasilLokasi.gagal(MasalahLokasi this.masalah) : titik = null;

  final LatLng? titik;
  final MasalahLokasi? masalah;
}

/// Lokasi GPS saat ini (meminta izin bila belum).
Future<HasilLokasi> lokasiSaatIni() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return const HasilLokasi.gagal(MasalahLokasi.gpsMati);
    var izin = await Geolocator.checkPermission();
    if (izin == LocationPermission.denied) izin = await Geolocator.requestPermission();
    if (izin == LocationPermission.deniedForever) return const HasilLokasi.gagal(MasalahLokasi.izinDiblokir);
    if (izin == LocationPermission.denied) return const HasilLokasi.gagal(MasalahLokasi.izinDitolak);
    final posisi = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
    );
    return HasilLokasi.dapat(LatLng(posisi.latitude, posisi.longitude));
  } on LocationServiceDisabledException {
    return const HasilLokasi.gagal(MasalahLokasi.gpsMati);
  } catch (_) {
    return const HasilLokasi.gagal(MasalahLokasi.tidakDitemukan);
  }
}

/// Satu titik di peta. Titik yang saling menutupi digabung oleh [LapisanTitik].
class TitikPeta {
  const TitikPeta({
    required this.titik,
    required this.label,
    this.warna = TemaAplikasi.hijau,
    this.ikon = Icons.place,
    this.onTap,
    this.terpilih = false,
  });

  final LatLng titik;
  final String label;
  final Color warna;
  final IconData ikon;
  final VoidCallback? onTap;
  final bool terpilih;
}

/// Mengelompokkan titik yang jaraknya di layar kurang dari [jarak] piksel.
/// Titik terpilih selalu berdiri sendiri dan digambar paling akhir.
List<List<TitikPeta>> kelompokkanTitik(
  List<TitikPeta> daftar,
  Offset Function(LatLng titik) keLayar, {
  double jarak = 40,
}) {
  final pusat = <Offset>[];
  final kelompok = <List<TitikPeta>>[];
  for (final t in daftar.where((t) => !t.terpilih)) {
    final posisi = keLayar(t.titik);
    final i = pusat.indexWhere((p) => (p - posisi).distance < jarak);
    if (i >= 0) {
      kelompok[i].add(t);
    } else {
      pusat.add(posisi);
      kelompok.add([t]);
    }
  }
  return [
    ...kelompok,
    for (final t in daftar.where((t) => t.terpilih)) [t],
  ];
}

/// Peta OpenStreetMap (tanpa API key).
///
/// [interaktif] = false: peta tidak bisa digeser/diperbesar (hanya ketuk), agar
/// peta kecil di dalam formulir tidak "menelan" gerakan gulir halaman.
/// [batas]: kamera awal dipaskan ke titik-titik ini; bila kurang dari dua lokasi
/// berbeda, kamera memakai [pusat] dan [zoom].
class PetaOsm extends StatelessWidget {
  const PetaOsm({
    super.key,
    required this.pusat,
    this.zoom = 14,
    this.penanda = const [],
    this.titik = const [],
    this.poligon = const [],
    this.batas = const [],
    this.paddingBatas = const EdgeInsets.all(48),
    this.onTap,
    this.controller,
    this.interaktif = true,
    this.kontrolZoom = false,
    this.jarakBawah = 0,
  });

  final LatLng pusat;
  final double zoom;
  final List<Marker> penanda;
  final List<TitikPeta> titik;
  final List<Polygon> poligon;
  final List<LatLng> batas;
  final EdgeInsets paddingBatas;
  final void Function(LatLng titik)? onTap;
  final MapController? controller;
  final bool interaktif;
  final bool kontrolZoom;

  /// Ruang di bawah tanda hak cipta, bila bagian bawah peta tertutup navigasi.
  final double jarakBawah;

  @override
  Widget build(BuildContext context) {
    final bisaDipaskan = batas.toSet().length >= 2;
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: pusat,
        initialZoom: zoom,
        initialCameraFit: bisaDipaskan
            ? CameraFit.coordinates(coordinates: batas, padding: paddingBatas, maxZoom: 16)
            : null,
        minZoom: 7,
        maxZoom: 19,
        interactionOptions: interaktif
            ? const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate)
            : const InteractionOptions(flags: InteractiveFlag.none),
        onTap: onTap == null ? null : (_, titik) => onTap!(titik),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}',
          maxNativeZoom: 16,
          userAgentPackageName: 'id.tubaba.bank_sampah_tubaba',
        ),
        const _LapisanWilayah(),
        TileLayer(
          urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Reference/MapServer/tile/{z}/{y}/{x}',
          maxNativeZoom: 16,
          userAgentPackageName: 'id.tubaba.bank_sampah_tubaba',
        ),
        if (poligon.isNotEmpty) PolygonLayer(polygons: poligon),
        if (titik.isNotEmpty) LapisanTitik(titik: titik),
        if (penanda.isNotEmpty) MarkerLayer(markers: penanda),
        if (kontrolZoom) const _KontrolZoom(),
        _AtribusiOsm(jarakBawah: jarakBawah),
      ],
    );
  }
}

/// Warna kecamatan dan garis batas, bergaya peta bank sampah di panel DLH.
class _LapisanWilayah extends ConsumerStatefulWidget {
  const _LapisanWilayah();

  @override
  ConsumerState<_LapisanWilayah> createState() => _LapisanWilayahState();
}

class _LapisanWilayahState extends ConsumerState<_LapisanWilayah> {
  DataWilayah? _wilayah;
  Map<String, int>? _jumlah;
  List<Polygon> _jauh = const [];
  List<Polygon> _dekat = const [];

  // Daftar disimpan agar lapisan tidak menghitung ulang ribuan titik setiap kamera bergerak
  void _susun(DataWilayah wilayah, Map<String, int> jumlah) {
    if (identical(wilayah, _wilayah) && identical(jumlah, _jumlah)) return;
    _wilayah = wilayah;
    _jumlah = jumlah;
    final perNama = {for (final e in jumlah.entries) normalisasiWilayah(e.key): e.value};
    final maks = perNama.values.fold(0, (a, b) => a > b ? a : b);
    final luar = [
      Polygon(
        points: const [LatLng(-30, 85), LatLng(-30, 125), LatLng(20, 125), LatLng(20, 85)],
        holePointsList: [for (final k in wilayah.kabupaten) for (final b in k.bagian) b.luar],
        color: Colors.white.withValues(alpha: 0.62),
      ),
    ];
    List<Polygon> kecamatan(double kerapatan) => [
      for (final k in wilayah.kecamatan)
        for (final b in k.bagian)
          Polygon(
            points: b.luar,
            holePointsList: b.lubang,
            color: warnaKepadatan(perNama[normalisasiWilayah(k.nama)] ?? 0, maks).withValues(alpha: kerapatan),
            borderColor: Colors.white,
            borderStrokeWidth: 1.4,
          ),
    ];
    final kabupaten = [
      for (final k in wilayah.kabupaten)
        for (final b in k.bagian)
          Polygon(points: b.luar, borderColor: _warnaGarisWilayah, borderStrokeWidth: 2.4),
    ];
    _jauh = [...luar, ...kecamatan(0.78), ...kabupaten];
    _dekat = [
      ...luar,
      ...kecamatan(0.28),
      for (final d in wilayah.desa)
        for (final b in d.bagian)
          Polygon(points: b.luar, borderColor: _warnaGarisWilayah.withValues(alpha: 0.55), borderStrokeWidth: 0.8),
      ...kabupaten,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final wilayah = ref.watch(wilayahTubabaProvider).value;
    if (wilayah == null) return const SizedBox.shrink();
    _susun(wilayah, ref.watch(bankPerKecamatanProvider).value ?? const {});
    return PolygonLayer(polygons: MapCamera.of(context).zoom >= _zoomDekat ? _dekat : _jauh);
  }
}

/// Tanda sumber peta yang wajib tampil, dibuat kecil agar tidak menutupi peta.
class _AtribusiOsm extends StatelessWidget {
  const _AtribusiOsm({required this.jarakBawah});

  final double jarakBawah;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomRight,
    child: Padding(
      padding: EdgeInsets.only(bottom: jarakBawah),
      child: GestureDetector(
        onTap: () => launchUrl(
          Uri.parse('https://www.openstreetmap.org/copyright'),
          mode: LaunchMode.externalApplication,
        ).catchError((_) => false),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(6)),
          ),
          child: const Text('© Esri, OpenStreetMap, BIG', style: TextStyle(fontSize: 10, color: Color(0xFF444444))),
        ),
      ),
    ),
  );
}

class _KontrolZoom extends StatelessWidget {
  const _KontrolZoom();

  @override
  Widget build(BuildContext context) {
    final peta = MapController.of(context);
    Widget tombol(IconData ikon, String tip, double selisih) => IconButton(
      tooltip: tip,
      visualDensity: VisualDensity.compact,
      icon: Icon(ikon, size: 20),
      // Dibaca saat ditekan, agar tekanan beruntun tidak memakai posisi lama
      onPressed: () => peta.move(peta.camera.center, peta.camera.zoom + selisih),
    );
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Material(
          color: Colors.white,
          elevation: 3,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              tombol(Icons.add, 'Perbesar', 1),
              const SizedBox(width: 28, child: Divider(height: 1)),
              tombol(Icons.remove, 'Perkecil', -1),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pin peta. Ujung bawahnya tepat di koordinat, karena Marker memakai topCenter.
class PinPeta extends StatelessWidget {
  const PinPeta({super.key, required this.warna, required this.ikon, this.terpilih = false});

  static const lebar = 46.0;
  static const tinggi = 54.0;

  final Color warna;
  final IconData ikon;
  final bool terpilih;

  @override
  Widget build(BuildContext context) {
    final ukuran = terpilih ? 44.0 : 36.0;
    return SizedBox(
      width: lebar,
      height: tinggi,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          CustomPaint(size: const Size(16, 14), painter: _EkorPin(warna)),
          Positioned(
            bottom: 9,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              width: ukuran,
              height: ukuran,
              decoration: BoxDecoration(
                color: warna,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: terpilih ? 3 : 2.5),
                boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 6, offset: Offset(0, 2))],
              ),
              child: Icon(ikon, size: terpilih ? 22 : 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _EkorPin extends CustomPainter {
  const _EkorPin(this.warna);

  final Color warna;

  @override
  void paint(Canvas canvas, Size size) {
    final jalur = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(jalur, Paint()..color = warna);
  }

  @override
  bool shouldRepaint(_EkorPin lama) => lama.warna != warna;
}

Marker penandaPin(LatLng titik, {Color warna = Colors.red, IconData ikon = Icons.place, VoidCallback? onTap, bool terpilih = false}) => Marker(
      point: titik,
      width: PinPeta.lebar,
      height: PinPeta.tinggi,
      alignment: Alignment.topCenter,
      child: GestureDetector(onTap: onTap, child: PinPeta(warna: warna, ikon: ikon, terpilih: terpilih)),
    );

/// Lapisan pin yang menggabungkan titik berdekatan menjadi satu angka sesuai zoom,
/// sehingga pin tidak bertumpuk. Mengetuk angka memperbesar peta ke titik-titiknya.
class LapisanTitik extends StatelessWidget {
  const LapisanTitik({super.key, required this.titik});

  final List<TitikPeta> titik;

  void _bukaKelompok(BuildContext context, MapCamera kamera, List<TitikPeta> isi) {
    final layar = isi.map((t) => kamera.projectAtZoom(t.titik, 19)).toList();
    final menumpuk = layar.every((p) => (p - layar.first).distance < 40);
    if (menumpuk || kamera.zoom >= 18) {
      tampilkanSheet<void>(
        context,
        (c) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in isi)
              ListTile(
                leading: Icon(t.ikon, color: t.warna),
                title: Text(t.label),
                onTap: () {
                  Navigator.pop(c);
                  t.onTap?.call();
                },
              ),
          ],
        ),
      );
      return;
    }
    MapController.of(context).fitCamera(
      CameraFit.coordinates(
        coordinates: [for (final t in isi) t.titik],
        padding: const EdgeInsets.all(80),
        maxZoom: 18,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kamera = MapCamera.of(context);
    final terpilih = titik.where((t) => t.terpilih).map((t) => kamera.projectAtZoom(t.titik)).toList();
    bool dekatTerpilih(LatLng t) => terpilih.any((p) => (p - kamera.projectAtZoom(t)).distance < 56);
    return MarkerLayer(
      markers: [
        for (final isi in kelompokkanTitik(titik, kamera.projectAtZoom))
          if (isi.length == 1)
            penandaPin(
              isi.first.titik,
              warna: isi.first.warna,
              ikon: isi.first.ikon,
              terpilih: isi.first.terpilih,
              onTap: isi.first.onTap,
            )
          else
            Marker(
              point: isi.first.titik,
              width: 46,
              height: 46,
              alignment: dekatTerpilih(isi.first.titik) ? const Alignment(1.7, 0.5) : Alignment.center,
              child: GestureDetector(
                onTap: () => _bukaKelompok(context, kamera, isi),
                child: _TandaKelompok(jumlah: isi.length, warna: isi.first.warna),
              ),
            ),
      ],
    );
  }
}

class _TandaKelompok extends StatelessWidget {
  const _TandaKelompok({required this.jumlah, required this.warna});

  final int jumlah;
  final Color warna;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$jumlah titik',
    child: Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: warna,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Text(
        '$jumlah',
        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
      ),
    ),
  );
}

/// Bagian formulir untuk menandai titik rumah, dengan peta kecil setelah terisi.
class PemilihTitikRumah extends StatelessWidget {
  const PemilihTitikRumah({
    super.key,
    required this.titik,
    required this.onBerubah,
    this.galat,
    this.penandaLain = const [],
  });

  final LatLng? titik;
  final ValueChanged<LatLng> onBerubah;
  final String? galat;

  /// Titik lain yang ikut tampil dan ikut dimuat kamera, mis. bank sampah terdekat.
  final List<Marker> penandaLain;

  Future<void> _pilih(BuildContext context) async {
    final hasil = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(builder: (_) => PilihLokasiPage(awal: titik, judul: 'Titik rumah Anda')),
    );
    if (hasil != null) onBerubah(hasil);
  }

  @override
  Widget build(BuildContext context) {
    final t = titik;
    final warnaGalat = Theme.of(context).colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (t != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 170,
              child: PetaOsm(
                key: ValueKey('${t.latitude},${t.longitude},${penandaLain.length}'),
                interaktif: false,
                pusat: t,
                zoom: 15,
                batas: [t, for (final m in penandaLain) m.point],
                paddingBatas: const EdgeInsets.fromLTRB(40, 64, 40, 24),
                penanda: [
                  ...penandaLain,
                  penandaPin(t, warna: const Color(0xFF2563EB), ikon: Icons.home_rounded),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: () => _pilih(context),
          icon: Icon(t == null ? Icons.add_location_alt_outlined : Icons.edit_location_alt_outlined),
          label: Text(t == null ? 'Tandai titik rumah di peta' : 'Ubah titik rumah'),
        ),
        if (galat != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(galat!, style: TextStyle(fontSize: 12, color: warnaGalat)),
          ),
      ],
    );
  }
}

/// Label kecil "Mencari lokasi…" dengan spinner, untuk ditumpuk di atas peta.
class LabelMencariLokasi extends StatelessWidget {
  const LabelMencariLokasi({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 8),
          Text('Mencari lokasi…'),
        ]),
      ),
    );
  }
}

/// Kotak pesan saat GPS gagal: alasan, tombol pengaturan (bila relevan) dan
/// "Coba lagi". Kosong jika [masalah] null.
class PesanMasalahLokasi extends StatelessWidget {
  const PesanMasalahLokasi({super.key, required this.masalah, required this.onCobaLagi, this.catatan});

  final MasalahLokasi? masalah;
  final VoidCallback onCobaLagi;

  /// Kalimat tambahan, mis. cara menandai lokasi secara manual.
  final String? catatan;

  @override
  Widget build(BuildContext context) {
    final m = masalah;
    if (m == null) return const SizedBox.shrink();
    final skema = Theme.of(context).colorScheme;
    final pengaturan = m.bukaPengaturan;

    return Container(
      key: const Key('masalah-lokasi'),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 4),
      decoration: BoxDecoration(color: skema.errorContainer, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.location_off_outlined, color: skema.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(child: Text([m.pesan, ?catatan].join(' '), style: TextStyle(color: skema.onErrorContainer))),
        ]),
        Wrap(alignment: WrapAlignment.end, children: [
          if (pengaturan != null) TextButton(onPressed: pengaturan, child: const Text('Buka pengaturan')),
          TextButton(onPressed: onCobaLagi, child: const Text('Coba lagi')),
        ]),
      ]),
    );
  }
}

/// Pemilih lokasi layar penuh: peta bisa digeser & diperbesar, ketuk untuk
/// memindahkan pin. Kembali (pop) dengan titik terpilih.
class PilihLokasiPage extends StatefulWidget {
  const PilihLokasiPage({super.key, this.awal, this.judul = 'Pilih lokasi'});

  final LatLng? awal;
  final String judul;

  @override
  State<PilihLokasiPage> createState() => _PilihLokasiPageState();
}

class _PilihLokasiPageState extends State<PilihLokasiPage> {
  final _peta = MapController();
  late LatLng? _titik = widget.awal;
  bool _mencari = false;
  MasalahLokasi? _masalah;

  Future<void> _lokasiSaya() async {
    setState(() {
      _mencari = true;
      _masalah = null;
    });
    final hasil = await lokasiSaatIni();
    if (!mounted) return;
    setState(() {
      _mencari = false;
      _masalah = hasil.masalah;
      _titik = hasil.titik ?? _titik;
    });
    if (hasil.titik != null) _peta.move(hasil.titik!, 17);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.judul),
        actions: [IconButton(tooltip: 'Pakai lokasi saya', onPressed: _mencari ? null : _lokasiSaya, icon: const Icon(Icons.my_location))],
      ),
      body: Stack(children: [
        PetaOsm(
          controller: _peta,
          pusat: _titik ?? pusatTubaba,
          zoom: _titik != null ? 17 : 11,
          penanda: [if (_titik != null) penandaPin(_titik!)],
          onTap: (t) => setState(() => _titik = t),
        ),
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: _masalah != null
              ? PesanMasalahLokasi(masalah: _masalah, onCobaLagi: _lokasiSaya)
              : Center(
                  child: _mencari
                      ? const LabelMencariLokasi()
                      : Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Text(_titik == null ? 'Ketuk peta untuk menandai lokasi.' : 'Ketuk peta untuk memindahkan pin. Geser dan cubit untuk memperbesar.'),
                          ),
                        ),
                ),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _titik == null ? null : () => Navigator.pop(context, _titik),
            icon: const Icon(Icons.check),
            label: const Text('Pakai lokasi ini'),
          ),
        ),
      ),
    );
  }
}
