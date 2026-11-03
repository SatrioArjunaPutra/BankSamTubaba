import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/daftar_berhalaman.dart';
import '../../core/format.dart';
import '../../core/komponen_ui.dart';
import '../../core/models/bank_sampah.dart';
import '../../core/models/transaksi.dart';
import '../../core/repositories.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../auth/auth_controller.dart';
import '../berita/berita_pages.dart';
import '../berita/berita_repository.dart';
import '../preloved/chat_pages.dart';
import '../preloved/preloved_tab.dart';
import 'warga_providers.dart';

/// Kerangka warga: Beranda, Jemput, Preloved, Chat, Akun.
class WargaShell extends ConsumerStatefulWidget {
  const WargaShell({super.key});

  @override
  ConsumerState<WargaShell> createState() => _WargaShellState();
}

class _WargaShellState extends ConsumerState<WargaShell> {
  int _tab = 0;
  final _daftarJemput = GlobalKey<DaftarBerhalamanState<Penjemputan>>();
  final _preloved = GlobalKey<PrelovedTabState>();

  Future<void> _jualBarang() async {
    if (await context.push<bool>('/warga/preloved/jual') == true) {
      _preloved.currentState?.segarkan();
    }
  }

  static const _judul = [
    'Bank Sampah Tubaba',
    'Penjemputan',
    'Preloved',
    'Chat',
    'Akun',
    'Riwayat transaksi',
  ];

  Future<void> _mintaJemput() async {
    final dibuat = await context.push<bool>('/warga/jemput/baru');
    if (dibuat == true && mounted) {
      setState(() => _tab = 1);
      _daftarJemput.currentState?.segarkan();
    }
  }

  @override
  Widget build(BuildContext context) {
    final halaman = [
      BerandaWarga(
        bukaPenjemputan: () => setState(() => _tab = 1),
      ),
      DaftarJemputWarga(daftarKey: _daftarJemput),
      PrelovedTab(key: _preloved),
      DaftarChatTab(aktif: _tab == 3),
      const ProfilWarga(),
      DaftarBerhalaman<Setoran>(
        muat: (hal) => ref.read(wargaRepositoryProvider).setoran(halaman: hal),
        kosong: 'Belum ada transaksi.',
        itemBuilder: (_, s, _) => KartuSetoran(setoran: s),
      ),
    ];

    return Scaffold(
      extendBody: true,
      appBar: _tab == 0
          ? HeaderPeran(
              judul: ref.watch(authProvider).value?.name ?? 'Warga Tubaba',
              subjudul: sapaanWaktu(),
              inisial: 'W',
            )
          : AppBar(
              title: Text(_tab == 4 ? 'Profil' : _judul[_tab]),
              actions: [
                if (_tab == 2)
                  IconButton(
                    tooltip: 'Chat dan tawaran',
                    onPressed: () => setState(() => _tab = 3),
                    icon: const Icon(Icons.chat_bubble_outline),
                  ),
              ],
            ),
      body: PindahTab(
        indeks: _tab,
        child: IndexedStack(index: _tab, children: halaman),
      ),
      floatingActionButton: switch (_tab) {
        1 => FloatingActionButton.extended(
          onPressed: _mintaJemput,
          icon: const Icon(Icons.add_location_alt),
          label: const Text('Minta Jemput'),
        ),
        2 => FloatingActionButton.extended(
          onPressed: _jualBarang,
          icon: const Icon(Icons.add_a_photo_outlined),
          label: const Text('Jual Barang'),
        ),
        _ => null,
      },
      bottomNavigationBar: NavigasiPill(
        index: switch (_tab) {
          5 => 1,
          1 => 2,
          2 => 3,
          4 => 4,
          _ => 0,
        },
        aksiTengah: 2,
        labelTengah: 'Jemput',
        onPilih: (i) {
          if (i == 2) {
            _mintaJemput();
          } else {
            setState(() => _tab = [0, 5, 1, 2, 4][i]);
          }
        },
        tujuan: const [
          (ikon: Icons.home_outlined, label: 'Beranda'),
          (ikon: Icons.history, label: 'Riwayat'),
          (ikon: Icons.local_shipping_outlined, label: 'Pesan jemput sampah'),
          (ikon: Icons.storefront_outlined, label: 'Preloved'),
          (ikon: Icons.person_outline, label: 'Profil'),
        ],
      ),
    );
  }
}

class BerandaWarga extends ConsumerWidget {
  const BerandaWarga({super.key, required this.bukaPenjemputan});
  final VoidCallback bukaPenjemputan;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saldo = ref.watch(saldoProvider);
    final setoran = ref.watch(setoranTerbaruProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(saldoProvider);
        ref.invalidate(setoranTerbaruProvider);
        ref.invalidate(beritaTerbaruProvider);
        ref.invalidate(bankTerdekatRumahProvider);
        await ref.read(saldoProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        // Bagian beranda tetap terpasang, jadi animasi masuknya tidak berulang saat digulir
        scrollCacheExtent: const ScrollCacheExtent.pixels(2000),
        padding: paddingAman(
          context,
          dasar: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        ),
        children: [
          KartuHero(
            child: TampilanAsync(
              nilai: saldo,
              onUlang: () => ref.invalidate(saldoProvider),
              data: (s) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Saldo tabungan',
                    style: TextStyle(
                      color: Color(0xFFD5EBDC),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Saldo besar mengecil agar tetap satu baris
                  AngkaNaik(
                    nilai: s.total,
                    format: rupiah,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '1 poin = 1 rupiah',
                    style: TextStyle(color: Color(0xFFD5EBDC), fontSize: 11.5),
                  ),
                  const SizedBox(height: 14),
                  Material(
                    color: TemaAplikasi.limau,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () async {
                        await context.push('/warga/penarikan');
                        ref.invalidate(saldoProvider);
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 18,
                              color: TemaAplikasi.hijauPekat,
                            ),
                            SizedBox(width: 7),
                            Text(
                              'Tarik saldo',
                              style: TextStyle(
                                color: TemaAplikasi.hijauPekat,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          IntrinsicHeight(
            child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AksiCepat(
                ikon: Icons.recycling,
                label: 'Setor',
                utama: true,
                onTap: () => context.push('/warga/cari'),
              ),
              AksiCepat(
                ikon: Icons.volunteer_activism_outlined,
                label: 'Donasi',
                warna: const Color(0xFFC2185B),
                latar: const Color(0xFFFDEBF1),
                onTap: () => context.push('/warga/donasi'),
              ),
              AksiCepat(
                ikon: Icons.local_shipping_outlined,
                label: 'Status jemput',
                warna: const Color(0xFFB45309),
                latar: const Color(0xFFFEF3C7),
                onTap: bukaPenjemputan,
              ),
            ],
            ),
          ),
          const _KartuBankTerdekat(),
          const SizedBox(height: 20),
          const MunculBertahap(urutan: 3, child: _HargaHariIni()),
          const SizedBox(height: 20),
          const JudulBagian('Aktivitas terakhir'),
          const SizedBox(height: 8),
          TampilanAsync(
            nilai: setoran,
            onUlang: () => ref.invalidate(setoranTerbaruProvider),
            data: (daftar) => daftar.isEmpty
                ? const KartuKosong(
                    ikon: Icons.recycling,
                    judul: 'Belum ada aktivitas',
                    keterangan: 'Mulai dengan menyetor sampah ke bank sampah terdekat.',
                  )
                : Column(
                    children: [
                      for (final s in daftar) KartuSetoran(setoran: s),
                    ],
                  ),
          ),
          const BeritaBeranda(),
        ],
      ),
    );
  }
}

class _HargaHariIni extends ConsumerStatefulWidget {
  const _HargaHariIni();
  @override
  ConsumerState<_HargaHariIni> createState() => _HargaHariIniState();
}

class _HargaHariIniState extends ConsumerState<_HargaHariIni> {
  int? _bank;

  /// Bank tempat saldo terbesar warga, lalu bank terdekat dari rumah, lalu yang pertama.
  int? _bankUtama(List<BankSampah> daftar) {
    bool tersedia(int? id) => daftar.any((b) => b.id == id);
    final saldo = [...?ref.watch(saldoProvider).value?.daftar.where((s) => s.saldo > 0 && tersedia(s.bankSampahId))]
      ..sort((a, b) => b.saldo.compareTo(a.saldo));
    if (saldo.isNotEmpty) return saldo.first.bankSampahId;
    final terdekat = ref.watch(bankTerdekatRumahProvider).value?.id;
    return tersedia(terdekat) ? terdekat : daftar.firstOrNull?.id;
  }

  @override
  Widget build(BuildContext context) {
    final pilihan = ref.watch(pilihanBankProvider);
    final daftar = pilihan.value ?? [];
    final id = _bank ?? _bankUtama(daftar);
    final detail = id == null ? null : ref.watch(detailBankProvider(id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        JudulBagian(
          'Harga sampah hari ini',
          aksi: 'Lihat semua',
          onTap: () => context.push('/warga/cari'),
        ),
        if (daftar.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: TemaAplikasi.garis),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.storefront_outlined, size: 19, color: TemaAplikasi.hijau),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: id,
                isDense: true,
                isExpanded: true,
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: TemaAplikasi.teks,
                ),
                items: [
                  for (final b in daftar)
                    DropdownMenuItem(
                      value: b.id,
                      child: Text(
                        b.nama,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _bank = v),
              ),
                  ),
                ),
              ],
            ),
          ),
        if (pilihan.isLoading || detail?.isLoading == true)
          const LinearProgressIndicator(minHeight: 2)
        else if (pilihan.hasError || detail?.hasError == true)
          TextButton(
            onPressed: () => ref.invalidate(pilihanBankProvider),
            child: const Text('Coba muat harga lagi'),
          )
        else if (detail?.value?.harga.isNotEmpty == true)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final h in detail!.value!.harga.take(6))
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Container(
                      width: 134,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: TemaAplikasi.garis),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IlustrasiReferensi(
                            ilustrasiJenis(h.nama),
                            ukuran: 36,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            h.nama,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            h.hargaPerKg == null
                                ? 'Belum diatur'
                                : '${rupiah(h.hargaPerKg)}/kg',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          )
        else
          const KartuKosong(
            ikon: Icons.sell_outlined,
            judul: 'Harga belum tersedia',
            keterangan: 'Bank sampah ini belum mengatur harga. Coba pilih bank sampah lain.',
          ),
      ],
    );
  }
}

class ProfilWarga extends ConsumerWidget {
  const ProfilWarga({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final saldo = ref.watch(saldoProvider);
    return ListView(
      padding: paddingAman(context, dasar: const EdgeInsets.all(20)),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: TemaAplikasi.hijauLembut,
              child: Text(
                user?.name.isNotEmpty == true ? user!.name[0] : 'W',
                style: const TextStyle(
                  color: TemaAplikasi.hijauPekat,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.name ?? 'Warga',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  Text(
                    user?.phone ?? user?.email ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: TemaAplikasi.redup,
                    ),
                  ),
                  const Text(
                    'Warga · Bank Sampah Tubaba',
                    style: TextStyle(fontSize: 11, color: TemaAplikasi.redup),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Ubah profil',
              onPressed: () => context.push('/akun'),
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
        const SizedBox(height: 24),
        JudulBagian(
          'Saldo per bank sampah',
          aksi: 'Riwayat',
          onTap: () => context.push('/warga/riwayat'),
        ),
        const SizedBox(height: 10),
        TampilanAsync(
          nilai: saldo,
          onUlang: () => ref.invalidate(saldoProvider),
          data: (s) => Card(
            child: Column(
              children: [
                if (s.daftar.isEmpty)
                  const ListTile(
                    title: Text(
                      'Belum ada saldo',
                      style: TextStyle(fontSize: 13),
                    ),
                    subtitle: Text('Setor sampah untuk mulai menabung.'),
                  ),
                for (final b in s.daftar)
                  ListTile(
                    leading: const Icon(Icons.storefront_outlined),
                    title: Text(
                      b.bankSampah?.nama ?? 'Bank sampah',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    trailing: Text(
                      rupiah(b.saldo),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    onTap: () => context.push('/warga/penarikan'),
                  ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: TemaAplikasi.garis)),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Total saldo',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        rupiah(s.total),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const JudulBagian('Akun'),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: const Text('Alamat penjemputan'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/akun'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.shopping_bag_outlined),
                title: const Text('Barang preloved saya'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/warga/preloved/saya'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Keamanan akun'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/akun/password'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () async {
            if (await konfirmasi(
              context,
              'Keluar?',
              'Anda perlu login lagi untuk memakai aplikasi.',
              ya: 'Keluar',
            )) {
              await ref.read(authProvider.notifier).logout();
            }
          },
          icon: const Icon(Icons.logout),
          label: const Text('Keluar'),
        ),
      ],
    );
  }
}

/// Jarak rumah ke bank sampah terdekat, atau ajakan menandai titik rumah.
class _KartuBankTerdekat extends ConsumerWidget {
  const _KartuBankTerdekat();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    if (user?.lat == null || user?.lng == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: KartuAjakan(
          ikon: Icons.add_location_alt_outlined,
          warna: const Color(0xFFB45309),
          latar: const Color(0xFFFEF3C7),
          judul: 'Tandai titik rumah Anda',
          keterangan: 'Agar jarak ke bank sampah terdekat bisa dihitung.',
          onTap: () => context.push('/akun'),
        ),
      );
    }
    final bank = ref.watch(bankTerdekatRumahProvider).value;
    if (bank == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: KartuAjakan(
        ikon: Icons.near_me_outlined,
        warna: TemaAplikasi.hijau,
        latar: TemaAplikasi.hijauLembut,
        judul: bank.nama,
        keterangan: 'Bank sampah terdekat, ${jarakKm(bank.jarakKm ?? 0)} dari rumah Anda.',
        onTap: () => context.push('/warga/bank/${bank.id}'),
      ),
    );
  }
}

class KartuSetoran extends StatelessWidget {
  const KartuSetoran({
    super.key,
    required this.setoran,
    this.tampilkanWarga = false,
    this.onBatalkan,
  });

  final Setoran setoran;
  final bool tampilkanWarga;

  /// Hanya diisi di aplikasi operator.
  final VoidCallback? onBatalkan;

  @override
  Widget build(BuildContext context) {
    final s = setoran;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        shape: const Border(),
        tilePadding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: s.dibatalkan
                ? TemaAplikasi.latar
                : s.donasi
                ? const Color(0xFFFDEBF1)
                : TemaAplikasi.hijauLembut,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            s.dibatalkan
                ? Icons.cancel_outlined
                : s.donasi
                ? Icons.volunteer_activism
                : Icons.recycling,
            size: 21,
            color: s.dibatalkan
                ? TemaAplikasi.redup
                : s.donasi
                ? const Color(0xFFC2185B)
                : TemaAplikasi.hijau,
          ),
        ),
        title: Text(
          tampilkanWarga ? (s.namaWarga ?? '-') : namaBankRingkas(s.bankSampah?.nama ?? '-'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${tanggalRingkas(s.createdAt)} · ${kg(s.totalKg).replaceAll(' ', '\u00A0')}',
          style: const TextStyle(fontSize: 12.5, color: TemaAplikasi.redup),
        ),
        trailing: Text(
          s.dibatalkan
              ? 'Dibatalkan'
              : s.donasi
              ? 'Donasi'
              : '+${rupiah(s.totalNilai)}',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: s.dibatalkan
                ? TemaAplikasi.redup
                : s.donasi
                ? const Color(0xFFC2185B)
                : TemaAplikasi.hijau,
          ),
        ),
        children: [
          if (s.dibatalkan)
            ListTile(
              dense: true,
              leading: const Icon(Icons.info_outline),
              title: const Text('Setoran ini dibatalkan'),
              subtitle: Text(s.alasanBatal ?? '-'),
            ),
          for (final i in s.items)
            ListTile(
              dense: true,
              title: Text(i.nama),
              subtitle: Text(
                s.donasi
                    ? kg(i.beratKg)
                    : '${kg(i.beratKg)} × ${rupiah(i.hargaPerKg)}',
              ),
              trailing: s.donasi ? null : Text(rupiah(i.subtotal)),
            ),
          if (onBatalkan != null && !s.dibatalkan)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onBatalkan,
                icon: const Icon(Icons.undo),
                label: const Text('Batalkan setoran'),
              ),
            ),
        ],
      ),
    );
  }
}

class DaftarJemputWarga extends ConsumerWidget {
  const DaftarJemputWarga({super.key, this.daftarKey});

  final GlobalKey<DaftarBerhalamanState<Penjemputan>>? daftarKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DaftarBerhalaman<Penjemputan>(
      key: daftarKey,
      muat: (hal) =>
          ref.read(wargaRepositoryProvider).penjemputan(halaman: hal),
      kosong: 'Belum ada permintaan jemput.\nKetuk "Minta Jemput" untuk mengajukan.',
      adaFab: true,
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
                      p.bankSampah?.nama ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  LabelStatus(
                    labelStatusJemput[p.status] ?? p.status,
                    warna: warnaStatus(p.status),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(p.alamat),
              Text(
                'Diajukan ${tanggalJam(p.createdAt)}',
                style: const TextStyle(fontSize: 12),
              ),
              if (p.jadwalAt != null) Text('Jadwal: ${tanggalJam(p.jadwalAt)}'),
              if (p.driver != null)
                Text('Bentor: ${p.driver!.name} (${p.platNomor ?? '-'})'),
              if (p.alasanTolak != null)
                Text(
                  'Alasan ditolak: ${p.alasanTolak}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (p.status == 'diajukan')
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () async {
                      if (!await konfirmasi(
                        context,
                        'Batalkan permintaan?',
                        'Permintaan jemput ini akan dibatalkan.',
                        ya: 'Batalkan',
                      )) {
                        return;
                      }
                      if (!context.mounted) return;
                      final ok = await jalankan(
                        context,
                        () =>
                            ref.read(wargaRepositoryProvider).batalJemput(p.id),
                        sukses: 'Permintaan jemput dibatalkan.',
                      );
                      if (ok) segarkan();
                    },
                    child: const Text('Batalkan'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
