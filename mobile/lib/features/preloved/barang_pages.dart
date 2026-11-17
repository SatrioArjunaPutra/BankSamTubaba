
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_exception.dart';
import '../../core/format.dart';
import '../../core/models/preloved.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'preloved_repository.dart';
import 'preloved_tab.dart';

const infoCod = 'Transaksi dilakukan langsung (COD). Periksa barang sebelum membayar.';

final detailBarangProvider = FutureProvider.autoDispose.family<BarangPreloved, int>(
  (ref, id) => ref.watch(prelovedRepositoryProvider).detail(id),
);

/// Detail barang. Kembali dengan `true` jika barang berubah/dihapus agar
/// daftar pemanggil dimuat ulang.
class DetailBarangPage extends ConsumerStatefulWidget {
  const DetailBarangPage({super.key, required this.id});

  final int id;

  @override
  ConsumerState<DetailBarangPage> createState() => _DetailBarangPageState();
}

class _DetailBarangPageState extends ConsumerState<DetailBarangPage> {
  int _foto = 0;
  bool _berubah = false;
  bool _sibuk = false;
  BarangPreloved? _lokal;

  Future<void> _chat(BarangPreloved b) async {
    setState(() => _sibuk = true);
    try {
      final percakapan = await ref.read(prelovedRepositoryProvider).bukaChat(b.id);
      if (mounted) context.push('/warga/chat/${percakapan.id}', extra: percakapan);
    } catch (e) {
      if (mounted) tampilPesan(context, pesanDari(e), gagal: true);
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _lapor(BarangPreloved b) async {
    final teks = TextEditingController();
    final alasan = await showDialog<String>(
      context: context,
      builder: (c) => DialogAplikasi(
        judul: 'Laporkan barang',
        isi: TextField(
          controller: teks,
          autofocus: true,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(hintText: 'Contoh: barang palsu, penipuan, barang terlarang'),
        ),
        aksi: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(c, teks.text.trim()), child: const Text('Kirim')),
        ],
      ),
    );
    if (alasan == null || !mounted) return;
    if (alasan.length < 5) {
      tampilPesan(context, 'Tuliskan alasan minimal 5 huruf.', gagal: true);
      return;
    }
    await jalankan(context, () async {
      final pesan = await ref.read(prelovedRepositoryProvider).lapor(b.id, alasan);
      if (mounted) tampilPesan(context, pesan);
    });
  }

  Future<void> _terjual(BarangPreloved b) async {
    if (!await konfirmasi(context, 'Tandai terjual?', 'Barang tidak akan tampil lagi di daftar preloved.', ya: 'Terjual')) return;
    if (!mounted) return;
    final ok = await jalankan(context, () => ref.read(prelovedRepositoryProvider).tandaiTerjual(b.id), sukses: 'Barang ditandai terjual.');
    if (ok) {
      _berubah = true;
      ref.invalidate(detailBarangProvider(b.id));
    }
  }

  Future<void> _hapus(BarangPreloved b) async {
    if (!await konfirmasi(context, 'Hapus barang?', 'Barang, foto, dan percakapannya akan dihapus permanen.', ya: 'Hapus')) return;
    if (!mounted) return;
    final ok = await jalankan(context, () => ref.read(prelovedRepositoryProvider).hapus(b.id), sukses: 'Barang dihapus.');
    if (ok && mounted) context.pop(true);
  }

  Future<void> _ubahFavorit(BarangPreloved b) async {
    if (_sibuk) return;
    final simpan = !b.difavoritkan;
    setState(() {
      _sibuk = true;
      _lokal = b.denganFavorit(difavoritkan: simpan, jumlahFavorit: b.jumlahFavorit + (simpan ? 1 : -1));
    });
    try {
      final baru = await ref.read(prelovedRepositoryProvider).favorit(b.id, simpan: simpan);
      _berubah = true;
      if (mounted) setState(() => _lokal = b.denganFavorit(difavoritkan: baru.difavoritkan, jumlahFavorit: baru.jumlahFavorit));
    } catch (e) {
      if (!mounted) return;
      setState(() => _lokal = b);
      tampilPesan(context, pesanDari(e), gagal: true);
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(detailBarangProvider(widget.id));
    // Favorit yang baru ditekan ditampilkan tanpa menunggu detail dimuat ulang
    final dimuat = detail.value;
    final barang = _lokal != null && dimuat != null && _lokal!.id == dimuat.id ? _lokal! : dimuat;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.pop(_berubah);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Detail barang'),
          actions: [
            if (barang != null && !barang.milikSaya)
              IconButton(tooltip: 'Laporkan', onPressed: () => _lapor(barang), icon: const Icon(Icons.flag_outlined)),
          ],
        ),
        bottomNavigationBar: barang == null || barang.milikSaya
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(children: [
                    OutlinedButton.icon(
                      onPressed: barang.tersedia || barang.difavoritkan ? () => _ubahFavorit(barang) : null,
                      icon: Icon(barang.difavoritkan ? Icons.favorite : Icons.favorite_border, color: barang.difavoritkan ? Colors.red.shade600 : null),
                      label: Text(barang.jumlahFavorit > 0 ? '${barang.jumlahFavorit}' : 'Simpan'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: barang.tersedia && !_sibuk ? () => _chat(barang) : null,
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: Text(barang.tersedia ? 'Chat Penjual' : 'Tidak tersedia'),
                      ),
                    ),
                  ]),
                ),
              ),
        body: TampilanAsync(
          nilai: detail,
          onUlang: () => ref.invalidate(detailBarangProvider(widget.id)),
          data: (dariServer) {
            final b = barang ?? dariServer;
            return ListView(children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(children: [
                PageView(
                  onPageChanged: (i) => setState(() => _foto = i),
                  children: [for (final f in b.foto.isEmpty ? <String?>[null] : b.foto) FotoJaringan(url: f)],
                ),
                if (b.foto.length > 1)
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      for (var i = 0; i < b.foto.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: i == _foto ? 18 : 7,
                          height: 7,
                          margin: const EdgeInsets.all(3),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: i == _foto ? Colors.white : Colors.white60),
                        ),
                    ]),
                  ),
                if (b.foto.length > 1)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        child: Text('${_foto + 1}/${b.foto.length}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('${b.kategori} · ${kondisiBarang[b.kondisi] ?? b.kondisi}', style: const TextStyle(color: TemaAplikasi.redup)),
                const SizedBox(height: 2),
                Text(b.judul, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(rupiah(b.harga), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.place_outlined, size: 16, color: TemaAplikasi.redup),
                  const SizedBox(width: 4),
                  Expanded(child: Text(b.kecamatan, style: const TextStyle(color: TemaAplikasi.redup))),
                  if (b.jumlahFavorit > 0) ...[
                    Icon(Icons.favorite, size: 16, color: Colors.red.shade600),
                    const SizedBox(width: 4),
                    Text('${b.jumlahFavorit} menyimpan', style: const TextStyle(color: TemaAplikasi.redup)),
                  ],
                ]),
                if (!b.tersedia) ...[
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerLeft, child: LabelStatus(b.status == 'terjual' ? 'Terjual' : 'Disembunyikan', warna: Colors.red.shade700)),
                ],
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: TemaAplikasi.hijauLembut,
                      child: Text(
                        (b.penjual?.name.trim().isNotEmpty ?? false) ? b.penjual!.name.trim()[0].toUpperCase() : '?',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: TemaAplikasi.hijauPekat),
                      ),
                    ),
                    title: Text(b.milikSaya ? 'Barang Anda' : (b.penjual?.name ?? '-'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('Dipasang ${tanggal(b.createdAt)}'),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Deskripsi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(b.deskripsi),
                const SizedBox(height: 16),
                Card(
                  color: Colors.amber.shade50,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(children: [Icon(Icons.info_outline), SizedBox(width: 8), Expanded(child: Text(infoCod))]),
                  ),
                ),
                const SizedBox(height: 16),
                if (b.milikSaya) ...[
                  if (b.status == 'disembunyikan')
                    const Text('Barang ini disembunyikan oleh DLH karena laporan pengguna.', style: TextStyle(color: Colors.red)),
                  if (b.tersedia) FilledButton.icon(onPressed: () => _terjual(b), icon: const Icon(Icons.sell), label: const Text('Tandai terjual')),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      if (await context.push<bool>('/warga/preloved/${b.id}/ubah', extra: b) == true) {
                        _berubah = true;
                        ref.invalidate(detailBarangProvider(b.id));
                      }
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Ubah'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(onPressed: () => _hapus(b), icon: const Icon(Icons.delete_outline), label: const Text('Hapus')),
                ],
              ]),
            ),
          ]);
          },
        ),
      ),
    );
  }
}

/// Form jual (tambah) atau ubah barang. Foto 1–5, dikompres saat dipilih
/// (lebar maks. 1600 px, kualitas 75) dan ditolak jika masih > 2 MB.
class FormBarangPage extends ConsumerStatefulWidget {
  const FormBarangPage({super.key, this.barang});

  final BarangPreloved? barang;

  @override
  ConsumerState<FormBarangPage> createState() => _FormBarangPageState();
}

class _FormBarangPageState extends ConsumerState<FormBarangPage> {
  static const _maksFoto = 5;
  static const _maksByte = 2 * 1024 * 1024;

  final _form = GlobalKey<FormState>();
  late final _judul = TextEditingController(text: widget.barang?.judul);
  late final _deskripsi = TextEditingController(text: widget.barang?.deskripsi);
  late final _harga = TextEditingController(text: widget.barang?.harga.toStringAsFixed(0));
  late String? _kategori = widget.barang?.kategori;
  late String? _kondisi = widget.barang?.kondisi;
  late String? _kecamatan = widget.barang?.kecamatan;
  // Isi foto disimpan agar pratinjau dan cek ukuran berjalan juga di browser
  final _foto = <({XFile berkas, Uint8List isi})>[];
  bool _menyimpan = false;
  Map<String, String> _galat = {};

  bool get _ubah => widget.barang != null;

  @override
  void dispose() {
    _judul.dispose();
    _deskripsi.dispose();
    _harga.dispose();
    super.dispose();
  }

  Future<void> _tambahFoto(ImageSource sumber) async {
    final sisa = _maksFoto - _foto.length;
    final dipilih = sumber == ImageSource.camera
        ? [?await ImagePicker().pickImage(source: sumber, maxWidth: 1600, imageQuality: 75)]
        : await ImagePicker().pickMultiImage(maxWidth: 1600, imageQuality: 75, limit: sisa);

    var terlaluBesar = 0;
    for (final f in dipilih.take(sisa)) {
      final isi = await f.readAsBytes();
      if (isi.length > _maksByte) {
        terlaluBesar++;
      } else {
        _foto.add((berkas: f, isi: isi));
      }
    }
    if (!mounted) return;
    setState(() {});
    if (terlaluBesar > 0) tampilPesan(context, '$terlaluBesar foto masih lebih dari 2 MB dan dilewati.', gagal: true);
  }

  Future<void> _simpan() async {
    if (!_form.currentState!.validate()) return;
    if (!_ubah && _foto.isEmpty) {
      tampilPesan(context, 'Tambahkan minimal 1 foto.', gagal: true);
      return;
    }
    setState(() {
      _menyimpan = true;
      _galat = {};
    });
    final data = <String, Object>{
      'judul': _judul.text.trim(),
      'deskripsi': _deskripsi.text.trim(),
      'kategori': _kategori!,
      'kondisi': _kondisi!,
      'harga': double.parse(_harga.text),
      'kecamatan': _kecamatan!,
    };
    final repo = ref.read(prelovedRepositoryProvider);
    try {
      if (_ubah) {
        await repo.ubah(widget.barang!.id, data, [for (final f in _foto) f.berkas]);
      } else {
        await repo.pasang(data, [for (final f in _foto) f.berkas]);
      }
      if (!mounted) return;
      tampilPesan(context, _ubah ? 'Barang diperbarui.' : 'Barang berhasil dipasang.');
      context.pop(true);
    } on ApiException catch (e) {
      setState(() => _galat = e.errors);
      if (mounted) tampilPesan(context, e.pesan, gagal: true);
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String? wajib(Object? v) => (v == null || '$v'.trim().isEmpty) ? 'Wajib diisi.' : null;
    final galatFoto = _galat.entries.where((e) => e.key.startsWith('foto')).map((e) => e.value).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(_ubah ? 'Ubah barang' : 'Jual barang')),
      body: Form(
        key: _form,
        child: ListView(padding: paddingAman(context), children: [
          Text(_ubah ? 'Foto (pilih foto baru untuk mengganti semua foto lama)' : 'Foto (1–$_maksFoto)'),
          const SizedBox(height: 8),
          SizedBox(
            height: 96,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              if (_ubah && _foto.isEmpty)
                for (final url in widget.barang!.foto)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 96, child: FotoJaringan(url: url))),
                  ),
              for (var i = 0; i < _foto.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(_foto[i].isi, width: 96, height: 96, fit: BoxFit.cover)),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton.filledTonal(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _foto.removeAt(i)),
                        icon: const Icon(Icons.close, size: 16),
                      ),
                    ),
                  ]),
                ),
              if (_foto.length < _maksFoto) ...[
                _tombolFoto(Icons.photo_camera, 'Kamera', () => _tambahFoto(ImageSource.camera)),
                _tombolFoto(Icons.photo_library, 'Galeri', () => _tambahFoto(ImageSource.gallery)),
              ],
            ]),
          ),
          if (galatFoto != null) Text(galatFoto, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 16),
          TextFormField(controller: _judul, maxLength: 100, decoration: InputDecoration(labelText: 'Judul', errorText: _galat['judul']), validator: wajib),
          TextFormField(
            controller: _deskripsi,
            maxLines: 4,
            maxLength: 2000,
            decoration: InputDecoration(labelText: 'Deskripsi', errorText: _galat['deskripsi']),
            validator: wajib,
          ),
          DropdownButtonFormField<String>(
            initialValue: kategoriPreloved.contains(_kategori) ? _kategori : null,
            decoration: InputDecoration(labelText: 'Kategori', errorText: _galat['kategori']),
            items: [for (final k in kategoriPreloved) DropdownMenuItem(value: k, child: Text(k))],
            onChanged: (v) => _kategori = v,
            validator: wajib,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _kondisi,
            decoration: InputDecoration(labelText: 'Kondisi', errorText: _galat['kondisi']),
            items: [for (final e in kondisiBarang.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) => _kondisi = v,
            validator: wajib,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _harga,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: 'Harga', prefixText: 'Rp ', errorText: _galat['harga']),
            validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Harga harus lebih dari 0.' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: kecamatanTubaba.contains(_kecamatan) ? _kecamatan : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: 'Kecamatan', errorText: _galat['kecamatan']),
            items: [for (final k in kecamatanTubaba) DropdownMenuItem(value: k, child: Text(k))],
            onChanged: (v) => _kecamatan = v,
            validator: wajib,
          ),
          const SizedBox(height: 12),
          const Text(infoCod, style: TextStyle(fontSize: 12)),
          const SizedBox(height: 16),
          FilledButton(onPressed: _menyimpan ? null : _simpan, child: Text(_menyimpan ? 'Mengunggah...' : (_ubah ? 'Simpan perubahan' : 'Pasang barang'))),
        ]),
      ),
    );
  }

  Widget _tombolFoto(IconData ikon, String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 96,
            decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outline), borderRadius: BorderRadius.circular(8)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(ikon), Text(label, style: const TextStyle(fontSize: 12))]),
          ),
        ),
      );
}

