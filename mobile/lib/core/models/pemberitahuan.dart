/// Pemberitahuan di dalam aplikasi. [tujuan] menunjuk halaman terkait,
/// mis. {'penjemputan': 12}, {'setoran': 5}, {'penarikan': 3}, {'tugas': 12}.
class Pemberitahuan {
  const Pemberitahuan({
    required this.id,
    required this.jenis,
    required this.judul,
    required this.isi,
    required this.tujuan,
    required this.dibaca,
    this.dibuat,
  });

  final int id;
  final String jenis;
  final String judul;
  final String isi;
  final Map<String, int> tujuan;
  final bool dibaca;
  final DateTime? dibuat;

  factory Pemberitahuan.dariJson(Map<String, dynamic> json) => Pemberitahuan(
        id: json['id'] as int,
        jenis: '${json['jenis']}',
        judul: '${json['judul']}',
        isi: '${json['isi']}',
        tujuan: {
          for (final e in ((json['tujuan'] as Map?) ?? const {}).entries)
            '${e.key}': (e.value as num).toInt(),
        },
        dibaca: json['dibaca'] == true,
        dibuat: DateTime.tryParse('${json['dibuat_at']}')?.toLocal(),
      );

  Pemberitahuan sudahDibaca() => Pemberitahuan(
        id: id,
        jenis: jenis,
        judul: judul,
        isi: isi,
        tujuan: tujuan,
        dibaca: true,
        dibuat: dibuat,
      );
}
