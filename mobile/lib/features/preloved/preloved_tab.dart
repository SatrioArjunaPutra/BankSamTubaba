import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/models/preloved.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'preloved_repository.dart';

/// Tab Preloved: grid barang tersedia, cari, filter kategori & kecamatan,
/// pull-to-refresh, infinite scroll.
class PrelovedTab extends ConsumerStatefulWidget {
  const PrelovedTab({super.key});

  @override
  ConsumerState<PrelovedTab> createState() => PrelovedTabState();
}

class PrelovedTabState extends ConsumerState<PrelovedTab> {
  final _scroll = ScrollController();
  final _items = <BarangPreloved>[];
  String _q = '';
  String? _kategori;
  String? _kecamatan;
  int _halaman = 0;
  bool _adaBerikutnya = true;
  bool _memuat = true;
  String? _galat;
  int _generasi = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        _muat();
      }
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
    await _muat();
  }

  Future<void> _muat({bool paksa = false}) async {
    if ((_memuat && !paksa) || !_adaBerikutnya) return;
    final generasi = _generasi;
    setState(() {
      _memuat = true;
      _galat = null;
    });
    try {
      final h = await ref
          .read(prelovedRepositoryProvider)
          .daftar(
            q: _q,
            kategori: _kategori,
            kecamatan: _kecamatan,
            halaman: _halaman + 1,
          );
      if (!mounted || generasi != _generasi) return;
      setState(() {
        _items.addAll(h.items);
        _halaman = h.halaman;
        _adaBerikutnya = h.adaBerikutnya;
      });
    } catch (e) {
      if (mounted && generasi == _generasi) {
        setState(() => _galat = pesanDari(e));
      }
    } finally {
      if (mounted && generasi == _generasi) setState(() => _memuat = false);
    }
  }

  Widget _filter(
    String label,
    String? nilai,
    List<String> pilihan,
    ValueChanged<String?> ubah,
  ) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: FilterChip(
      label: Text(nilai ?? label),
      selected: nilai != null,
      onSelected: (_) async {
        final dipilih = await tampilkanSheet<String>(
          context,
          isScrollControlled: false,
          gulir: false,
          (c) => ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: Text('Semua ${label.toLowerCase()}'),
                onTap: () => Navigator.pop(c, ''),
              ),
              for (final p in pilihan)
                ListTile(
                  title: Text(p),
                  selected: p == nilai,
                  onTap: () => Navigator.pop(c, p),
                ),
            ],
          ),
        );
        if (dipilih == null) return;
        ubah(dipilih.isEmpty ? null : dipilih);
        segarkan();
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Cari kursi, baju, buku…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Barang saya',
                icon: const Icon(Icons.inventory_2_outlined),
                onPressed: () => context.push('/warga/preloved/saya'),
              ),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (v) {
              _q = v.trim();
              segarkan();
            },
          ),
        ),
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            children: [
              for (final kategori in [
                null,
                'Perabot',
                'Pakaian',
                'Elektronik',
                'Buku',
                ...kategoriPreloved.where(
                  (k) =>
                      !['Perabot', 'Pakaian', 'Elektronik', 'Buku'].contains(k),
                ),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(kategori ?? 'Semua'),
                    selected: _kategori == kategori,
                    showCheckmark: false,
                    selectedColor: TemaAplikasi.hijauPekat,
                    labelStyle: TextStyle(
                      color: _kategori == kategori
                          ? Colors.white
                          : TemaAplikasi.redup,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: const StadiumBorder(),
                    onSelected: (_) {
                      setState(() => _kategori = kategori);
                      segarkan();
                    },
                  ),
                ),
              _filter(
                'Kecamatan',
                _kecamatan,
                kecamatanTubaba,
                (v) => _kecamatan = v,
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: segarkan,
            child: _items.isEmpty && _galat != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [PesanGagal(pesan: _galat!, onUlang: segarkan)],
                  )
                : _items.isEmpty && !_memuat
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      Kosong(
                        pesan:
                            'Belum ada barang. Jadilah yang pertama menjual!',
                        ikon: Icons.storefront_outlined,
                      ),
                    ],
                  )
                : GridView.builder(
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: paddingAman(
                      context,
                      dasar: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      adaFab: true,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.68,
                        ),
                    itemCount: _items.length + (_memuat ? 2 : 0),
                    itemBuilder: (context, i) => i < _items.length
                        ? KartuBarang(barang: _items[i], onKembali: segarkan)
                        : const Card(
                            child: Center(child: CircularProgressIndicator()),
                          ),
                  ),
          ),
        ),
      ],
    );
  }
}

class KartuBarang extends StatelessWidget {
  const KartuBarang({super.key, required this.barang, this.onKembali});

  final BarangPreloved barang;
  final VoidCallback? onKembali;

  @override
  Widget build(BuildContext context) {
    final b = barang;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final berubah = await context.push<bool>('/warga/preloved/${b.id}');
          if (berubah == true) onKembali?.call();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FotoJaringan(url: b.foto.firstOrNull),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .95),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'COD',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: TemaAplikasi.hijauPekat,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.kategori,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: TemaAplikasi.redup,
                    ),
                  ),
                  Text(
                    b.judul,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rupiah(b.harga),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    b.kecamatan,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (!b.tersedia)
                    LabelStatus(
                      b.status,
                      warna: b.status == 'terjual'
                          ? Colors.grey.shade700
                          : Colors.red.shade700,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
