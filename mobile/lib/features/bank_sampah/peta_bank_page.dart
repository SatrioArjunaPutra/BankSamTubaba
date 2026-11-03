import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/models/bank_sampah.dart';
import '../../core/models/transaksi.dart';
import '../../core/peta.dart';
import '../../core/repositories.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../core/wilayah_tubaba.dart';
import '../auth/auth_controller.dart';

const _statusJemputAktif = ['diajukan', 'dijadwalkan', 'menuju', 'diambil'];
const _warnaTiyuh = Color(0xFF15803D);
const _warnaJemput = Color(0xFFD97706);

class _DataPeta {
  const _DataPeta(this.bank, this.jemput, this.tiyuh);
  final BankSampah bank;
  final List<Penjemputan> jemput;

  /// Batas tiyuh bank ini; null bila namanya belum cocok dengan data batas.
  final Wilayah? tiyuh;
}

final _dataPetaProvider = FutureProvider.autoDispose<_DataPeta>((ref) async {
  final id = ref.watch(authProvider).value?.bankSampah?.id;
  if (id == null) throw StateError('Akun ini belum terhubung ke bank sampah.');
  final bank = await ref.watch(umumRepositoryProvider).detailBankSampah(id);
  final repo = ref.watch(bankSampahRepositoryProvider);
  final hasil = await Future.wait([
    for (final status in _statusJemputAktif) repo.penjemputan(status),
  ]);
  final wilayah = await ref.watch(wilayahTubabaProvider.future);
  return _DataPeta(bank, [for (final h in hasil) ...h.items], wilayah.cariDesa(bank.tiyuh, bank.kecamatan));
});

/// Peta bank sampah milik operator: lokasinya, titik jemput warga yang masih
/// aktif, dan batas wilayah yang datanya tersedia.
class PetaBankBsPage extends ConsumerWidget {
  const PetaBankBsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_dataPetaProvider);
    return data.when(
      data: (d) => _IsiPeta(data: d),
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Peta wilayah')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Peta wilayah')),
        body: TampilanAsync(
          nilai: data,
          onUlang: () => ref.invalidate(_dataPetaProvider),
          data: (_) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _IsiPeta extends StatefulWidget {
  const _IsiPeta({required this.data});

  final _DataPeta data;

  @override
  State<_IsiPeta> createState() => _IsiPetaState();
}

class _IsiPetaState extends State<_IsiPeta> {
  final _peta = MapController();
  int? _jemputId;

  _DataPeta get _d => widget.data;
  LatLng? get _lokasiBank =>
      _d.bank.lat == null || _d.bank.lng == null ? null : LatLng(_d.bank.lat!, _d.bank.lng!);
  Penjemputan? get _jemput => _d.jemput.where((j) => j.id == _jemputId).firstOrNull;

  void _pilih(int? jemputId) => setState(() => _jemputId = jemputId);

  void _fokus(LatLng titik) => _peta.move(titik, 16);

  Future<void> _bukaRute(LatLng titik) async {
    final ok = await launchUrl(
      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${titik.latitude},${titik.longitude}'),
      mode: LaunchMode.externalApplication,
    ).catchError((_) => false);
    if (!ok && mounted) tampilPesan(context, 'Tidak dapat membuka Google Maps.', gagal: true);
  }

  @override
  Widget build(BuildContext context) {
    final lokasi = _lokasiBank;
    final jemput = _jemput;
    final titikDipilih = jemput != null ? LatLng(jemput.lat, jemput.lng) : lokasi;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Peta wilayah', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text(
              'Kec. ${_d.bank.kecamatan}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: TemaAplikasi.redup),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: PetaOsm(
                    controller: _peta,
                    pusat: lokasi ?? pusatTubaba,
                    zoom: lokasi == null ? 10 : 15,
                    kontrolZoom: true,
                    batas: [
                      ?lokasi,
                      for (final j in _d.jemput) LatLng(j.lat, j.lng),
                      ...?_d.tiyuh?.semuaTitik,
                    ],
                    paddingBatas: const EdgeInsets.fromLTRB(40, 110, 56, 40),
                    poligon: [
                      for (final b in _d.tiyuh?.bagian ?? const <PoligonWilayah>[])
                        Polygon(
                          points: b.luar,
                          holePointsList: b.lubang,
                          color: _warnaTiyuh.withValues(alpha: 0.16),
                          borderColor: _warnaTiyuh,
                          borderStrokeWidth: 2.5,
                        ),
                    ],
                    titik: [
                      for (final j in _d.jemput)
                        TitikPeta(
                          titik: LatLng(j.lat, j.lng),
                          label: j.warga?.name ?? j.alamat,
                          warna: _warnaJemput,
                          ikon: Icons.home_rounded,
                          terpilih: j.id == _jemputId,
                          onTap: () => _pilih(j.id),
                        ),
                      if (lokasi != null)
                        TitikPeta(
                          titik: lokasi,
                          label: _d.bank.nama,
                          ikon: Icons.storefront,
                          terpilih: _jemputId == null,
                          onTap: () => _pilih(null),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: _Legenda(
                    butir: [
                      if (lokasi != null) const _ButirLegenda(TemaAplikasi.hijau, 'Bank sampah', titik: true),
                      if (_d.jemput.isNotEmpty) _ButirLegenda(_warnaJemput, 'Titik jemput (${_d.jemput.length})', titik: true),
                      if (_d.tiyuh != null) _ButirLegenda(_warnaTiyuh, 'Tiyuh ${_d.tiyuh!.nama}'),
                      const _ButirLegenda(Color(0xFF2C8177), 'Warna tua: banyak bank sampah'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.white,
            elevation: 10,
            child: SafeArea(
              top: false,
              child: AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: jemput != null
                            ? _RincianJemput(key: ValueKey(jemput.id), jemput: jemput)
                            : _RincianBank(key: const ValueKey('bank'), data: _d),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: titikDipilih == null ? null : () => _fokus(titikDipilih),
                              icon: const Icon(Icons.center_focus_strong, size: 18),
                              label: const Text('Fokus'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: titikDipilih == null ? null : () => _bukaRute(titikDipilih),
                              icon: const Icon(Icons.directions, size: 18),
                              label: const Text('Rute'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RincianBank extends StatelessWidget {
  const _RincianBank({super.key, required this.data});

  final _DataPeta data;

  @override
  Widget build(BuildContext context) {
    final b = data.bank;
    final jumlah = data.jemput.length;
    return _KepalaRincian(
      ikon: Icons.storefront,
      warna: TemaAplikasi.hijau,
      judul: b.nama,
      baris: [
        b.alamat ?? '${b.tiyuh}, Kec. ${b.kecamatan}',
        if (b.lat == null || b.lng == null)
          'Titik lokasi belum diisi. DLH dapat melengkapinya.'
        else if (b.koordinatEstimasi)
          'Titik lokasi masih perkiraan. DLH dapat memperbaruinya.',
        jumlah == 0 ? 'Belum ada permintaan jemput aktif.' : '$jumlah titik jemput aktif. Ketuk pin untuk melihat rinciannya.',
      ],
    );
  }
}

class _RincianJemput extends StatelessWidget {
  const _RincianJemput({super.key, required this.jemput});

  final Penjemputan jemput;

  @override
  Widget build(BuildContext context) => _KepalaRincian(
    ikon: Icons.home_rounded,
    warna: _warnaJemput,
    judul: jemput.warga?.name ?? 'Permintaan jemput',
    tambahan: LabelStatus(labelStatusJemput[jemput.status] ?? jemput.status, warna: warnaStatus(jemput.status)),
    baris: [
      jemput.alamat,
      if (jemput.perkiraanKg != null) 'Perkiraan ${kg(jemput.perkiraanKg!)}',
    ],
  );
}

class _KepalaRincian extends StatelessWidget {
  const _KepalaRincian({
    required this.ikon,
    required this.warna,
    required this.judul,
    required this.baris,
    this.tambahan,
  });

  final IconData ikon;
  final Color warna;
  final String judul;
  final List<String> baris;
  final Widget? tambahan;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: warna.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(ikon, color: warna, size: 23),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              judul,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, height: 1.25),
            ),
            for (final b in baris)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(b, style: const TextStyle(fontSize: 12.5, height: 1.35, color: TemaAplikasi.redup)),
              ),
          ],
        ),
      ),
      if (tambahan != null) ...[const SizedBox(width: 8), tambahan!],
    ],
  );
}

class _ButirLegenda {
  const _ButirLegenda(this.warna, this.label, {this.titik = false});
  final Color warna;
  final String label;
  final bool titik;
}

class _Legenda extends StatelessWidget {
  const _Legenda({required this.butir});

  final List<_ButirLegenda> butir;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 6, offset: Offset(0, 2))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final b in butir)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: b.titik ? b.warna : b.warna.withValues(alpha: 0.2),
                    shape: b.titik ? BoxShape.circle : BoxShape.rectangle,
                    borderRadius: b.titik ? null : BorderRadius.circular(3),
                    border: Border.all(color: b.titik ? Colors.white : b.warna, width: 1.5),
                  ),
                ),
                const SizedBox(width: 6),
                Text(b.label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
      ],
    ),
  );
}
