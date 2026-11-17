import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../core/daftar_berhalaman.dart';
import '../../core/format.dart';
import '../../core/komponen_ui.dart';
import '../../core/logo_aplikasi.dart';
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
        bukaPreloved: () => setState(() => _tab = 2),
        mintaJemput: _mintaJemput,
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
      // Beranda memakai header hijau sendiri yang menyatu dengan bilah status
      appBar: _tab == 0
          ? null
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

class BerandaWarga extends ConsumerStatefulWidget {
  const BerandaWarga({
    super.key,
    required this.bukaPenjemputan,
    required this.bukaPreloved,
    required this.mintaJemput,
  });
  final VoidCallback bukaPenjemputan;
  final VoidCallback bukaPreloved;
  final VoidCallback mintaJemput;

  @override
  ConsumerState<BerandaWarga> createState() => _BerandaWargaState();
}

class _BerandaWargaState extends ConsumerState<BerandaWarga> {
  final _kunciHarga = GlobalKey();

  /// Menggulir ke bagian harga di beranda; bila belum terpasang, buka daftar bank sampah.
  void _lihatHarga() {
    final tujuan = _kunciHarga.currentContext;
    if (tujuan == null) {
      context.push('/warga/cari');
      return;
    }
    Scrollable.ensureVisible(
      tujuan,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      alignment: .05,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mintaJemput = widget.mintaJemput;
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(saldoProvider);
        ref.invalidate(beritaTerbaruProvider);
        ref.invalidate(bankTerdekatRumahProvider);
        await ref.read(saldoProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        // Bagian beranda tetap terpasang, jadi animasi masuknya tidak berulang saat digulir
        scrollCacheExtent: const ScrollCacheExtent.pixels(2000),
        padding: paddingAman(context, dasar: const EdgeInsets.only(bottom: 20)),
        children: [
          const _HeaderBeranda(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MunculBertahap(
                  urutan: 1,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MenuKotak(
                        label: 'Cara setor',
                        gambar: 'setor',
                        onTap: () => _bukaCaraSetor(context, mintaJemput: mintaJemput),
                      ),
                      _MenuKotak(
                        label: 'Donasi',
                        gambar: 'donasi',
                        onTap: () => context.push('/warga/donasi'),
                      ),
                      // Satu-satunya jalan ke daftar status jemput; tombol Jemput di navigasi membuat permintaan baru
                      _MenuKotak(
                        label: 'Status jemput',
                        gambar: 'jemput',
                        onTap: widget.bukaPenjemputan,
                      ),
                      _MenuKotak(
                        label: 'Harga sampah',
                        gambar: 'dompet',
                        onTap: _lihatHarga,
                      ),
                    ],
                  ),
                ),
                const _KartuBankTerdekat(),
                const SizedBox(height: 18),
                MunculBertahap(
                  urutan: 2,
                  child: _BannerAjakan(
                    label: 'LAYANAN JEMPUT',
                    labelKedua: 'Bentor bank sampah',
                    judul: 'Sampah menumpuk? Minta dijemput dari rumah',
                    isi: 'Pilih bank sampah, tandai lokasi, lalu bentor datang menjemput.',
                    tombol: 'Minta jemput',
                    warna: const [TemaAplikasi.hijauPekat, TemaAplikasi.hijau],
                    ikon: Icons.local_shipping_outlined,
                    onTap: mintaJemput,
                  ),
                ),
                const SizedBox(height: 14),
                MunculBertahap(
                  urutan: 3,
                  child: _BannerAjakan(
                    label: 'PRELOVED WARGA',
                    labelKedua: 'Transaksi COD',
                    judul: 'Barang tak terpakai bisa jadi uang',
                    isi: 'Foto barangnya, beri harga, dan tunggu pembeli menghubungimu.',
                    tombol: 'Jual barang',
                    warna: const [TemaAplikasi.hijau, TemaAplikasi.hijauSedang],
                    ikon: Icons.sell_outlined,
                    onTap: () => context.push('/warga/preloved/jual'),
                  ),
                ),
                const SizedBox(height: 20),
                MunculBertahap(urutan: 4, child: KeyedSubtree(key: _kunciHarga, child: const _HargaHariIni())),
                const BeritaBeranda(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Header hijau penuh sampai bilah status: cari, merek, ilustrasi bentor, lalu kartu sapaan dan saldo.
class _HeaderBeranda extends ConsumerWidget {
  const _HeaderBeranda();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final atas = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Stack(
        children: [
          Container(
            height: atas + 300,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [TemaAplikasi.hijau, TemaAplikasi.hijauSedang],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                // Lingkaran samar sebagai hiasan, seperti header aplikasi layanan desa
                Positioned(
                  top: -60,
                  right: -50,
                  child: _Lingkaran(ukuran: 210, alpha: .10),
                ),
                Positioned(
                  top: atas + 150,
                  right: 60,
                  child: _Lingkaran(ukuran: 120, alpha: .07),
                ),
                const Positioned.fill(
                  child: Opacity(
                    opacity: .10,
                    child: DecoratedBox(decoration: BoxDecoration(image: corakTapis)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, atas + 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: 'Cari bank sampah',
                        excludeSemantics: true,
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(28),
                            onTap: () => context.push('/warga/cari'),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                              child: Row(
                                children: [
                                  Icon(Icons.search, color: TemaAplikasi.redup),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Cari bank sampah terdekat…',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: TemaAplikasi.redup, fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Chat dan tawaran',
                        onPressed: () => context.push('/warga/chat'),
                        icon: const Icon(Icons.chat_bubble_outline, color: TemaAplikasi.hijauPekat),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                                child: const LogoAplikasi(ukuran: 40),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Bank Sampah',
                                        style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, height: 1.05),
                                      ),
                                    ),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'KABUPATEN TULANG BAWANG BARAT',
                                        style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: .6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Tabung sampah, minta jemput, dan jual barang bekas',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 10),
                          // Alur singkat menabung sampah; mengecil di layar sempit agar tidak meluap
                          const FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                _Langkah(ikon: Icons.recycling, teks: 'Pilah'),
                                _Panah(),
                                _Langkah(ikon: Icons.scale_outlined, teks: 'Timbang'),
                                _Panah(),
                                _Langkah(ikon: Icons.savings_outlined, teks: 'Tabung'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Image.asset(
                        'assets/illustrations/ikon/jemput.png',
                        width: 108,
                        height: 108,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const MunculBertahap(child: SizedBox(width: double.infinity, child: _KartuSapaan())),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Lingkaran extends StatelessWidget {
  const _Lingkaran({required this.ukuran, required this.alpha});

  final double ukuran;
  final double alpha;

  @override
  Widget build(BuildContext context) => Container(
        width: ukuran,
        height: ukuran,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: alpha)),
      );
}

/// Satu langkah menabung sampah di header: ikon dan label dalam pil gelap tipis.
class _Langkah extends StatelessWidget {
  const _Langkah({required this.ikon, required this.teks});

  final IconData ikon;
  final String teks;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(5, 5, 11, 5),
        decoration: BoxDecoration(
          color: TemaAplikasi.hijauPekat.withValues(alpha: .35),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: .18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(color: TemaAplikasi.limau, shape: BoxShape.circle),
              child: Icon(ikon, size: 14, color: TemaAplikasi.hijauPekat),
            ),
            const SizedBox(width: 6),
            Text(teks, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _Panah extends StatelessWidget {
  const _Panah();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 3),
        child: Icon(Icons.chevron_right, size: 18, color: Color(0xB3FFFFFF)),
      );
}

/// Kartu putih berisi sapaan, saldo, dan tombol tarik saldo.
class _KartuSapaan extends ConsumerWidget {
  const _KartuSapaan();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saldo = ref.watch(saldoProvider);
    final nama = (ref.watch(authProvider).value?.name ?? 'Warga').trim().split(' ').first;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: TemaAplikasi.garisHijau, width: 1.5),
        boxShadow: [
          BoxShadow(color: TemaAplikasi.hijauPekat.withValues(alpha: .14), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: TampilanAsync(
          nilai: saldo,
          onUlang: () => ref.invalidate(saldoProvider),
          data: (s) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Halo, $nama 👋',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: TemaAplikasi.hijauLembut, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: TemaAplikasi.hijau),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          sapaanWaktu().replaceAll(',', ''),
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: TemaAplikasi.hijauPekat),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, color: TemaAplikasi.hijauLembut),
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(color: TemaAplikasi.hijauLembut, borderRadius: BorderRadius.circular(14)),
                    child: Image.asset('assets/illustrations/ikon/dompet.png', excludeFromSemantics: true),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Saldo tabungan',
                          style: TextStyle(color: TemaAplikasi.redup, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        // Saldo besar mengecil agar tetap satu baris
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: AngkaNaik(
                            nilai: s.total,
                            format: rupiah,
                            style: const TextStyle(
                              color: TemaAplikasi.hijauPekat,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.6,
                            ),
                          ),
                        ),
                        Text(
                          _keteranganSaldo(s.daftar.where((b) => b.saldo > 0).length),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: TemaAplikasi.redup),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    // Tema bawaan membuat tombol selebar layar; di dalam Row lebarnya harus dibatasi
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    onPressed: () async {
                      await context.push('/warga/penarikan');
                      ref.invalidate(saldoProvider);
                    },
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('Tarik saldo'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Menu berupa kotak ilustrasi 3D dengan label di bawahnya.
class _MenuKotak extends StatelessWidget {
  const _MenuKotak({required this.gambar, required this.label, required this.onTap});

  final String gambar;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        // container: tiap menu jadi tombol tersendiri bagi pembaca layar, tidak tergabung satu baris
        child: Semantics(
          container: true,
          button: true,
          label: label,
          excludeSemantics: true,
          onTap: onTap,
          child: TekanSkala(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  children: [
                    KotakIkon(gambar: gambar),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

/// Banner ajakan bergradasi dengan label kecil, judul, dan tombol putih.
class _BannerAjakan extends StatelessWidget {
  const _BannerAjakan({
    required this.label,
    required this.labelKedua,
    required this.judul,
    required this.isi,
    required this.tombol,
    required this.warna,
    required this.ikon,
    required this.onTap,
  });

  final String label;
  final String labelKedua;
  final String judul;
  final String isi;
  final String tombol;
  final List<Color> warna;
  final IconData ikon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: warna, begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -18,
                bottom: -18,
                child: Icon(ikon, size: 120, color: Colors.white.withValues(alpha: .10)),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _Label(label, latar: TemaAplikasi.limau, warna: TemaAplikasi.hijauPekat),
                        _Label(labelKedua, latar: Colors.white.withValues(alpha: .18), warna: Colors.white),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      judul,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, height: 1.25),
                    ),
                    const SizedBox(height: 4),
                    Text(isi, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: warna.first,
                        minimumSize: const Size(0, 42),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: onTap,
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: Text(tombol),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _Label extends StatelessWidget {
  const _Label(this.teks, {required this.latar, required this.warna});

  final String teks;
  final Color latar;
  final Color warna;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: latar, borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(teks, style: TextStyle(color: warna, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: .4)),
        ),
      );
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
        _GrupPengaturan('Akun', [
          _ButirPengaturan(Icons.person_outline, 'Ubah profil', onTap: () => context.push('/akun')),
          _ButirPengaturan(
            Icons.location_on_outlined,
            'Alamat dan titik jemput',
            keterangan: user?.lat == null ? 'Titik rumah belum ditandai' : null,
            onTap: () => context.push('/akun'),
          ),
        ]),
        _GrupPengaturan('Keamanan', [
          _ButirPengaturan(Icons.lock_outline, 'Ganti password', onTap: () => context.push('/akun/password')),
          _ButirPengaturan(
            Icons.devices_outlined,
            'Perangkat aktif',
            keterangan: 'Lihat dan keluarkan perangkat lain',
            onTap: () => context.push('/akun/perangkat'),
          ),
        ]),
        _GrupPengaturan('Bantuan', [
          _ButirPengaturan(
            Icons.help_outline,
            'Cara menabung sampah',
            onTap: () => _bukaCaraSetor(context, mintaJemput: () => context.push('/warga/jemput/baru')),
          ),
          _ButirPengaturan(
            Icons.support_agent_outlined,
            'Hubungi bank sampah',
            keterangan: 'Termasuk untuk reset password',
            onTap: () => _pilihBankDihubungi(context, saldo.value?.daftar ?? const []),
          ),
        ]),
        _GrupPengaturan('Privasi dan data', [
          _ButirPengaturan(Icons.privacy_tip_outlined, 'Kebijakan privasi', onTap: () => context.push('/akun/privasi')),
          _ButirPengaturan(
            Icons.delete_outline,
            'Hapus akun',
            bahaya: true,
            onTap: () => context.push('/akun/hapus'),
          ),
        ]),
        const _GrupPengaturan('Tentang', [
          _ButirPengaturan(Icons.info_outline, 'Bank Sampah Tubaba', keterangan: 'Versi $versiAplikasi'),
        ]),
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
                ? TemaAplikasi.garisHijau
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
                ? TemaAplikasi.hijauPekat
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
                ? TemaAplikasi.hijauPekat
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

/// Keterangan di bawah saldo: di berapa bank sampah saldo tersimpan.
String _keteranganSaldo(int jumlahBank) =>
    jumlahBank == 0 ? 'Ayo mulai menabung' : 'Di $jumlahBank bank sampah';

/// Panduan singkat menabung sampah, dengan jalan pintas ke minta jemput dan cari bank.
Future<void> _bukaCaraSetor(BuildContext context, {required VoidCallback mintaJemput}) =>
    tampilkanSheet<void>(
      context,
      (lembar) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Cara menabung sampah', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text(
                'Sampahmu ditimbang petugas, lalu nilainya masuk ke saldo.',
                style: TextStyle(fontSize: 13, color: TemaAplikasi.redup),
              ),
              const SizedBox(height: 18),
              for (final (i, (judul, isi)) in _langkahSetor.indexed)
                _ButirLangkah(nomor: i + 1, judul: judul, isi: isi, terakhir: i == _langkahSetor.length - 1),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(lembar);
                  mintaJemput();
                },
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('Minta jemput'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(lembar);
                  context.push('/warga/cari');
                },
                icon: const Icon(Icons.search),
                label: const Text('Cari bank sampah terdekat'),
              ),
            ],
          ),
        ),
    );

const _langkahSetor = [
  ('Pilah dari rumah', 'Pisahkan plastik, kardus, kertas, logam, kaca, dan minyak jelantah. Usahakan bersih dan kering.'),
  ('Bawa atau minta jemput', 'Antar ke bank sampah terdekat, atau minta bentor menjemput dari rumahmu.'),
  ('Ditimbang petugas', 'Nilai sampah sesuai harga di bank sampah itu langsung masuk ke saldomu.'),
  ('Tarik saldo', 'Ajukan penarikan di aplikasi, lalu pengelola bank sampah memprosesnya.'),
];

class _ButirLangkah extends StatelessWidget {
  const _ButirLangkah({required this.nomor, required this.judul, required this.isi, required this.terakhir});

  final int nomor;
  final String judul;
  final String isi;
  final bool terakhir;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: TemaAplikasi.hijauLembut, shape: BoxShape.circle),
                  child: Text('$nomor', style: const TextStyle(color: TemaAplikasi.hijau, fontWeight: FontWeight.w800)),
                ),
                if (!terakhir) Expanded(child: Container(width: 2, color: TemaAplikasi.garisHijau)),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(judul, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(isi, style: const TextStyle(fontSize: 12.5, height: 1.4, color: TemaAplikasi.redup)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

/// Kelompok menu pengaturan dengan judul kecil di atas kartu.
class _GrupPengaturan extends StatelessWidget {
  const _GrupPengaturan(this.judul, this.butir);

  final String judul;
  final List<_ButirPengaturan> butir;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            judul.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .6, color: TemaAplikasi.redup),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (i, b) in butir.indexed) ...[
                if (i > 0) const Divider(height: 1, indent: 56),
                b,
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _ButirPengaturan extends StatelessWidget {
  const _ButirPengaturan(this.ikon, this.judul, {this.keterangan, this.onTap, this.bahaya = false});

  final IconData ikon;
  final String judul;
  final String? keterangan;
  final VoidCallback? onTap;
  final bool bahaya;

  @override
  Widget build(BuildContext context) {
    final warna = bahaya ? Theme.of(context).colorScheme.error : TemaAplikasi.hijau;
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bahaya ? warna.withValues(alpha: .1) : TemaAplikasi.hijauLembut,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(ikon, size: 20, color: warna),
      ),
      title: Text(
        judul,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: bahaya ? warna : null),
      ),
      subtitle: keterangan == null ? null : Text(keterangan!, style: const TextStyle(fontSize: 12)),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
    );
  }
}

/// Pilih bank sampah tempat menabung untuk dihubungi; bila belum ada, cari bank terdekat.
Future<void> _pilihBankDihubungi(BuildContext context, List<Saldo> daftar) {
  if (daftar.isEmpty) return context.push('/warga/cari');
  if (daftar.length == 1) return context.push('/warga/bank/${daftar.first.bankSampahId}');
  return tampilkanSheet<void>(
    context,
    (lembar) => Padding(
      padding: const EdgeInsets.fromLTRB(8, 20, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Text('Hubungi bank sampah', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text(
              'Pengelola bank sampah juga bisa mereset password bila kamu lupa.',
              style: TextStyle(fontSize: 12.5, color: TemaAplikasi.redup),
            ),
          ),
          for (final s in daftar)
            ListTile(
              leading: const Icon(Icons.storefront_outlined, color: TemaAplikasi.hijau),
              title: Text(s.bankSampah?.nama ?? 'Bank sampah', style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(lembar);
                context.push('/warga/bank/${s.bankSampahId}');
              },
            ),
        ],
      ),
    ),
  );
}
