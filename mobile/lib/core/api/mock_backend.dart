import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Backend palsu di memori untuk mode USE_MOCK=true: menjawab request
/// dengan JSON berbentuk sama dengan kontrak API (Prompt 0), supaya UI bisa
/// dikerjakan dan didemokan tanpa server. Semua akun berpassword "password":
///   warga@demo.id, operator@demo.id, bentor@demo.id
/// Data hilang saat aplikasi ditutup.
class MockBackend implements HttpClientAdapter {
  MockBackend() {
    _isiData();
  }

  final _users = <int, Map<String, dynamic>>{};
  final _password = <int, String>{};
  final _token = <String, int>{};
  final _bank = <int, Map<String, dynamic>>{};
  final _jenis = <int, Map<String, dynamic>>{};
  final _harga = <String, double>{}; // "bankId:jenisId"
  final _saldo = <String, double>{}; // "wargaId:bankId"
  final _setoran = <Map<String, dynamic>>[];
  final _permintaanSetoran = <String, (String, Map<String, dynamic>)>{};
  final _jemput = <Map<String, dynamic>>[];
  final _tarik = <Map<String, dynamic>>[];
  final _armada = <int, Map<String, dynamic>>{};
  final _pengepul = <Map<String, dynamic>>[];
  int _id = 1000;

  int get _idBaru => ++_id;
  String get _sekarang => DateTime.now().toUtc().toIso8601String();

  void _isiData() {
    final jenis = [
      'Botol Kaca',
      'Kardus',
      'Kertas',
      'Logam',
      'Minyak Jelantah',
      'Plastik',
    ];
    for (var i = 0; i < jenis.length; i++) {
      _jenis[i + 1] = {
        'id': i + 1,
        'nama': jenis[i],
        'satuan': 'kg',
        'is_aktif': true,
      };
    }

    _bank[1] = _bankBaru(
      1,
      'BS-DEMO-01',
      'Bank Sampah Demo Panaragan',
      'Panaragan',
      'Tulang Bawang Tengah',
      -4.495,
      105.075,
    );
    _bank[2] = _bankBaru(
      2,
      'BS-DEMO-02',
      'Bank Sampah Demo Daya Murni',
      'Daya Murni',
      'Tumijajar',
      -4.512,
      105.152,
    );
    _bank[3] = _bankBaru(
      3,
      'BS-DEMO-03',
      'Bank Sampah Demo Gunung Agung',
      'Mulya Jaya',
      'Gunung Agung',
      -4.265,
      105.065,
    );
    const dasar = [500, 2000, 1500, 6000, 5000, 3000];
    for (final b in _bank.keys) {
      for (var j = 1; j <= 6; j++) {
        _harga['$b:$j'] = (dasar[j - 1] + (b - 1) * 250).toDouble();
      }
    }

    _userBaru(
      1,
      'Siti Warga',
      'warga@demo.id',
      'warga',
      null,
      '081211110001',
      alamat: 'Jl. Melati 1, Panaragan',
      lat: -4.49,
      lng: 105.07,
    );
    _userBaru(2, 'Budi Warga', 'budi@demo.id', 'warga', null, '081211110002');
    _userBaru(
      3,
      'Operator Demo',
      'operator@demo.id',
      'bank_sampah',
      1,
      '081211110003',
    );
    _userBaru(4, 'Pak Bentor', 'bentor@demo.id', 'bentor', 1, '081211110004');
    _userBaru(5, 'Bentor Dua', 'bentor2@demo.id', 'bentor', 1, '081211110005');
    _armada[1] = {
      'id': 1,
      'bank_sampah_id': 1,
      'driver_id': 4,
      'plat_nomor': 'BE 4011 DM',
      'kapasitas_kg': 150,
      'status': 'siaga',
    };
    _armada[2] = {
      'id': 2,
      'bank_sampah_id': 1,
      'driver_id': 5,
      'plat_nomor': 'BE 4012 DM',
      'kapasitas_kg': 150,
      'status': 'siaga',
    };

    _saldo['1:1'] = 45000;
    _saldo['1:2'] = 12500;
    _saldo['2:1'] = 8000;
    _setoran.add(
      _setoranJson(
        _idBaru,
        1,
        1,
        'jual',
        [(6, 5.0, 3000.0), (2, 10.0, 2000.0)],
        3,
        null,
      ),
    );
    _setoran.add(
      _setoranJson(_idBaru, 1, 1, 'donasi', [(5, 2.0, 0.0)], 3, null),
    );
    _jemput.add(_jemputJson(_idBaru, 1, 1, 'diajukan'));
    _jemput.add(_jemputJson(_idBaru, 2, 1, 'dijadwalkan', armadaId: 1));
    _tarik.add({
      'id': _idBaru,
      'warga_id': 2,
      'bank_sampah_id': 1,
      'jumlah': 5000.0,
      'status': 'diajukan',
      'catatan': null,
      'created_at': _sekarang,
    });
  }

  Map<String, dynamic> _bankBaru(
    int id,
    String kode,
    String nama,
    String tiyuh,
    String kec,
    double lat,
    double lng,
  ) => {
    'id': id,
    'kode': kode,
    'nama': nama,
    'tiyuh': tiyuh,
    'kecamatan': kec,
    'alamat': 'Tiyuh $tiyuh, Kec. $kec',
    'lat': lat,
    'lng': lng,
    'koordinat_estimasi': false,
    'no_hp_publik': null,
    'is_aktif': true,
  };

  void _userBaru(
    int id,
    String name,
    String email,
    String role,
    int? bankId,
    String phone, {
    String? alamat,
    double? lat,
    double? lng,
  }) {
    _users[id] = {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'bank_sampah_id': bankId,
      'alamat': alamat,
      'lat': lat,
      'lng': lng,
      'is_aktif': true,
    };
    _password[id] = 'password';
  }

  Map<String, dynamic> _ringkasBank(int id) => {
    'id': id,
    'kode': _bank[id]!['kode'],
    'nama': _bank[id]!['nama'],
  };

  Map<String, dynamic> _userJson(int id) {
    final u = Map<String, dynamic>.of(_users[id]!);
    u['bank_sampah'] = u['bank_sampah_id'] == null
        ? null
        : _ringkasBank(u['bank_sampah_id'] as int);
    return u;
  }

  Map<String, dynamic> _setoranJson(
    int id,
    int wargaId,
    int bankId,
    String tipe,
    List<(int, double, double)> items,
    int olehId,
    int? jemputId,
  ) {
    final rincian = items
        .map(
          (i) => {
            'jenis_sampah_id': i.$1,
            'nama': _jenis[i.$1]!['nama'],
            'berat_kg': i.$2,
            'harga_per_kg': i.$3,
            'subtotal': i.$2 * i.$3,
          },
        )
        .toList();
    return {
      'id': id,
      'bank_sampah_id': bankId,
      'bank_sampah': _ringkasBank(bankId),
      'warga_id': wargaId,
      'warga': {'id': wargaId, 'name': _users[wargaId]!['name']},
      'tipe': tipe,
      'total_kg': rincian.fold<double>(
        0,
        (s, i) => s + (i['berat_kg'] as double),
      ),
      'total_nilai': rincian.fold<double>(
        0,
        (s, i) => s + (i['subtotal'] as double),
      ),
      'penjemputan_id': jemputId,
      'dicatat_oleh': olehId,
      'catatan': null,
      'items': rincian,
      'created_at': _sekarang,
    };
  }

  Map<String, dynamic> _jemputJson(
    int id,
    int wargaId,
    int bankId,
    String status, {
    int? armadaId,
  }) => {
    'id': id,
    'bank_sampah_id': bankId,
    'warga_id': wargaId,
    'armada_id': armadaId,
    'alamat': 'Jl. Melati $id, Panaragan',
    'lat': -4.49 - id % 10 / 1000,
    'lng': 105.07 + id % 10 / 1000,
    'perkiraan_kg': 5.0,
    'catatan': null,
    'foto_url': null,
    'status': status,
    'alasan_tolak': null,
    'jadwal_at': armadaId == null ? null : _sekarang,
    'created_at': _sekarang,
  };

  Map<String, dynamic> _jemputLengkap(Map<String, dynamic> j) {
    final armada = j['armada_id'] == null ? null : _armada[j['armada_id']];
    final driver = armada == null ? null : _users[armada['driver_id']];
    final warga = _users[j['warga_id']]!;
    return {
      ...j,
      'bank_sampah': _ringkasBank(j['bank_sampah_id'] as int),
      'warga': {
        'id': warga['id'],
        'name': warga['name'],
        'phone': warga['phone'],
      },
      'armada': armada == null
          ? null
          : {
              'id': armada['id'],
              'plat_nomor': armada['plat_nomor'],
              'driver': {
                'id': driver!['id'],
                'name': driver['name'],
                'phone': driver['phone'],
              },
            },
    };
  }

  Map<String, dynamic> _armadaJson(Map<String, dynamic> a) {
    final d = _users[a['driver_id']]!;
    return {
      ...a,
      'driver': {
        'id': d['id'],
        'name': d['name'],
        'phone': d['phone'],
        'email': d['email'],
        'is_aktif': d['is_aktif'],
      },
      'tugas_aktif': _jemput
          .where(
            (j) =>
                j['armada_id'] == a['id'] &&
                ['dijadwalkan', 'menuju', 'diambil'].contains(j['status']),
          )
          .length,
    };
  }

  // ---------------------------------------------------------------------------

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final (status, body) = _jawab(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  Map<String, dynamic> _data(RequestOptions o) {
    final d = o.data;
    if (d is Map) return d.cast<String, dynamic>();
    if (d is FormData) return {for (final f in d.fields) f.key: f.value};
    return {};
  }

  (int, Map<String, dynamic>) _sukses(
    String pesan, [
    Object? data,
    int status = 200,
  ]) => (status, {'status': 'sukses', 'pesan': pesan, 'data': ?data});

  (int, Map<String, dynamic>) _gagal(
    int status,
    String pesan, [
    Map<String, List<String>>? errors,
  ]) => (status, {'status': 'gagal', 'pesan': pesan, 'errors': ?errors});

  (int, Map<String, dynamic>) _halaman(
    String pesan,
    List<Map<String, dynamic>> items,
    RequestOptions o,
  ) {
    final hal = int.tryParse('${o.queryParameters['page'] ?? 1}') ?? 1;
    final terakhir = items.isEmpty ? 1 : (items.length / 20).ceil();
    final potong = items.skip((hal - 1) * 20).take(20).toList();
    return (
      200,
      {
        'status': 'sukses',
        'pesan': pesan,
        'data': potong,
        'meta': {
          'current_page': hal,
          'last_page': terakhir,
          'total': items.length,
          'per_page': 20,
        },
      },
    );
  }

  (int, Map<String, dynamic>) _jawab(RequestOptions o) {
    final m = o.method.toUpperCase();
    final p = o.path
        .replaceFirst(RegExp(r'^https?://[^/]+'), '')
        .replaceFirst(RegExp(r'^/api/v1'), '');
    final d = _data(o);
    final q = o.queryParameters;
    int? idDari(String pola) =>
        int.tryParse(RegExp(pola).firstMatch(p)?.group(1) ?? '');

    // --- publik ---
    if (m == 'GET' && p == '/berita') {
      final kata = '${q['q'] ?? ''}'.toLowerCase();
      return _halaman(
        'Daftar berita berhasil dimuat.',
        [
          for (final b in _berita)
            if ('${b['judul']}'.toLowerCase().contains(kata))
              {...b}..remove('isi'),
        ],
        o,
      );
    }
    final idBerita = idDari(r'^/berita/(\d+)$');
    if (m == 'GET' && idBerita != null) {
      final b = _berita.where((b) => b['id'] == idBerita).firstOrNull;
      if (b == null) return _gagal(404, 'Data tidak ditemukan.');
      b['dibaca'] = (b['dibaca'] as int) + 1;
      return _sukses('Detail berita berhasil dimuat.', {...b});
    }
    if (m == 'POST' && p == '/auth/login') {
      final u = _users.values
          .where((u) => u['email'] == d['email'])
          .firstOrNull;
      if (u == null || _password[u['id']] != d['password']) {
        return _gagal(401, 'Email atau password salah.');
      }
      if (u['is_aktif'] != true) {
        return _gagal(403, 'Akun Anda dinonaktifkan. Hubungi pengelola.');
      }
      if (d['role'] != null && d['role'] != u['role']) {
        return _gagal(403, switch (u['role']) {
          'dlh' => 'Akun DLH hanya bisa masuk lewat web dashboard.',
          'bank_sampah' =>
            "Akun ini terdaftar sebagai Bank sampah. Pilih 'Bank sampah' lalu coba lagi.",
          'bentor' =>
            "Akun ini terdaftar sebagai Bentor. Pilih 'Bentor' lalu coba lagi.",
          _ => "Akun ini terdaftar sebagai Warga. Pilih 'Warga' lalu coba lagi.",
        });
      }
      return _sukses('Login berhasil.', _login(u['id'] as int));
    }
    if (m == 'GET' && p == '/statistik-publik') {
      final perKecamatan = <String, int>{};
      for (final b in _bank.values) {
        final nama = '${b['kecamatan']}';
        perKecamatan[nama] = (perKecamatan[nama] ?? 0) + 1;
      }
      return _sukses('Statistik berhasil dimuat.', {'bank_per_kecamatan': perKecamatan});
    }
    if (m == 'GET' && p == '/pendaftaran/bank-terdekat') {
      return _sukses('Bank sampah terdekat berhasil dimuat.', [
        for (final b in _bank.values.take(3))
          {...b, 'jarak_km': (b['id'] as int) * 1.7},
      ]);
    }
    if (m == 'POST' && p == '/auth/register') {
      if (_users.values.any((u) => u['email'] == d['email'])) {
        return _gagal(422, 'Data yang dikirim tidak valid.', {
          'email': ['Email sudah terdaftar.'],
        });
      }
      final id = _idBaru;
      _userBaru(
        id,
        '${d['name']}',
        '${d['email']}',
        'warga',
        null,
        '${d['phone']}',
        alamat: '${d['alamat']}',
        lat: (d['lat'] as num).toDouble(),
        lng: (d['lng'] as num).toDouble(),
      );
      _password[id] = '${d['password']}';
      return _sukses('Pendaftaran berhasil.', _login(id), 201);
    }

    final token = '${o.headers['Authorization'] ?? ''}'.replaceFirst(
      'Bearer ',
      '',
    );
    final saya = _token[token];
    if (saya == null) {
      return _gagal(
        401,
        'Sesi tidak valid atau sudah berakhir. Silakan login kembali.',
      );
    }
    final user = _users[saya]!;
    final bankSaya = user['bank_sampah_id'] as int?;

    // --- akun ---
    if (m == 'POST' && p == '/auth/logout') {
      _token.remove(token);
      return _sukses('Logout berhasil.');
    }
    if (m == 'GET' && p == '/me') {
      return _sukses('Data pengguna berhasil dimuat.', _userJson(saya));
    }
    if (m == 'PATCH' && p == '/me') {
      for (final k in ['name', 'phone', 'alamat', 'lat', 'lng']) {
        if (d.containsKey(k)) user[k] = d[k];
      }
      return _sukses('Profil berhasil diperbarui.', _userJson(saya));
    }
    if (m == 'PUT' && p == '/me/password') {
      if (d['password_lama'] != _password[saya]) {
        return _gagal(422, 'Data yang dikirim tidak valid.', {
          'password_lama': ['Password lama salah.'],
        });
      }
      _password[saya] = '${d['password']}';
      return _sukses(
        'Password berhasil diubah. Perangkat lain telah dikeluarkan.',
      );
    }

    // --- umum ---
    if (m == 'GET' && p == '/jenis-sampah') {
      return _sukses(
        'Daftar jenis sampah berhasil dimuat.',
        _jenis.values.toList(),
      );
    }
    if (m == 'GET' && (p == '/bank-sampah' || p == '/bank-sampah/nearby')) {
      final kata = '${q['q'] ?? ''}'.toLowerCase();
      final daftar = _bank.values
          .where((b) => '${b['nama']}'.toLowerCase().contains(kata))
          .map((b) {
            if (p.endsWith('nearby')) {
              return {...b, 'jarak_km': (b['id'] as int) * 1.7};
            }
            return b;
          })
          .toList();
      return p.endsWith('nearby')
          ? _sukses('Bank sampah terdekat berhasil dimuat.', daftar)
          : _halaman('Daftar bank sampah berhasil dimuat.', daftar, o);
    }
    if (m == 'GET' && idDari(r'^/bank-sampah/(\d+)$') != null) {
      final id = idDari(r'^/bank-sampah/(\d+)$')!;
      final b = _bank[id];
      if (b == null) return _gagal(404, 'Data tidak ditemukan.');
      return _sukses('Detail bank sampah berhasil dimuat.', {
        ...b,
        'harga': _jenis.values
            .where((j) => _harga.containsKey('$id:${j['id']}'))
            .map(
              (j) => {
                'jenis_sampah_id': j['id'],
                'nama': j['nama'],
                'satuan': 'kg',
                'harga_per_kg': _harga['$id:${j['id']}'],
              },
            )
            .toList(),
      });
    }

    // --- warga ---
    if (p.startsWith('/warga/')) {
      if (user['role'] != 'warga') {
        return _gagal(403, 'Anda tidak memiliki akses ke fitur ini.');
      }
      return _warga(m, p, d, q, o, saya);
    }
    // --- bank sampah ---
    if (p.startsWith('/bs/')) {
      if (user['role'] != 'bank_sampah') {
        return _gagal(403, 'Anda tidak memiliki akses ke fitur ini.');
      }
      return _bs(m, p, d, q, o, saya, bankSaya!);
    }
    // --- bentor ---
    if (p.startsWith('/bentor/')) {
      if (user['role'] != 'bentor') {
        return _gagal(403, 'Anda tidak memiliki akses ke fitur ini.');
      }
      return _bentor(m, p, d, q, o, saya);
    }
    // --- preloved & chat ---
    if (p.startsWith('/preloved') || p.startsWith('/chat')) {
      if (user['role'] != 'warga') {
        return _gagal(403, 'Anda tidak memiliki akses ke fitur ini.');
      }
      return _preloved(m, p, d, q, o, saya);
    }

    return _gagal(404, 'Data tidak ditemukan.');
  }

  // --- preloved & chat (dibuat saat pertama dipakai) ---
  final _barang = <int, Map<String, dynamic>>{};
  final _chat = <int, Map<String, dynamic>>{};
  final _sudahMelapor = <String>{};
  final _berita = <Map<String, dynamic>>[
    {
      'id': 1,
      'judul': 'Warga dapat meminta penjemputan sampah lewat aplikasi',
      'ringkasan': 'Bank sampah menjadwalkan bentor untuk datang ke alamat warga.',
      'isi':
          'Warga mengajukan penjemputan dari aplikasi.\n\n## Cara mengajukan\n\nPilih bank sampah tujuan, lalu isi alamat.\n\n> Sampah ditimbang langsung di lokasi.',
      'kategori': 'kegiatan',
      'foto': null,
      'diterbitkan_at': '2026-11-02T08:00:00+07:00',
      'dibaca': 12,
    },
    {
      'id': 2,
      'judul': 'Cara menabung sampah di bank sampah terdekat',
      'ringkasan': 'Sampah ditimbang dan nilainya masuk ke saldo warga.',
      'isi': 'Saldo dapat ditarik dengan mengajukan penarikan.',
      'kategori': 'berita',
      'foto': null,
      'diterbitkan_at': '2026-11-01T08:00:00+07:00',
      'dibaca': 7,
    },
    {
      'id': 3,
      'judul': 'Donasi sampah tetap tercatat dalam kinerja bank sampah',
      'ringkasan': 'Sampah dapat didonasikan tanpa menambah saldo.',
      'isi': 'Beratnya tetap dihitung dalam kinerja bank sampah.',
      'kategori': 'pengumuman',
      'foto': null,
      'diterbitkan_at': '2026-10-31T08:00:00+07:00',
      'dibaca': 3,
    },
    {
      'id': 4,
      'judul': 'Barang bekas layak pakai bisa dijual lewat aplikasi warga',
      'ringkasan': 'Warga dapat memasang barang dan berbincang lewat chat.',
      'isi': 'Pembayaran dilakukan secara COD.',
      'kategori': 'berita',
      'foto': null,
      'diterbitkan_at': '2026-10-30T08:00:00+07:00',
      'dibaca': 5,
    },
  ];
  final _pesan = <Map<String, dynamic>>[];
  bool _prelovedSiap = false;

  void _isiPreloved() {
    if (_prelovedSiap) return;
    _prelovedSiap = true;
    void barang(
      int penjual,
      String judul,
      String kategori,
      double harga,
      String kec,
    ) {
      final id = _idBaru;
      _barang[id] = {
        'id': id,
        'penjual_id': penjual,
        'judul': judul,
        'deskripsi': 'Masih layak pakai, silakan tanya-tanya dulu.',
        'kategori': kategori,
        'kondisi': 'bekas_baik',
        'harga': harga,
        'kecamatan': kec,
        'foto': ['https://picsum.photos/seed/bs$id/600/600'],
        'status': 'tersedia',
        'created_at': _sekarang,
      };
    }

    barang(2, 'Sepeda anak 16 inci', 'Mainan', 250000, 'Tumijajar');
    barang(2, 'Meja belajar kayu', 'Perabot', 150000, 'Tulang Bawang Tengah');
    barang(
      1,
      'Tas anyaman plastik daur ulang',
      'Kerajinan Daur Ulang',
      35000,
      'Tulang Bawang Tengah',
    );
  }

  Map<String, dynamic> _barangJson(Map<String, dynamic> b, int saya) {
    final penjual = _users[b['penjual_id']]!;
    return {
      ...b,
      'penjual': {'id': penjual['id'], 'name': penjual['name']},
      'milik_saya': b['penjual_id'] == saya,
    };
  }

  Map<String, dynamic> _pesanJson(Map<String, dynamic> p, int saya) => {
    ...p,
    'milik_saya': p['pengirim_id'] == saya,
  };

  Map<String, dynamic> _chatJson(Map<String, dynamic> c, int saya) {
    final b = _barang[c['preloved_item_id']]!;
    final penjual = c['penjual_id'] == saya;
    final lawan = _users[penjual ? c['pembeli_id'] : c['penjual_id']]!;
    final daftar = _pesan.where((p) => p['percakapan_id'] == c['id']).toList();
    return {
      'id': c['id'],
      'peran_saya': penjual ? 'penjual' : 'pembeli',
      'barang': {
        'id': b['id'],
        'judul': b['judul'],
        'harga': b['harga'],
        'status': b['status'],
        'foto': (b['foto'] as List).firstOrNull,
      },
      'lawan_bicara': {'id': lawan['id'], 'name': lawan['name']},
      'pesan_terakhir': daftar.isEmpty ? null : _pesanJson(daftar.last, saya),
      'unread_count': daftar
          .where((p) => p['pengirim_id'] != saya && p['dibaca_at'] == null)
          .length,
      'last_message_at': c['last_message_at'],
      'created_at': c['created_at'],
    };
  }

  (int, Map<String, dynamic>) _preloved(
    String m,
    String p,
    Map<String, dynamic> d,
    Map<String, dynamic> q,
    RequestOptions o,
    int saya,
  ) {
    _isiPreloved();
    final fotoBaru = o.data is FormData ? (o.data as FormData).files.length : 0;

    if (m == 'GET' && p == '/preloved') {
      final kata = '${q['q'] ?? ''}'.toLowerCase();
      final daftar = _barang.values.where(
        (b) =>
            b['status'] == 'tersedia' &&
            '${b['judul']}'.toLowerCase().contains(kata) &&
            (q['kategori'] == null || b['kategori'] == q['kategori']) &&
            (q['kecamatan'] == null || b['kecamatan'] == q['kecamatan']),
      );
      return _halaman(
        'Daftar barang berhasil dimuat.',
        daftar.toList().reversed.map((b) => _barangJson(b, saya)).toList(),
        o,
      );
    }
    if (m == 'GET' && p == '/preloved/saya') {
      return _halaman(
        'Barang Anda berhasil dimuat.',
        _barang.values
            .where((b) => b['penjual_id'] == saya)
            .map((b) => _barangJson(b, saya))
            .toList(),
        o,
      );
    }
    if (m == 'POST' && p == '/preloved') {
      final id = _idBaru;
      _barang[id] = {
        'id': id,
        'penjual_id': saya,
        'judul': d['judul'],
        'deskripsi': d['deskripsi'],
        'kategori': d['kategori'],
        'kondisi': d['kondisi'],
        'harga': double.tryParse('${d['harga']}') ?? 0,
        'kecamatan': d['kecamatan'],
        'foto': [
          for (var i = 0; i < fotoBaru; i++)
            'https://picsum.photos/seed/bs$id-$i/600/600',
        ],
        'status': 'tersedia',
        'created_at': _sekarang,
      };
      return _sukses(
        'Barang berhasil dipasang.',
        _barangJson(_barang[id]!, saya),
        201,
      );
    }

    final mBarang = RegExp(r'^/preloved/(\d+)(/\w+)?$').firstMatch(p);
    if (mBarang != null) {
      final b = _barang[int.parse(mBarang.group(1)!)];
      final aksi = mBarang.group(2);
      if (b == null ||
          (b['status'] == 'disembunyikan' && b['penjual_id'] != saya)) {
        return _gagal(404, 'Data tidak ditemukan.');
      }
      final milik = b['penjual_id'] == saya;

      if (aksi == null && m == 'GET') {
        return _sukses('Detail barang berhasil dimuat.', _barangJson(b, saya));
      }
      if (aksi == null && (m == 'PATCH' || m == 'POST' || m == 'DELETE')) {
        if (!milik) {
          return _gagal(403, 'Anda tidak memiliki akses ke fitur ini.');
        }
        if (m == 'DELETE') {
          _barang.remove(b['id']);
          return _sukses('Barang berhasil dihapus.');
        }
        for (final k in [
          'judul',
          'deskripsi',
          'kategori',
          'kondisi',
          'kecamatan',
        ]) {
          if (d.containsKey(k)) b[k] = d[k];
        }
        if (d.containsKey('harga')) {
          b['harga'] = double.tryParse('${d['harga']}') ?? b['harga'];
        }
        if (fotoBaru > 0) {
          b['foto'] = [
            for (var i = 0; i < fotoBaru; i++)
              'https://picsum.photos/seed/bs${b['id']}-u$i/600/600',
          ];
        }
        return _sukses('Barang berhasil diperbarui.', _barangJson(b, saya));
      }
      if (aksi == '/terjual') {
        if (!milik) {
          return _gagal(403, 'Anda tidak memiliki akses ke fitur ini.');
        }
        if (b['status'] != 'tersedia') {
          return _gagal(422, 'Data yang dikirim tidak valid.', {
            'status': ['Barang tidak bisa ditandai terjual.'],
          });
        }
        b['status'] = 'terjual';
        return _sukses('Barang ditandai terjual.', _barangJson(b, saya));
      }
      if (aksi == '/lapor') {
        if (milik) {
          return _gagal(422, 'Data yang dikirim tidak valid.', {
            'alasan': ['Anda tidak bisa melaporkan barang sendiri.'],
          });
        }
        if (!_sudahMelapor.add('${b['id']}:$saya')) {
          return _gagal(422, 'Data yang dikirim tidak valid.', {
            'alasan': ['Anda sudah melaporkan barang ini.'],
          });
        }
        return _sukses(
          'Laporan terkirim. Terima kasih, DLH akan meninjau barang ini.',
          null,
          201,
        );
      }
      if (aksi == '/chat') {
        if (milik) {
          return _gagal(422, 'Data yang dikirim tidak valid.', {
            'preloved_item_id': ['Anda tidak bisa chat dengan barang sendiri.'],
          });
        }
        final ada = _chat.values
            .where(
              (c) =>
                  c['preloved_item_id'] == b['id'] && c['pembeli_id'] == saya,
            )
            .firstOrNull;
        if (ada != null) {
          return _sukses('Percakapan siap.', _chatJson(ada, saya));
        }
        final id = _idBaru;
        _chat[id] = {
          'id': id,
          'preloved_item_id': b['id'],
          'pembeli_id': saya,
          'penjual_id': b['penjual_id'],
          'last_message_at': null,
          'created_at': _sekarang,
        };
        return _sukses('Percakapan siap.', _chatJson(_chat[id]!, saya), 201);
      }
    }

    if (m == 'GET' && p == '/chat') {
      final daftar =
          _chat.values
              .where(
                (c) =>
                    (c['pembeli_id'] == saya || c['penjual_id'] == saya) &&
                    c['last_message_at'] != null,
              )
              .toList()
            ..sort(
              (a, b) => '${b['last_message_at']}'.compareTo(
                '${a['last_message_at']}',
              ),
            );
      return _halaman(
        'Daftar chat berhasil dimuat.',
        daftar.map((c) => _chatJson(c, saya)).toList(),
        o,
      );
    }
    final mChat = RegExp(r'^/chat/(\d+)/(pesan|baca)$').firstMatch(p);
    if (mChat != null) {
      final c = _chat[int.parse(mChat.group(1)!)];
      if (c == null) return _gagal(404, 'Data tidak ditemukan.');
      if (c['pembeli_id'] != saya && c['penjual_id'] != saya) {
        return _gagal(403, 'Anda tidak memiliki akses ke fitur ini.');
      }
      final milikChat = _pesan.where((x) => x['percakapan_id'] == c['id']);

      if (mChat.group(2) == 'baca') {
        var jumlah = 0;
        for (final x in milikChat.where(
          (x) => x['pengirim_id'] != saya && x['dibaca_at'] == null,
        )) {
          x['dibaca_at'] = _sekarang;
          jumlah++;
        }
        return _sukses('Pesan ditandai dibaca.', {'jumlah': jumlah});
      }
      if (m == 'GET') {
        final after = int.tryParse('${q['after_id'] ?? ''}');
        final daftar = after == null
            ? milikChat.toList().reversed.take(50).toList().reversed
            : milikChat.where((x) => (x['id'] as int) > after).take(50);
        return _sukses(
          'Pesan berhasil dimuat.',
          daftar.map((x) => _pesanJson(x, saya)).toList(),
        );
      }
      final pesan = {
        'id': _idBaru,
        'percakapan_id': c['id'],
        'pengirim_id': saya,
        'isi': d['isi'],
        'tawaran_harga': d['tawaran_harga'] == null
            ? null
            : (d['tawaran_harga'] as num).toDouble(),
        'dibaca_at': null,
        'created_at': _sekarang,
      };
      _pesan.add(pesan);
      c['last_message_at'] = _sekarang;
      // Lawan bicara palsu membalas tawaran agar polling terlihat bekerja di mode mock
      if (pesan['tawaran_harga'] != null) {
        _pesan.add({
          'id': _idBaru,
          'percakapan_id': c['id'],
          'pengirim_id': c['penjual_id'] == saya
              ? c['pembeli_id']
              : c['penjual_id'],
          'isi': 'Tawaran diterima, kapan bisa COD?',
          'tawaran_harga': null,
          'dibaca_at': null,
          'created_at': _sekarang,
        });
      }
      return _sukses('Pesan terkirim.', _pesanJson(pesan, saya), 201);
    }

    return _gagal(404, 'Data tidak ditemukan.');
  }

  Map<String, dynamic> _login(int id) {
    final token = 'mock-$_idBaru';
    _token[token] = id;
    return {
      'user': _userJson(id),
      'token': token,
      'token_type': 'Bearer',
      'expires_at': null,
    };
  }

  (int, Map<String, dynamic>) _warga(
    String m,
    String p,
    Map<String, dynamic> d,
    Map<String, dynamic> q,
    RequestOptions o,
    int saya,
  ) {
    if (m == 'GET' && p == '/warga/saldo') {
      final daftar = _saldo.entries
          .where((e) => e.key.startsWith('$saya:'))
          .map((e) {
            final bankId = int.parse(e.key.split(':')[1]);
            return {
              'bank_sampah_id': bankId,
              'bank_sampah': _ringkasBank(bankId),
              'saldo': e.value,
              'updated_at': _sekarang,
            };
          })
          .toList();
      final total = daftar.fold<double>(
        0,
        (s, e) => s + (e['saldo'] as double),
      );
      return _sukses('Saldo berhasil dimuat.', {
        'total_saldo': total,
        'daftar': daftar,
      });
    }
    if (m == 'GET' && p == '/warga/setoran') {
      final bankId = int.tryParse('${q['bank_sampah_id'] ?? ''}');
      return _halaman(
        'Riwayat setoran berhasil dimuat.',
        _setoran.reversed
            .where(
              (s) =>
                  s['warga_id'] == saya &&
                  (bankId == null || s['bank_sampah_id'] == bankId),
            )
            .toList(),
        o,
      );
    }
    if (m == 'GET' && p == '/warga/penjemputan') {
      return _halaman(
        'Daftar penjemputan berhasil dimuat.',
        _jemput.reversed
            .where((j) => j['warga_id'] == saya)
            .map(_jemputLengkap)
            .toList(),
        o,
      );
    }
    if (m == 'POST' && p == '/warga/penjemputan') {
      final j =
          _jemputJson(
              _idBaru,
              saya,
              int.parse('${d['bank_sampah_id']}'),
              'diajukan',
            )
            ..['alamat'] = d['alamat']
            ..['lat'] = double.tryParse('${d['lat']}') ?? 0
            ..['lng'] = double.tryParse('${d['lng']}') ?? 0
            ..['perkiraan_kg'] = double.tryParse('${d['perkiraan_kg'] ?? ''}')
            ..['catatan'] = d['catatan'];
      _jemput.add(j);
      return _sukses(
        'Permintaan jemput berhasil diajukan.',
        _jemputLengkap(j),
        201,
      );
    }
    final batal = RegExp(r'^/warga/penjemputan/(\d+)/batal$').firstMatch(p);
    if (m == 'POST' && batal != null) {
      final j = _jemput
          .where(
            (j) =>
                j['id'] == int.parse(batal.group(1)!) && j['warga_id'] == saya,
          )
          .firstOrNull;
      if (j == null) {
        return _gagal(403, 'Anda tidak memiliki akses ke fitur ini.');
      }
      if (j['status'] != 'diajukan') {
        return _gagal(422, 'Data yang dikirim tidak valid.', {
          'status': [
            'Penjemputan berstatus ${j['status']} tidak bisa diubah menjadi dibatalkan.',
          ],
        });
      }
      j['status'] = 'dibatalkan';
      return _sukses('Permintaan jemput dibatalkan.', _jemputLengkap(j));
    }
    if (m == 'GET' && p == '/warga/penarikan') {
      return _halaman(
        'Riwayat penarikan berhasil dimuat.',
        _tarik.reversed
            .where((t) => t['warga_id'] == saya)
            .map(
              (t) => {
                ...t,
                'bank_sampah': _ringkasBank(t['bank_sampah_id'] as int),
              },
            )
            .toList(),
        o,
      );
    }
    if (m == 'POST' && p == '/warga/penarikan') {
      final bankId = int.parse('${d['bank_sampah_id']}');
      final jumlah = double.tryParse('${d['jumlah']}') ?? 0;
      final saldo = _saldo['$saya:$bankId'] ?? 0;
      if (jumlah > saldo) {
        return _gagal(422, 'Data yang dikirim tidak valid.', {
          'jumlah': ['Saldo tidak mencukupi.'],
        });
      }
      if (_tarik.any(
        (t) =>
            t['warga_id'] == saya &&
            t['bank_sampah_id'] == bankId &&
            t['status'] == 'diajukan',
      )) {
        return _gagal(422, 'Data yang dikirim tidak valid.', {
          'jumlah': [
            'Masih ada penarikan yang menunggu persetujuan di bank sampah ini.',
          ],
        });
      }
      final t = {
        'id': _idBaru,
        'warga_id': saya,
        'bank_sampah_id': bankId,
        'jumlah': jumlah,
        'status': 'diajukan',
        'catatan': d['catatan'],
        'created_at': _sekarang,
      };
      _tarik.add(t);
      return _sukses(
        'Penarikan berhasil diajukan dan menunggu persetujuan bank sampah.',
        {...t, 'bank_sampah': _ringkasBank(bankId)},
        201,
      );
    }
    return _gagal(404, 'Data tidak ditemukan.');
  }

  (int, Map<String, dynamic>) _bs(
    String m,
    String p,
    Map<String, dynamic> d,
    Map<String, dynamic> q,
    RequestOptions o,
    int saya,
    int bank,
  ) {
    if (m == 'GET' && p == '/bs/dashboard') {
      final milik = _setoran.where((s) => s['bank_sampah_id'] == bank);
      Map<String, dynamic> ringkas() => {
        'jumlah_setoran': milik.length,
        'total_kg': milik.fold<double>(
          0,
          (s, e) => s + (e['total_kg'] as double),
        ),
        'kg_donasi': milik
            .where((e) => e['tipe'] == 'donasi')
            .fold<double>(0, (s, e) => s + (e['total_kg'] as double)),
        'total_nilai': milik.fold<double>(
          0,
          (s, e) => s + (e['total_nilai'] as double),
        ),
      };
      final tarik = _tarik.where(
        (t) => t['bank_sampah_id'] == bank && t['status'] == 'diajukan',
      );
      final saldo = _saldo.entries.where((e) => e.key.endsWith(':$bank'));
      return _sukses('Ringkasan bank sampah berhasil dimuat.', {
        'hari_ini': ringkas(),
        'bulan_ini': ringkas(),
        'penjemputan': {
          'diajukan': _jemput
              .where(
                (j) => j['bank_sampah_id'] == bank && j['status'] == 'diajukan',
              )
              .length,
          'berjalan': _jemput
              .where(
                (j) =>
                    j['bank_sampah_id'] == bank &&
                    ['dijadwalkan', 'menuju', 'diambil'].contains(j['status']),
              )
              .length,
        },
        'penarikan_diajukan': {
          'jumlah': tarik.length,
          'total': tarik.fold<double>(0, (s, t) => s + (t['jumlah'] as double)),
        },
        'nasabah': {
          'jumlah': saldo.length,
          'total_saldo': saldo.fold<double>(0, (s, e) => s + e.value),
        },
      });
    }
    if (p == '/bs/harga') {
      if (m == 'PUT') {
        for (final h in (d['harga'] as List)) {
          _harga['$bank:${h['jenis_sampah_id']}'] = (h['harga_per_kg'] as num)
              .toDouble();
        }
      }
      return _sukses(
        m == 'PUT'
            ? 'Harga berhasil disimpan.'
            : 'Daftar harga berhasil dimuat.',
        _jenis.values
            .map(
              (j) => {
                'jenis_sampah_id': j['id'],
                'nama': j['nama'],
                'satuan': 'kg',
                'harga_per_kg': _harga['$bank:${j['id']}'],
              },
            )
            .toList(),
      );
    }
    if (m == 'GET' && p == '/bs/nasabah') {
      final kata = '${q['q'] ?? ''}'.toLowerCase();
      final daftar = _users.values
          .where((u) => u['role'] == 'warga')
          .where(
            (u) => kata.isEmpty
                ? _saldo.containsKey('${u['id']}:$bank')
                : '${u['name']} ${u['phone']} ${u['email']}'
                      .toLowerCase()
                      .contains(kata),
          )
          .map(
            (u) => {
              'id': u['id'],
              'name': u['name'],
              'email': u['email'],
              'phone': u['phone'],
              'alamat': u['alamat'],
              'saldo': _saldo['${u['id']}:$bank'] ?? 0,
              'sudah_nasabah': _saldo.containsKey('${u['id']}:$bank'),
            },
          )
          .toList();
      return _halaman('Daftar warga berhasil dimuat.', daftar, o);
    }
    if (m == 'GET' && p == '/bs/setoran') {
      return _halaman(
        'Riwayat setoran berhasil dimuat.',
        _setoran.reversed.where((s) => s['bank_sampah_id'] == bank).toList(),
        o,
      );
    }
    final batalSetoran = RegExp(r'^/bs/setoran/(\d+)/batal$').firstMatch(p);
    if (m == 'POST' && batalSetoran != null) {
      final s = _setoran
          .where(
            (s) =>
                s['id'] == int.parse(batalSetoran.group(1)!) &&
                s['bank_sampah_id'] == bank,
          )
          .firstOrNull;
      if (s == null) return _gagal(404, 'Data tidak ditemukan.');
      if (s['dibatalkan_at'] != null) {
        return _gagal(422, 'Data yang dikirim tidak valid.', {
          'alasan': ['Setoran ini sudah dibatalkan.'],
        });
      }
      final kunci = '${s['warga_id']}:$bank';
      final nilai = s['total_nilai'] as double;
      if (nilai > (_saldo[kunci] ?? 0)) {
        return _gagal(422, 'Data yang dikirim tidak valid.', {
          'alasan': [
            'Saldo warga kurang dari nilai setoran ini. Selesaikan langsung dengan warga.',
          ],
        });
      }
      _saldo[kunci] = (_saldo[kunci] ?? 0) - nilai;
      s['dibatalkan_at'] = DateTime.now().toIso8601String();
      s['alasan_batal'] = d['alasan'];
      return _sukses('Setoran berhasil dibatalkan.', s);
    }
    if (m == 'POST' && p == '/bs/setoran') {
      final requestId = d['request_id'] as String?;
      final requestKey = '$saya:${requestId?.toLowerCase()}';
      final normalizedItems =
          [
            for (final i in d['items'] as List)
              {
                'jenis_sampah_id': i['jenis_sampah_id'],
                'berat_sen': ((i['berat_kg'] as num) * 100).round(),
              },
          ]..sort(
            (a, b) => (a['jenis_sampah_id'] as int).compareTo(
              b['jenis_sampah_id'] as int,
            ),
          );
      final fingerprint = jsonEncode({
        'warga_id': d['warga_id'],
        'tipe': d['tipe'],
        'items': normalizedItems,
        'penjemputan_id': d['penjemputan_id'],
        'catatan': d['catatan'],
      });
      final lama = requestId == null ? null : _permintaanSetoran[requestKey];
      if (lama != null) {
        if (lama.$1 != fingerprint) {
          return _gagal(422, 'Data yang dikirim tidak valid.', {
            'request_id': [
              'Permintaan ini sudah diproses dengan rincian berbeda. Periksa riwayat setoran.',
            ],
          });
        }
        return _sukses(
          d['tipe'] == 'donasi'
              ? 'Donasi sampah berhasil dicatat.'
              : 'Setoran berhasil dicatat.',
          lama.$2,
          201,
        );
      }
      final wargaId = d['warga_id'] as int;
      final tipe = '${d['tipe']}';
      final items = <(int, double, double)>[];
      for (final i in (d['items'] as List)) {
        final jenisId = i['jenis_sampah_id'] as int;
        final harga = _harga['$bank:$jenisId'];
        if (tipe == 'jual' && harga == null) {
          return _gagal(422, 'Data yang dikirim tidak valid.', {
            'items.0.jenis_sampah_id': [
              'Harga ${_jenis[jenisId]!['nama']} belum diatur di bank sampah ini.',
            ],
          });
        }
        items.add((
          jenisId,
          (i['berat_kg'] as num).toDouble(),
          tipe == 'jual' ? harga! : 0,
        ));
      }
      final jemputId = d['penjemputan_id'] as int?;
      if (jemputId != null) {
        final j = _jemput.firstWhere((j) => j['id'] == jemputId);
        if (j['status'] != 'diambil') {
          return _gagal(422, 'Data yang dikirim tidak valid.', {
            'penjemputan_id': [
              'Setoran hanya bisa dicatat untuk penjemputan berstatus diambil.',
            ],
          });
        }
        j['status'] = 'selesai';
        _armada[j['armada_id']]?['status'] = 'siaga';
      }
      final s = _setoranJson(
        _idBaru,
        wargaId,
        bank,
        tipe,
        items,
        saya,
        jemputId,
      );
      _setoran.add(s);
      final kunci = '$wargaId:$bank';
      _saldo[kunci] = (_saldo[kunci] ?? 0) + (s['total_nilai'] as double);
      final hasil = {'setoran': s, 'saldo_sekarang': _saldo[kunci]};
      if (requestId != null) {
        _permintaanSetoran[requestKey] = (
          fingerprint,
          (jsonDecode(jsonEncode(hasil)) as Map).cast<String, dynamic>(),
        );
      }
      return _sukses(
        tipe == 'donasi'
            ? 'Donasi sampah berhasil dicatat.'
            : 'Setoran berhasil dicatat.',
        hasil,
        201,
      );
    }
    if (m == 'GET' && p == '/bs/penjemputan') {
      final status = '${q['status'] ?? ''}'
          .split(',')
          .where((s) => s.isNotEmpty)
          .toSet();
      return _halaman(
        'Daftar penjemputan berhasil dimuat.',
        _jemput.reversed
            .where(
              (j) =>
                  j['bank_sampah_id'] == bank &&
                  (status.isEmpty || status.contains(j['status'])),
            )
            .map(_jemputLengkap)
            .toList(),
        o,
      );
    }
    final ubahJemput = RegExp(r'^/bs/penjemputan/(\d+)$').firstMatch(p);
    if (m == 'PATCH' && ubahJemput != null) {
      final j = _jemput.firstWhere(
        (j) => j['id'] == int.parse(ubahJemput.group(1)!),
      );
      if (j['status'] != 'diajukan') {
        return _gagal(422, 'Data yang dikirim tidak valid.', {
          'status': [
            'Penjemputan berstatus ${j['status']} tidak bisa diproses lagi.',
          ],
        });
      }
      if (d['aksi'] == 'jadwalkan') {
        j
          ..['status'] = 'dijadwalkan'
          ..['armada_id'] = d['armada_id']
          ..['jadwal_at'] = d['jadwal_at'];
      } else {
        j
          ..['status'] = 'ditolak'
          ..['alasan_tolak'] = d['alasan'];
      }
      return _sukses(
        d['aksi'] == 'jadwalkan'
            ? 'Penjemputan berhasil dijadwalkan.'
            : 'Penjemputan ditolak.',
        _jemputLengkap(j),
      );
    }
    if (m == 'GET' && p == '/bs/armada') {
      final punyaArmada = _armada.values.map((a) => a['driver_id']).toSet();
      return _sukses('Daftar armada berhasil dimuat.', {
        'armada': _armada.values
            .where((a) => a['bank_sampah_id'] == bank)
            .map(_armadaJson)
            .toList(),
        'bentor_tanpa_armada': _users.values
            .where(
              (u) =>
                  u['role'] == 'bentor' &&
                  u['bank_sampah_id'] == bank &&
                  !punyaArmada.contains(u['id']),
            )
            .toList(),
      });
    }
    if (m == 'POST' && p == '/bs/armada') {
      final a = {
        'id': _idBaru,
        'bank_sampah_id': bank,
        'driver_id': d['driver_id'],
        'plat_nomor': d['plat_nomor'],
        'kapasitas_kg': d['kapasitas_kg'],
        'status': 'siaga',
      };
      _armada[a['id'] as int] = a;
      return _sukses('Armada berhasil ditambahkan.', _armadaJson(a), 201);
    }
    final ubahArmada = RegExp(r'^/bs/armada/(\d+)$').firstMatch(p);
    if (m == 'PATCH' && ubahArmada != null) {
      final a = _armada[int.parse(ubahArmada.group(1)!)]!;
      a.addAll(d);
      return _sukses('Armada berhasil diperbarui.', _armadaJson(a));
    }
    if (m == 'POST' && p == '/bs/bentor') {
      final id = _idBaru;
      _userBaru(
        id,
        '${d['name']}',
        '${d['email']}',
        'bentor',
        bank,
        '${d['phone']}',
      );
      Map<String, dynamic>? armada;
      if ('${d['plat_nomor'] ?? ''}'.isNotEmpty) {
        armada = {
          'id': _idBaru,
          'bank_sampah_id': bank,
          'driver_id': id,
          'plat_nomor': d['plat_nomor'],
          'kapasitas_kg': d['kapasitas_kg'],
          'status': 'siaga',
        };
        _armada[armada['id'] as int] = armada;
      }
      return _sukses('Akun bentor berhasil dibuat.', {
        'bentor': _userJson(id),
        'armada': armada == null ? null : _armadaJson(armada),
      }, 201);
    }
    final statusBentor = RegExp(r'^/bs/bentor/(\d+)/status$').firstMatch(p);
    if (m == 'PATCH' && statusBentor != null) {
      final target = _users[int.parse(statusBentor.group(1)!)];
      if (target == null ||
          target['role'] != 'bentor' ||
          target['bank_sampah_id'] != bank) {
        return _gagal(403, 'Anda tidak memiliki akses ke fitur ini.');
      }
      final aktif = d['is_aktif'] == true;
      target['is_aktif'] = aktif;
      if (!aktif) {
        _token.removeWhere((_, id) => id == target['id']);
        _armada.values
            .where((a) => a['driver_id'] == target['id'])
            .forEach((a) => a['status'] = 'nonaktif');
      }
      return _sukses(
        aktif
            ? 'Akun bentor diaktifkan.'
            : 'Akun bentor dinonaktifkan dan dikeluarkan dari semua perangkat.',
        _userJson(target['id'] as int),
      );
    }
    if (m == 'GET' && p == '/bs/penarikan') {
      final status = q['status'];
      return _halaman(
        'Daftar penarikan berhasil dimuat.',
        _tarik.reversed
            .where(
              (t) =>
                  t['bank_sampah_id'] == bank &&
                  (status == null || t['status'] == status),
            )
            .map((t) {
              final w = _users[t['warga_id']]!;
              return {
                ...t,
                'warga': {
                  'id': w['id'],
                  'name': w['name'],
                  'phone': w['phone'],
                },
              };
            })
            .toList(),
        o,
      );
    }
    final ubahTarik = RegExp(r'^/bs/penarikan/(\d+)$').firstMatch(p);
    if (m == 'PATCH' && ubahTarik != null) {
      final t = _tarik.firstWhere(
        (t) => t['id'] == int.parse(ubahTarik.group(1)!),
      );
      if (t['status'] != 'diajukan') {
        return _gagal(422, 'Data yang dikirim tidak valid.', {
          'aksi': ['Penarikan ini sudah ${t['status']}.'],
        });
      }
      if (d['aksi'] == 'setujui') {
        final kunci = '${t['warga_id']}:$bank';
        if ((_saldo[kunci] ?? 0) < (t['jumlah'] as double)) {
          return _gagal(422, 'Data yang dikirim tidak valid.', {
            'aksi': ['Saldo nasabah tidak mencukupi. Tolak penarikan ini.'],
          });
        }
        _saldo[kunci] = _saldo[kunci]! - (t['jumlah'] as double);
        t['status'] = 'disetujui';
      } else {
        t['status'] = 'ditolak';
      }
      final w = _users[t['warga_id']]!;
      return _sukses(
        d['aksi'] == 'setujui'
            ? 'Penarikan disetujui dan saldo nasabah telah dikurangi.'
            : 'Penarikan ditolak.',
        {
          ...t,
          'warga': {'id': w['id'], 'name': w['name'], 'phone': w['phone']},
        },
      );
    }
    if (p == '/bs/penjualan-pengepul') {
      if (m == 'POST') {
        final berat = (d['berat_kg'] as num).toDouble();
        final harga = (d['harga_per_kg'] as num).toDouble();
        if (berat > 100000) {
          return _gagal(422, 'Data yang dikirim tidak valid.', {
            'berat_kg': ['Berat tidak boleh lebih dari 100000.'],
          });
        }
        _pengepul.add({
          'id': _idBaru,
          'bank_sampah_id': bank,
          'nama_pengepul': d['nama_pengepul'],
          'jenis_sampah_id': d['jenis_sampah_id'],
          'jenis_sampah': _jenis[d['jenis_sampah_id']]?['nama'],
          'berat_kg': berat,
          'harga_per_kg': harga,
          'total': berat * harga,
          'tanggal':
              d['tanggal'] ?? DateTime.now().toIso8601String().substring(0, 10),
          'created_at': _sekarang,
        });
        return _sukses(
          'Penjualan ke pengepul berhasil dicatat.',
          _pengepul.last,
          201,
        );
      }
      return _halaman(
        'Riwayat penjualan ke pengepul berhasil dimuat.',
        _pengepul.reversed.where((x) => x['bank_sampah_id'] == bank).toList(),
        o,
      );
    }
    return _gagal(404, 'Data tidak ditemukan.');
  }

  (int, Map<String, dynamic>) _bentor(
    String m,
    String p,
    Map<String, dynamic> d,
    Map<String, dynamic> q,
    RequestOptions o,
    int saya,
  ) {
    final armada = _armada.values
        .where((a) => a['driver_id'] == saya)
        .firstOrNull;
    if (m == 'GET' && p == '/bentor/tugas') {
      final status = '${q['status'] ?? 'dijadwalkan,menuju,diambil'}'
          .split(',')
          .toSet();
      return _halaman(
        'Daftar tugas berhasil dimuat.',
        _jemput
            .where(
              (j) =>
                  armada != null &&
                  j['armada_id'] == armada['id'] &&
                  status.contains(j['status']),
            )
            .map(_jemputLengkap)
            .toList(),
        o,
      );
    }
    final timbang = RegExp(r'^/bentor/tugas/(\d+)/setoran$').firstMatch(p);
    if (m == 'POST' && timbang != null) {
      final j = _jemput.firstWhere(
        (j) => j['id'] == int.parse(timbang.group(1)!),
      );
      if (armada == null || j['armada_id'] != armada['id']) {
        return _gagal(403, 'Anda tidak memiliki akses ke fitur ini.');
      }
      // Warga dan penjemputan selalu dari tugas, seperti di server asli
      return _bs(
        m,
        '/bs/setoran',
        {...d, 'warga_id': j['warga_id'], 'penjemputan_id': j['id']},
        q,
        o,
        saya,
        j['bank_sampah_id'] as int,
      );
    }
    final ubah = RegExp(r'^/bentor/tugas/(\d+)/status$').firstMatch(p);
    if (m == 'PATCH' && ubah != null) {
      final j = _jemput.firstWhere((j) => j['id'] == int.parse(ubah.group(1)!));
      if (armada == null || j['armada_id'] != armada['id']) {
        return _gagal(403, 'Anda tidak memiliki akses ke fitur ini.');
      }
      final sah = {'dijadwalkan': 'menuju', 'menuju': 'diambil'}[j['status']];
      if (sah != d['status']) {
        return _gagal(422, 'Data yang dikirim tidak valid.', {
          'status': [
            'Penjemputan berstatus ${j['status']} tidak bisa diubah menjadi ${d['status']}.',
          ],
        });
      }
      j['status'] = d['status'];
      if (d['status'] == 'menuju') armada['status'] = 'bertugas';
      return _sukses('Status diperbarui.', _jemputLengkap(j));
    }
    if (m == 'GET' && p == '/bentor/armada') {
      if (armada == null) return _gagal(404, 'Data tidak ditemukan.');
      return _sukses('Data armada berhasil dimuat.', _armadaJson(armada));
    }
    if (m == 'PATCH' && p == '/bentor/armada/status') {
      if (armada == null) return _gagal(404, 'Data tidak ditemukan.');
      armada['status'] = d['status'];
      return _sukses('Status armada diperbarui.', _armadaJson(armada));
    }
    return _gagal(404, 'Data tidak ditemukan.');
  }
}
