import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/config.dart';

/// Rincian tetap untuk pengiriman ulang, termasuk setelah aplikasi ditutup.
class PermintaanSetoran {
  PermintaanSetoran({
    required this.requestId,
    required this.operatorId,
    required this.bankId,
    required this.wargaId,
    required this.namaWarga,
    required this.tipe,
    required List<(int, double)> items,
    this.penjemputanId,
  }) : items = List.unmodifiable(items);

  final String requestId;
  final int operatorId;
  final int bankId;
  final int wargaId;
  final String namaWarga;
  final String tipe;
  final List<(int, double)> items;
  final int? penjemputanId;

  static String idBaru() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final h = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Map<String, dynamic> toJson() => {
    'request_id': requestId,
    'operator_id': operatorId,
    'bank_id': bankId,
    'warga_id': wargaId,
    'nama_warga': namaWarga,
    'tipe': tipe,
    'items': [
      for (final (id, kg) in items) {'jenis_sampah_id': id, 'berat_kg': kg},
    ],
    'penjemputan_id': penjemputanId,
  };

  factory PermintaanSetoran.dariJson(Map<String, dynamic> json) =>
      PermintaanSetoran(
        requestId: json['request_id'] as String,
        operatorId: json['operator_id'] as int,
        bankId: json['bank_id'] as int,
        wargaId: json['warga_id'] as int,
        namaWarga: json['nama_warga'] as String,
        tipe: json['tipe'] as String,
        items: [
          for (final i in json['items'] as List)
            (i['jenis_sampah_id'] as int, (i['berat_kg'] as num).toDouble()),
        ],
        penjemputanId: json['penjemputan_id'] as int?,
      );
}

abstract class PenyimpananSetoran {
  Future<PermintaanSetoran?> baca(int operatorId, int bankId);
  Future<void> simpan(PermintaanSetoran data);
  Future<void> hapus(int operatorId, int bankId);
}

class PenyimpananSetoranAman implements PenyimpananSetoran {
  PenyimpananSetoranAman(this.lingkungan);
  final String lingkungan;
  final _storage = const FlutterSecureStorage();
  String _key(int operatorId, int bankId) =>
      'setoran_pending_${base64Url.encode(utf8.encode(lingkungan))}_${operatorId}_$bankId';

  @override
  Future<PermintaanSetoran?> baca(int operatorId, int bankId) async {
    final teks = await _storage.read(key: _key(operatorId, bankId));
    if (teks == null) return null;
    final data = PermintaanSetoran.dariJson(
      (jsonDecode(teks) as Map).cast<String, dynamic>(),
    );
    if (data.operatorId != operatorId || data.bankId != bankId) {
      throw StateError('Identitas setoran tertunda tidak cocok.');
    }
    return data;
  }

  @override
  Future<void> simpan(PermintaanSetoran data) => _storage.write(
    key: _key(data.operatorId, data.bankId),
    value: jsonEncode(data.toJson()),
  );

  @override
  Future<void> hapus(int operatorId, int bankId) =>
      _storage.delete(key: _key(operatorId, bankId));
}

class PenyimpananSetoranMemori implements PenyimpananSetoran {
  final _data = <(int, int), PermintaanSetoran>{};
  @override
  Future<PermintaanSetoran?> baca(int operatorId, int bankId) async =>
      _data[(operatorId, bankId)];
  @override
  Future<void> simpan(PermintaanSetoran data) async {
    _data[(data.operatorId, data.bankId)] = data;
  }

  @override
  Future<void> hapus(int operatorId, int bankId) async {
    _data.remove((operatorId, bankId));
  }
}

final penyimpananSetoranProvider = Provider<PenyimpananSetoran>(
  (ref) => Config.useMock
      ? PenyimpananSetoranMemori()
      : PenyimpananSetoranAman(Config.apiUrl),
);
