import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_exception.dart';
import 'theme.dart';

/// Tampilkan AsyncValue: loading, error (dengan tombol coba lagi), atau data.
class TampilanAsync<T> extends StatelessWidget {
  const TampilanAsync({super.key, required this.nilai, required this.data, this.onUlang});

  final AsyncValue<T> nilai;
  final Widget Function(T data) data;
  final VoidCallback? onUlang;

  @override
  Widget build(BuildContext context) {
    return nilai.when(
      skipLoadingOnRefresh: true,
      data: data,
      loading: () => const _KerangkaMuat(),
      error: (e, _) => PesanGagal(pesan: pesanDari(e), onUlang: onUlang),
    );
  }
}

String pesanDari(Object e) => e is ApiException ? e.pesan : 'Terjadi kesalahan. Coba lagi.';

class PesanGagal extends StatelessWidget {
  const PesanGagal({super.key, required this.pesan, this.onUlang});

  final String pesan;
  final VoidCallback? onUlang;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off, size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Text(pesan, textAlign: TextAlign.center),
          if (onUlang != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: onUlang, icon: const Icon(Icons.refresh), label: const Text('Coba lagi')),
          ],
        ]),
      ),
    );
  }
}

class Kosong extends StatelessWidget {
  const Kosong({super.key, required this.pesan, this.ikon = Icons.inbox_outlined});

  final String pesan;
  final IconData ikon;

  @override
  Widget build(BuildContext context) {
    final baris = pesan.split('\n');
    // Bisa digulir: ruang sempit (mis. keyboard terbuka di ruang chat) tidak overflow
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: .7, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(color: TemaAplikasi.hijauLembut, shape: BoxShape.circle),
              child: Icon(ikon, size: 38, color: TemaAplikasi.hijau),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            baris.first,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          if (baris.length > 1) ...[
            const SizedBox(height: 4),
            Text(
              baris.skip(1).join('\n'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: TemaAplikasi.redup),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Kerangka berdenyut selagi data dimuat, pengganti lingkaran putar.
class _KerangkaMuat extends StatefulWidget {
  const _KerangkaMuat();

  @override
  State<_KerangkaMuat> createState() => _KerangkaMuatState();
}

class _KerangkaMuatState extends State<_KerangkaMuat> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
    lowerBound: .35,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _balok(double lebar, double tinggi) => Container(
    width: lebar,
    height: tinggi,
    decoration: BoxDecoration(
      color: TemaAplikasi.redup.withValues(alpha: .28),
      borderRadius: BorderRadius.circular(8),
    ),
  );

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _c,
    child: Semantics(
      label: 'Memuat',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _balok(110, 12),
            const SizedBox(height: 12),
            _balok(190, 30),
            const SizedBox(height: 12),
            _balok(150, 12),
          ],
        ),
      ),
    ),
  );
}

/// Ruang tambahan di akhir daftar agar item terakhir tidak tertutup FAB.
const ruangFab = 88.0;

/// Padding untuk isi halaman yang digulir, ditambah inset bilah navigasi sistem.
///
/// ListView/GridView dengan padding eksplisit tidak menambahkan inset sistem
/// sendiri, sehingga di Android 15 (edge-to-edge) tombol terakhir tertutup
/// bilah navigasi. Memakai `MediaQuery.paddingOf` (sama seperti SafeArea):
/// bernilai 0 saat keyboard terbuka atau di dalam Scaffold yang sudah punya
/// bottomNavigationBar.
EdgeInsets paddingAman(BuildContext context, {EdgeInsets dasar = const EdgeInsets.all(16), bool adaFab = false}) =>
    dasar.copyWith(bottom: dasar.bottom + (adaFab ? ruangFab : 0) + MediaQuery.paddingOf(context).bottom);

/// Semua bottom sheet lewat sini: tidak menabrak status bar (`useSafeArea`) dan
/// isinya tidak tertutup bilah navigasi.
///
/// [gulir] (bawaan): isi dinaikkan setinggi keyboard dan bisa digulir, sehingga
/// formulir tidak overflow saat keyboard terbuka. Matikan untuk sheet yang
/// sudah mengatur tinggi & gulirnya sendiri (mis. berisi ListView).
Future<T?> tampilkanSheet<T>(BuildContext context, WidgetBuilder builder, {bool isScrollControlled = true, bool gulir = true}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useSafeArea: true,
      builder: (c) => SafeArea(
        top: false,
        child: gulir
            ? Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
                child: SingleChildScrollView(child: builder(c)),
              )
            : builder(c),
      ),
    );

/// AlertDialog standar aplikasi: tombol Batal & aksi utama sejajar di kanan.
/// Tema global membuat FilledButton selebar layar (untuk formulir); di dalam
/// dialog ukurannya dikembalikan normal.
class DialogAplikasi extends StatelessWidget {
  const DialogAplikasi({super.key, required this.judul, required this.isi, required this.aksi});

  final String judul;
  final Widget isi;
  final List<Widget> aksi;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size(64, 40))),
      ),
      child: AlertDialog(title: Text(judul), content: isi, actions: aksi),
    );
  }
}

void tampilPesan(BuildContext context, String pesan, {bool gagal = false, SnackBarAction? aksi}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(pesan),
      backgroundColor: gagal ? Theme.of(context).colorScheme.error : null,
      behavior: SnackBarBehavior.floating,
      action: aksi,
    ));
}

/// Jalankan aksi API dengan pesan sukses/gagal. Mengembalikan true jika sukses.
Future<bool> jalankan(BuildContext context, Future<void> Function() aksi, {String? sukses}) async {
  try {
    await aksi();
    if (context.mounted && sukses != null) tampilPesan(context, sukses);
    return true;
  } catch (e) {
    if (context.mounted) tampilPesan(context, pesanDari(e), gagal: true);
    return false;
  }
}

Future<bool> konfirmasi(BuildContext context, String judul, String isi, {String ya = 'Ya'}) async {
  final hasil = await showDialog<bool>(
    context: context,
    builder: (c) => DialogAplikasi(
      judul: judul,
      isi: Text(isi),
      aksi: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(ya)),
      ],
    ),
  );
  return hasil ?? false;
}

class LabelStatus extends StatelessWidget {
  const LabelStatus(this.teks, {super.key, this.warna});

  final String teks;
  final Color? warna;

  @override
  Widget build(BuildContext context) {
    final w = warna ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: w.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      // Status mentah dari API ("tersedia", "siaga") diawali huruf kapital
      child: Text(teks.isEmpty ? teks : teks[0].toUpperCase() + teks.substring(1), style: TextStyle(color: w, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

Color warnaStatus(String status) => switch (status) {
      'diajukan' => Colors.orange.shade800,
      'dijadwalkan' || 'menuju' => Colors.blue.shade700,
      'diambil' => Colors.indigo,
      'selesai' || 'disetujui' || 'siaga' => TemaAplikasi.hijau,
      'ditolak' || 'dibatalkan' || 'nonaktif' => Colors.red.shade700,
      'bertugas' => Colors.blue.shade700,
      _ => Colors.grey.shade700,
    };
