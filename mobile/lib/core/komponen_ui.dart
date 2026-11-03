import 'package:flutter/material.dart';

import 'gerak.dart';
import 'theme.dart';
import 'logo_aplikasi.dart';

export 'gerak.dart';

String ilustrasiJenis(String nama) {
  final n = nama.toLowerCase();
  if (n.contains('plastik')) {
    return 'plastik';
  }
  if (n.contains('kardus')) {
    return 'sampah';
  }
  if (n.contains('logam') || n.contains('kaleng')) {
    return 'logam';
  }
  if (n.contains('kertas')) {
    return 'kertas';
  }
  return 'sampah';
}

class IlustrasiReferensi extends StatelessWidget {
  const IlustrasiReferensi(this.nama, {super.key, this.ukuran = 40});
  final String nama;
  final double ukuran;
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/illustrations/$nama.png',
    width: ukuran,
    height: ukuran,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
  );
}

String sapaanWaktu([DateTime? waktu]) {
  final jam = (waktu ?? DateTime.now()).hour;
  if (jam < 11) return 'Selamat pagi,';
  if (jam < 15) return 'Selamat siang,';
  if (jam < 18) return 'Selamat sore,';
  return 'Selamat malam,';
}

/// Tombol ikon di kepala halaman.
final gayaTombolKepala = IconButton.styleFrom(
  backgroundColor: Colors.white,
  side: const BorderSide(color: TemaAplikasi.garis),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
);

/// Header role yang tetap bisa tumbuh ketika ukuran teks sistem diperbesar.
class HeaderPeran extends StatelessWidget implements PreferredSizeWidget {
  const HeaderPeran({
    super.key,
    required this.judul,
    required this.subjudul,
    this.ikon = Icons.recycling,
    this.inisial,
    this.aksi,
  });
  final String judul;
  final String subjudul;
  final IconData ikon;
  final String? inisial;
  final Widget? aksi;

  @override
  Size get preferredSize => const Size.fromHeight(84);

  @override
  Widget build(BuildContext context) => Material(
    color: TemaAplikasi.latar,
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: inisial == null ? Colors.white : TemaAplikasi.hijauPekat,
                borderRadius: BorderRadius.circular(inisial == null ? 14 : 24),
              ),
              alignment: Alignment.center,
              child: inisial == null
                  ? const Padding(
                      padding: EdgeInsets.all(4),
                      child: LogoAplikasi(ukuran: 36),
                    )
                  : Text(
                      inisial!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subjudul,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    judul,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            if (aksi != null) ...[const SizedBox(width: 8), aksi!],
          ],
        ),
      ),
    ),
  );
}

/// Motif tapis untuk bidang hijau tua, sama dengan web.
const corakTapis = DecorationImage(
  image: AssetImage('assets/branding/corak-tapis.png'),
  repeat: ImageRepeat.repeat,
  scale: 2,
  alignment: Alignment.topCenter,
);

class KartuHero extends StatelessWidget {
  const KartuHero({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => MunculBertahap(
    child: DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: TemaAplikasi.hijauPekat.withValues(alpha: .28),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: TemaAplikasi.hijauPekat,
          image: corakTapis,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: Colors.white),
            child: IconTheme(
              data: const IconThemeData(color: TemaAplikasi.limau),
              child: child,
            ),
          ),
        ),
      ),
    ),
    ),
  );
}

/// Kartu pintasan yang menonjol di beranda.
class KartuAjakan extends StatelessWidget {
  const KartuAjakan({
    super.key,
    required this.ikon,
    required this.judul,
    required this.keterangan,
    required this.onTap,
    this.warna = const Color(0xFFC2185B),
    this.latar = const Color(0xFFFDEBF1),
  });
  final IconData ikon;
  final String judul;
  final String keterangan;
  final VoidCallback onTap;
  final Color warna;
  final Color latar;

  @override
  Widget build(BuildContext context) => MunculBertahap(
    urutan: 3,
    child: TekanSkala(
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: latar,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(ikon, size: 23, color: warna),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(judul, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(keterangan, style: const TextStyle(fontSize: 12.5, height: 1.35, color: TemaAplikasi.redup)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, color: TemaAplikasi.redup),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Pesan kosong di dalam halaman, supaya tidak tampil sebagai teks polos.
class KartuKosong extends StatelessWidget {
  const KartuKosong({super.key, required this.ikon, required this.judul, required this.keterangan});
  final IconData ikon;
  final String judul;
  final String keterangan;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: TemaAplikasi.hijauLembut,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(ikon, size: 22, color: TemaAplikasi.hijau),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(judul, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(keterangan, style: const TextStyle(fontSize: 12.5, height: 1.35, color: TemaAplikasi.redup)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Angka kecil di dalam KartuHero. Pasang di dalam Row.
class KotakAngkaHero extends StatelessWidget {
  const KotakAngkaHero(this.label, this.nilai, {super.key});
  final String label;
  final String nilai;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Angka panjang mengecil agar tetap satu baris, tinggi kotak tetap sama
          SizedBox(
            height: 22,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                nilai,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFFD5EBDC), fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class AksiCepat extends StatelessWidget {
  const AksiCepat({
    super.key,
    required this.ikon,
    required this.label,
    required this.onTap,
    this.utama = false,
    this.warna = TemaAplikasi.hijau,
    this.latar = TemaAplikasi.hijauLembut,
  });
  final IconData ikon;
  final String label;
  final VoidCallback onTap;

  /// Aksi yang paling sering dipakai pada peran ini.
  final bool utama;
  final Color warna;
  final Color latar;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: MunculBertahap(
        urutan: 2,
        child: TekanSkala(
        child: Semantics(
        button: true,
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: TemaAplikasi.garis),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
              child: Column(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: utama ? TemaAplikasi.hijauPekat : latar,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      ikon,
                      size: 23,
                      color: utama ? TemaAplikasi.limau : warna,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
      ),
    ),
  );
}

class JudulBagian extends StatelessWidget {
  const JudulBagian(this.judul, {super.key, this.aksi, this.onTap});
  final String judul;
  final String? aksi;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 4,
        height: 16,
        decoration: BoxDecoration(
          color: TemaAplikasi.hijau,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(judul, style: Theme.of(context).textTheme.titleMedium),
      ),
      if (aksi != null)
        TextButton(
          onPressed: onTap,
          child: Text(aksi!, style: const TextStyle(fontSize: 12)),
        ),
    ],
  );
}

/// Navigasi bawah selebar layar, dengan aksi utama opsional di tengah.
class NavigasiPill extends StatelessWidget {
  const NavigasiPill({
    super.key,
    required this.index,
    required this.onPilih,
    required this.tujuan,
    this.aksiTengah,
    this.labelTengah,
  });
  final int index;
  final ValueChanged<int> onPilih;
  final List<({IconData ikon, String label})> tujuan;
  final int? aksiTengah;

  /// Teks singkat di bawah aksi tengah. Label lengkapnya tetap jadi tooltip.
  final String? labelTengah;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      border: const Border(top: BorderSide(color: TemaAplikasi.garis)),
      boxShadow: [
        BoxShadow(
          color: TemaAplikasi.hijauPekat.withValues(alpha: .07),
          blurRadius: 18,
          offset: const Offset(0, -6),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(6, 8, 6, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < tujuan.length; i++)
            Expanded(
              child: Semantics(
                selected: i == index,
                button: true,
                label: tujuan[i].label,
                child: Tooltip(
                  message: tujuan[i].label,
                  child: InkWell(
                    onTap: () => onPilih(i),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: ExcludeSemantics(
                        child: i == aksiTengah
                            ? _tengah(tujuan[i])
                            : _biasa(tujuan[i], i == index),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _tengah(({IconData ikon, String label}) t) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      TekanSkala(
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: TemaAplikasi.hijauPekat,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: TemaAplikasi.hijauPekat.withValues(alpha: .35),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(t.ikon, color: TemaAplikasi.limau, size: 23),
        ),
      ),
      const SizedBox(height: 3),
      _teks(labelTengah ?? t.label, TemaAplikasi.hijauPekat, true),
    ],
  );

  Widget _biasa(({IconData ikon, String label}) t, bool aktif) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: aktif ? 18 : 12, vertical: 4),
        decoration: BoxDecoration(
          color: aktif ? TemaAplikasi.hijauLembut : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
        ),
        child: AnimatedScale(
          scale: aktif ? 1.08 : 1,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutBack,
          child: Icon(
            t.ikon,
            size: 22,
            color: aktif ? TemaAplikasi.hijau : TemaAplikasi.redup,
          ),
        ),
      ),
      const SizedBox(height: 3),
      _teks(t.label, aktif ? TemaAplikasi.hijau : TemaAplikasi.redup, aktif),
    ],
  );

  Widget _teks(String isi, Color warna, bool tebal) => AnimatedDefaultTextStyle(
    duration: const Duration(milliseconds: 200),
    style: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      color: warna,
      fontSize: 11.5,
      fontWeight: tebal ? FontWeight.w700 : FontWeight.w500,
    ),
    child: Text(isi, maxLines: 1, overflow: TextOverflow.ellipsis),
  );
}

class SegmenReferensi<T> extends StatelessWidget {
  const SegmenReferensi({
    super.key,
    required this.nilai,
    required this.pilihan,
    required this.onUbah,
  });
  final T nilai;
  final List<(T, String)> pilihan;
  final ValueChanged<T>? onUbah;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: TemaAplikasi.garis),
    ),
    child: Row(
      children: [
        for (final p in pilihan)
          Expanded(
            child: Semantics(
              selected: nilai == p.$1,
              button: true,
              child: InkWell(
                onTap: onUbah == null ? null : () => onUbah!(p.$1),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 5,
                  ),
                  decoration: BoxDecoration(
                    color: nilai == p.$1
                        ? TemaAplikasi.hijauPekat
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    p.$2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: nilai == p.$1 ? Colors.white : TemaAplikasi.redup,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
