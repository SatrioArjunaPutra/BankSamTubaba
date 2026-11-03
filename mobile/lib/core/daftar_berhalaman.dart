import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'gerak.dart';
import 'widgets.dart';

/// Daftar dengan pull-to-refresh dan infinite scroll (20 item per halaman).
/// Ganti [kunci] untuk memuat ulang dari halaman 1 (mis. saat filter berubah).
class DaftarBerhalaman<T> extends StatefulWidget {
  const DaftarBerhalaman({
    super.key,
    required this.muat,
    required this.itemBuilder,
    this.kosong = 'Belum ada data.',
    this.padding = const EdgeInsets.all(12),
    this.pemisah = 8,
    this.header,
    this.adaFab = false,
  });

  final Future<Halaman<T>> Function(int halaman) muat;
  final Widget Function(BuildContext context, T item, VoidCallback segarkan) itemBuilder;
  final String kosong;
  final EdgeInsets padding;
  final double pemisah;
  final Widget? header;

  /// Halaman punya FAB: beri ruang di akhir daftar agar item terakhir tidak tertutup.
  final bool adaFab;

  @override
  State<DaftarBerhalaman<T>> createState() => DaftarBerhalamanState<T>();
}

class DaftarBerhalamanState<T> extends State<DaftarBerhalaman<T>> {
  final _items = <T>[];
  final _scroll = ScrollController();
  int _halaman = 0;
  bool _adaBerikutnya = true;
  bool _memuat = true; // spinner langsung tampil sampai halaman pertama datang
  String? _galat;
  int _generasi = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _muatBerikutnya();
    });
    // Setelah frame pertama: muat() boleh mengubah provider/state lain
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _muatBerikutnya(paksa: true);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Muat ulang dari halaman pertama.
  Future<void> segarkan() async {
    _generasi++;
    setState(() {
      _items.clear();
      _halaman = 0;
      _adaBerikutnya = true;
      _memuat = false;
      _galat = null;
    });
    await _muatBerikutnya();
  }

  /// Dipakai pemanggil yang ingin tahu apakah ini muat ulang oleh pengguna.
  bool get sudahPernahMuat => _halaman > 0 || _galat != null;

  Future<void> _muatBerikutnya({bool paksa = false}) async {
    if ((_memuat && !paksa) || !_adaBerikutnya) return;
    final generasi = _generasi;
    setState(() {
      _memuat = true;
      _galat = null;
    });
    try {
      final hasil = await widget.muat(_halaman + 1);
      if (!mounted || generasi != _generasi) return;
      setState(() {
        _items.addAll(hasil.items);
        _halaman = hasil.halaman;
        _adaBerikutnya = hasil.adaBerikutnya;
      });
    } catch (e) {
      if (mounted && generasi == _generasi) setState(() => _galat = pesanDari(e));
    } finally {
      if (mounted && generasi == _generasi) setState(() => _memuat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final header = widget.header;
    final adaHeader = header != null ? 1 : 0;

    // Kosong/galat tetap bisa ditarik untuk menyegarkan, dengan padding yang sama dengan daftar
    final paddingDaftar = paddingAman(context, dasar: widget.padding, adaFab: widget.adaFab);
    Widget isi;
    if (_items.isEmpty && _galat != null) {
      isi = ListView(physics: const AlwaysScrollableScrollPhysics(), padding: paddingDaftar, children: [?header, PesanGagal(pesan: _galat!, onUlang: segarkan)]);
    } else if (_items.isEmpty && !_memuat) {
      isi = ListView(physics: const AlwaysScrollableScrollPhysics(), padding: paddingDaftar, children: [?header, Kosong(pesan: widget.kosong)]);
    } else {
      isi = ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: paddingDaftar,
        itemCount: adaHeader + _items.length + 1,
        separatorBuilder: (_, i) => SizedBox(height: i < adaHeader ? 0 : widget.pemisah),
        itemBuilder: (context, i) {
          if (i < adaHeader) return header!;
          final idx = i - adaHeader;
          if (idx < _items.length) {
            return MunculBertahap(
              urutan: idx < 6 ? idx : 0,
              child: widget.itemBuilder(context, _items[idx], segarkan),
            );
          }
          if (_galat != null) {
            return TextButton(onPressed: _muatBerikutnya, child: Text('$_galat Ketuk untuk mencoba lagi.'));
          }
          return _memuat
              ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
              : const SizedBox(height: 24);
        },
      );
    }

    return RefreshIndicator(onRefresh: segarkan, child: isi);
  }
}
