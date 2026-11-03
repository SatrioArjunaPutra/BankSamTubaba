import '../format.dart';

const kategoriBerita = {
  'berita': 'Berita',
  'pengumuman': 'Pengumuman',
  'kegiatan': 'Kegiatan',
};

class Berita {
  const Berita({
    required this.id,
    required this.judul,
    required this.ringkasan,
    required this.isi,
    required this.kategori,
    required this.foto,
    required this.diterbitkanAt,
    required this.dibaca,
  });

  final int id;
  final String judul;
  final String ringkasan;

  /// Hanya terisi pada detail artikel.
  final String? isi;
  final String kategori;
  final String? foto;
  final DateTime? diterbitkanAt;
  final int dibaca;

  String get labelKategori => kategoriBerita[kategori] ?? kategori;

  factory Berita.dariJson(Map<String, dynamic> json) => Berita(
    id: json['id'] as int,
    judul: '${json['judul']}',
    ringkasan: '${json['ringkasan'] ?? ''}',
    isi: json['isi'] as String?,
    kategori: '${json['kategori']}',
    foto: json['foto'] as String?,
    diterbitkanAt: keTanggal(json['diterbitkan_at']),
    dibaca: keDouble(json['dibaca']).toInt(),
  );
}

enum JenisBlokBerita { paragraf, subjudul, kutipan }

class BlokBerita {
  BlokBerita(this.jenis, this.teks);

  final JenisBlokBerita jenis;
  String teks;
}

/// Mengurai isi berita sama seperti web: "## judul" = subjudul, "> teks" =
/// kutipan, baris kosong = pemisah paragraf.
List<BlokBerita> uraiIsiBerita(String? teks) {
  final blok = <BlokBerita>[];
  var sela = true;

  for (final mentah in (teks ?? '').split(RegExp(r'\r?\n'))) {
    final baris = mentah.trim();
    if (baris.isEmpty) {
      sela = true;
      continue;
    }

    final terakhir = blok.isEmpty ? null : blok.last;
    if (baris.startsWith('## ')) {
      blok.add(BlokBerita(JenisBlokBerita.subjudul, baris.substring(3).trim()));
    } else if (baris.startsWith('>')) {
      final isi = baris.substring(1).trim();
      if (!sela && terakhir?.jenis == JenisBlokBerita.kutipan) {
        terakhir!.teks += '\n$isi';
      } else {
        blok.add(BlokBerita(JenisBlokBerita.kutipan, isi));
      }
    } else if (!sela && terakhir?.jenis == JenisBlokBerita.paragraf) {
      terakhir!.teks += '\n$baris';
    } else {
      blok.add(BlokBerita(JenisBlokBerita.paragraf, baris));
    }
    sela = false;
  }

  return blok;
}
