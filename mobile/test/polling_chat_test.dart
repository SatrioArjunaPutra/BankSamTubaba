import 'package:bank_sampah_tubaba/core/models/preloved.dart';
import 'package:bank_sampah_tubaba/features/preloved/pengelola_pesan.dart';
import 'package:flutter_test/flutter_test.dart';

PesanChat _p(int id, {bool saya = false, String? isi, double? tawaran}) =>
    PesanChat(id: id, milikSaya: saya, isi: isi ?? 'pesan $id', tawaranHarga: tawaran);

/// Server palsu: menyimpan pesan, menjawab ?after_id= seperti backend
/// (id > after_id, urut naik, maks 50; tanpa after_id = 50 terakhir).
class _Server {
  final pesan = <PesanChat>[];
  final permintaanAfterId = <int?>[];
  bool gagalKirim = false;
  int _id = 0;

  void masuk({String? isi}) => pesan.add(_p(++_id, isi: isi));

  Future<List<PesanChat>> ambil(int? afterId) async {
    permintaanAfterId.add(afterId);
    if (afterId == null) return pesan.length > 50 ? pesan.sublist(pesan.length - 50) : List.of(pesan);
    return pesan.where((p) => p.id > afterId).take(50).toList();
  }

  Future<PesanChat> kirim({String? isi, double? tawaranHarga}) async {
    if (gagalKirim) throw Exception('jaringan putus');
    final p = PesanChat(id: ++_id, milikSaya: true, isi: isi, tawaranHarga: tawaranHarga);
    pesan.add(p);
    return p;
  }
}

void main() {
  late _Server server;
  late PengelolaPesan pengelola;

  setUp(() {
    server = _Server();
    pengelola = PengelolaPesan(ambil: server.ambil, kirimKeServer: server.kirim);
  });

  List<int> idTampil() => pengelola.pesan.map((p) => p.pesan.id).toList();

  test('muat awal lalu polling memakai after_id yang terus bertambah', () async {
    server..masuk()..masuk();
    await pengelola.muatAwal();
    expect(idTampil(), [1, 2]);
    expect(pengelola.afterId, 2);

    server.masuk();
    expect(await pengelola.ambilBaru(), 1);
    expect(pengelola.afterId, 3);

    // Tidak ada pesan baru: after_id tetap
    expect(await pengelola.ambilBaru(), 0);
    expect(pengelola.afterId, 3);

    server..masuk()..masuk();
    await pengelola.ambilBaru();
    expect(pengelola.afterId, 5);
    expect(server.permintaanAfterId, [null, 2, 3, 3]);
    expect(idTampil(), [1, 2, 3, 4, 5]);
  });

  test('pesan tidak terduplikasi walau server mengirim ulang pesan lama', () async {
    server.masuk();
    await pengelola.muatAwal();

    // Server mengembalikan pesan yang sudah dimiliki + satu baru
    final pengelolaBandel = PengelolaPesan(
      ambil: (afterId) async => [_p(1), _p(2), _p(2)],
      kirimKeServer: server.kirim,
    );
    await pengelolaBandel.muatAwal();
    await pengelolaBandel.ambilBaru();
    expect(pengelolaBandel.pesan.map((p) => p.pesan.id).toList(), [1, 2]);
  });

  test('kiriman sendiri yang ikut terbawa polling tidak dobel', () async {
    await pengelola.muatAwal();
    await pengelola.kirim(isi: 'halo');
    expect(idTampil(), [1]);

    // Polling berikutnya tidak membawa pesan lagi (after_id = 1)
    await pengelola.ambilBaru();
    expect(server.permintaanAfterId.last, 1);
    expect(idTampil(), [1]);
    expect(pengelola.pesan.single.status, StatusKirim.terkirim);
  });

  test('kirim optimistis: langsung tampil, gagal, lalu kirim ulang', () async {
    await pengelola.muatAwal();
    server.gagalKirim = true;

    final proses = pengelola.kirim(tawaranHarga: 140000);
    expect(pengelola.pesan.single.status, StatusKirim.mengirim);
    expect(pengelola.pesan.single.pesan.tawaranHarga, 140000);
    await proses;
    expect(pengelola.pesan.single.status, StatusKirim.gagal);

    server.gagalKirim = false;
    await pengelola.kirimUlang(pengelola.pesan.single.kunci);
    expect(pengelola.pesan.single.status, StatusKirim.terkirim);
    expect(pengelola.pesan.single.pesan.id, 1);
    expect(pengelola.afterId, 1);
  });

  test('pesan baru dari lawan muncul di atas kiriman yang masih gagal', () async {
    await pengelola.muatAwal();
    server.gagalKirim = true;
    await pengelola.kirim(isi: 'gagal');
    server.masuk(isi: 'dari lawan');
    await pengelola.ambilBaru();

    expect(pengelola.pesan.map((p) => p.pesan.isi).toList(), ['dari lawan', 'gagal']);
    pengelola.hapusGagal(pengelola.pesan.last.kunci);
    expect(pengelola.pesan.length, 1);
  });

  test('ambilBaru tidak berjalan ganda bila dipanggil bersamaan', () async {
    await pengelola.muatAwal();
    server.masuk();
    final hasil = await Future.wait([pengelola.ambilBaru(), pengelola.ambilBaru()]);
    expect(hasil.reduce((a, b) => a + b), 1);
    expect(server.permintaanAfterId.length, 2); // muatAwal + satu polling
  });
}
