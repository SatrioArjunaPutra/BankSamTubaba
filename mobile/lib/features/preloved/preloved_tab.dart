import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../core/gerak.dart';
import '../../core/komponen_ui.dart' show corakTapis;
import '../../core/models/preloved.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'preloved_repository.dart';

/// Ikon dan warna lembut tiap kategori, dipakai di deret kategori.
const gayaKategori = <String, ({IconData ikon, Color latar, Color warna})>{
  'Pakaian': (ikon: Icons.checkroom_outlined, latar: Color(0xFFFCE7F3), warna: Color(0xFFBE185D)),
  'Elektronik': (ikon: Icons.devices_other_outlined, latar: Color(0xFFE0F2FE), warna: Color(0xFF0369A1)),
  'Perabot': (ikon: Icons.chair_outlined, latar: Color(0xFFFEF3C7), warna: Color(0xFFB45309)),
  'Buku': (ikon: Icons.menu_book_outlined, latar: Color(0xFFEDE9FE), warna: Color(0xFF6D28D9)),
  'Mainan': (ikon: Icons.toys_outlined, latar: Color(0xFFFFEDD5), warna: Color(0xFFC2410C)),
  'Kerajinan Daur Ulang': (ikon: Icons.recycling_outlined, latar: Color(0xFFDCFCE7), warna: Color(0xFF15803D)),
  'Lainnya': (ikon: Icons.category_outlined, latar: Color(0xFFF1F5F9), warna: Color(0xFF475569)),
};

final _barangHematProvider = FutureProvider.autoDispose<List<BarangPreloved>>(
  (ref) async => (await ref.watch(prelovedRepositoryProvider).daftar(urut: 'termurah')).items.take(10).toList(),
);

final _favoritRingkasProvider = FutureProvider.autoDispose<List<BarangPreloved>>(
  (ref) async => (await ref.watch(prelovedRepositoryProvider).favoritSaya()).items.take(10).toList(),
);

/// Tab Preloved: header bermotif tapis, kategori, deret favorit dan harga hemat, lalu semua barang terbaru.
class PrelovedTab extends ConsumerStatefulWidget {
  const PrelovedTab({super.key});

  @override
  ConsumerState<PrelovedTab> createState() => PrelovedTabState();
}

class PrelovedTabState extends ConsumerState<PrelovedTab> {
  final _grid = GlobalKey<GridBarangState>();

  Future<void> segarkan() async {
    ref.invalidate(_barangHematProvider);
    ref.invalidate(_favoritRingkasProvider);
    await _grid.currentState?.segarkan();
  }

  Future<void> _buka(String lokasi, {Object? extra}) async {
    await context.push(lokasi, extra: extra);
    if (mounted) segarkan();
  }

  @override
  Widget build(BuildContext context) {
    final favorit = ref.watch(_favoritRingkasProvider);
    final hemat = ref.watch(_barangHematProvider);

    return GridBarang(
      key: _grid,
      muat: (hal) => ref.read(prelovedRepositoryProvider).daftar(halaman: hal),
      onSegarkan: () async {
        ref.invalidate(_barangHematProvider);
        ref.invalidate(_favoritRingkasProvider);
      },
      adaFab: true,
      kosong: 'Belum ada barang. Jadilah yang pertama menjual!',
      header: [
        SliverToBoxAdapter(
          child: _HeaderPreloved(
            onCari: () => _buka('/warga/preloved/cari'),
            onFavorit: () => _buka('/warga/preloved/favorit'),
            onToko: () => _buka('/warga/preloved/saya'),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 104,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
              children: [
                for (final (i, k) in kategoriPreloved.indexed)
                  MunculBertahap(
                    urutan: i,
                    child: _TombolKategori(kategori: k, onTap: () => _buka('/warga/preloved/cari', extra: {'kategori': k})),
                  ),
              ],
            ),
          ),
        ),
        if (favorit.value?.isNotEmpty ?? false)
          SliverToBoxAdapter(
            child: DeretBarang(
              judul: 'Favoritmu',
              ikon: Icons.favorite,
              warnaIkon: Colors.red.shade600,
              barang: favorit.value!,
              onLihatSemua: () => _buka('/warga/preloved/favorit'),
              onKembali: segarkan,
            ),
          ),
        if (hemat.value?.isNotEmpty ?? false)
          SliverToBoxAdapter(
            child: DeretBarang(
              judul: 'Harga hemat',
              ikon: Icons.local_offer_outlined,
              warnaIkon: TemaAplikasi.hijau,
              barang: hemat.value!,
              onLihatSemua: () => _buka('/warga/preloved/cari', extra: {'urut': 'termurah'}),
              onKembali: segarkan,
            ),
          ),
        SliverToBoxAdapter(child: _AjakanJual(onTap: () => _buka('/warga/preloved/jual'))),
        const SliverToBoxAdapter(child: JudulDeret('Barang terbaru', ikon: Icons.auto_awesome_outlined)),
      ],
    );
  }
}

class _HeaderPreloved extends StatelessWidget {
  const _HeaderPreloved({required this.onCari, required this.onFavorit, required this.onToko});

  final VoidCallback onCari;
  final VoidCallback onFavorit;
  final VoidCallback onToko;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: DecoratedBox(
            decoration: const BoxDecoration(color: TemaAplikasi.hijauPekat, image: corakTapis),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 12, 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Preloved Warga', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      SizedBox(height: 2),
                      Text('Barang bekas layak pakai dari warga sekitar', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ]),
                  ),
                  _TombolBulat(ikon: Icons.favorite_border, tooltip: 'Favorit saya', onTap: onFavorit),
                  const SizedBox(width: 6),
                  _TombolBulat(ikon: Icons.storefront_outlined, tooltip: 'Toko saya', onTap: onToko),
                ]),
                const SizedBox(height: 14),
                Padding(padding: const EdgeInsets.only(right: 6), child: KotakCari(onTap: onCari, terang: true)),
              ]),
            ),
          ),
        ),
      );
}

class _TombolBulat extends StatelessWidget {
  const _TombolBulat({required this.ikon, required this.tooltip, required this.onTap});

  final IconData ikon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.white.withValues(alpha: .14),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(padding: const EdgeInsets.all(10), child: Icon(ikon, color: Colors.white, size: 22)),
          ),
        ),
      );
}

/// Kotak cari yang membuka halaman cari. [terang] untuk dipasang di atas latar gelap.
class KotakCari extends StatelessWidget {
  const KotakCari({super.key, required this.onTap, this.teks = 'Cari barang preloved…', this.terang = false});

  final VoidCallback onTap;
  final String teks;
  final bool terang;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Cari barang',
        excludeSemantics: true,
        child: Material(
          color: terang ? Colors.white : TemaAplikasi.hijauLembut,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(children: [
                const Icon(Icons.search, color: TemaAplikasi.hijau),
                const SizedBox(width: 10),
                Expanded(child: Text(teks, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: TemaAplikasi.redup))),
                const Icon(Icons.tune, color: TemaAplikasi.redup, size: 20),
              ]),
            ),
          ),
        ),
      );
}

class _TombolKategori extends StatelessWidget {
  const _TombolKategori({required this.kategori, required this.onTap});

  final String kategori;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gaya = gayaKategori[kategori] ?? gayaKategori['Lainnya']!;
    return SizedBox(
      width: 78,
      child: TekanSkala(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Column(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: gaya.latar, borderRadius: BorderRadius.circular(18)),
            child: Icon(gaya.ikon, color: gaya.warna, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            kategori == 'Kerajinan Daur Ulang' ? 'Daur ulang' : kategori,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          ]),
        ),
      ),
    );
  }
}

class _AjakanJual extends StatelessWidget {
  const _AjakanJual({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Material(
          color: TemaAplikasi.hijauLembut,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Row(children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: TemaAplikasi.hijau,
                  child: Icon(Icons.add_a_photo_outlined, color: Colors.white, size: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Punya barang tak terpakai?', style: TextStyle(fontWeight: FontWeight.w800)),
                    Text('Foto, beri harga, dan tunggu pembeli menghubungimu.', style: TextStyle(fontSize: 12, color: TemaAplikasi.redup)),
                  ]),
                ),
                Icon(Icons.chevron_right, color: TemaAplikasi.hijau),
              ]),
            ),
          ),
        ),
      );
}

class JudulDeret extends StatelessWidget {
  const JudulDeret(this.judul, {super.key, this.onLihatSemua, this.ikon, this.warnaIkon = TemaAplikasi.hijau});

  final String judul;
  final VoidCallback? onLihatSemua;
  final IconData? ikon;
  final Color warnaIkon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 12, 6),
        child: Row(children: [
          if (ikon != null) ...[Icon(ikon, size: 20, color: warnaIkon), const SizedBox(width: 6)],
          Expanded(child: Text(judul, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          if (onLihatSemua != null) TextButton(onPressed: onLihatSemua, child: const Text('Lihat semua')),
        ]),
      );
}

/// Deretan barang yang digeser ke samping, seperti "Your likes" di aplikasi preloved.
class DeretBarang extends StatelessWidget {
  const DeretBarang({
    super.key,
    required this.judul,
    required this.barang,
    this.ikon,
    this.warnaIkon = TemaAplikasi.hijau,
    this.onLihatSemua,
    this.onKembali,
  });

  final String judul;
  final List<BarangPreloved> barang;
  final IconData? ikon;
  final Color warnaIkon;
  final VoidCallback? onLihatSemua;
  final VoidCallback? onKembali;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        JudulDeret(judul, ikon: ikon, warnaIkon: warnaIkon, onLihatSemua: onLihatSemua),
        SizedBox(
          height: 300,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
            itemCount: barang.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => SizedBox(width: 160, child: KartuBarang(barang: barang[i], onKembali: onKembali)),
          ),
        ),
      ]);
}

/// Grid barang berhalaman dengan tarik-untuk-muat-ulang. [header] berupa sliver di atas grid.
class GridBarang extends StatefulWidget {
  const GridBarang({
    super.key,
    required this.muat,
    this.header = const [],
    this.kosong = 'Belum ada barang.',
    this.adaFab = false,
    this.onSegarkan,
    this.onTotal,
  });

  final Future<Halaman<BarangPreloved>> Function(int halaman) muat;
  final List<Widget> header;
  final String kosong;
  final bool adaFab;
  final Future<void> Function()? onSegarkan;

  /// Dipanggil dengan jumlah seluruh barang setiap halaman pertama dimuat
  final ValueChanged<int>? onTotal;

  @override
  State<GridBarang> createState() => GridBarangState();
}

class GridBarangState extends State<GridBarang> {
  final _scroll = ScrollController();
  final _items = <BarangPreloved>[];
  int _halaman = 0;
  bool _adaBerikutnya = true;
  bool _memuat = true;
  String? _galat;
  int _generasi = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) _muat();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _muat(paksa: true));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> segarkan() async {
    _generasi++;
    setState(() {
      _items.clear();
      _halaman = 0;
      _adaBerikutnya = true;
      _memuat = false;
      _galat = null;
    });
    await Future.wait([_muat(), ?widget.onSegarkan?.call()]);
  }

  Future<void> _muat({bool paksa = false}) async {
    if ((_memuat && !paksa) || !_adaBerikutnya) return;
    final generasi = _generasi;
    setState(() {
      _memuat = true;
      _galat = null;
    });
    try {
      final h = await widget.muat(_halaman + 1);
      if (!mounted || generasi != _generasi) return;
      if (h.halaman == 1) widget.onTotal?.call(h.total);
      setState(() {
        _items.addAll(h.items);
        _halaman = h.halaman;
        _adaBerikutnya = h.adaBerikutnya;
      });
    } catch (e) {
      if (mounted && generasi == _generasi) setState(() => _galat = pesanDari(e));
    } finally {
      if (mounted && generasi == _generasi) setState(() => _memuat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bawah = paddingAman(context, dasar: const EdgeInsets.fromLTRB(20, 8, 20, 20), adaFab: widget.adaFab);
    return RefreshIndicator(
      onRefresh: segarkan,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          ...widget.header,
          if (_items.isEmpty && _galat != null)
            SliverToBoxAdapter(child: PesanGagal(pesan: _galat!, onUlang: segarkan))
          else if (_items.isEmpty && !_memuat)
            SliverToBoxAdapter(child: Kosong(pesan: widget.kosong, ikon: Icons.storefront_outlined))
          else
            SliverPadding(
              padding: bawah,
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.52,
                ),
                itemCount: _items.length + (_memuat ? (_items.isEmpty ? 4 : 2) : 0),
                itemBuilder: (context, i) => i < _items.length
                    ? MunculBertahap(urutan: i % 6, child: KartuBarang(barang: _items[i], onKembali: segarkan))
                    : const KartuMemuat(),
              ),
            ),
        ],
      ),
    );
  }
}

/// Kerangka kartu yang berkedip pelan selama barang dimuat.
class KartuMemuat extends StatefulWidget {
  const KartuMemuat({super.key});

  @override
  State<KartuMemuat> createState() => _KartuMemuatState();
}

class _KartuMemuatState extends State<KartuMemuat> with SingleTickerProviderStateMixin {
  late final _kedip = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _kedip.dispose();
    super.dispose();
  }

  Widget _garis(double lebar) => Container(
        height: 12,
        width: lebar,
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(color: TemaAplikasi.garis, borderRadius: BorderRadius.circular(6)),
      );

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: .45, end: 1.0).animate(_kedip),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Container(decoration: BoxDecoration(color: TemaAplikasi.hijauLembut, borderRadius: BorderRadius.circular(18))),
          ),
          _garis(80),
          _garis(120),
          _garis(64),
        ]),
      );
}

/// Kartu barang bergaya aplikasi preloved: foto besar, kondisi, tombol favorit, lalu ringkasan.
class KartuBarang extends ConsumerStatefulWidget {
  const KartuBarang({super.key, required this.barang, this.onKembali});

  final BarangPreloved barang;
  final VoidCallback? onKembali;

  @override
  ConsumerState<KartuBarang> createState() => _KartuBarangState();
}

class _KartuBarangState extends ConsumerState<KartuBarang> {
  late BarangPreloved _b = widget.barang;
  bool _sibuk = false;

  @override
  void didUpdateWidget(KartuBarang lama) {
    super.didUpdateWidget(lama);
    if (!identical(lama.barang, widget.barang)) _b = widget.barang;
  }

  Future<void> _ubahFavorit() async {
    if (_sibuk) return;
    final semula = _b;
    final simpan = !_b.difavoritkan;
    // Langsung berubah di layar, lalu disamakan dengan jawaban server
    setState(() {
      _sibuk = true;
      _b = _b.denganFavorit(difavoritkan: simpan, jumlahFavorit: _b.jumlahFavorit + (simpan ? 1 : -1));
    });
    try {
      final baru = await ref.read(prelovedRepositoryProvider).favorit(_b.id, simpan: simpan);
      if (mounted) setState(() => _b = _b.denganFavorit(difavoritkan: baru.difavoritkan, jumlahFavorit: baru.jumlahFavorit));
    } catch (e) {
      if (!mounted) return;
      setState(() => _b = semula);
      tampilPesan(context, pesanDari(e), gagal: true);
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _b;
    return TekanSkala(
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFD7EEDF), width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            final berubah = await context.push<bool>('/warga/preloved/${b.id}');
            if (berubah == true) widget.onKembali?.call();
          },
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(fit: StackFit.expand, children: [
                    FotoJaringan(url: b.foto.firstOrNull),
                    if (!b.tersedia)
                      ColoredBox(
                        color: Colors.black45,
                        child: Center(child: LabelStatus(b.status == 'terjual' ? 'Terjual' : 'Disembunyikan', warna: Colors.white)),
                      ),
                    if (b.foto.length > 1)
                      Positioned(top: 6, left: 6, child: _Lencana(ikon: Icons.photo_library_outlined, teks: '${b.foto.length}')),
                    Positioned(right: 6, bottom: 6, child: _Lencana(teks: kondisiSingkat[b.kondisi] ?? b.kondisi)),
                  ]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    b.kategori.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: .4, color: TemaAplikasi.hijau),
                  ),
                  const SizedBox(height: 2),
                  Text(b.judul, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Row(children: [
                    const Icon(Icons.place_outlined, size: 12, color: TemaAplikasi.redup),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(b.kecamatan, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: TemaAplikasi.redup)),
                    ),
                  ]),
                  const Divider(height: 14, color: Color(0xFFE6F2EA)),
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(rupiah(b.harga), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: TemaAplikasi.hijau)),
                        ),
                        Text(
                          b.jumlahFavorit > 0 ? '${b.jumlahFavorit} menyimpan' : 'COD',
                          style: const TextStyle(fontSize: 11, color: TemaAplikasi.redup),
                        ),
                      ]),
                    ),
                    if (!b.milikSaya) TombolFavorit(barang: b, onTap: b.tersedia || b.difavoritkan ? _ubahFavorit : null),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Tombol hati kotak hijau seperti tombol tambah di katalog, membesar sesaat saat ditekan.
/// [onTap] null berarti tidak bisa ditekan.
class TombolFavorit extends StatelessWidget {
  const TombolFavorit({super.key, required this.barang, this.onTap});

  final BarangPreloved barang;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final aktif = barang.difavoritkan;
    return Semantics(
      // Simpul sendiri agar tidak tergabung ke kartu yang juga bisa diketuk
      container: true,
      button: true,
      label: aktif ? 'Hapus dari favorit' : 'Simpan ke favorit',
      excludeSemantics: true,
      child: Material(
        color: aktif ? const Color(0xFFFDE8EC) : TemaAplikasi.hijau,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: TweenAnimationBuilder<double>(
              key: ValueKey(aktif),
              tween: Tween(begin: aktif ? 1.5 : 1, end: 1),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutBack,
              builder: (_, skala, ikon) => Transform.scale(scale: skala, child: ikon),
              child: Icon(aktif ? Icons.favorite : Icons.favorite_border, size: 20, color: aktif ? Colors.red.shade600 : Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _Lencana extends StatelessWidget {
  const _Lencana({required this.teks, this.ikon});

  final String teks;
  final IconData? ikon;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .94), borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (ikon != null) ...[Icon(ikon, size: 13, color: TemaAplikasi.teks), const SizedBox(width: 3)],
            Text(teks, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: TemaAplikasi.hijauPekat)),
          ]),
        ),
      );
}

class FotoJaringan extends StatelessWidget {
  const FotoJaringan({super.key, required this.url, this.fit = BoxFit.cover});

  final String? url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final latar = Container(
      color: TemaAplikasi.hijauLembut,
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: TemaAplikasi.redup),
    );
    if (url == null) return latar;
    return Image.network(
      url!,
      fit: fit,
      width: double.infinity,
      errorBuilder: (_, _, _) => latar,
      frameBuilder: (_, gambar, bingkai, sinkron) => sinkron
          ? gambar
          : AnimatedOpacity(opacity: bingkai == null ? 0 : 1, duration: const Duration(milliseconds: 300), child: gambar),
      loadingBuilder: (c, child, progres) => progres == null ? child : latar,
    );
  }
}
