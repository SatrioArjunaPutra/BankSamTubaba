// Uji kontrak: repository aplikasi melawan backend Laravel sungguhan (data
// DEMO dari DemoSeeder). Dilewati kecuali URL diberikan:
//
//   flutter test test/kontrak_api_test.dart \
//     --dart-define=KONTRAK_API_URL=http://127.0.0.1:8000/api/v1 \
//     --dart-define=KONTRAK_PASSWORD=<SEED_DEMO_PASSWORD>
//
// JANGAN arahkan ke produksi: test ini membuat setoran, penjemputan, penarikan.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:bank_sampah_tubaba/core/api/api_client.dart';
import 'package:bank_sampah_tubaba/core/api/api_exception.dart';
import 'package:bank_sampah_tubaba/core/repositories.dart';
import 'package:bank_sampah_tubaba/features/berita/berita_repository.dart';
import 'package:bank_sampah_tubaba/features/preloved/preloved_repository.dart';
import 'package:bank_sampah_tubaba/core/storage/token_storage.dart';
import 'package:bank_sampah_tubaba/features/bank_sampah/permintaan_setoran.dart';
import 'package:flutter_test/flutter_test.dart';

const _url = String.fromEnvironment('KONTRAK_API_URL');
const _password = String.fromEnvironment('KONTRAK_PASSWORD');

Future<ApiClient> _masuk(String email) async {
  final api = ApiClient(baseUrl: _url, tokenStorage: MemoryTokenStorage());
  final body = await api.post(
    '/auth/login',
    data: {'email': email, 'password': _password},
  );
  await api.tokenStorage.simpan('${body['data']['token']}');
  return api;
}

void main() {
  test(
    'alur warga → operator → bentor → setoran → penarikan',
    () async {
      final warga = await _masuk('warga1@banksampah.test');
      final operator = await _masuk('operator1@banksampah.test');
      final wargaRepo = WargaRepository(warga);
      final umum = UmumRepository(warga);
      final bs = BankSampahRepository(operator);

      // Umum
      final daftarBank = await umum.daftarBankSampah(q: 'demo');
      expect(daftarBank.items, isNotEmpty);
      final bank = daftarBank.items.firstWhere((b) => b.kode == 'BS-DEMO-01');
      final detail = await umum.detailBankSampah(bank.id);
      expect(detail.harga, isNotEmpty);
      expect(detail.harga.first.hargaPerKg, greaterThan(0));
      expect(await umum.bankTerdekat(bank.lat!, bank.lng!), isNotEmpty);
      expect((await umum.jenisSampah()).length, greaterThanOrEqualTo(6));

      // Warga minta jemput
      final saldoAwal =
          (await wargaRepo.saldo()).daftar
              .where((s) => s.bankSampahId == bank.id)
              .firstOrNull
              ?.saldo ??
          0;
      final jemput = await wargaRepo.ajukanJemput(
        bankSampahId: bank.id,
        alamat: 'Uji kontrak',
        lat: -4.58,
        lng: 105.13,
        perkiraanKg: 3,
      );
      expect(jemput.status, 'diajukan');

      // Operator: dashboard, harga, jadwalkan ke armada bentor 1A
      final dash = await bs.dashboard();
      expect(dash.jemputDiajukan, greaterThanOrEqualTo(1));
      final harga = await bs.harga();
      final plastik = harga.firstWhere((h) => h.nama == 'Plastik');
      final (armada, _) = await bs.armada();
      final armada1a = armada.firstWhere((a) => a.driver!.name.endsWith('1A'));
      final dijadwalkan = await bs.jadwalkan(
        jemput.id,
        armada1a.id,
        DateTime.now().add(const Duration(hours: 1)),
      );
      expect(dijadwalkan.status, 'dijadwalkan');
      expect(dijadwalkan.platNomor, armada1a.platNomor);

      // Bentor
      final bentor = BentorRepository(await _masuk('bentor1a@banksampah.test'));
      final tugas = await bentor.tugas();
      expect(tugas.items.map((t) => t.id), contains(jemput.id));
      expect(
        (await bentor.ubahStatusTugas(jemput.id, 'menuju')).status,
        'menuju',
      );
      expect((await bentor.armada()).status, 'bertugas');
      expect(
        (await bentor.ubahStatusTugas(jemput.id, 'diambil')).status,
        'diambil',
      );

      // Operator catat setoran hasil jemput
      // Warga yang belum jadi nasabah hanya bisa dicari dengan email/HP persis
      final hasilCari = await bs.cariNasabah('warga1@banksampah.test');
      final wargaId = hasilCari.items.single.id;
      final requestId = PermintaanSetoran.idBaru();
      final (setoran, saldoBaru) = await bs.catatSetoran(
        wargaId: wargaId,
        tipe: 'jual',
        items: [(plastik.jenisSampahId, 2.5)],
        penjemputanId: jemput.id,
        requestId: requestId,
      );
      expect(setoran.totalKg, 2.5);
      expect(setoran.totalNilai, 2.5 * plastik.hargaPerKg!);
      expect(saldoBaru, saldoAwal + setoran.totalNilai);
      final (ulang, saldoUlang) = await bs.catatSetoran(
        wargaId: wargaId,
        tipe: 'jual',
        items: [(plastik.jenisSampahId, 2.5)],
        penjemputanId: jemput.id,
        requestId: requestId,
      );
      expect(ulang.id, setoran.id);
      expect(saldoUlang, saldoBaru);
      expect((await bentor.armada()).status, 'siaga');

      // Warga ajukan penarikan, operator setujui
      final tarik = await wargaRepo.ajukanPenarikan(bank.id, 1000, null);
      expect(tarik.status, 'diajukan');
      final menunggu = await bs.penarikan('diajukan');
      expect(menunggu.items.map((p) => p.id), contains(tarik.id));
      expect(
        (await bs.prosesPenarikan(tarik.id, true, null)).status,
        'disetujui',
      );
      final saldoAkhir = (await wargaRepo.saldo()).daftar
          .firstWhere((s) => s.bankSampahId == bank.id)
          .saldo;
      expect(saldoAkhir, saldoBaru - 1000);

      // Riwayat & lain-lain bisa di-parse
      expect((await wargaRepo.setoran()).items.first.items, isNotEmpty);
      expect((await wargaRepo.penjemputan()).items, isNotEmpty);
      expect((await bs.setoran()).items, isNotEmpty);
      await bs.catatPenjualanPengepul({
        'nama_pengepul': 'Uji',
        'jenis_sampah_id': plastik.jenisSampahId,
        'berat_kg': 10,
        'harga_per_kg': 3500,
      });
      expect((await bs.penjualanPengepul()).items.first.total, 35000);
    },
    skip: _url.isEmpty
        ? 'Set --dart-define=KONTRAK_API_URL untuk menjalankan'
        : null,
  );

  test(
    'operator menonaktifkan akun bentor: token langsung tidak berlaku, lalu diaktifkan lagi',
    () async {
      final bs = BankSampahRepository(
        await _masuk('operator1@banksampah.test'),
      );
      final bentor = BentorRepository(await _masuk('bentor1b@banksampah.test'));
      expect((await bentor.armada()).platNomor, isNotEmpty);

      final (armada, _) = await bs.armada();
      final milik1b = armada.firstWhere((a) => a.driver!.name.endsWith('1B'));
      await bs.ubahStatusAkunBentor(milik1b.driver!.id, false);

      await expectLater(
        bentor.tugas(),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
      );
      await expectLater(
        _masuk('bentor1b@banksampah.test'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
      );
      final (setelah, _) = await bs.armada();
      final nonaktif = setelah.firstWhere((a) => a.id == milik1b.id);
      expect(nonaktif.driverAktif, isFalse);
      expect(nonaktif.status, 'nonaktif');

      // Pulihkan agar data demo tetap utuh
      await bs.ubahStatusAkunBentor(milik1b.driver!.id, true);
      await bs.ubahArmada(milik1b.id, {'status': 'siaga'});
      expect(
        (await BentorRepository(
          await _masuk('bentor1b@banksampah.test'),
        ).armada()).status,
        'siaga',
      );
    },
    skip: _url.isEmpty
        ? 'Set --dart-define=KONTRAK_API_URL untuk menjalankan'
        : null,
  );

  test(
    'preloved & chat: pasang dengan foto, chat, tawar, polling, terjual, hapus',
    () async {
      final penjual = PrelovedRepository(
        await _masuk('warga1@banksampah.test'),
      );
      final pembeli = PrelovedRepository(
        await _masuk('warga2@banksampah.test'),
      );
      final orangLain = PrelovedRepository(
        await _masuk('warga3@banksampah.test'),
      );

      // PNG 1x1 asli agar lolos validasi mimes di server
      final dir = await Directory.systemTemp.createTemp('kontrak');
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
      );
      final foto = [
        for (var i = 0; i < 2; i++)
          (await File('${dir.path}/f$i.png').writeAsBytes(png)).path,
      ];

      final barang = await penjual.pasang({
        'judul': 'Uji kontrak kursi',
        'deskripsi': 'Barang uji otomatis',
        'kategori': 'Perabot',
        'kondisi': 'bekas_baik',
        'harga': 150000,
        'kecamatan': 'Tumijajar',
      }, foto);
      expect(barang.foto, hasLength(2));
      expect(barang.milikSaya, isTrue);
      expect(
        (await pembeli.daftar(q: 'Uji kontrak kursi')).items.map((b) => b.id),
        contains(barang.id),
      );

      // Penjual tidak bisa chat barang sendiri
      await expectLater(
        penjual.bukaChat(barang.id),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 422)),
      );

      final chat = await pembeli.bukaChat(barang.id);
      expect(chat.peranSaya, 'pembeli');
      expect((await pembeli.bukaChat(barang.id)).id, chat.id); // idempoten

      final p1 = await pembeli.kirim(chat.id, isi: 'Masih ada?');
      final p2 = await pembeli.kirim(chat.id, tawaranHarga: 120000);
      expect(p2.tawaranHarga, 120000);

      // Penjual: polling after_id hanya pesan baru
      final semua = await penjual.pesan(chat.id);
      expect(semua.map((p) => p.id), [p1.id, p2.id]);
      expect(semua.first.milikSaya, isFalse);
      final daftarPenjual = await penjual.daftarChat();
      final diPenjual = daftarPenjual.items.firstWhere((c) => c.id == chat.id);
      expect(diPenjual.peranSaya, 'penjual');
      expect(diPenjual.unreadCount, 2);
      expect(diPenjual.pesanTerakhir!.tawaranHarga, 120000);
      await penjual.tandaiDibaca(chat.id);
      expect(
        (await penjual.daftarChat()).items
            .firstWhere((c) => c.id == chat.id)
            .unreadCount,
        0,
      );

      final balas = await penjual.kirim(
        chat.id,
        isi: 'Boleh, COD di Panaragan',
      );
      final baru = await pembeli.pesan(chat.id, afterId: p2.id);
      expect(baru.map((p) => p.id), [balas.id]);
      expect(await pembeli.pesan(chat.id, afterId: balas.id), isEmpty);

      // Orang ketiga ditolak
      await expectLater(
        orangLain.pesan(chat.id),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
      );

      // Terjual → hilang dari daftar; hapus → foto & chat ikut terhapus
      expect((await penjual.tandaiTerjual(barang.id)).status, 'terjual');
      expect(
        (await pembeli.daftar(q: 'Uji kontrak kursi')).items.map((b) => b.id),
        isNot(contains(barang.id)),
      );
      await penjual.hapus(barang.id);
      await expectLater(
        penjual.detail(barang.id),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
      );

      await dir.delete(recursive: true);
    },
    skip: _url.isEmpty
        ? 'Set --dart-define=KONTRAK_API_URL untuk menjalankan'
        : null,
  );

  test(
    'berita publik: daftar tanpa isi, detail lengkap, dibaca bertambah',
    () async {
      final repo = BeritaRepository(
        ApiClient(baseUrl: _url, tokenStorage: MemoryTokenStorage()),
      );

      final daftar = await repo.daftar();
      expect(daftar.items, isNotEmpty);
      final b = daftar.items.first;
      expect(b.isi, isNull);
      expect(b.diterbitkanAt, isNotNull);
      expect(b.labelKategori, isNot(b.kategori));

      final pertama = await repo.detail(b.id);
      expect(pertama.isi, isNotEmpty);
      expect((await repo.detail(b.id)).dibaca, greaterThan(pertama.dibaca));

      await expectLater(
        repo.detail(99999999),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
      );
    },
    skip: _url.isEmpty
        ? 'Set --dart-define=KONTRAK_API_URL untuk menjalankan'
        : null,
  );
}
