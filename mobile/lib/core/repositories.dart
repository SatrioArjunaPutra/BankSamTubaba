import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_client.dart';
import 'models/bank_sampah.dart';
import 'models/operasional.dart';
import 'models/transaksi.dart';
import 'models/user.dart';
import 'providers.dart';

T _data<T>(Map<String, dynamic> body, T Function(Map<String, dynamic>) dari) =>
    dari((body['data'] as Map).cast());

/// Endpoint umum & akun (semua role).
class UmumRepository {
  UmumRepository(this._api);
  final ApiClient _api;

  Future<Halaman<BankSampah>> daftarBankSampah({String? q, int halaman = 1}) =>
      _api.daftar(
        '/bank-sampah',
        BankSampah.dariJson,
        query: {'q': q},
        halaman: halaman,
      );

  Future<List<BankSampah>> bankTerdekat(
    double lat,
    double lng, {
    double radiusKm = 20,
  }) => _api.list(
    '/bank-sampah/nearby',
    BankSampah.dariJson,
    query: {'lat': lat, 'lng': lng, 'radius_km': radiusKm},
  );

  /// Tanpa login: jumlah bank sampah aktif per kecamatan untuk warna peta.
  Future<Map<String, int>> bankPerKecamatan() async {
    final data = (await _api.get('/statistik-publik'))['data'] as Map;
    final jumlah = data['bank_per_kecamatan'];
    return jumlah is Map ? {for (final e in jumlah.entries) '${e.key}': (e.value as num).toInt()} : const {};
  }

  /// Tanpa login: jarak ke bank sampah saat calon warga mengisi formulir daftar.
  Future<List<BankSampah>> bankTerdekatPublik(double lat, double lng) => _api.list(
    '/pendaftaran/bank-terdekat',
    BankSampah.dariJson,
    query: {'lat': lat, 'lng': lng},
  );

  Future<BankSampah> detailBankSampah(int id) async =>
      _data(await _api.get('/bank-sampah/$id'), BankSampah.dariJson);

  Future<List<JenisSampah>> jenisSampah() =>
      _api.list('/jenis-sampah', JenisSampah.dariJson);

  Future<User> ubahProfil(Map<String, dynamic> data) async =>
      _data(await _api.patch('/me', data: data), User.dariJson);

  Future<String> ubahPassword(String lama, String baru) async {
    final body = await _api.put(
      '/me/password',
      data: {
        'password_lama': lama,
        'password': baru,
        'password_confirmation': baru,
      },
    );
    return '${body['pesan']}';
  }
}

class WargaRepository {
  WargaRepository(this._api);
  final ApiClient _api;

  Future<RingkasanSaldo> saldo() async =>
      _data(await _api.get('/warga/saldo'), RingkasanSaldo.dariJson);

  Future<Halaman<Setoran>> setoran({int? bankSampahId, int halaman = 1}) =>
      _api.daftar(
        '/warga/setoran',
        Setoran.dariJson,
        query: {'bank_sampah_id': bankSampahId},
        halaman: halaman,
      );

  Future<Halaman<Penjemputan>> penjemputan({int halaman = 1}) =>
      _api.daftar('/warga/penjemputan', Penjemputan.dariJson, halaman: halaman);

  Future<Penjemputan> ajukanJemput({
    required int bankSampahId,
    required String alamat,
    required double lat,
    required double lng,
    double? perkiraanKg,
    String? catatan,
    String? pathFoto,
  }) async {
    final form = FormData.fromMap({
      'bank_sampah_id': bankSampahId,
      'alamat': alamat,
      'lat': lat,
      'lng': lng,
      'perkiraan_kg': ?perkiraanKg,
      if (catatan != null && catatan.isNotEmpty) 'catatan': catatan,
      if (pathFoto != null) 'foto': await MultipartFile.fromFile(pathFoto),
    });
    return _data(
      await _api.post('/warga/penjemputan', data: form),
      Penjemputan.dariJson,
    );
  }

  Future<Penjemputan> batalJemput(int id) async => _data(
    await _api.post('/warga/penjemputan/$id/batal'),
    Penjemputan.dariJson,
  );

  Future<Halaman<Penarikan>> penarikan({int halaman = 1}) =>
      _api.daftar('/warga/penarikan', Penarikan.dariJson, halaman: halaman);

  Future<Penarikan> ajukanPenarikan(
    int bankSampahId,
    double jumlah,
    String? catatan,
  ) async => _data(
    await _api.post(
      '/warga/penarikan',
      data: {
        'bank_sampah_id': bankSampahId,
        'jumlah': jumlah,
        'catatan': catatan,
      },
    ),
    Penarikan.dariJson,
  );
}

class BankSampahRepository {
  BankSampahRepository(this._api);
  final ApiClient _api;

  Future<DashboardBank> dashboard() async =>
      _data(await _api.get('/bs/dashboard'), DashboardBank.dariJson);

  Future<List<Harga>> harga() => _api.list('/bs/harga', Harga.dariJson);

  Future<List<Harga>> simpanHarga(Map<int, double> harga) async {
    final body = await _api.put(
      '/bs/harga',
      data: {
        'harga': [
          for (final e in harga.entries)
            {'jenis_sampah_id': e.key, 'harga_per_kg': e.value},
        ],
      },
    );
    return (body['data'] as List)
        .map((e) => Harga.dariJson((e as Map).cast()))
        .toList();
  }

  Future<Halaman<WargaNasabah>> cariNasabah(String? q, {int halaman = 1}) =>
      _api.daftar(
        '/bs/nasabah',
        WargaNasabah.dariJson,
        query: {'q': q},
        halaman: halaman,
      );

  Future<Halaman<Setoran>> setoran({int halaman = 1}) =>
      _api.daftar('/bs/setoran', Setoran.dariJson, halaman: halaman);

  /// Kembalikan setoran dan saldo warga setelahnya.
  Future<(Setoran, double)> catatSetoran({
    required int wargaId,
    required String tipe,
    required List<(int jenisId, double beratKg)> items,
    int? penjemputanId,
    String? catatan,
    String? requestId,
  }) async {
    final body = await _api.post(
      '/bs/setoran',
      data: {
        'warga_id': wargaId,
        'tipe': tipe,
        'items': [
          for (final i in items) {'jenis_sampah_id': i.$1, 'berat_kg': i.$2},
        ],
        'penjemputan_id': ?penjemputanId,
        'request_id': ?requestId,
        if (catatan != null && catatan.isNotEmpty) 'catatan': catatan,
      },
    );
    final data = (body['data'] as Map).cast<String, dynamic>();
    return (
      Setoran.dariJson((data['setoran'] as Map).cast()),
      (data['saldo_sekarang'] as num).toDouble(),
    );
  }

  Future<Setoran> batalkanSetoran(int id, String alasan) async => _data(
    await _api.post('/bs/setoran/$id/batal', data: {'alasan': alasan}),
    Setoran.dariJson,
  );

  Future<Halaman<Penjemputan>> penjemputan(String status, {int halaman = 1}) =>
      _api.daftar(
        '/bs/penjemputan',
        Penjemputan.dariJson,
        query: {'status': status},
        halaman: halaman,
      );

  Future<Penjemputan> jadwalkan(int id, int armadaId, DateTime jadwal) async =>
      _data(
        await _api.patch(
          '/bs/penjemputan/$id',
          data: {
            'aksi': 'jadwalkan',
            'armada_id': armadaId,
            'jadwal_at': jadwal.toUtc().toIso8601String(),
          },
        ),
        Penjemputan.dariJson,
      );

  Future<Penjemputan> tolakJemput(int id, String alasan) async => _data(
    await _api.patch(
      '/bs/penjemputan/$id',
      data: {'aksi': 'tolak', 'alasan': alasan},
    ),
    Penjemputan.dariJson,
  );

  Future<(List<Armada>, List<User>)> armada() async {
    final data = ((await _api.get('/bs/armada'))['data'] as Map)
        .cast<String, dynamic>();
    return (
      (data['armada'] as List)
          .map((e) => Armada.dariJson((e as Map).cast()))
          .toList(),
      (data['bentor_tanpa_armada'] as List)
          .map((e) => User.dariJson((e as Map).cast()))
          .toList(),
    );
  }

  Future<Armada> tambahArmada(
    int driverId,
    String platNomor,
    double? kapasitasKg,
  ) async => _data(
    await _api.post(
      '/bs/armada',
      data: {
        'driver_id': driverId,
        'plat_nomor': platNomor,
        'kapasitas_kg': ?kapasitasKg,
      },
    ),
    Armada.dariJson,
  );

  Future<Armada> ubahArmada(int id, Map<String, dynamic> data) async =>
      _data(await _api.patch('/bs/armada/$id', data: data), Armada.dariJson);

  Future<void> buatBentor(Map<String, dynamic> data) =>
      _api.post('/bs/bentor', data: data);

  /// Nonaktif = driver langsung keluar dari semua perangkat & armadanya nonaktif.
  Future<void> ubahStatusAkunBentor(int userId, bool aktif) =>
      _api.patch('/bs/bentor/$userId/status', data: {'is_aktif': aktif});

  Future<Halaman<Penarikan>> penarikan(String? status, {int halaman = 1}) =>
      _api.daftar(
        '/bs/penarikan',
        Penarikan.dariJson,
        query: {'status': status},
        halaman: halaman,
      );

  Future<Penarikan> prosesPenarikan(
    int id,
    bool setujui,
    String? catatan,
  ) async => _data(
    await _api.patch(
      '/bs/penarikan/$id',
      data: {'aksi': setujui ? 'setujui' : 'tolak', 'catatan': catatan},
    ),
    Penarikan.dariJson,
  );

  Future<Halaman<PenjualanPengepul>> penjualanPengepul({int halaman = 1}) =>
      _api.daftar(
        '/bs/penjualan-pengepul',
        PenjualanPengepul.dariJson,
        halaman: halaman,
      );

  Future<void> catatPenjualanPengepul(Map<String, dynamic> data) =>
      _api.post('/bs/penjualan-pengepul', data: data);
}

class BentorRepository {
  BentorRepository(this._api);
  final ApiClient _api;

  Future<Halaman<Penjemputan>> tugas({String? status, int halaman = 1}) =>
      _api.daftar(
        '/bentor/tugas',
        Penjemputan.dariJson,
        query: {'status': status},
        halaman: halaman,
      );

  Future<Penjemputan> ubahStatusTugas(int id, String status) async => _data(
    await _api.patch('/bentor/tugas/$id/status', data: {'status': status}),
    Penjemputan.dariJson,
  );

  /// Hasil timbang di lokasi. Kembalikan setoran dan saldo warga setelahnya.
  Future<(Setoran, double)> catatSetoranTugas({
    required int tugasId,
    required String tipe,
    required List<(int jenisId, double beratKg)> items,
    String? requestId,
  }) async {
    final body = await _api.post(
      '/bentor/tugas/$tugasId/setoran',
      data: {
        'tipe': tipe,
        'items': [
          for (final i in items) {'jenis_sampah_id': i.$1, 'berat_kg': i.$2},
        ],
        'request_id': ?requestId,
      },
    );
    final data = (body['data'] as Map).cast<String, dynamic>();
    return (
      Setoran.dariJson((data['setoran'] as Map).cast()),
      (data['saldo_sekarang'] as num).toDouble(),
    );
  }

  Future<Armada> armada() async =>
      _data(await _api.get('/bentor/armada'), Armada.dariJson);

  Future<Armada> ubahStatusArmada(String status) async => _data(
    await _api.patch('/bentor/armada/status', data: {'status': status}),
    Armada.dariJson,
  );
}

final umumRepositoryProvider = Provider(
  (ref) => UmumRepository(ref.watch(apiClientProvider)),
);
final wargaRepositoryProvider = Provider(
  (ref) => WargaRepository(ref.watch(apiClientProvider)),
);
final bankSampahRepositoryProvider = Provider(
  (ref) => BankSampahRepository(ref.watch(apiClientProvider)),
);
final bentorRepositoryProvider = Provider(
  (ref) => BentorRepository(ref.watch(apiClientProvider)),
);
