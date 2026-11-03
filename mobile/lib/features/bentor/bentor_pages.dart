import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/daftar_berhalaman.dart';
import '../../core/format.dart';
import '../../core/komponen_ui.dart';
import '../../core/models/operasional.dart';
import '../../core/models/transaksi.dart';
import '../../core/peta.dart';
import '../../core/repositories.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../akun/akun_pages.dart';
import '../auth/auth_controller.dart';

final armadaBentorProvider = FutureProvider.autoDispose<Armada>(
  (ref) => ref.watch(bentorRepositoryProvider).armada(),
);

class BentorBerandaPage extends ConsumerStatefulWidget {
  const BentorBerandaPage({super.key});

  @override
  ConsumerState<BentorBerandaPage> createState() => _BentorBerandaPageState();
}

final _petaTugasProvider = FutureProvider.autoDispose<List<Penjemputan>>(
  (ref) async => (await ref.watch(bentorRepositoryProvider).tugas()).items,
);
final _selesaiBentorProvider = FutureProvider.autoDispose<int>(
  (ref) async =>
      (await ref.watch(bentorRepositoryProvider).tugas(status: 'selesai'))
          .total,
);

class _BentorBerandaPageState extends ConsumerState<BentorBerandaPage> {
  final _daftar = GlobalKey<DaftarBerhalamanState<Penjemputan>>();
  int _tab = 0;
  int? _unggulanId;
  bool _adaAntrean = false;

  Future<void> _buka(Penjemputan t) async {
    await context.push('/bentor/tugas/${t.id}', extra: t);
    _daftar.currentState?.segarkan();
    ref.invalidate(armadaBentorProvider);
    ref.invalidate(_petaTugasProvider);
    ref.invalidate(_selesaiBentorProvider);
  }

  Future<void> _aktif(Armada a, bool aktif) async {
    final ok = await jalankan(
      context,
      () => ref
          .read(bentorRepositoryProvider)
          .ubahStatusArmada(aktif ? 'siaga' : 'nonaktif'),
      sukses: aktif ? 'Anda siaga.' : 'Anda sedang istirahat.',
    );
    if (ok) {
      ref.invalidate(armadaBentorProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final armada = ref.watch(armadaBentorProvider);
    final selesai = ref.watch(_selesaiBentorProvider);
    final user = ref.watch(authProvider).value;
    return Scaffold(
      extendBody: true,
      appBar: HeaderPeran(
        judul: user?.name ?? 'Bentor',
        subjudul: 'Bentor · ${user?.bankSampah?.nama ?? 'Bank sampah'}',
        inisial: 'BT',
        aksi: armada.when(
          loading: () => const SizedBox(
            width: 40,
            height: 20,
            child: LinearProgressIndicator(),
          ),
          error: (_, _) => IconButton(
            onPressed: () => ref.invalidate(armadaBentorProvider),
            icon: const Icon(Icons.refresh),
          ),
          data: (a) => Container(
            padding: const EdgeInsets.only(left: 10, right: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: TemaAplikasi.garis),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  a.status == 'nonaktif' ? 'Istirahat' : 'Aktif',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Tooltip(
                  message: 'Ketersediaan menerima tugas',
                  child: Switch(
                    value: a.status != 'nonaktif',
                    onChanged: a.status == 'bertugas'
                        ? null
                        : (v) => _aktif(a, v),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigasiPill(
        index: _tab,
        onPilih: (i) {
          if (i == _tab) {
            return;
          }
          setState(() => _tab = i);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _daftar.currentState?.segarkan();
            }
          });
        },
        tujuan: const [
          (ikon: Icons.assignment_outlined, label: 'Tugas'),
          (ikon: Icons.map_outlined, label: 'Peta'),
          (ikon: Icons.history, label: 'Riwayat'),
          (ikon: Icons.person_outline, label: 'Profil'),
        ],
      ),
      body: PindahTab(
        indeks: _tab,
        child: _tab == 3
          ? const AkunIsi()
          : _tab == 1
          ? _PetaTugasBentor(onBuka: _buka)
          : DaftarBerhalaman<Penjemputan>(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              key: _daftar,
              muat: (hal) async {
                if (hal == 1 &&
                    (_daftar.currentState?.sudahPernahMuat ?? false)) {
                  ref.invalidate(armadaBentorProvider);
                }
                final hasil = await ref
                    .read(bentorRepositoryProvider)
                    .tugas(status: _tab == 2 ? 'selesai' : null, halaman: hal);
                if (hal == 1) {
                  _unggulanId = hasil.items
                      .where(
                        (t) =>
                            t.status == 'dijadwalkan' || t.status == 'menuju',
                      )
                      .firstOrNull
                      ?.id;
                  _adaAntrean = hasil.items.length > 1;
                }
                return hasil;
              },
              kosong: 'Belum ada tugas jemput.\nTunggu penugasan dari operator bank sampah.',
              header: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_tab == 2) ...[
                      const Text(
                        'Riwayat penjemputan',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      Semantics(
                        label: 'Tugas jemput',
                        child: KartuHero(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Tugas aktif',
                                style: TextStyle(
                                  color: Color(0xFFD5EBDC),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              AngkaNaik(
                                nilai: (armada.value?.tugasAktif ?? 0).toDouble(),
                                format: (v) => angka(v.round()),
                                style: const TextStyle(
                                  fontSize: 34,
                                  letterSpacing: -1,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  KotakAngkaHero(
                                    'Selesai',
                                    angka(selesai.value ?? 0),
                                  ),
                                  const SizedBox(width: 8),
                                  KotakAngkaHero(
                                    'Kapasitas',
                                    armada.value?.kapasitasKg == null
                                        ? '—'
                                        : kg(armada.value!.kapasitasKg),
                                  ),
                                  const SizedBox(width: 8),
                                  KotakAngkaHero(
                                    'Armada',
                                    switch (armada.value?.status) {
                                      'siaga' => 'Siaga',
                                      'bertugas' => 'Bertugas',
                                      'nonaktif' => 'Istirahat',
                                      _ => '—',
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (armada.value?.status == 'nonaktif')
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDEFDC),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.pause_circle_outline,
                                color: Color(0xFF9A3412),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Kamu sedang istirahat. Aktifkan status untuk menerima tugas.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              itemBuilder: (context, t, segarkan) {
                final unggulan = _tab == 0 && t.id == _unggulanId;
                if (!unggulan) {
                  return Card(
                    child: ListTile(
                      leading: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: TemaAplikasi.latar,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          t.id.toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      title: Text(
                        t.warga?.name ?? 'Warga',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        t.alamat,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _buka(t),
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const JudulBagian('Tugas berikutnya'),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: TemaAplikasi.hijauLembut,
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: Text(
                                      tanggalJam(t.jadwalAt),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: TemaAplikasi.hijau,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '#${t.id}',
                                  style: const TextStyle(
                                    color: TemaAplikasi.redup,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              t.warga?.name ?? 'Warga',
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 16,
                                  color: TemaAplikasi.hijau,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    t.alamat,
                                    style: const TextStyle(
                                      color: TemaAplikasi.redup,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final s in [
                                  labelStatusJemput[t.status] ?? t.status,
                                  if (t.perkiraanKg != null)
                                    '±${kg(t.perkiraanKg)}',
                                ])
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: TemaAplikasi.latar,
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: Text(
                                      s,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final ok = await launchUrl(
                                        Uri.parse(
                                          'https://www.google.com/maps/dir/?api=1&destination=${t.lat},${t.lng}',
                                        ),
                                        mode: LaunchMode.externalApplication,
                                      );
                                      if (!ok && context.mounted) {
                                        tampilPesan(
                                          context,
                                          'Tidak bisa membuka navigasi.',
                                          gagal: true,
                                        );
                                      }
                                    },
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 48),
                                    ),
                                    icon: const Icon(
                                      Icons.navigation_outlined,
                                      size: 16,
                                    ),
                                    label: const Text('Navigasi'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () => _buka(t),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: TemaAplikasi.hijauPekat,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(0, 48),
                                    ),
                                    child: Text(
                                      t.status == 'dijadwalkan'
                                          ? 'Mulai jemput'
                                          : 'Lanjut jemput',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_adaAntrean) ...[
                      const SizedBox(height: 20),
                      const JudulBagian('Antrean tugas'),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
      ),
    );
  }
}

class _PetaTugasBentor extends ConsumerWidget {
  const _PetaTugasBentor({required this.onBuka});
  final ValueChanged<Penjemputan> onBuka;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasil = ref.watch(_petaTugasProvider);
    return TampilanAsync(
      nilai: hasil,
      onUlang: () => ref.invalidate(_petaTugasProvider),
      data: (tugas) {
        final aktif = tugas.where((t) => t.status != 'selesai').toList();
        return Stack(
          children: [
            Positioned.fill(
              child: PetaOsm(
                pusat: aktif.isEmpty
                    ? pusatTubaba
                    : LatLng(aktif.first.lat, aktif.first.lng),
                zoom: aktif.isEmpty ? 10 : 15,
                kontrolZoom: true,
                // Sisakan ruang agar titik tidak tertutup kartu atas dan daftar bawah
                batas: [for (final t in aktif) LatLng(t.lat, t.lng)],
                paddingBatas: const EdgeInsets.fromLTRB(48, 100, 48, 400),
                jarakBawah: 96,
                titik: [
                  for (final t in aktif)
                    TitikPeta(
                      titik: LatLng(t.lat, t.lng),
                      label: t.warga?.name ?? t.alamat,
                      ikon: Icons.home_rounded,
                      onTap: () => onBuka(t),
                    ),
                ],
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              top: 12,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.route_outlined,
                        color: TemaAplikasi.hijau,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Titik jemput · ${aktif.length} lokasi',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 110,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 260),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: TemaAplikasi.garis),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daftar titik jemput',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (aktif.isEmpty)
                      const Text(
                        'Belum ada tugas yang ditugaskan.',
                        style: TextStyle(
                          fontSize: 12,
                          color: TemaAplikasi.redup,
                        ),
                      )
                    else
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          children: [
                            for (final (i, t) in aktif.indexed)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: TemaAplikasi.hijauLembut,
                                  child: Text('${i + 1}'),
                                ),
                                title: Text(
                                  t.warga?.name ?? 'Warga',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  t.alamat,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => onBuka(t),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class DetailTugasPage extends ConsumerStatefulWidget {
  const DetailTugasPage({super.key, required this.tugas});

  final Penjemputan tugas;

  @override
  ConsumerState<DetailTugasPage> createState() => _DetailTugasPageState();
}

class _DetailTugasPageState extends ConsumerState<DetailTugasPage> {
  late Penjemputan _t = widget.tugas;
  bool _mengubah = false;

  Future<void> _buka(Uri uri, String gagal) async {
    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    ).catchError((_) => false);
    if (!ok && mounted) tampilPesan(context, gagal, gagal: true);
  }

  Future<void> _ubahStatus(String status) async {
    final pesan = status == 'menuju'
        ? 'Mulai menuju lokasi warga?'
        : 'Sampah sudah diambil dari warga?';
    if (!await konfirmasi(context, 'Ubah status', pesan)) return;
    if (!mounted) return;
    setState(() => _mengubah = true);
    final ok = await jalankan(
      context,
      () async {
        final baru = await ref
            .read(bentorRepositoryProvider)
            .ubahStatusTugas(_t.id, status);
        setState(() => _t = baru);
      },
      sukses: status == 'menuju'
          ? 'Selamat jalan! Status: menuju.'
          : 'Tercatat diambil. Lanjut timbang sampahnya.',
    );
    if (mounted) setState(() => _mengubah = false);
    if (ok) ref.invalidate(armadaBentorProvider);
    if (ok && status == 'diambil' && mounted) await _timbang();
  }

  Future<void> _timbang() async {
    final selesai = await context.push<bool>(
      '/bentor/tugas/${_t.id}/timbang',
      extra: _t,
    );
    if (selesai == true && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final titik = LatLng(_t.lat, _t.lng);
    final hp = _t.warga?.phone;

    return Scaffold(
      appBar: AppBar(title: const Text('Konfirmasi jemput')),
      body: ListView(
        children: [
          SizedBox(
            height: 240,
            child: PetaOsm(
              pusat: titik,
              zoom: 15,
              interaktif: false,
              kontrolZoom: true,
              penanda: [penandaPin(titik, warna: TemaAplikasi.hijau, ikon: Icons.home_rounded)],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _t.warga?.name ?? '-',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    LabelStatus(
                      labelStatusJemput[_t.status] ?? _t.status,
                      warna: warnaStatus(_t.status),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(_t.alamat),
                const SizedBox(height: 4),
                Text('Jadwal: ${tanggalJam(_t.jadwalAt)}'),
                if (_t.perkiraanKg != null)
                  Text('Perkiraan: ${kg(_t.perkiraanKg)}'),
                if (_t.catatan != null) Text('Catatan warga: ${_t.catatan}'),
                if (_t.fotoUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _t.fotoUrl!,
                        height: 160,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _buka(
                          Uri.parse(
                            'https://www.google.com/maps/dir/?api=1&destination=${_t.lat},${_t.lng}',
                          ),
                          'Tidak bisa membuka Google Maps.',
                        ),
                        icon: const Icon(Icons.directions),
                        label: const Text('Google Maps'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: hp == null
                            ? null
                            : () => _buka(
                                Uri(scheme: 'tel', path: hp),
                                'Tidak bisa membuka aplikasi telepon.',
                              ),
                        icon: const Icon(Icons.phone),
                        label: const Text('Telepon'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_t.status == 'dijadwalkan')
                  FilledButton.icon(
                    onPressed: _mengubah ? null : () => _ubahStatus('menuju'),
                    icon: const Icon(Icons.navigation),
                    label: const Text('Mulai: Menuju lokasi'),
                  ),
                if (_t.status == 'menuju')
                  FilledButton.icon(
                    onPressed: _mengubah ? null : () => _ubahStatus('diambil'),
                    icon: const Icon(Icons.inventory_2),
                    label: const Text('Sampah sudah diambil'),
                  ),
                if (_t.status == 'diambil') ...[
                  FilledButton.icon(
                    onPressed: _mengubah ? null : _timbang,
                    icon: const Icon(Icons.scale_outlined),
                    label: const Text('Timbang sampah'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Hasil timbang langsung menambah saldo warga. Kalau tidak bisa menimbang di lokasi, operator dapat mencatatnya di bank sampah.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
