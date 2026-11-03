import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_exception.dart';
import '../../core/daftar_berhalaman.dart';
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

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(detailBarangProvider(widget.id));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.pop(_berubah);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Detail barang')),
        body: TampilanAsync(
          nilai: detail,
          onUlang: () => ref.invalidate(detailBarangProvider(widget.id)),
          data: (b) => ListView(children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(children: [
                PageView(
                  onPageChanged: (i) => setState(() => _foto = i),
                  children: [for (final f in b.foto.isEmpty ? <String?>[null] : b.foto) FotoJaringan(url: f, fit: BoxFit.contain)],
                ),
                if (b.foto.length > 1)
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      for (var i = 0; i < b.foto.length; i++)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.all(3),
                          decoration: BoxDecoration(shape: BoxShape.circle, color: i == _foto ? Colors.white : Colors.white54),
                        ),
                    ]),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(b.judul, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(rupiah(b.harga), style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  Chip(label: Text(kondisiBarang[b.kondisi] ?? b.kondisi)),
                  Chip(label: Text(b.kategori)),
                  Chip(label: Text(b.kecamatan)),
                  if (!b.tersedia) Chip(label: Text(b.status.toUpperCase())),
                ]),
                const SizedBox(height: 8),
                Text(b.deskripsi),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(b.milikSaya ? 'Barang Anda' : (b.penjual?.name ?? '-')),
                  subtitle: Text('Dipasang ${tanggal(b.createdAt)}'),
                ),
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
                ] else ...[
                  if (b.tersedia)
                    FilledButton.icon(onPressed: _sibuk ? null : () => _chat(b), icon: const Icon(Icons.chat), label: const Text('Chat Penjual')),
                  const SizedBox(height: 8),
                  TextButton.icon(onPressed: () => _lapor(b), icon: const Icon(Icons.flag_outlined), label: const Text('Laporkan')),
                ],
              ]),
            ),
          ]),
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
  final _foto = <XFile>[];
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
      if (await File(f.path).length() > _maksByte) {
        terlaluBesar++;
      } else {
        _foto.add(f);
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
        await repo.ubah(widget.barang!.id, data, [for (final f in _foto) f.path]);
      } else {
        await repo.pasang(data, [for (final f in _foto) f.path]);
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
                    ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(_foto[i].path), width: 96, height: 96, fit: BoxFit.cover)),
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

class BarangSayaPage extends ConsumerStatefulWidget {
  const BarangSayaPage({super.key});

  @override
  ConsumerState<BarangSayaPage> createState() => _BarangSayaPageState();
}

class _BarangSayaPageState extends ConsumerState<BarangSayaPage> {
  final _daftar = GlobalKey<DaftarBerhalamanState<BarangPreloved>>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Barang saya')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (await context.push<bool>('/warga/preloved/jual') == true) _daftar.currentState?.segarkan();
        },
        icon: const Icon(Icons.add),
        label: const Text('Jual barang'),
      ),
      body: DaftarBerhalaman<BarangPreloved>(
        key: _daftar,
        muat: (hal) => ref.read(prelovedRepositoryProvider).milikSaya(halaman: hal),
        kosong: 'Anda belum menjual barang.',
        adaFab: true,
        itemBuilder: (context, b, segarkan) => Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: SizedBox(width: 56, height: 56, child: FotoJaringan(url: b.foto.firstOrNull)),
            title: Text(b.judul, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(rupiah(b.harga)),
            trailing: LabelStatus(b.status, warna: b.tersedia ? TemaAplikasi.hijau : (b.status == 'terjual' ? Colors.grey.shade700 : Colors.red.shade700)),
            onTap: () async {
              if (await context.push<bool>('/warga/preloved/${b.id}') == true) segarkan();
            },
          ),
        ),
      ),
    );
  }
}
