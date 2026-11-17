import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../core/models/preloved.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'preloved_repository.dart';

const ikonKategori = <String, IconData>{
  'Pakaian': Icons.checkroom_outlined,
  'Elektronik': Icons.devices_other_outlined,
  'Perabot': Icons.chair_outlined,
  'Buku': Icons.menu_book_outlined,
  'Mainan': Icons.toys_outlined,
  'Kerajinan Daur Ulang': Icons.recycling_outlined,
  'Lainnya': Icons.category_outlined,
};

final _barangHematProvider = FutureProvider.autoDispose<List<BarangPreloved>>(
  (ref) async => (await ref.watch(prelovedRepositoryProvider).daftar(urut: 'termurah')).items.take(10).toList(),
);

final _favoritRingkasProvider = FutureProvider.autoDispose<List<BarangPreloved>>(
  (ref) async => (await ref.watch(prelovedRepositoryProvider).favoritSaya()).items.take(10).toList(),
);

/// Tab Preloved: cari, kategori, deret favorit dan harga hemat, lalu semua barang terbaru.
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
            child: Row(children: [
              Expanded(child: KotakCari(onTap: () => _buka('/warga/preloved/cari'))),
              IconButton(
                tooltip: 'Favorit saya',
                onPressed: () => _buka('/warga/preloved/favorit'),
                icon: const Icon(Icons.favorite_border),
              ),
              IconButton(
                tooltip: 'Toko saya',
                onPressed: () => _buka('/warga/preloved/saya'),
                icon: const Icon(Icons.storefront_outlined),
              ),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              children: [
                for (final k in kategoriPreloved)
                  _TombolKategori(kategori: k, onTap: () => _buka('/warga/preloved/cari', extra: {'kategori': k})),
              ],
            ),
          ),
        ),
        if (favorit.value?.isNotEmpty ?? false)
          SliverToBoxAdapter(
            child: DeretBarang(
              judul: 'Favoritmu',
              barang: favorit.value!,
              onLihatSemua: () => _buka('/warga/preloved/favorit'),
              onKembali: segarkan,
            ),
          ),
        if (hemat.value?.isNotEmpty ?? false)
          SliverToBoxAdapter(
            child: DeretBarang(
              judul: 'Harga hemat',
              barang: hemat.value!,
              onLihatSemua: () => _buka('/warga/preloved/cari', extra: {'urut': 'termurah'}),
              onKembali: segarkan,
            ),
          ),
        const SliverToBoxAdapter(child: JudulDeret('Barang terbaru')),
      ],
    );
  }
}

/// Kotak cari yang membuka halaman cari.
class KotakCari extends StatelessWidget {
  const KotakCari({super.key, required this.onTap, this.teks = 'Cari barang preloved…'});

  final VoidCallback onTap;
  final String teks;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Cari barang',
        excludeSemantics: true,
        child: Material(
          color: TemaAplikasi.hijauLembut,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(children: [
                const Icon(Icons.search, color: TemaAplikasi.redup),
                const SizedBox(width: 10),
                Expanded(child: Text(teks, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: TemaAplikasi.redup))),
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
  Widget build(BuildContext context) => SizedBox(
        width: 76,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Column(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: TemaAplikasi.hijauLembut, borderRadius: BorderRadius.circular(14)),
              child: Icon(ikonKategori[kategori] ?? Icons.category_outlined, color: TemaAplikasi.hijauPekat),
            ),
            const SizedBox(height: 6),
            Text(
              kategori == 'Kerajinan Daur Ulang' ? 'Daur ulang' : kategori,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ]),
        ),
      );
}

class JudulDeret extends StatelessWidget {
  const JudulDeret(this.judul, {super.key, this.onLihatSemua});

  final String judul;
  final VoidCallback? onLihatSemua;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
        child: Row(children: [
          Expanded(child: Text(judul, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          if (onLihatSemua != null) TextButton(onPressed: onLihatSemua, child: const Text('Lihat semua')),
        ]),
      );
}

/// Deretan barang yang digeser ke samping, seperti "Your likes" di aplikasi preloved.
class DeretBarang extends StatelessWidget {
  const DeretBarang({super.key, required this.judul, required this.barang, this.onLihatSemua, this.onKembali});

  final String judul;
  final List<BarangPreloved> barang;
  final VoidCallback? onLihatSemua;
  final VoidCallback? onKembali;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        JudulDeret(judul, onLihatSemua: onLihatSemua),
        SizedBox(
          height: 268,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: barang.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => SizedBox(width: 156, child: KartuBarang(barang: barang[i], onKembali: onKembali)),
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
  });

  final Future<Halaman<BarangPreloved>> Function(int halaman) muat;
  final List<Widget> header;
  final String kosong;
  final bool adaFab;
  final Future<void> Function()? onSegarkan;

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
                  mainAxisSpacing: 18,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.6,
                ),
                itemCount: _items.length + (_memuat ? 2 : 0),
                itemBuilder: (context, i) => i < _items.length
                    ? KartuBarang(barang: _items[i], onKembali: segarkan)
                    : const _KartuMemuat(),
              ),
            ),
        ],
      ),
    );
  }
}

class _KartuMemuat extends StatelessWidget {
  const _KartuMemuat();

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: TemaAplikasi.hijauLembut, borderRadius: BorderRadius.circular(16)),
        child: const Center(child: CircularProgressIndicator()),
      );
}

/// Kartu barang bergaya aplikasi preloved: foto besar, tombol favorit, lalu ringkasan.
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
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final berubah = await context.push<bool>('/warga/preloved/${b.id}');
        if (berubah == true) widget.onKembali?.call();
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(fit: StackFit.expand, children: [
              FotoJaringan(url: b.foto.firstOrNull),
              if (!b.tersedia)
                ColoredBox(
                  color: Colors.black45,
                  child: Center(
                    child: LabelStatus(b.status == 'terjual' ? 'Terjual' : 'Disembunyikan', warna: Colors.white),
                  ),
                ),
              if (b.foto.length > 1)
                Positioned(
                  top: 8,
                  left: 8,
                  child: _Lencana(ikon: Icons.photo_library_outlined, teks: '${b.foto.length}'),
                ),
              Positioned(
                right: 8,
                bottom: 8,
                child: b.milikSaya
                    ? (b.jumlahFavorit > 0 ? _Lencana(ikon: Icons.favorite, teks: '${b.jumlahFavorit}', merah: true) : const SizedBox.shrink())
                    : TombolFavorit(barang: b, onTap: b.tersedia || b.difavoritkan ? _ubahFavorit : null),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${b.kategori} · ${kondisiSingkat[b.kondisi] ?? b.kondisi}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: TemaAplikasi.redup),
        ),
        Text(b.judul, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(rupiah(b.harga), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: TemaAplikasi.teks)),
        Row(children: [
          const Icon(Icons.place_outlined, size: 13, color: TemaAplikasi.redup),
          const SizedBox(width: 2),
          Expanded(
            child: Text(b.kecamatan, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: TemaAplikasi.redup)),
          ),
        ]),
      ]),
    );
  }
}

/// Tombol hati putih berisi jumlah favorit. [onTap] null berarti tidak bisa ditekan.
class TombolFavorit extends StatelessWidget {
  const TombolFavorit({super.key, required this.barang, this.onTap});

  final BarangPreloved barang;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        // Simpul sendiri agar tidak tergabung ke kartu yang juga bisa diketuk
        container: true,
        button: true,
        label: barang.difavoritkan ? 'Hapus dari favorit' : 'Simpan ke favorit',
        excludeSemantics: true,
        child: Material(
          color: Colors.white,
          shape: const StadiumBorder(),
          elevation: 1,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  barang.difavoritkan ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                  color: barang.difavoritkan ? Colors.red.shade600 : TemaAplikasi.teks,
                ),
                if (barang.jumlahFavorit > 0) ...[
                  const SizedBox(width: 4),
                  Text('${barang.jumlahFavorit}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ]),
            ),
          ),
        ),
      );
}

class _Lencana extends StatelessWidget {
  const _Lencana({required this.ikon, required this.teks, this.merah = false});

  final IconData ikon;
  final String teks;
  final bool merah;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .95), borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(ikon, size: 14, color: merah ? Colors.red.shade600 : TemaAplikasi.teks),
            const SizedBox(width: 3),
            Text(teks, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported_outlined),
    );
    if (url == null) return latar;
    return Image.network(
      url!,
      fit: fit,
      width: double.infinity,
      errorBuilder: (_, _, _) => latar,
      loadingBuilder: (c, child, progres) => progres == null ? child : latar,
    );
  }
}
