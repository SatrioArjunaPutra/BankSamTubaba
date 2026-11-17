import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/komponen_ui.dart';
import '../../core/models/preloved.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../auth/auth_controller.dart';
import 'chat_pages.dart';
import 'preloved_repository.dart';
import 'preloved_tab.dart';

/// Cari barang dengan kata kunci, kategori, kondisi, kecamatan, dan urutan harga.
class CariBarangPage extends ConsumerStatefulWidget {
  const CariBarangPage({super.key, this.kategori, this.urut});

  final String? kategori;
  final String? urut;

  @override
  ConsumerState<CariBarangPage> createState() => _CariBarangPageState();
}

class _CariBarangPageState extends ConsumerState<CariBarangPage> {
  final _grid = GlobalKey<GridBarangState>();
  final _teks = TextEditingController();
  late String? _kategori = widget.kategori;
  late String _urut = widget.urut ?? 'terbaru';
  String? _kondisi;
  String? _kecamatan;

  @override
  void dispose() {
    _teks.dispose();
    super.dispose();
  }

  void _ubah(VoidCallback ubah) {
    setState(ubah);
    _grid.currentState?.segarkan();
  }

  Future<void> _pilih(String judul, Map<String, String> pilihan, String? nilai, ValueChanged<String?> ubah, {bool bisaKosong = true}) async {
    final dipilih = await tampilkanSheet<String>(
      context,
      isScrollControlled: false,
      gulir: false,
      (c) => ListView(shrinkWrap: true, children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 8), child: Text(judul, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
        if (bisaKosong) ListTile(title: const Text('Semua'), selected: nilai == null, onTap: () => Navigator.pop(c, '')),
        for (final p in pilihan.entries) ListTile(title: Text(p.value), selected: p.key == nilai, onTap: () => Navigator.pop(c, p.key)),
      ]),
    );
    if (dipilih == null) return;
    _ubah(() => ubah(dipilih.isEmpty ? null : dipilih));
  }

  Widget _chip(String label, String? nilai, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(nilai ?? label),
          selected: nilai != null,
          showCheckmark: false,
          avatar: const Icon(Icons.expand_more, size: 18),
          onSelected: (_) => onTap(),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _teks,
          autofocus: widget.kategori == null && widget.urut == null,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Cari kursi, baju, buku…',
            isDense: true,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              tooltip: 'Hapus kata kunci',
              icon: const Icon(Icons.close),
              onPressed: () => _ubah(_teks.clear),
            ),
          ),
          onSubmitted: (_) => _grid.currentState?.segarkan(),
        ),
        actions: const [SizedBox(width: 12)],
      ),
      body: GridBarang(
        key: _grid,
        kosong: 'Barang tidak ditemukan. Coba kata kunci atau saringan lain.',
        muat: (hal) => ref.read(prelovedRepositoryProvider).daftar(
              q: _teks.text.trim(),
              kategori: _kategori,
              kondisi: _kondisi,
              kecamatan: _kecamatan,
              urut: _urut,
              halaman: hal,
            ),
        header: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: [
                  _chip('Urutkan', urutanBarang[_urut], () => _pilih('Urutkan', urutanBarang, _urut, (v) => _urut = v ?? 'terbaru', bisaKosong: false)),
                  _chip('Kategori', _kategori, () => _pilih('Kategori', {for (final k in kategoriPreloved) k: k}, _kategori, (v) => _kategori = v)),
                  _chip('Kondisi', kondisiSingkat[_kondisi], () => _pilih('Kondisi', kondisiSingkat, _kondisi, (v) => _kondisi = v)),
                  _chip('Kecamatan', _kecamatan, () => _pilih('Kecamatan', {for (final k in kecamatanTubaba) k: k}, _kecamatan, (v) => _kecamatan = v)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barang yang disimpan warga dengan tombol hati.
class FavoritPage extends ConsumerWidget {
  const FavoritPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Favorit saya')),
        body: GridBarang(
          muat: (hal) => ref.read(prelovedRepositoryProvider).favoritSaya(halaman: hal),
          kosong: 'Belum ada barang favorit.\nKetuk ikon hati pada barang untuk menyimpannya.',
        ),
      );
}

/// Halaman toko milik warga: ajakan menjual, pintasan, dan semua barang yang dijual.
class TokoSayaPage extends ConsumerStatefulWidget {
  const TokoSayaPage({super.key});

  @override
  ConsumerState<TokoSayaPage> createState() => _TokoSayaPageState();
}

class _TokoSayaPageState extends ConsumerState<TokoSayaPage> {
  final _grid = GlobalKey<GridBarangState>();

  Future<void> _jual() async {
    if (await context.push<bool>('/warga/preloved/jual') == true) _grid.currentState?.segarkan();
  }

  @override
  Widget build(BuildContext context) {
    final nama = ref.watch(authProvider).value?.name ?? 'Warga Tubaba';
    return Scaffold(
      appBar: AppBar(title: const Text('Toko saya')),
      body: GridBarang(
        key: _grid,
        muat: (hal) => ref.read(prelovedRepositoryProvider).milikSaya(halaman: hal),
        kosong: 'Kamu belum menjual barang.',
        header: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: TemaAplikasi.hijauLembut,
                      child: Text(nama.trim().isEmpty ? 'W' : nama.trim()[0].toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w800, color: TemaAplikasi.hijauPekat)),
                    ),
                    title: Text(nama, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('Penjual preloved · transaksi COD'),
                  ),
                ),
                const SizedBox(height: 12),
                _BannerJual(onJual: _jual),
                const SizedBox(height: 12),
                Card(
                  child: Column(children: [
                    ListTile(
                      leading: const Icon(Icons.favorite_border),
                      title: const Text('Favorit'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/warga/preloved/favorit'),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.chat_bubble_outline),
                      title: const Text('Chat dan tawaran'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/warga/chat'),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
          const SliverToBoxAdapter(child: JudulDeret('Barang yang kamu jual')),
        ],
      ),
    );
  }
}

class _BannerJual extends StatelessWidget {
  const _BannerJual({required this.onJual});

  final VoidCallback onJual;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: DecoratedBox(
          decoration: const BoxDecoration(color: TemaAplikasi.hijauPekat, image: corakTapis),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Mulai jual barangmu', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  SizedBox(height: 4),
                  Text('Barang tak terpakai bisa jadi cuan, dan sampahnya berkurang.', style: TextStyle(color: Colors.white70)),
                ]),
              ),
              const SizedBox(width: 12),
              FilledButton(
                // Tema bawaan membuat tombol selebar layar; di dalam Row lebarnya harus dibatasi
                style: FilledButton.styleFrom(
                  backgroundColor: TemaAplikasi.limau,
                  foregroundColor: TemaAplikasi.hijauPekat,
                  minimumSize: const Size(88, 44),
                ),
                onPressed: onJual,
                child: const Text('Jual'),
              ),
            ]),
          ),
        ),
      );
}

/// Daftar percakapan sebagai halaman tersendiri, dibuka dari Toko saya.
class DaftarChatPage extends StatelessWidget {
  const DaftarChatPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Chat dan tawaran')),
        body: const DaftarChatTab(aktif: true),
      );
}
