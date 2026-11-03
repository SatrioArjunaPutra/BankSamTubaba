import '../format.dart';
import 'transaksi.dart';

class Armada {
  const Armada({
    required this.id,
    required this.platNomor,
    required this.status,
    this.kapasitasKg,
    this.driver,
    this.driverAktif = true,
    this.tugasAktif = 0,
  });

  final int id;
  final String platNomor;

  /// siaga | bertugas | nonaktif
  final String status;
  final double? kapasitasKg;
  final Kontak? driver;

  /// Akun login driver aktif (false = sudah dinonaktifkan operator/DLH).
  final bool driverAktif;
  final int tugasAktif;

  factory Armada.dariJson(Map<String, dynamic> json) => Armada(
        id: json['id'] as int,
        platNomor: '${json['plat_nomor']}',
        status: '${json['status']}',
        kapasitasKg: keDoubleAtauNull(json['kapasitas_kg']),
        driver: Kontak.dariJson(json['driver']),
        driverAktif: (json['driver'] as Map?)?['is_aktif'] != false,
        tugasAktif: (json['tugas_aktif'] as num?)?.toInt() ?? 0,
      );
}

class WargaNasabah {
  const WargaNasabah({required this.id, required this.name, required this.saldo, this.phone, this.email, this.sudahNasabah = false});

  final int id;
  final String name;
  final String? phone;
  final String? email;
  final double saldo;
  final bool sudahNasabah;

  factory WargaNasabah.dariJson(Map<String, dynamic> json) => WargaNasabah(
        id: json['id'] as int,
        name: '${json['name']}',
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        saldo: keDouble(json['saldo']),
        sudahNasabah: json['sudah_nasabah'] == true,
      );
}

class RingkasSetoran {
  const RingkasSetoran({required this.jumlah, required this.totalKg, required this.kgDonasi, required this.totalNilai});

  final int jumlah;
  final double totalKg;
  final double kgDonasi;
  final double totalNilai;

  factory RingkasSetoran.dariJson(Map<String, dynamic> json) => RingkasSetoran(
        jumlah: (json['jumlah_setoran'] as num).toInt(),
        totalKg: keDouble(json['total_kg']),
        kgDonasi: keDouble(json['kg_donasi']),
        totalNilai: keDouble(json['total_nilai']),
      );
}

class DashboardBank {
  const DashboardBank({
    required this.hariIni,
    required this.bulanIni,
    required this.jemputDiajukan,
    required this.jemputBerjalan,
    required this.penarikanDiajukan,
    required this.totalPenarikanDiajukan,
    required this.jumlahNasabah,
    required this.totalSaldoNasabah,
  });

  final RingkasSetoran hariIni;
  final RingkasSetoran bulanIni;
  final int jemputDiajukan;
  final int jemputBerjalan;
  final int penarikanDiajukan;
  final double totalPenarikanDiajukan;
  final int jumlahNasabah;
  final double totalSaldoNasabah;

  factory DashboardBank.dariJson(Map<String, dynamic> json) => DashboardBank(
        hariIni: RingkasSetoran.dariJson((json['hari_ini'] as Map).cast()),
        bulanIni: RingkasSetoran.dariJson((json['bulan_ini'] as Map).cast()),
        jemputDiajukan: (json['penjemputan']['diajukan'] as num).toInt(),
        jemputBerjalan: (json['penjemputan']['berjalan'] as num).toInt(),
        penarikanDiajukan: (json['penarikan_diajukan']['jumlah'] as num).toInt(),
        totalPenarikanDiajukan: keDouble(json['penarikan_diajukan']['total']),
        jumlahNasabah: (json['nasabah']['jumlah'] as num).toInt(),
        totalSaldoNasabah: keDouble(json['nasabah']['total_saldo']),
      );
}

class PenjualanPengepul {
  const PenjualanPengepul({
    required this.id,
    required this.namaPengepul,
    required this.jenisSampah,
    required this.beratKg,
    required this.hargaPerKg,
    required this.total,
    required this.tanggal,
  });

  final int id;
  final String namaPengepul;
  final String jenisSampah;
  final double beratKg;
  final double hargaPerKg;
  final double total;
  final DateTime? tanggal;

  factory PenjualanPengepul.dariJson(Map<String, dynamic> json) => PenjualanPengepul(
        id: json['id'] as int,
        namaPengepul: '${json['nama_pengepul']}',
        jenisSampah: '${json['jenis_sampah'] ?? ''}',
        beratKg: keDouble(json['berat_kg']),
        hargaPerKg: keDouble(json['harga_per_kg']),
        total: keDouble(json['total']),
        tanggal: keTanggal(json['tanggal']),
      );
}
