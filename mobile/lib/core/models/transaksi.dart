import '../format.dart';
import 'user.dart';

class Saldo {
  const Saldo({required this.bankSampahId, required this.bankSampah, required this.saldo});

  final int bankSampahId;
  final RingkasBank? bankSampah;
  final double saldo;

  factory Saldo.dariJson(Map<String, dynamic> json) => Saldo(
        bankSampahId: json['bank_sampah_id'] as int,
        bankSampah: RingkasBank.dariJson(json['bank_sampah']),
        saldo: keDouble(json['saldo']),
      );
}

class RingkasanSaldo {
  const RingkasanSaldo({required this.total, required this.daftar});

  final double total;
  final List<Saldo> daftar;

  factory RingkasanSaldo.dariJson(Map<String, dynamic> json) => RingkasanSaldo(
        total: keDouble(json['total_saldo']),
        daftar: (json['daftar'] as List).map((e) => Saldo.dariJson((e as Map).cast())).toList(),
      );
}

class ItemSetoran {
  const ItemSetoran({required this.jenisSampahId, required this.nama, required this.beratKg, required this.hargaPerKg, required this.subtotal});

  final int jenisSampahId;
  final String nama;
  final double beratKg;
  final double hargaPerKg;
  final double subtotal;

  factory ItemSetoran.dariJson(Map<String, dynamic> json) => ItemSetoran(
        jenisSampahId: json['jenis_sampah_id'] as int,
        nama: '${json['nama'] ?? ''}',
        beratKg: keDouble(json['berat_kg']),
        hargaPerKg: keDouble(json['harga_per_kg']),
        subtotal: keDouble(json['subtotal']),
      );
}

class Setoran {
  const Setoran({
    required this.id,
    required this.tipe,
    required this.totalKg,
    required this.totalNilai,
    required this.createdAt,
    this.bankSampah,
    this.namaWarga,
    this.penjemputanId,
    this.items = const [],
    this.dibatalkanAt,
    this.alasanBatal,
  });

  final int id;

  /// 'jual' | 'donasi'
  final String tipe;
  final double totalKg;
  final double totalNilai;
  final DateTime? createdAt;
  final RingkasBank? bankSampah;
  final String? namaWarga;
  final int? penjemputanId;
  final List<ItemSetoran> items;
  final DateTime? dibatalkanAt;
  final String? alasanBatal;

  bool get donasi => tipe == 'donasi';
  bool get dibatalkan => dibatalkanAt != null;

  factory Setoran.dariJson(Map<String, dynamic> json) => Setoran(
        id: json['id'] as int,
        tipe: '${json['tipe']}',
        totalKg: keDouble(json['total_kg']),
        totalNilai: keDouble(json['total_nilai']),
        createdAt: keTanggal(json['created_at']),
        bankSampah: RingkasBank.dariJson(json['bank_sampah']),
        namaWarga: (json['warga'] as Map?)?['name'] as String?,
        penjemputanId: json['penjemputan_id'] as int?,
        dibatalkanAt: keTanggal(json['dibatalkan_at']),
        alasanBatal: json['alasan_batal'] as String?,
        items: (json['items'] as List? ?? const []).map((e) => ItemSetoran.dariJson((e as Map).cast())).toList(),
      );
}

class Kontak {
  const Kontak({required this.id, required this.name, this.phone});

  final int id;
  final String name;
  final String? phone;

  static Kontak? dariJson(Object? json) =>
      json is Map ? Kontak(id: json['id'] as int, name: '${json['name']}', phone: json['phone'] as String?) : null;
}

class Penjemputan {
  const Penjemputan({
    required this.id,
    required this.status,
    required this.alamat,
    required this.lat,
    required this.lng,
    this.bankSampahId,
    this.bankSampah,
    this.warga,
    this.armadaId,
    this.platNomor,
    this.driver,
    this.perkiraanKg,
    this.catatan,
    this.fotoUrl,
    this.alasanTolak,
    this.jadwalAt,
    this.createdAt,
  });

  final int id;
  final String status;
  final String alamat;
  final double lat;
  final double lng;
  final int? bankSampahId;
  final RingkasBank? bankSampah;
  final Kontak? warga;
  final int? armadaId;
  final String? platNomor;
  final Kontak? driver;
  final double? perkiraanKg;
  final String? catatan;
  final String? fotoUrl;
  final String? alasanTolak;
  final DateTime? jadwalAt;
  final DateTime? createdAt;

  factory Penjemputan.dariJson(Map<String, dynamic> json) {
    final armada = json['armada'] as Map?;
    return Penjemputan(
      id: json['id'] as int,
      status: '${json['status']}',
      alamat: '${json['alamat'] ?? ''}',
      lat: keDouble(json['lat']),
      lng: keDouble(json['lng']),
      bankSampahId: json['bank_sampah_id'] as int?,
      bankSampah: RingkasBank.dariJson(json['bank_sampah']),
      warga: Kontak.dariJson(json['warga']),
      armadaId: json['armada_id'] as int?,
      platNomor: armada?['plat_nomor'] as String?,
      driver: Kontak.dariJson(armada?['driver']),
      perkiraanKg: keDoubleAtauNull(json['perkiraan_kg']),
      catatan: json['catatan'] as String?,
      fotoUrl: json['foto_url'] as String?,
      alasanTolak: json['alasan_tolak'] as String?,
      jadwalAt: keTanggal(json['jadwal_at']),
      createdAt: keTanggal(json['created_at']),
    );
  }
}

class Penarikan {
  const Penarikan({required this.id, required this.jumlah, required this.status, this.bankSampah, this.warga, this.catatan, this.createdAt});

  final int id;
  final double jumlah;
  final String status;
  final RingkasBank? bankSampah;
  final Kontak? warga;
  final String? catatan;
  final DateTime? createdAt;

  factory Penarikan.dariJson(Map<String, dynamic> json) => Penarikan(
        id: json['id'] as int,
        jumlah: keDouble(json['jumlah']),
        status: '${json['status']}',
        bankSampah: RingkasBank.dariJson(json['bank_sampah']),
        warga: Kontak.dariJson(json['warga']),
        catatan: json['catatan'] as String?,
        createdAt: keTanggal(json['created_at']),
      );
}

/// Label status penjemputan untuk ditampilkan.
const labelStatusJemput = {
  'diajukan': 'Diajukan',
  'dijadwalkan': 'Dijadwalkan',
  'menuju': 'Bentor menuju',
  'diambil': 'Sudah diambil',
  'selesai': 'Selesai',
  'ditolak': 'Ditolak',
  'dibatalkan': 'Dibatalkan',
};

/// Label status penarikan; "diajukan" ditampilkan "Menunggu" seperti tab operator.
const labelStatusPenarikan = {'diajukan': 'Menunggu', 'disetujui': 'Disetujui', 'ditolak': 'Ditolak'};
