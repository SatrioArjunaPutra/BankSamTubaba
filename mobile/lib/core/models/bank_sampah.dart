import '../format.dart';

class Harga {
  const Harga({required this.jenisSampahId, required this.nama, this.satuan = 'kg', this.hargaPerKg});

  final int jenisSampahId;
  final String nama;
  final String satuan;

  /// null = belum diatur oleh bank sampah ini
  final double? hargaPerKg;

  factory Harga.dariJson(Map<String, dynamic> json) => Harga(
        jenisSampahId: json['jenis_sampah_id'] as int,
        nama: '${json['nama'] ?? ''}',
        satuan: '${json['satuan'] ?? 'kg'}',
        hargaPerKg: keDoubleAtauNull(json['harga_per_kg']),
      );
}

class JenisSampah {
  const JenisSampah({required this.id, required this.nama, this.satuan = 'kg'});

  final int id;
  final String nama;
  final String satuan;

  factory JenisSampah.dariJson(Map<String, dynamic> json) =>
      JenisSampah(id: json['id'] as int, nama: '${json['nama']}', satuan: '${json['satuan'] ?? 'kg'}');
}

class BankSampah {
  const BankSampah({
    required this.id,
    required this.kode,
    required this.nama,
    required this.tiyuh,
    required this.kecamatan,
    this.alamat,
    this.lat,
    this.lng,
    this.koordinatEstimasi = false,
    this.noHpPublik,
    this.jarakKm,
    this.harga = const [],
  });

  final int id;
  final String kode;
  final String nama;
  final String tiyuh;
  final String kecamatan;
  final String? alamat;
  final double? lat;
  final double? lng;
  final bool koordinatEstimasi;
  final String? noHpPublik;
  final double? jarakKm;
  final List<Harga> harga;

  factory BankSampah.dariJson(Map<String, dynamic> json) => BankSampah(
        id: json['id'] as int,
        kode: '${json['kode']}',
        nama: '${json['nama']}',
        tiyuh: '${json['tiyuh'] ?? ''}',
        kecamatan: '${json['kecamatan'] ?? ''}',
        alamat: json['alamat'] as String?,
        lat: keDoubleAtauNull(json['lat']),
        lng: keDoubleAtauNull(json['lng']),
        koordinatEstimasi: json['koordinat_estimasi'] == true,
        noHpPublik: json['no_hp_publik'] as String?,
        jarakKm: keDoubleAtauNull(json['jarak_km']),
        harga: (json['harga'] as List? ?? const []).map((e) => Harga.dariJson((e as Map).cast())).toList(),
      );
}
