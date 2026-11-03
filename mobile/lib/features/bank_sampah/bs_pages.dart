import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/daftar_berhalaman.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/komponen_ui.dart';
import '../../core/models/operasional.dart';
import '../../core/models/transaksi.dart';
import '../../core/repositories.dart';
import '../../core/widgets.dart';
import 'bs_providers.dart';

final _angkaDesimal = [
  FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}')),
];

double? _baca(String teks) => double.tryParse(teks.trim().replaceAll(',', '.'));

class AturHargaPage extends ConsumerStatefulWidget {
  const AturHargaPage({super.key});

  @override
  ConsumerState<AturHargaPage> createState() => _AturHargaPageState();
}

class _AturHargaPageState extends ConsumerState<AturHargaPage> {
  final _input = <int, TextEditingController>{};
  bool _menyimpan = false;

  @override
  void dispose() {
    for (final c in _input.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _simpan() async {
    final harga = <int, double>{
      for (final e in _input.entries)
        if (_baca(e.value.text) != null) e.key: _baca(e.value.text)!,
    };
    if (harga.isEmpty) {
      tampilPesan(context, 'Isi minimal satu harga.', gagal: true);
      return;
    }
    setState(() => _menyimpan = true);
    final ok = await jalankan(
      context,
      () => ref.read(bankSampahRepositoryProvider).simpanHarga(harga),
      sukses: 'Harga disimpan. Berlaku untuk setoran berikutnya.',
    );
    if (!mounted) return;
    setState(() => _menyimpan = false);
    if (ok) ref.invalidate(hargaBsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final harga = ref.watch(hargaBsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Atur harga')),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: TemaAplikasi.garis)),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: TemaAplikasi.hijau,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Berlaku untuk setoran berikutnya',
                        style: TextStyle(
                          fontSize: 11,
                          color: TemaAplikasi.redup,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _menyimpan || harga.isLoading ? null : _simpan,
                style: FilledButton.styleFrom(
                  backgroundColor: TemaAplikasi.hijauPekat,
                  minimumSize: const Size(0, 48),
                ),
                child: Text(_menyimpan ? 'Menyimpan...' : 'Simpan harga'),
              ),
            ],
          ),
        ),
      ),
      body: TampilanAsync(
        nilai: harga,
        onUlang: () => ref.invalidate(hargaBsProvider),
        data: (daftar) {
          for (final h in daftar) {
            _input.putIfAbsent(
              h.jenisSampahId,
              () => TextEditingController(
                text: h.hargaPerKg == null
                    ? ''
                    : h.hargaPerKg!.toStringAsFixed(
                        h.hargaPerKg! % 1 == 0 ? 0 : 2,
                      ),
              ),
            );
          }
          final grup = <String, List<dynamic>>{};
          for (final h in daftar) {
            final nama = h.nama.toLowerCase();
            final g = nama.contains('plastik')
                ? 'PLASTIK'
                : nama.contains('kertas') || nama.contains('kardus')
                ? 'KERTAS'
                : 'LOGAM & LAINNYA';
            grup.putIfAbsent(g, () => []).add(h);
          }
          return ListView(
            padding: paddingAman(context, dasar: const EdgeInsets.all(20)),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: TemaAplikasi.hijauLembut,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: TemaAplikasi.hijau,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Harga baru berlaku untuk setoran setelah disimpan dan langsung tampil di aplikasi warga. Setoran yang sudah tercatat tidak ikut berubah.',
                        style: TextStyle(fontSize: 12, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              for (final g in grup.entries) ...[
                Text(
                  g.key,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                    color: TemaAplikasi.redup,
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < g.value.length; i++) ...[
                        if (i > 0)
                          const Divider(height: 1, indent: 14, endIndent: 14),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: TemaAplikasi.hijauLembut,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: IlustrasiReferensi(
                                    ilustrasiJenis(g.value[i].nama as String),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      g.value[i].nama as String,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    const Text(
                                      'Harga per kilogram',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: TemaAplikasi.redup,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 125,
                                child: TextField(
                                  controller: _input[g.value[i].jenisSampahId],
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: _angkaDesimal,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Belum diatur',
                                    prefixText: 'Rp ',
                                    suffixText: '/kg',
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 12,
                                    ),
                                    labelText: g.value[i].nama as String,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 22),
              ],
            ],
          );
        },
      ),
    );
  }
}

class PersetujuanPenarikanPage extends ConsumerStatefulWidget {
  const PersetujuanPenarikanPage({super.key});

  @override
  ConsumerState<PersetujuanPenarikanPage> createState() =>
      _PersetujuanPenarikanPageState();
}

class _PersetujuanPenarikanPageState
    extends ConsumerState<PersetujuanPenarikanPage> {
  String _status = 'diajukan';

  Future<void> _proses(Penarikan p, bool setujui, VoidCallback segarkan) async {
    final ok = await konfirmasi(
      context,
      setujui ? 'Setujui penarikan?' : 'Tolak penarikan?',
      setujui
          ? 'Serahkan uang ${rupiah(p.jumlah)} kepada ${p.warga?.name}. Saldo nasabah akan dipotong.'
          : 'Penarikan ${rupiah(p.jumlah)} dari ${p.warga?.name} akan ditolak.',
      ya: setujui ? 'Setujui' : 'Tolak',
    );
    if (!ok || !mounted) return;
    final berhasil = await jalankan(
      context,
      () => ref
          .read(bankSampahRepositoryProvider)
          .prosesPenarikan(p.id, setujui, null),
      sukses: setujui ? 'Penarikan disetujui.' : 'Penarikan ditolak.',
    );
    if (berhasil) segarkan();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Penarikan saldo')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'diajukan', label: Text('Menunggu')),
                ButtonSegment(value: 'disetujui', label: Text('Disetujui')),
                ButtonSegment(value: 'ditolak', label: Text('Ditolak')),
              ],
              selected: {_status},
              onSelectionChanged: (s) => setState(() => _status = s.first),
            ),
          ),
          Expanded(
            child: DaftarBerhalaman<Penarikan>(
              key: ValueKey(_status),
              muat: (hal) => ref
                  .read(bankSampahRepositoryProvider)
                  .penarikan(_status, halaman: hal),
              kosong: 'Tidak ada penarikan.',
              itemBuilder: (_, p, segarkan) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              p.warga?.name ?? '-',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            rupiah(p.jumlah),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${p.warga?.phone ?? ''} · ${tanggalJam(p.createdAt)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (p.status == 'diajukan')
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => _proses(p, false, segarkan),
                              child: const Text('Tolak'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 40),
                              ),
                              onPressed: () => _proses(p, true, segarkan),
                              child: const Text('Setujui'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PenjualanPengepulPage extends ConsumerStatefulWidget {
  const PenjualanPengepulPage({super.key});

  @override
  ConsumerState<PenjualanPengepulPage> createState() =>
      _PenjualanPengepulPageState();
}

class _PenjualanPengepulPageState extends ConsumerState<PenjualanPengepulPage> {
  final _daftar = GlobalKey<DaftarBerhalamanState<PenjualanPengepul>>();

  Future<void> _tambah() async {
    final ok = await tampilkanSheet<bool>(
      context,
      (_) => const _FormPengepul(),
    );
    if (ok == true) _daftar.currentState?.segarkan();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Penjualan ke pengepul')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _tambah,
        icon: const Icon(Icons.add),
        label: const Text('Catat'),
      ),
      body: DaftarBerhalaman<PenjualanPengepul>(
        key: _daftar,
        muat: (hal) => ref
            .read(bankSampahRepositoryProvider)
            .penjualanPengepul(halaman: hal),
        kosong: 'Belum ada penjualan ke pengepul.',
        adaFab: true,
        itemBuilder: (_, p, _) => Card(
          child: ListTile(
            title: Text('${p.namaPengepul} · ${p.jenisSampah}'),
            subtitle: Text(
              '${tanggal(p.tanggal)} · ${kg(p.beratKg)} × ${rupiah(p.hargaPerKg)}',
            ),
            trailing: Text(
              rupiah(p.total),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormPengepul extends ConsumerStatefulWidget {
  const _FormPengepul();

  @override
  ConsumerState<_FormPengepul> createState() => _FormPengepulState();
}

class _FormPengepulState extends ConsumerState<_FormPengepul> {
  final _nama = TextEditingController();
  final _berat = TextEditingController();
  final _harga = TextEditingController();
  int? _jenisId;
  bool _menyimpan = false;

  @override
  void dispose() {
    _nama.dispose();
    _berat.dispose();
    _harga.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jenis = ref.watch(hargaBsProvider);
    final berat = _baca(_berat.text) ?? 0;
    final harga = _baca(_harga.text) ?? 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Catat penjualan ke pengepul',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nama,
            decoration: const InputDecoration(labelText: 'Nama pengepul'),
          ),
          const SizedBox(height: 10),
          TampilanAsync(
            nilai: jenis,
            data: (daftar) => DropdownButtonFormField<int>(
              initialValue: _jenisId,
              decoration: const InputDecoration(labelText: 'Jenis sampah'),
              items: [
                for (final h in daftar)
                  DropdownMenuItem(value: h.jenisSampahId, child: Text(h.nama)),
              ],
              onChanged: (v) => setState(() => _jenisId = v),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _berat,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: _angkaDesimal,
                  decoration: const InputDecoration(
                    labelText: 'Berat',
                    suffixText: 'kg',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _harga,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: _angkaDesimal,
                  decoration: const InputDecoration(
                    labelText: 'Harga/kg',
                    prefixText: 'Rp ',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Total ${rupiah(berat * harga)}',
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          FilledButton(
            // Harga wajib diisi (boleh 0 bila memang diberikan gratis); kosong tidak dianggap 0
            onPressed:
                _menyimpan ||
                    _jenisId == null ||
                    _nama.text.trim().isEmpty ||
                    berat <= 0 ||
                    _baca(_harga.text) == null
                ? null
                : () async {
                    setState(() => _menyimpan = true);
                    final ok = await jalankan(
                      context,
                      () => ref
                          .read(bankSampahRepositoryProvider)
                          .catatPenjualanPengepul({
                            'nama_pengepul': _nama.text.trim(),
                            'jenis_sampah_id': _jenisId,
                            'berat_kg': berat,
                            'harga_per_kg': harga,
                          }),
                      sukses: 'Penjualan dicatat.',
                    );
                    if (!context.mounted) return;
                    setState(() => _menyimpan = false);
                    if (ok) Navigator.pop(context, true);
                  },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

/// Buat akun bentor; armada ikut dibuat jika plat nomor diisi.
class TambahBentorPage extends ConsumerStatefulWidget {
  const TambahBentorPage({super.key});

  @override
  ConsumerState<TambahBentorPage> createState() => _TambahBentorPageState();
}

class _TambahBentorPageState extends ConsumerState<TambahBentorPage> {
  final _form = GlobalKey<FormState>();
  final _c = {
    for (final k in [
      'name',
      'email',
      'phone',
      'password',
      'plat_nomor',
      'kapasitas_kg',
    ])
      k: TextEditingController(),
  };
  Map<String, String> _galat = {};
  bool _menyimpan = false;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _simpan() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _menyimpan = true;
      _galat = {};
    });
    try {
      await ref.read(bankSampahRepositoryProvider).buatBentor({
        'name': _c['name']!.text.trim(),
        'email': _c['email']!.text.trim(),
        'phone': _c['phone']!.text.trim(),
        'password': _c['password']!.text,
        'password_confirmation': _c['password']!.text,
        if (_c['plat_nomor']!.text.trim().isNotEmpty)
          'plat_nomor': _c['plat_nomor']!.text.trim(),
        if (_baca(_c['kapasitas_kg']!.text) != null)
          'kapasitas_kg': _baca(_c['kapasitas_kg']!.text),
      });
      if (!mounted) return;
      tampilPesan(
        context,
        'Akun bentor dibuat. Sampaikan email & password kepada driver.',
      );
      context.pop(true);
    } on ApiException catch (e) {
      setState(() => _galat = e.errors);
      if (mounted) tampilPesan(context, e.pesan, gagal: true);
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  Widget _field(
    String kunci,
    String label, {
    TextInputType? tipe,
    bool rahasia = false,
    String? Function(String?)? validator,
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: _c[kunci],
      keyboardType: tipe,
      obscureText: rahasia,
      textCapitalization: kunci == 'plat_nomor'
          ? TextCapitalization.characters
          : TextCapitalization.none,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: _galat[kunci],
      ),
      validator: validator,
    ),
  );

  @override
  Widget build(BuildContext context) {
    String? wajib(String? v) =>
        (v == null || v.trim().isEmpty) ? 'Wajib diisi.' : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Tambah bentor')),
      body: Form(
        key: _form,
        child: ListView(
          padding: paddingAman(context),
          children: [
            _field('name', 'Nama driver', validator: wajib),
            _field(
              'email',
              'Email (untuk login)',
              tipe: TextInputType.emailAddress,
              validator: (v) =>
                  (v ?? '').contains('@') ? null : 'Email tidak valid.',
            ),
            _field(
              'phone',
              'Nomor HP',
              tipe: TextInputType.phone,
              hint: '08xxxxxxxxxx',
              validator: wajib,
            ),
            _field(
              'password',
              'Password (min. 8)',
              rahasia: true,
              validator: (v) =>
                  (v ?? '').length < 8 ? 'Minimal 8 karakter.' : null,
            ),
            const Divider(),
            const Text('Armada (opsional)'),
            const SizedBox(height: 8),
            _field('plat_nomor', 'Plat nomor', hint: 'BE 1234 AB'),
            _field(
              'kapasitas_kg',
              'Kapasitas (kg)',
              tipe: TextInputType.number,
            ),
            FilledButton(
              onPressed: _menyimpan ? null : _simpan,
              child: const Text('Buat akun'),
            ),
          ],
        ),
      ),
    );
  }
}
