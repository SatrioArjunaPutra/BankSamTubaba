enum Role {
  dlh,
  bankSampah,
  bentor,
  warga;

  static Role dari(String? nilai) => switch (nilai) {
        'dlh' => Role.dlh,
        'bank_sampah' => Role.bankSampah,
        'bentor' => Role.bentor,
        _ => Role.warga,
      };
}

class RingkasBank {
  const RingkasBank({required this.id, required this.kode, required this.nama});

  final int id;
  final String kode;
  final String nama;

  static RingkasBank? dariJson(Object? json) {
    if (json is! Map) return null;
    return RingkasBank(id: json['id'] as int, kode: '${json['kode']}', nama: '${json['nama']}');
  }
}

class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.bankSampah,
    this.alamat,
    this.lat,
    this.lng,
    this.harusGantiPassword = false,
  });

  final int id;
  final String name;
  final String email;
  final String? phone;
  final Role role;
  final RingkasBank? bankSampah;
  final String? alamat;
  final double? lat;
  final double? lng;

  /// Akun memakai password sementara dari petugas dan wajib menggantinya dulu.
  final bool harusGantiPassword;

  User salin({bool? harusGantiPassword}) => User(
        id: id,
        name: name,
        email: email,
        role: role,
        phone: phone,
        bankSampah: bankSampah,
        alamat: alamat,
        lat: lat,
        lng: lng,
        harusGantiPassword: harusGantiPassword ?? this.harusGantiPassword,
      );

  factory User.dariJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        name: '${json['name']}',
        email: '${json['email']}',
        phone: json['phone'] as String?,
        role: Role.dari(json['role'] as String?),
        bankSampah: RingkasBank.dariJson(json['bank_sampah']),
        alamat: json['alamat'] as String?,
        lat: double.tryParse('${json['lat']}'),
        lng: double.tryParse('${json['lng']}'),
        harusGantiPassword: json['harus_ganti_password'] == true,
      );
}

/// Satu sesi login di sebuah perangkat.
class Perangkat {
  const Perangkat({required this.id, required this.nama, required this.saatIni, this.terakhirDipakai, this.dibuat});

  final int id;
  final String nama;
  final bool saatIni;
  final DateTime? terakhirDipakai;
  final DateTime? dibuat;

  factory Perangkat.dariJson(Map<String, dynamic> json) => Perangkat(
        id: json['id'] as int,
        nama: '${json['nama'] ?? 'Perangkat'}',
        saatIni: json['saat_ini'] == true,
        terakhirDipakai: DateTime.tryParse('${json['terakhir_dipakai_at']}')?.toLocal(),
        dibuat: DateTime.tryParse('${json['dibuat_at']}')?.toLocal(),
      );
}
