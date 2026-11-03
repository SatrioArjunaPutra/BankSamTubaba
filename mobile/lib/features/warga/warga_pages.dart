import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart' show MapController;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api/api_exception.dart';
import '../../core/daftar_berhalaman.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/models/bank_sampah.dart';
import '../../core/models/transaksi.dart';
import '../../core/peta.dart';
import '../../core/wilayah_tubaba.dart';
import '../../core/repositories.dart';
import '../../core/widgets.dart';
import 'warga_providers.dart';

/// Cari bank sampah: daftar (cari nama) atau peta; tombol "Terdekat" memakai GPS.
class CariBankPage extends ConsumerStatefulWidget {
  const CariBankPage({super.key});

  @override
  ConsumerState<CariBankPage> createState() => _CariBankPageState();
}

class _CariBankPageState extends ConsumerState<CariBankPage> {
  final _daftarKey = GlobalKey<DaftarBerhalamanState<BankSampah>>();
  String _q = '';
  bool _modePeta = false;
  List<BankSampah>? _terdekat;
  LatLng? _posisi;
  bool _mencari = false;

  Future<void> _cariTerdekat() async {
    setState(() => _mencari = true);
    final hasil = await lokasiSaatIni();
    if (!mounted) return;
    final posisi = hasil.titik;
    if (posisi == null) {
      setState(() => _mencari = false);
      final pengaturan = hasil.masalah!.bukaPengaturan;
      tampilPesan(
        context,
        hasil.masalah!.pesan,
        gagal: true,
        aksi: pengaturan == null
            ? null
            : SnackBarAction(
                label: 'Pengaturan',
                textColor: Colors.white,
                onPressed: pengaturan,
              ),
      );
      return;
    }
    try {
      final hasil = await ref
          .read(umumRepositoryProvider)
          .bankTerdekat(posisi.latitude, posisi.longitude);
      setState(() {
        _posisi = posisi;
        _terdekat = hasil;
      });
    } on ApiException catch (e) {
      if (mounted) tampilPesan(context, e.pesan, gagal: true);
    } finally {
      if (mounted) setState(() => _mencari = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cari bank sampah'),
        actions: [
          IconButton(
            tooltip: _modePeta ? 'Tampilkan daftar' : 'Tampilkan peta',
            icon: Icon(_modePeta ? Icons.list : Icons.map_outlined),
            onPressed: () => setState(() => _modePeta = !_modePeta),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Nama / tiyuh',
                      prefixIcon: Icon(Icons.search),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (v) {
                      setState(() {
                        _q = v.trim();
                        _terdekat = null;
                      });
                      _daftarKey.currentState?.segarkan();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _mencari ? null : _cariTerdekat,
                  icon: _mencari
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: Text(_mencari ? 'Mencari…' : 'Terdekat'),
                ),
              ],
            ),
          ),
          if (_terdekat != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_terdekat!.length} bank sampah dalam 20 km dari lokasi Anda',
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _terdekat = null),
                    child: const Text('Semua'),
                  ),
                ],
              ),
            ),
          Expanded(child: _modePeta ? _peta() : _daftar()),
        ],
      ),
    );
  }

  Widget _daftar() {
    if (_terdekat != null) {
      return _terdekat!.isEmpty
          ? const Kosong(pesan: 'Tidak ada bank sampah dalam 20 km.')
          : ListView.separated(
              padding: paddingAman(context, dasar: const EdgeInsets.all(12)),
              itemCount: _terdekat!.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _KartuBank(bank: _terdekat![i]),
            );
    }
    return DaftarBerhalaman<BankSampah>(
      key: _daftarKey,
      muat: (hal) => ref
          .read(umumRepositoryProvider)
          .daftarBankSampah(q: _q, halaman: hal),
      kosong: 'Bank sampah tidak ditemukan.',
      itemBuilder: (_, b, _) => _KartuBank(bank: b),
    );
  }

  Widget _peta() {
    // Peta menampilkan hasil terdekat, atau semua bank sampah aktif
    final daftar =
        _terdekat ?? ref.watch(pilihanBankProvider).value ?? const [];
    final lokasi = [
      for (final b in daftar.where((b) => b.lat != null && b.lng != null))
        LatLng(b.lat!, b.lng!),
    ];
    return PetaOsm(
      // Kamera awal hanya dibaca sekali: buat ulang saat posisi atau hasil berubah
      key: ValueKey('${_posisi?.latitude},${_posisi?.longitude},${_terdekat?.length}'),
      pusat: _posisi ?? pusatTubaba,
      zoom: _posisi != null ? 12 : 10,
      kontrolZoom: true,
      // Tanpa posisi, kamera memuat seluruh Tubaba walau ada titik yang keliru jauh
      batas: _posisi != null
          ? [_posisi!, ...lokasi]
          : batasTubaba,
      penanda: [
        if (_posisi != null)
          penandaPin(_posisi!, warna: const Color(0xFF2563EB), ikon: Icons.person),
      ],
      titik: [
        for (final b in daftar.where((b) => b.lat != null && b.lng != null))
          TitikPeta(
            titik: LatLng(b.lat!, b.lng!),
            label: b.nama,
            ikon: Icons.recycling,
            onTap: () => context.push('/warga/bank/${b.id}'),
          ),
      ],
    );
  }
}

class _KartuBank extends StatelessWidget {
  const _KartuBank({required this.bank});

  final BankSampah bank;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.recycling)),
        title: Text(bank.nama),
        subtitle: Text('${bank.tiyuh}, ${bank.kecamatan}'),
        trailing: bank.jarakKm != null
            ? Text(jarakKm(bank.jarakKm!))
            : const Icon(Icons.chevron_right),
        onTap: () => context.push('/warga/bank/${bank.id}'),
      ),
    );
  }
}

class DetailBankPage extends ConsumerWidget {
  const DetailBankPage({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(detailBankProvider(id));

    return Scaffold(
      appBar: AppBar(title: const Text('Detail bank sampah')),
      body: TampilanAsync(
        nilai: detail,
        onUlang: () => ref.invalidate(detailBankProvider(id)),
        data: (b) => ListView(
          padding: paddingAman(context),
          children: [
            Text(b.nama, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('${b.alamat ?? '${b.tiyuh}, ${b.kecamatan}'}\nKode ${b.kode}'),
            if (b.noHpPublik != null) Text('HP: ${b.noHpPublik}'),
            if (b.lat != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 180,
                  child: PetaOsm(
                    // Tidak bisa digeser, agar halaman tetap mudah digulir
                    interaktif: false,
                    kontrolZoom: true,
                    pusat: LatLng(b.lat!, b.lng!),
                    zoom: 15,
                    penanda: [
                      penandaPin(
                        LatLng(b.lat!, b.lng!),
                        warna: TemaAplikasi.hijau,
                        ikon: Icons.storefront,
                      ),
                    ],
                  ),
                ),
              ),
              if (b.koordinatEstimasi)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Lokasi di peta masih perkiraan.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            Text(
              'Harga sampah per kg',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (b.harga.isEmpty)
              const Text('Harga belum diatur oleh bank sampah ini.'),
            for (final h in b.harga)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(h.nama),
                trailing: Text(rupiah(h.hargaPerKg)),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.push('/warga/jemput/baru?bank=${b.id}'),
              icon: const Icon(Icons.local_shipping),
              label: const Text('Minta jemput ke bank sampah ini'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Form minta jemput: pilih bank, pin lokasi (default GPS), perkiraan kg,
/// catatan, foto opsional. Kembali dengan `true` jika berhasil diajukan.
class MintaJemputPage extends ConsumerStatefulWidget {
  const MintaJemputPage({
    super.key,
    this.bankSampahId,
    this.catatanAwal,
    this.perkiraanKgAwal,
  });

  final int? bankSampahId;
  final String? catatanAwal;
  final String? perkiraanKgAwal;

  @override
  ConsumerState<MintaJemputPage> createState() => _MintaJemputPageState();
}

class _MintaJemputPageState extends ConsumerState<MintaJemputPage> {
  final _form = GlobalKey<FormState>();
  final _alamat = TextEditingController();
  final _kg = TextEditingController();
  final _catatan = TextEditingController();
  int? _bankId;
  LatLng? _titik;
  XFile? _foto;
  bool _mencariLokasi = true;
  MasalahLokasi? _masalahLokasi;
  final _peta = MapController();
  bool _mengirim = false;
  Map<String, String> _galat = {};

  @override
  void initState() {
    super.initState();
    _bankId = widget.bankSampahId;
    _catatan.text = widget.catatanAwal ?? '';
    _kg.text = widget.perkiraanKgAwal ?? '';
    _alamat.text = '';
    _ambilLokasi();
  }

  @override
  void dispose() {
    _alamat.dispose();
    _kg.dispose();
    _catatan.dispose();
    super.dispose();
  }

  Future<void> _ambilLokasi() async {
    setState(() {
      _mencariLokasi = true;
      _masalahLokasi = null;
    });
    final hasil = await lokasiSaatIni();
    if (!mounted) return;
    setState(() {
      _titik = hasil.titik ?? _titik;
      _masalahLokasi = hasil.masalah;
      _mencariLokasi = false;
    });
    // Pin baru bisa berada di luar tampilan peta: pindahkan kamera ke sana
    if (hasil.titik != null) _peta.move(hasil.titik!, 16);
  }

  Future<void> _perbesarPeta() async {
    final titik = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            PilihLokasiPage(awal: _titik, judul: 'Lokasi penjemputan'),
      ),
    );
    if (titik == null || !mounted) return;
    setState(() {
      _titik = titik;
      _masalahLokasi = null;
    });
    _peta.move(titik, 16);
  }

  Future<void> _pilihFoto(ImageSource sumber) async {
    final foto = await ImagePicker().pickImage(
      source: sumber,
      maxWidth: 1600,
      imageQuality: 75,
    );
    if (foto != null) setState(() => _foto = foto);
  }

  Future<void> _kirim() async {
    if (!_form.currentState!.validate()) return;
    if (_titik == null) {
      tampilPesan(context, 'Tandai lokasi penjemputan di peta.', gagal: true);
      return;
    }
    setState(() {
      _mengirim = true;
      _galat = {};
    });
    try {
      await ref
          .read(wargaRepositoryProvider)
          .ajukanJemput(
            bankSampahId: _bankId!,
            alamat: _alamat.text.trim(),
            lat: _titik!.latitude,
            lng: _titik!.longitude,
            perkiraanKg: double.tryParse(_kg.text.replaceAll(',', '.')),
            catatan: _catatan.text.trim(),
            pathFoto: _foto?.path,
          );
      if (!mounted) return;
      tampilPesan(context, 'Permintaan jemput berhasil diajukan.');
      context.pop(true);
    } on ApiException catch (e) {
      setState(() => _galat = e.errors);
      if (mounted) tampilPesan(context, e.pesan, gagal: true);
    } finally {
      if (mounted) setState(() => _mengirim = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bank = ref.watch(pilihanBankProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Minta jemput')),
      body: Form(
        key: _form,
        child: ListView(
          padding: paddingAman(context),
          children: [
            TampilanAsync(
              nilai: bank,
              onUlang: () => ref.invalidate(pilihanBankProvider),
              data: (daftar) => DropdownButtonFormField<int>(
                initialValue: daftar.any((b) => b.id == _bankId)
                    ? _bankId
                    : null,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Bank sampah tujuan',
                  errorText: _galat['bank_sampah_id'],
                ),
                items: [
                  for (final b in daftar)
                    DropdownMenuItem(
                      value: b.id,
                      child: Text(b.nama, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _bankId = v),
                validator: (v) => v == null ? 'Pilih bank sampah.' : null,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Lokasi penjemputan',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Pakai lokasi saya',
                  onPressed: _mencariLokasi ? null : _ambilLokasi,
                  icon: const Icon(Icons.my_location),
                ),
              ],
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 200,
                child: Stack(
                  children: [
                    // Tidak bisa digeser (agar halaman tetap mudah digulir); ketuk untuk memindah pin
                    PetaOsm(
                      controller: _peta,
                      interaktif: false,
                      pusat: _titik ?? pusatTubaba,
                      zoom: _titik != null ? 16 : 10,
                      penanda: [if (_titik != null) penandaPin(_titik!)],
                      onTap: (t) => setState(() => _titik = t),
                    ),
                    if (_mencariLokasi)
                      const Positioned(
                        top: 8,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          child: Center(child: LabelMencariLokasi()),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Ketuk peta untuk memindahkan pin.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                TextButton.icon(
                  onPressed: _perbesarPeta,
                  icon: const Icon(Icons.open_in_full, size: 18),
                  label: const Text('Perbesar peta'),
                ),
              ],
            ),
            PesanMasalahLokasi(
              masalah: _masalahLokasi,
              onCobaLagi: _ambilLokasi,
              catatan: 'Anda juga bisa menandai lokasi langsung di peta.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _alamat,
              decoration: InputDecoration(
                labelText: 'Alamat / patokan',
                errorText: _galat['alamat'],
              ),
              maxLines: 2,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Alamat wajib diisi.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _kg,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: 'Perkiraan berat (kg, opsional)',
                errorText: _galat['perkiraan_kg'],
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _catatan,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            if (_foto != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.image),
                title: Text(_foto!.name, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _foto = null),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pilihFoto(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera),
                      label: const Text('Foto'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pilihFoto(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Galeri'),
                    ),
                  ),
                ],
              ),
            if (_galat['foto'] != null)
              Text(
                _galat['foto']!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _mengirim ? null : _kirim,
              child: Text(_mengirim ? 'Mengirim...' : 'Ajukan penjemputan'),
            ),
          ],
        ),
      ),
    );
  }
}

class PenarikanPage extends ConsumerStatefulWidget {
  const PenarikanPage({super.key});

  @override
  ConsumerState<PenarikanPage> createState() => _PenarikanPageState();
}

class _PenarikanPageState extends ConsumerState<PenarikanPage> {
  final _riwayat = GlobalKey<DaftarBerhalamanState<Penarikan>>();
  final _jumlah = TextEditingController();
  int? _bankId;
  bool _mengirim = false;

  @override
  void dispose() {
    _jumlah.dispose();
    super.dispose();
  }

  Future<void> _ajukan(List<Saldo> daftar) async {
    final saldo = daftar.where((s) => s.bankSampahId == _bankId).firstOrNull;
    final jumlah = double.tryParse(
      _jumlah.text.replaceAll('.', '').replaceAll(',', '.'),
    );
    if (saldo == null || jumlah == null || jumlah <= 0) {
      tampilPesan(
        context,
        'Pilih bank sampah dan isi jumlah penarikan.',
        gagal: true,
      );
      return;
    }
    if (jumlah > saldo.saldo) {
      tampilPesan(
        context,
        'Jumlah melebihi saldo Anda di bank ini (${rupiah(saldo.saldo)}).',
        gagal: true,
      );
      return;
    }
    setState(() => _mengirim = true);
    final ok = await jalankan(
      context,
      () => ref
          .read(wargaRepositoryProvider)
          .ajukanPenarikan(_bankId!, jumlah, null),
      sukses:
          'Penarikan diajukan. Ambil uang di bank sampah setelah disetujui.',
    );
    if (!mounted) return;
    setState(() => _mengirim = false);
    if (ok) {
      _jumlah.clear();
      _riwayat.currentState?.segarkan();
    }
  }

  @override
  Widget build(BuildContext context) {
    final saldo = ref.watch(saldoProvider);
    final selected = saldo.value?.daftar
        .where((s) => s.bankSampahId == _bankId)
        .firstOrNull;
    final nominal =
        double.tryParse(
          _jumlah.text.replaceAll('.', '').replaceAll(',', '.'),
        ) ??
        0;
    return Scaffold(
      appBar: AppBar(title: const Text('Tarik saldo')),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: TemaAplikasi.garis)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sisa saldo setelah tarik',
                      style: TextStyle(fontSize: 11, color: TemaAplikasi.redup),
                    ),
                    Text(
                      rupiah(
                        ((selected?.saldo ?? 0) - nominal).clamp(
                          0,
                          double.infinity,
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _mengirim || saldo.value?.daftar.isNotEmpty != true
                    ? null
                    : () => _ajukan(saldo.value!.daftar),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 50),
                  backgroundColor: TemaAplikasi.hijauPekat,
                ),
                child: Text(_mengirim ? 'Mengirim...' : 'Ajukan'),
              ),
            ],
          ),
        ),
      ),
      body: DaftarBerhalaman<Penarikan>(
        key: _riwayat,
        muat: (hal) =>
            ref.read(wargaRepositoryProvider).penarikan(halaman: hal),
        kosong: 'Belum ada riwayat penarikan.',
        padding: const EdgeInsets.all(20),
        header: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TampilanAsync(
            nilai: saldo,
            onUlang: () => ref.invalidate(saldoProvider),
            data: (s) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dari bank sampah',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                if (s.daftar.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        'Anda belum punya saldo di bank sampah mana pun.',
                        style: TextStyle(
                          fontSize: 12,
                          color: TemaAplikasi.redup,
                        ),
                      ),
                    ),
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        for (final b in s.daftar)
                          InkWell(
                            onTap: () =>
                                setState(() => _bankId = b.bankSampahId),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _bankId == b.bankSampahId
                                    ? TemaAplikasi.hijauLembut
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _bankId == b.bankSampahId
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    color: _bankId == b.bankSampahId
                                        ? TemaAplikasi.hijau
                                        : TemaAplikasi.redup,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      b.bankSampah?.nama ?? 'Bank sampah',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    rupiah(b.saldo),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                const Text(
                  'Jumlah penarikan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _jumlah,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: const InputDecoration(
                    prefixText: 'Rp ',
                    hintText: '0',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final n in [25000, 50000, 100000])
                      ChoiceChip(
                        label: Text(
                          rupiah(n),
                          style: const TextStyle(fontSize: 11),
                        ),
                        selected: nominal == n,
                        onSelected: (_) =>
                            setState(() => _jumlah.text = n.toString()),
                      ),
                    ActionChip(
                      label: const Text(
                        'Semua',
                        style: TextStyle(fontSize: 11),
                      ),
                      onPressed: selected == null
                          ? null
                          : () => setState(
                              () => _jumlah.text = selected.saldo
                                  .toStringAsFixed(0),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Cara terima',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                const Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.payments_outlined,
                      color: TemaAplikasi.hijau,
                    ),
                    title: Text(
                      'Tunai di bank sampah',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      'Ambil setelah disetujui pengelola.',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: Icon(
                      Icons.check_circle,
                      color: TemaAplikasi.hijau,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: TemaAplikasi.hijauLembut,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'Pengelola bank sampah akan mengonfirmasi penarikan. Saldo dipotong saat permintaan disetujui, bukan saat diajukan.',
                    style: TextStyle(fontSize: 12, height: 1.5),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Riwayat penarikan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
        itemBuilder: (_, p, _) => Card(
          child: ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: Text(
              rupiah(p.jumlah),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${p.bankSampah?.nama ?? '-'}\n${tanggalJam(p.createdAt)}',
              style: const TextStyle(fontSize: 12),
            ),
            isThreeLine: true,
            trailing: LabelStatus(
              labelStatusPenarikan[p.status] ?? p.status,
              warna: warnaStatus(p.status),
            ),
          ),
        ),
      ),
    );
  }
}
