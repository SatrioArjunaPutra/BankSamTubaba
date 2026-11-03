import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/daftar_berhalaman.dart';
import '../../core/format.dart';
import '../../core/komponen_ui.dart';
import '../../core/models/berita.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../preloved/preloved_tab.dart';
import 'berita_repository.dart';

/// Bagian paling bawah beranda warga. Tidak tampil bila belum ada artikel terbit.
class BeritaBeranda extends ConsumerWidget {
  const BeritaBeranda({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final berita = ref.watch(beritaTerbaruProvider);
    if (berita.asData?.value.isEmpty ?? false) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        JudulBagian(
          'Berita terbaru',
          aksi: 'Lihat semua',
          onTap: () => context.push('/warga/berita'),
        ),
        const SizedBox(height: 8),
        TampilanAsync(
          nilai: berita,
          onUlang: () => ref.invalidate(beritaTerbaruProvider),
          data: (daftar) => _DeretBerita(daftar: daftar),
        ),
      ],
    );
  }
}

class _FotoBerita extends StatelessWidget {
  const _FotoBerita({required this.url, this.ukuranIkon = 28});

  final String? url;
  final double ukuranIkon;

  @override
  Widget build(BuildContext context) => url != null
      ? FotoJaringan(url: url)
      : Container(
          color: TemaAplikasi.hijauLembut,
          alignment: Alignment.center,
          child: Icon(
            Icons.newspaper_outlined,
            size: ukuranIkon,
            color: TemaAplikasi.hijau,
          ),
        );
}

class _LabelKategori extends StatelessWidget {
  const _LabelKategori(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: TemaAplikasi.hijauLembut,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      teks,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: TemaAplikasi.hijauPekat,
      ),
    ),
  );
}

/// Deret artikel yang digeser ke samping, sampai ke tepi layar beranda.
class _DeretBerita extends StatelessWidget {
  const _DeretBerita({required this.daftar});

  static const _jarakTepi = 20.0;
  static const _jarakKartu = 14.0;

  final List<Berita> daftar;

  @override
  Widget build(BuildContext context) {
    final lebar = (MediaQuery.sizeOf(context).width * .42).clamp(150.0, 200.0);
    // Tinggi mengikuti ukuran huruf HP, agar judul 3 baris tidak terpotong
    final skala = MediaQuery.textScalerOf(context);
    final tinggi = lebar + 12 + skala.scale(KartuBeritaRingkas.tinggiJudul) + 6 + skala.scale(KartuBeritaRingkas.tinggiKeterangan) + 4;
    return LayoutBuilder(
      builder: (context, ukuran) => SizedBox(
        height: tinggi,
        child: OverflowBox(
          maxWidth: ukuran.maxWidth + _jarakTepi * 2,
          minWidth: ukuran.maxWidth + _jarakTepi * 2,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: _jarakTepi),
            itemCount: daftar.length,
            separatorBuilder: (_, _) => const SizedBox(width: _jarakKartu),
            itemBuilder: (_, i) => SizedBox(
              width: lebar,
              child: MunculBertahap(
                urutan: 4 + i,
                child: KartuBeritaRingkas(berita: daftar[i], lebar: lebar),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Foto persegi, judul maksimal 3 baris, lalu sumber dan waktu terbitnya.
class KartuBeritaRingkas extends StatelessWidget {
  const KartuBeritaRingkas({super.key, required this.berita, required this.lebar});

  static const _ukuranJudul = 14.5;
  static const _ukuranKeterangan = 12.0;
  static const tinggiJudul = _ukuranJudul * 1.3 * 3;
  static const tinggiKeterangan = _ukuranKeterangan * 1.35;

  final Berita berita;
  final double lebar;

  @override
  Widget build(BuildContext context) => TekanSkala(
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/warga/berita/${berita.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: SizedBox.square(
              dimension: lebar,
              child: _FotoBerita(url: berita.foto, ukuranIkon: 40),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            berita.judul,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: _ukuranJudul, fontWeight: FontWeight.w600, height: 1.3),
          ),
          const SizedBox(height: 6),
          Text(
            'DLH Tubaba · ${waktuLalu(berita.diterbitkanAt)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: _ukuranKeterangan, height: 1.35, color: TemaAplikasi.redup),
          ),
        ],
      ),
    ),
  );
}

class KartuBerita extends StatelessWidget {
  const KartuBerita({super.key, required this.berita});

  final Berita berita;

  @override
  Widget build(BuildContext context) => TekanSkala(
    child: Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/warga/berita/${berita.id}'),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox.square(
                  dimension: 80,
                  child: _FotoBerita(url: berita.foto),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      berita.labelKategori,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: TemaAplikasi.hijau,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      berita.judul,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tanggal(berita.diterbitkanAt),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: TemaAplikasi.redup,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class DaftarBeritaPage extends ConsumerStatefulWidget {
  const DaftarBeritaPage({super.key});

  @override
  ConsumerState<DaftarBeritaPage> createState() => _DaftarBeritaPageState();
}

class _DaftarBeritaPageState extends ConsumerState<DaftarBeritaPage> {
  String _q = '';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Berita')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Cari judul berita…',
              prefixIcon: Icon(Icons.search),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (v) => setState(() => _q = v.trim()),
          ),
        ),
        Expanded(
          child: DaftarBerhalaman<Berita>(
            key: ValueKey(_q),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            pemisah: 0,
            kosong: _q.isEmpty
                ? 'Belum ada berita.'
                : 'Tidak ada berita yang cocok.',
            muat: (hal) => ref
                .read(beritaRepositoryProvider)
                .daftar(q: _q.isEmpty ? null : _q, halaman: hal),
            itemBuilder: (_, b, _) => KartuBerita(berita: b),
          ),
        ),
      ],
    ),
  );
}

class DetailBeritaPage extends ConsumerWidget {
  const DetailBeritaPage({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Berita')),
    body: TampilanAsync(
      nilai: ref.watch(detailBeritaProvider(id)),
      onUlang: () => ref.invalidate(detailBeritaProvider(id)),
      data: (b) => ListView(
        padding: paddingAman(
          context,
          dasar: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        ),
        children: [
          if (b.foto != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: FotoJaringan(url: b.foto),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: _LabelKategori(b.labelKategori),
          ),
          const SizedBox(height: 10),
          Text(
            b.judul,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'DLH Tubaba · ${tanggal(b.diterbitkanAt)} · ${angka(b.dibaca)} dibaca',
            style: const TextStyle(fontSize: 12, color: TemaAplikasi.redup),
          ),
          const Divider(height: 28),
          for (final blok in uraiIsiBerita(b.isi)) _BlokIsi(blok),
        ],
      ),
    ),
  );
}

class _BlokIsi extends StatelessWidget {
  const _BlokIsi(this.blok);

  final BlokBerita blok;

  @override
  Widget build(BuildContext context) => switch (blok.jenis) {
    JenisBlokBerita.subjudul => Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Text(
        blok.teks,
        style: const TextStyle(
          fontSize: 16.5,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      ),
    ),
    JenisBlokBerita.kutipan => Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: const BoxDecoration(
        color: TemaAplikasi.hijauLembut,
        border: Border(left: BorderSide(color: TemaAplikasi.hijau, width: 3)),
      ),
      child: Text(
        blok.teks,
        style: const TextStyle(
          fontSize: 15,
          fontStyle: FontStyle.italic,
          height: 1.6,
        ),
      ),
    ),
    JenisBlokBerita.paragraf => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(blok.teks, style: const TextStyle(fontSize: 15, height: 1.65)),
    ),
  };
}
