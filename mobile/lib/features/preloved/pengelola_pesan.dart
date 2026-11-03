import 'package:flutter/foundation.dart';

import '../../core/models/preloved.dart';

enum StatusKirim { terkirim, mengirim, gagal }

/// Pesan yang tampil di layar: dari server, atau kiriman lokal (optimistic)
/// yang belum/tidak sampai.
class PesanTampil {
  const PesanTampil({required this.kunci, required this.pesan, this.status = StatusKirim.terkirim});

  /// `s{id}` untuk pesan server, `l{n}` untuk kiriman lokal.
  final String kunci;
  final PesanChat pesan;
  final StatusKirim status;
}

typedef AmbilPesan = Future<List<PesanChat>> Function(int? afterId);
typedef KirimPesan = Future<PesanChat> Function({String? isi, double? tawaranHarga});

/// Logika ruang chat tanpa UI (diuji di test/polling_chat_test.dart):
/// - muatAwal(): 50 pesan terakhir, afterId = id terbesar;
/// - ambilBaru(): GET ?after_id= ; afterId hanya bertambah; pesan yang sudah
///   ada (mis. dari kiriman sendiri) tidak digandakan;
/// - kirim(): pesan langsung tampil "mengirim", lalu jadi terkirim atau gagal;
///   kirimUlang() untuk yang gagal.
class PengelolaPesan extends ChangeNotifier {
  PengelolaPesan({required this.ambil, required this.kirimKeServer});

  final AmbilPesan ambil;
  final KirimPesan kirimKeServer;

  final _server = <int, PesanChat>{};
  final _lokal = <String, ({PesanChat pesan, StatusKirim status})>{};
  int _nomorLokal = 0;
  int? _afterId;
  bool _sedangAmbil = false;

  int? get afterId => _afterId;

  /// Urut naik berdasarkan id server; kiriman lokal di paling bawah.
  List<PesanTampil> get pesan {
    final dariServer = _server.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    return [
      for (final p in dariServer) PesanTampil(kunci: 's${p.id}', pesan: p),
      for (final e in _lokal.entries) PesanTampil(kunci: e.key, pesan: e.value.pesan, status: e.value.status),
    ];
  }

  Future<void> muatAwal() async {
    _gabung(await ambil(null));
  }

  /// Dipanggil timer polling. Satu permintaan pada satu waktu.
  /// Mengembalikan jumlah pesan baru.
  Future<int> ambilBaru() async {
    if (_sedangAmbil) return 0;
    _sedangAmbil = true;
    try {
      return _gabung(await ambil(_afterId));
    } finally {
      _sedangAmbil = false;
    }
  }

  Future<void> kirim({String? isi, double? tawaranHarga}) {
    final kunci = 'l${_nomorLokal++}';
    final draf = PesanChat(id: -1, milikSaya: true, isi: isi, tawaranHarga: tawaranHarga, createdAt: DateTime.now());
    _lokal[kunci] = (pesan: draf, status: StatusKirim.mengirim);
    notifyListeners();
    return _kirimLokal(kunci);
  }

  Future<void> kirimUlang(String kunci) {
    final draf = _lokal[kunci];
    if (draf == null || draf.status != StatusKirim.gagal) return Future.value();
    _lokal[kunci] = (pesan: draf.pesan, status: StatusKirim.mengirim);
    notifyListeners();
    return _kirimLokal(kunci);
  }

  void hapusGagal(String kunci) {
    if (_lokal.remove(kunci) != null) notifyListeners();
  }

  Future<void> _kirimLokal(String kunci) async {
    final draf = _lokal[kunci]!.pesan;
    try {
      final hasil = await kirimKeServer(isi: draf.isi, tawaranHarga: draf.tawaranHarga);
      _lokal.remove(kunci);
      _gabung([hasil]);
      notifyListeners();
    } catch (_) {
      _lokal[kunci] = (pesan: draf, status: StatusKirim.gagal);
      notifyListeners();
    }
  }

  int _gabung(List<PesanChat> masuk) {
    var baru = 0;
    for (final p in masuk) {
      if (_server.containsKey(p.id)) continue;
      _server[p.id] = p;
      baru++;
      if (_afterId == null || p.id > _afterId!) _afterId = p.id;
    }
    if (baru > 0) notifyListeners();
    return baru;
  }
}
