import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/daftar_berhalaman.dart';
import '../../core/format.dart';
import '../../core/models/pemberitahuan.dart';
import '../../core/repositories.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

const _intervalLonceng = Duration(seconds: 30);

/// Ikon lonceng berangka. Jumlah belum dibaca diambil berkala selama aplikasi
/// terbuka (polling, bukan push). Pemberitahuan yang diketuk dikembalikan ke
/// [onBuka] agar tiap peran membuka halamannya sendiri.
class LoncengPemberitahuan extends ConsumerStatefulWidget {
  const LoncengPemberitahuan({super.key, required this.onBuka, this.gaya});

  final ValueChanged<Pemberitahuan> onBuka;
  final ButtonStyle? gaya;

  @override
  ConsumerState<LoncengPemberitahuan> createState() => _LoncengPemberitahuanState();
}

class _LoncengPemberitahuanState extends ConsumerState<LoncengPemberitahuan> with WidgetsBindingObserver {
  int _jumlah = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mulai();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _mulai();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  void _mulai() {
    _timer?.cancel();
    _muat();
    _timer = Timer.periodic(_intervalLonceng, (_) => _muat());
  }

  Future<void> _muat() async {
    try {
      final jumlah = await ref.read(umumRepositoryProvider).jumlahBelumDibaca();
      if (mounted && jumlah != _jumlah) setState(() => _jumlah = jumlah);
    } catch (_) {
      // Gagal jaringan: angka lama tetap tampil, dicoba lagi di putaran berikutnya
    }
  }

  Future<void> _buka() async {
    final dipilih = await context.push<Pemberitahuan>('/akun/pemberitahuan');
    await _muat();
    if (dipilih != null && mounted) widget.onBuka(dipilih);
  }

  @override
  Widget build(BuildContext context) => IconButton(
        style: widget.gaya,
        tooltip: _jumlah == 0 ? 'Pemberitahuan' : 'Pemberitahuan, $_jumlah belum dibaca',
        onPressed: _buka,
        icon: Badge(
          isLabelVisible: _jumlah > 0,
          label: Text(_jumlah > 99 ? '99+' : '$_jumlah'),
          backgroundColor: Theme.of(context).colorScheme.error,
          child: const Icon(Icons.notifications_none_outlined, color: TemaAplikasi.hijauPekat),
        ),
      );
}

/// Daftar pemberitahuan; mengetuk satu akan menandainya dibaca lalu kembali
/// ke halaman pemanggil dengan pemberitahuan itu.
class PemberitahuanPage extends ConsumerStatefulWidget {
  const PemberitahuanPage({super.key});

  @override
  ConsumerState<PemberitahuanPage> createState() => _PemberitahuanPageState();
}

class _PemberitahuanPageState extends ConsumerState<PemberitahuanPage> {
  final _daftar = GlobalKey<DaftarBerhalamanState<Pemberitahuan>>();

  Future<void> _bacaSemua() async {
    final ok = await jalankan(
      context,
      () => ref.read(umumRepositoryProvider).bacaSemuaPemberitahuan(),
      sukses: 'Semua pemberitahuan ditandai dibaca.',
    );
    if (ok) _daftar.currentState?.segarkan();
  }

  /// Tandai dibaca dulu (maks. 3 detik) agar angka lonceng sudah turun saat kembali.
  /// Bila gagal, halaman tetap dibuka dan pemberitahuan masih terhitung belum dibaca.
  Future<void> _buka(Pemberitahuan p) async {
    if (!p.dibaca) {
      try {
        await ref.read(umumRepositoryProvider).bacaPemberitahuan(p.id).timeout(const Duration(seconds: 3));
      } catch (_) {}
    }
    if (mounted) context.pop(p.sudahDibaca());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Pemberitahuan'),
          actions: [
            IconButton(
              tooltip: 'Tandai semua dibaca',
              onPressed: _bacaSemua,
              icon: const Icon(Icons.done_all),
            ),
          ],
        ),
        body: DaftarBerhalaman<Pemberitahuan>(
          key: _daftar,
          muat: (hal) => ref.read(umumRepositoryProvider).pemberitahuan(halaman: hal),
          kosong: 'Belum ada pemberitahuan.',
          pemisah: 0,
          itemBuilder: (context, p, _) => _ButirPemberitahuan(p, onTap: () => _buka(p)),
        ),
      );
}

class _ButirPemberitahuan extends StatelessWidget {
  const _ButirPemberitahuan(this.p, {required this.onTap});

  final Pemberitahuan p;
  final VoidCallback onTap;

  /// Ikon dan warna per jenis; jenis yang belum dikenal memakai lonceng.
  static (IconData, Color) _gaya(String jenis) => switch (jenis) {
        'jemput_baru' || 'jemput_dijadwalkan' || 'jemput_menuju' || 'tugas_baru' => (Icons.local_shipping_outlined, TemaAplikasi.hijau),
        'jemput_diambil' || 'timbang_bentor' => (Icons.scale_outlined, TemaAplikasi.hijau),
        'setoran_tercatat' || 'penarikan_disetujui' => (Icons.savings_outlined, TemaAplikasi.hijau),
        'donasi_diterima' => (Icons.volunteer_activism_outlined, TemaAplikasi.hijau),
        'penarikan_baru' => (Icons.account_balance_wallet_outlined, TemaAplikasi.kuningTua),
        'jemput_ditolak' || 'setoran_dibatalkan' || 'penarikan_ditolak' || 'barang_disembunyikan' =>
          (Icons.error_outline, TemaAplikasi.kuningTua),
        _ => (Icons.notifications_none_outlined, TemaAplikasi.hijau),
      };

  @override
  Widget build(BuildContext context) {
    final (ikon, warna) = _gaya(p.jenis);
    return Material(
      color: p.dibaca ? Colors.transparent : TemaAplikasi.hijauLembut.withValues(alpha: .6),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: warna.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
                child: Icon(ikon, color: warna, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.judul,
                      style: TextStyle(fontSize: 14, fontWeight: p.dibaca ? FontWeight.w600 : FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(p.isi, style: const TextStyle(fontSize: 12.5, height: 1.4, color: TemaAplikasi.redup)),
                    const SizedBox(height: 4),
                    Text(tanggalRingkas(p.dibuat), style: const TextStyle(fontSize: 11, color: TemaAplikasi.redup)),
                  ],
                ),
              ),
              if (!p.dibaca)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6, left: 8),
                  decoration: const BoxDecoration(color: TemaAplikasi.hijau, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
