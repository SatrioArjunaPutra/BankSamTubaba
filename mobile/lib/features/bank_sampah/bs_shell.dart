import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/daftar_berhalaman.dart';
import '../../core/format.dart';
import '../../core/komponen_ui.dart';
import '../../core/models/operasional.dart';
import '../../core/models/transaksi.dart';
import '../../core/repositories.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../auth/auth_controller.dart';
import '../warga/warga_shell.dart' show KartuSetoran;
import 'bs_providers.dart';
import 'nasabah_tab.dart';

/// Kerangka operator bank sampah: Beranda, Setoran, Jemput, Bentor, Lainnya.
class BsShell extends ConsumerStatefulWidget {
  const BsShell({super.key});

  @override
  ConsumerState<BsShell> createState() => _BsShellState();
}

class _BsShellState extends ConsumerState<BsShell> {
  int _tab = 0;
  final _setoran = GlobalKey<DaftarBerhalamanState<Setoran>>();

  Future<void> _catatSetoran([Penjemputan? dariJemput]) async {
    final ok = await context.push<bool>('/bs/setoran/baru', extra: dariJemput);
    if (ok == true) {
      _setoran.currentState?.segarkan();
      ref.invalidate(dashboardBsProvider);
    }
  }

  Future<void> _batalkanSetoran(Setoran s, VoidCallback segarkan) async {
    final alasan = await showDialog<String>(
      context: context,
      builder: (_) => _DialogBatalSetoran(setoran: s),
    );
    if (alasan == null || !mounted) return;
    final ok = await jalankan(
      context,
      () => ref.read(bankSampahRepositoryProvider).batalkanSetoran(s.id, alasan),
      sukses: 'Setoran dibatalkan. Catat ulang setoran yang benar bila perlu.',
    );
    if (!ok) return;
    segarkan();
    ref.invalidate(dashboardBsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final bank = ref.watch(authProvider).value?.bankSampah;

    return Scaffold(
      extendBody: true,
      appBar: HeaderPeran(
        judul: bank?.nama ?? 'Bank Sampah',
        subjudul: 'Pengelola · Tubaba',
        ikon: Icons.storefront_outlined,
        aksi: IconButton(
          style: gayaTombolKepala,
          tooltip: 'Permintaan jemput',
          onPressed: () => setState(() => _tab = 2),
          icon: const Icon(Icons.notifications_none_outlined),
        ),
      ),
      body: PindahTab(
        indeks: _tab,
        child: IndexedStack(
        index: _tab,
        children: [
          BerandaBs(
            keTab: (i) => setState(() => _tab = i),
            catat: _catatSetoran,
          ),
          DaftarBerhalaman<Setoran>(
            key: _setoran,
            muat: (hal) =>
                ref.read(bankSampahRepositoryProvider).setoran(halaman: hal),
            kosong: 'Belum ada setoran.',
            adaFab: true,
            pemisah: 0,
            itemBuilder: (_, s, segarkan) => KartuSetoran(
              setoran: s,
              tampilkanWarga: true,
              onBatalkan: () => _batalkanSetoran(s, segarkan),
            ),
          ),
          _JemputTab(catat: _catatSetoran),
          const _BentorTab(),
          _Lainnya(
            onSetoran: () => setState(() => _tab = 1),
            onBentor: () => setState(() => _tab = 3),
          ),
          const NasabahTab(),
        ],
      ),
      ),
      bottomNavigationBar: NavigasiPill(
        index: switch (_tab) {
          2 => 1,
          5 => 3,
          4 => 4,
          _ => 0,
        },
        aksiTengah: 2,
        labelTengah: 'Catat',
        onPilih: (i) {
          if (i == 2) {
            _catatSetoran();
          } else {
            setState(() => _tab = [0, 2, 0, 5, 4][i]);
          }
        },
        tujuan: const [
          (ikon: Icons.home_outlined, label: 'Beranda'),
          (ikon: Icons.local_shipping_outlined, label: 'Jemput'),
          (ikon: Icons.add, label: 'Catat setoran'),
          (ikon: Icons.people_outline, label: 'Nasabah'),
          (ikon: Icons.person_outline, label: 'Profil'),
        ],
      ),
    );
  }
}

/// Ringkasan hari ini & bulan ini. Tombol Catat Setoran ada di FAB kerangka.
class BerandaBs extends ConsumerWidget {
  const BerandaBs({super.key, required this.keTab, this.catat});

  final ValueChanged<int> keTab;
  final VoidCallback? catat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(dashboardBsProvider);
    final permintaan = ref.watch(permintaanBaruBsProvider);

    Widget kotak(
      String label,
      String nilai,
      IconData ikon, {
      VoidCallback? onTap,
      Color? warna,
    }) => Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (warna ?? TemaAplikasi.hijau).withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(ikon, color: warna ?? TemaAplikasi.hijau, size: 22),
              ),
              const SizedBox(height: 8),
              // Angka panjang mengecil agar tetap satu baris; label boleh turun baris
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  nilai,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardBsProvider);
        await ref.read(dashboardBsProvider.future);
      },
      child: TampilanAsync(
        nilai: dash,
        onUlang: () => ref.invalidate(dashboardBsProvider),
        data: (d) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: paddingAman(
            context,
            dasar: const EdgeInsets.all(20),
            adaFab: true,
          ),
          children: [
            KartuHero(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sampah masuk hari ini',
                    style: TextStyle(
                      color: Color(0xFFD5EBDC),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  AngkaNaik(
                    nilai: d.hariIni.totalKg,
                    format: kg,
                    style: const TextStyle(
                      fontSize: 34,
                      letterSpacing: -1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      KotakAngkaHero('Setoran', angka(d.hariIni.jumlah)),
                      const SizedBox(width: 8),
                      KotakAngkaHero('Donasi', kg(d.hariIni.kgDonasi)),
                      const SizedBox(width: 8),
                      KotakAngkaHero('Nilai', rupiah(d.hariIni.totalNilai)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            IntrinsicHeight(
              child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AksiCepat(
                  ikon: Icons.sell_outlined,
                  label: 'Atur harga',
                  onTap: () => context.push('/bs/harga'),
                  utama: true,
                ),
                AksiCepat(
                  ikon: Icons.two_wheeler_outlined,
                  label: 'Bentor',
                  onTap: () => keTab(3),
                ),
                AksiCepat(
                  ikon: Icons.account_balance_wallet_outlined,
                  label: 'Penarikan',
                  warna: const Color(0xFFB45309),
                  latar: const Color(0xFFFEF3C7),
                  onTap: () => context.push('/bs/penarikan'),
                ),
                AksiCepat(
                  ikon: Icons.factory_outlined,
                  label: 'Pengepul',
                  onTap: () => context.push('/bs/pengepul'),
                ),
              ],
              ),
            ),
            const SizedBox(height: 14),
            KartuAjakan(
              ikon: Icons.map_outlined,
              warna: TemaAplikasi.hijau,
              latar: TemaAplikasi.hijauLembut,
              judul: 'Peta wilayah',
              keterangan: 'Lokasi bank sampah dan titik jemput warga.',
              onTap: () => context.push('/bs/peta'),
            ),
            const SizedBox(height: 16),
            JudulBagian(
              'Permintaan jemput',
              aksi: 'Lihat semua',
              onTap: () => keTab(2),
            ),

            if (permintaan.isLoading)
              const LinearProgressIndicator(minHeight: 2)
            else if (permintaan.hasError)
              Card(
                child: ListTile(
                  title: const Text('Permintaan belum dapat dimuat'),
                  trailing: IconButton(
                    onPressed: () => ref.invalidate(permintaanBaruBsProvider),
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              )
            else if ((permintaan.value ?? []).isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_shipping_outlined,
                        color: TemaAplikasi.redup,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Belum ada permintaan jemput baru.',
                          style: TextStyle(
                            fontSize: 13,
                            color: TemaAplikasi.redup,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              for (final p in permintaan.value!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFFE8F1FD),
                                child: Text(
                                  p.warga?.name.substring(0, 1) ?? 'W',
                                  style: const TextStyle(
                                    color: Color(0xFF1D4ED8),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.warga?.name ?? 'Warga',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      p.alamat,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: TemaAplikasi.redup,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 22),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p.perkiraanKg == null
                                      ? 'Menunggu penugasan'
                                      : 'Perkiraan ${kg(p.perkiraanKg)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: TemaAplikasi.redup,
                                  ),
                                ),
                              ),
                              FilledButton(
                                onPressed: () async {
                                  final ok = await tampilkanSheet<bool>(
                                    context,
                                    (_) => _FormJadwal(penjemputan: p),
                                  );
                                  if (ok == true) {
                                    ref.invalidate(permintaanBaruBsProvider);
                                    ref.invalidate(dashboardBsProvider);
                                  }
                                },
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 40),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Tugaskan'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            const SizedBox(height: 24),
            const JudulBagian('Bulan ini'),
            const SizedBox(height: 8),
            _Kisi2(
              children: [
                kotak(
                  'Berat terkumpul',
                  kg(d.bulanIni.totalKg),
                  Icons.recycling,
                ),
                kotak(
                  'Nilai setoran',
                  rupiah(d.bulanIni.totalNilai),
                  Icons.payments_outlined,
                ),
                kotak(
                  'Jemput baru',
                  angka(d.jemputDiajukan),
                  Icons.notifications_active_outlined,
                  warna: d.jemputDiajukan > 0 ? Colors.orange.shade800 : null,
                  onTap: () => keTab(2),
                ),
                kotak(
                  'Jemput berjalan',
                  angka(d.jemputBerjalan),
                  Icons.local_shipping_outlined,
                  onTap: () => keTab(2),
                ),
                kotak(
                  'Penarikan menunggu',
                  '${d.penarikanDiajukan} · ${rupiah(d.totalPenarikanDiajukan)}',
                  Icons.account_balance_wallet_outlined,
                  warna: d.penarikanDiajukan > 0
                      ? Colors.orange.shade800
                      : null,
                  onTap: () => context.push('/bs/penarikan'),
                ),
                kotak(
                  '${angka(d.jumlahNasabah)} nasabah',
                  rupiah(d.totalSaldoNasabah),
                  Icons.people_outline,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Kisi dua kolom yang tinggi tiap barisnya mengikuti isi kartu tertinggi.
/// Pengganti GridView dengan rasio tetap, yang terpotong saat huruf sistem
/// diperbesar atau layar sempit.
class _Kisi2 extends StatelessWidget {
  const _Kisi2({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < children.length; i += 2)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: children[i]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: i + 1 < children.length
                        ? children[i + 1]
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _JemputTab extends StatelessWidget {
  const _JemputTab({required this.catat});

  final Future<void> Function([Penjemputan?]) catat;

  static const _tab = [
    ('Baru', 'diajukan'),
    ('Dijadwalkan', 'dijadwalkan,menuju'),
    ('Diambil', 'diambil'),
    ('Riwayat', 'selesai,ditolak,dibatalkan'),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tab.length,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final t in _tab) Tab(text: t.$1)],
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final t in _tab)
                  _DaftarJemputBs(status: t.$2, catat: catat),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DaftarJemputBs extends ConsumerWidget {
  const _DaftarJemputBs({required this.status, required this.catat});

  final String status;
  final Future<void> Function([Penjemputan?]) catat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DaftarBerhalaman<Penjemputan>(
      muat: (hal) => ref
          .read(bankSampahRepositoryProvider)
          .penjemputan(status, halaman: hal),
      kosong: 'Tidak ada penjemputan.',
      itemBuilder: (context, p, segarkan) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      p.warga?.name ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  LabelStatus(
                    labelStatusJemput[p.status] ?? p.status,
                    warna: warnaStatus(p.status),
                  ),
                ],
              ),
              Text(p.alamat),
              Text(
                '${p.warga?.phone ?? ''} · diajukan ${tanggalJam(p.createdAt)}',
                style: const TextStyle(fontSize: 12),
              ),
              if (p.perkiraanKg != null) Text('Perkiraan ${kg(p.perkiraanKg)}'),
              if (p.catatan != null) Text('Catatan: ${p.catatan}'),
              if (p.jadwalAt != null)
                Text(
                  'Jadwal ${tanggalJam(p.jadwalAt)} · ${p.driver?.name ?? ''} (${p.platNomor ?? ''})',
                ),
              if (p.fotoUrl != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      p.fotoUrl!,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              if (p.status == 'diajukan')
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () async {
                        final alasan = await _mintaAlasan(context);
                        if (alasan == null || !context.mounted) return;
                        final ok = await jalankan(
                          context,
                          () => ref
                              .read(bankSampahRepositoryProvider)
                              .tolakJemput(p.id, alasan),
                          sukses: 'Penjemputan ditolak.',
                        );
                        if (ok) segarkan();
                      },
                      child: const Text('Tolak'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 40),
                      ),
                      onPressed: () async {
                        final ok = await tampilkanSheet<bool>(
                          context,
                          (_) => _FormJadwal(penjemputan: p),
                        );
                        if (ok == true) segarkan();
                      },
                      child: const Text('Jadwalkan'),
                    ),
                  ],
                ),
              if (p.status == 'diambil')
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                    ),
                    onPressed: () async {
                      await catat(p);
                      segarkan();
                    },
                    icon: const Icon(Icons.scale),
                    label: const Text('Catat Setoran'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _mintaAlasan(BuildContext context) {
    final teks = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (c) => DialogAplikasi(
        judul: 'Tolak penjemputan',
        isi: TextField(
          controller: teks,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Alasan'),
        ),
        aksi: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              c,
              teks.text.trim().isEmpty ? null : teks.text.trim(),
            ),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
  }
}

class _FormJadwal extends ConsumerStatefulWidget {
  const _FormJadwal({required this.penjemputan});

  final Penjemputan penjemputan;

  @override
  ConsumerState<_FormJadwal> createState() => _FormJadwalState();
}

class _FormJadwalState extends ConsumerState<_FormJadwal> {
  int? _armadaId;
  DateTime _jadwal = DateTime.now().add(const Duration(hours: 1));
  bool _menyimpan = false;

  Future<void> _pilihWaktu() async {
    final tgl = await showDatePicker(
      context: context,
      initialDate: _jadwal,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (tgl == null || !mounted) return;
    final jam = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_jadwal),
    );
    if (jam == null) return;
    setState(
      () => _jadwal = DateTime(
        tgl.year,
        tgl.month,
        tgl.day,
        jam.hour,
        jam.minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final armada = ref.watch(armadaBsProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: TampilanAsync(
        nilai: armada,
        onUlang: () => ref.invalidate(armadaBsProvider),
        data: (data) {
          final tersedia = data.$1
              .where((a) => a.status != 'nonaktif')
              .toList();
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Jadwalkan penjemputan',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (tersedia.isEmpty)
                const Text(
                  'Belum ada armada aktif. Tambahkan bentor di tab Bentor.',
                ),
              RadioGroup<int>(
                groupValue: _armadaId,
                onChanged: (v) => setState(() => _armadaId = v),
                child: Column(
                  children: [
                    for (final a in tersedia)
                      RadioListTile<int>(
                        value: a.id,
                        title: Text(
                          '${a.driver?.name ?? '-'} · ${a.platNomor}',
                        ),
                        subtitle: Text(
                          '${a.status} · ${a.tugasAktif} tugas berjalan',
                        ),
                      ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.event),
                title: Text(tanggalJam(_jadwal)),
                subtitle: const Text('Ketuk untuk mengubah waktu'),
                onTap: _pilihWaktu,
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _armadaId == null || _menyimpan
                    ? null
                    : () async {
                        setState(() => _menyimpan = true);
                        final ok = await jalankan(
                          context,
                          () => ref
                              .read(bankSampahRepositoryProvider)
                              .jadwalkan(
                                widget.penjemputan.id,
                                _armadaId!,
                                _jadwal,
                              ),
                          sukses: 'Penjemputan dijadwalkan.',
                        );
                        if (!context.mounted) return;
                        setState(() => _menyimpan = false);
                        if (ok) {
                          ref.invalidate(armadaBsProvider);
                          Navigator.pop(context, true);
                        }
                      },
                child: const Text('Simpan jadwal'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BentorTab extends ConsumerWidget {
  const _BentorTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(armadaBsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(armadaBsProvider);
        await ref.read(armadaBsProvider.future);
      },
      child: TampilanAsync(
        nilai: data,
        onUlang: () => ref.invalidate(armadaBsProvider),
        data: (d) {
          final (armada, tanpaArmada) = d;
          return ListView(
            padding: paddingAman(context, dasar: const EdgeInsets.all(12)),
            children: [
              FilledButton.icon(
                onPressed: () async {
                  if (await context.push<bool>('/bs/bentor/baru') == true) {
                    ref.invalidate(armadaBsProvider);
                  }
                },
                icon: const Icon(Icons.person_add),
                label: const Text('Tambah akun bentor'),
              ),
              const SizedBox(height: 12),
              if (armada.isEmpty) const Kosong(pesan: 'Belum ada armada.'),
              for (final a in armada) _KartuArmada(armada: a),
              if (tanpaArmada.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Bentor tanpa armada',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                for (final u in tanpaArmada)
                  Card(
                    child: ListTile(
                      title: Text(u.name),
                      subtitle: Text(u.phone ?? u.email),
                      trailing: TextButton(
                        onPressed: () async {
                          final plat = await _mintaPlat(context);
                          if (plat == null || !context.mounted) return;
                          final ok = await jalankan(
                            context,
                            () => ref
                                .read(bankSampahRepositoryProvider)
                                .tambahArmada(u.id, plat, null),
                            sukses: 'Armada ditambahkan.',
                          );
                          if (ok) ref.invalidate(armadaBsProvider);
                        },
                        child: const Text('Beri armada'),
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<String?> _mintaPlat(BuildContext context) {
    final teks = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (c) => DialogAplikasi(
        judul: 'Plat nomor bentor',
        isi: TextField(
          controller: teks,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'BE 1234 AB'),
        ),
        aksi: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              c,
              teks.text.trim().isEmpty ? null : teks.text.trim(),
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

class _KartuArmada extends ConsumerWidget {
  const _KartuArmada({required this.armada});

  final Armada armada;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = armada;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.two_wheeler)),
        title: Text('${a.driver?.name ?? '-'} · ${a.platNomor}'),
        subtitle: Text(
          '${a.driver?.phone ?? ''}${a.driverAktif ? '' : ' · AKUN NONAKTIF'}\n'
          '${a.tugasAktif} tugas berjalan${a.kapasitasKg != null ? ' · kapasitas ${kg(a.kapasitasKg)}' : ''}',
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          tooltip: 'Ubah status',
          onSelected: (pilihan) async {
            final repo = ref.read(bankSampahRepositoryProvider);
            final bool ok;
            if (pilihan.startsWith('akun-')) {
              final aktif = pilihan == 'akun-aktif';
              if (!aktif &&
                  !await konfirmasi(
                    context,
                    'Nonaktifkan akun ${a.driver?.name}?',
                    'Driver langsung keluar dari aplikasi di semua perangkat dan armadanya ikut nonaktif.',
                    ya: 'Nonaktifkan',
                  )) {
                return;
              }
              if (!context.mounted) return;
              ok = await jalankan(
                context,
                () => repo.ubahStatusAkunBentor(a.driver!.id, aktif),
                sukses: aktif
                    ? 'Akun driver diaktifkan. Aktifkan juga armadanya (Siaga).'
                    : 'Akun driver dinonaktifkan.',
              );
            } else {
              ok = await jalankan(
                context,
                () => repo.ubahArmada(a.id, {'status': pilihan}),
                sukses: 'Status armada diubah.',
              );
            }
            if (ok) ref.invalidate(armadaBsProvider);
          },
          itemBuilder: (_) => [
            if (a.driverAktif)
              const PopupMenuItem(value: 'siaga', child: Text('Armada: Siaga')),
            const PopupMenuItem(
              value: 'nonaktif',
              child: Text('Armada: Nonaktif'),
            ),
            const PopupMenuDivider(),
            if (a.driverAktif)
              const PopupMenuItem(
                value: 'akun-nonaktif',
                child: Text('Nonaktifkan akun driver'),
              )
            else
              const PopupMenuItem(
                value: 'akun-aktif',
                child: Text('Aktifkan akun driver'),
              ),
          ],
          child: LabelStatus(
            a.driverAktif ? a.status : 'akun nonaktif',
            warna: warnaStatus(a.driverAktif ? a.status : 'nonaktif'),
          ),
        ),
      ),
    );
  }
}

class _Lainnya extends ConsumerWidget {
  const _Lainnya({required this.onSetoran, required this.onBentor});
  final VoidCallback onSetoran;
  final VoidCallback onBentor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: paddingAman(context, dasar: const EdgeInsets.all(20)),
      children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.storefront_outlined)),
            title: Text(
              ref.watch(authProvider).value?.name ?? 'Pengelola',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text('Operator bank sampah'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/akun'),
          ),
        ),
        const SizedBox(height: 20),
        ListTile(
          leading: const Icon(Icons.receipt_long_outlined),
          title: const Text('Riwayat setoran'),
          onTap: onSetoran,
        ),
        ListTile(
          leading: const Icon(Icons.two_wheeler_outlined),
          title: const Text('Kelola bentor'),
          onTap: onBentor,
        ),
        ListTile(
          leading: const Icon(Icons.map_outlined),
          title: const Text('Peta titik tempat sampah'),
          subtitle: const Text('Batas polygon Panaragan & titik TPS'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/bs/peta'),
        ),
        ListTile(
          leading: const Icon(Icons.sell_outlined),
          title: const Text('Atur harga sampah'),
          onTap: () => context.push('/bs/harga'),
        ),
        ListTile(
          leading: const Icon(Icons.account_balance_wallet_outlined),
          title: const Text('Persetujuan penarikan saldo'),
          onTap: () async {
            await context.push('/bs/penarikan');
            ref.invalidate(dashboardBsProvider);
          },
        ),
        ListTile(
          leading: const Icon(Icons.factory_outlined),
          title: const Text('Penjualan ke pengepul'),
          onTap: () => context.push('/bs/pengepul'),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: const Text('Akun saya'),
          onTap: () => context.push('/akun'),
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Keluar'),
          onTap: () async {
            if (await konfirmasi(
              context,
              'Keluar?',
              'Anda perlu login lagi untuk memakai aplikasi.',
              ya: 'Keluar',
            )) {
              await ref.read(authProvider.notifier).logout();
            }
          },
        ),
      ],
    );
  }
}

class _DialogBatalSetoran extends StatefulWidget {
  const _DialogBatalSetoran({required this.setoran});

  final Setoran setoran;

  @override
  State<_DialogBatalSetoran> createState() => _DialogBatalSetoranState();
}

class _DialogBatalSetoranState extends State<_DialogBatalSetoran> {
  final _alasan = TextEditingController();
  String? _galat;

  @override
  void dispose() {
    _alasan.dispose();
    super.dispose();
  }

  void _kirim() {
    final isi = _alasan.text.trim();
    if (isi.length < 3) {
      setState(() => _galat = 'Tulis alasan pembatalan.');
      return;
    }
    Navigator.pop(context, isi);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.setoran;
    return DialogAplikasi(
      judul: 'Batalkan setoran?',
      isi: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.donasi
                ? 'Donasi ${kg(s.totalKg)} dari ${s.namaWarga ?? '-'} dibatalkan. Saldo tidak berubah.'
                : 'Saldo ${s.namaWarga ?? '-'} berkurang ${rupiah(s.totalNilai)}.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _alasan,
            autofocus: true,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: 'Alasan',
              hintText: 'Misalnya salah timbang',
              errorText: _galat,
            ),
          ),
        ],
      ),
      aksi: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Kembali'),
        ),
        FilledButton(onPressed: _kirim, child: const Text('Batalkan setoran')),
      ],
    );
  }
}
