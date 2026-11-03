/// Satu baris di form catat setoran.
class BarisSetoran {
  BarisSetoran({this.jenisSampahId, this.berat = ''}) : kunci = _berikut++;

  static int _berikut = 0;

  /// Identitas tetap untuk Key widget (indeks berubah saat baris dihapus).
  final int kunci;

  int? jenisSampahId;

  /// Teks input berat, boleh pakai koma desimal ("2,5").
  String berat;

  double? get beratKg {
    final v = double.tryParse(berat.trim().replaceAll(',', '.'));
    return v == null || v <= 0 ? null : v;
  }
}

/// Total realtime form setoran, dihitung dalam sen seperti backend
/// (berat 2 desimal × harga 2 desimal, dibulatkan per item) agar angka di
/// layar sama dengan yang tersimpan.
class TotalSetoran {
  const TotalSetoran({required this.totalKg, required this.totalNilai, required this.tanpaHarga});

  final double totalKg;
  final double totalNilai;

  /// Jenis yang dipilih tapi belum ada harganya di bank ini (tidak bisa dijual).
  final List<int> tanpaHarga;

  static TotalSetoran hitung(List<BarisSetoran> baris, Map<int, double?> harga, {required bool donasi}) {
    var kgSen = 0;
    var nilaiSen = 0;
    final tanpaHarga = <int>[];

    for (final b in baris) {
      final berat = b.beratKg;
      final jenis = b.jenisSampahId;
      if (berat == null || jenis == null) continue;

      final beratSen = (berat * 100).round();
      kgSen += beratSen;

      final h = harga[jenis];
      if (h == null) {
        if (!donasi) tanpaHarga.add(jenis);
        continue;
      }
      if (!donasi) nilaiSen += (beratSen * (h * 100).round() / 100).round();
    }

    return TotalSetoran(totalKg: kgSen / 100, totalNilai: nilaiSen / 100, tanpaHarga: tanpaHarga);
  }
}
