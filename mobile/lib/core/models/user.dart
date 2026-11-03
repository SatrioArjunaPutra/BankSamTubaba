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
      );
}
