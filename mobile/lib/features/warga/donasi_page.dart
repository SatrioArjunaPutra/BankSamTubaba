import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/komponen_ui.dart';
import '../../core/models/bank_sampah.dart';
import '../../core/repositories.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'warga_providers.dart';

final _jenisDonasiProvider = FutureProvider.autoDispose<List<JenisSampah>>(
  (ref) => ref.watch(umumRepositoryProvider).jenisSampah(),
);

class DonasiPage extends ConsumerStatefulWidget {
  const DonasiPage({super.key});
  @override
  ConsumerState<DonasiPage> createState() => _DonasiPageState();
}

class _DonasiPageState extends ConsumerState<DonasiPage> {
  int? _bank;
  final _jenis = <int>{};
  double _berat = 1;
  bool _jemput = true;
  Future<void> _lanjut(List<BankSampah> banks, List<JenisSampah> jenis) async {
    final bank = banks.where((b) => b.id == _bank).firstOrNull;
    if (bank == null || _jenis.isEmpty) {
      tampilPesan(
        context,
        'Pilih bank sampah dan jenis sampah yang akan didonasikan.',
        gagal: true,
      );
      return;
    }
    final nama = jenis
        .where((j) => _jenis.contains(j.id))
        .map((j) => j.nama)
        .join(', ');
    if (_jemput) {
      final uri = Uri(
        path: '/warga/jemput/baru',
        queryParameters: {
          'bank': bank.id.toString(),
          'catatan': '[DONASI] $nama',
          'kg': _berat.toString(),
        },
      );
      final ok = await context.push<bool>(uri.toString());
      if (ok == true && mounted) {
        context.pop(true);
      }
    } else {
      if (await konfirmasi(
            context,
            'Antar donasi ke bank sampah',
            'Bawa ${kg(_berat)} $nama ke ${bank.nama}. Sampaikan kepada operator bahwa ini donasi. Berat akan ditimbang ulang dan donasi baru tercatat setelah dikonfirmasi operator.',
            ya: 'Lihat lokasi',
          ) &&
          mounted) {
        await context.push('/warga/bank/${bank.id}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final banks = ref.watch(pilihanBankProvider);
    final jenis = ref.watch(_jenisDonasiProvider);
    final daftar = banks.value ?? [];
    final terpilih = daftar.where((b) => b.id == _bank).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Donasi sampah')),
      body: ListView(
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
                  Icons.volunteer_activism_outlined,
                  color: TemaAplikasi.hijau,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sampah ini didonasikan untuk bank sampah dan tidak diubah menjadi uang atau saldo. Bank sampah mencatatnya atas namamu.',
                    style: TextStyle(fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const JudulBagian('1 · Pilih bank sampah'),
          const SizedBox(height: 10),
          TampilanAsync(
            nilai: banks,
            onUlang: () => ref.invalidate(pilihanBankProvider),
            data: (items) => Column(
              children: [
                for (final b in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => setState(() => _bank = b.id),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _bank == b.id
                                ? TemaAplikasi.hijau
                                : TemaAplikasi.garis,
                            width: _bank == b.id ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.storefront_outlined,
                              color: TemaAplikasi.hijau,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    b.nama,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    b.kecamatan,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: TemaAplikasi.redup,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              _bank == b.id
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: _bank == b.id
                                  ? TemaAplikasi.hijau
                                  : TemaAplikasi.garis,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const JudulBagian('2 · Jenis sampah'),
          const SizedBox(height: 10),
          TampilanAsync(
            nilai: jenis,
            onUlang: () => ref.invalidate(_jenisDonasiProvider),
            data: (items) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final j in items)
                  FilterChip(
                    label: Text(
                      j.nama,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    selected: _jenis.contains(j.id),
                    onSelected: (v) => setState(() {
                      if (v) {
                        _jenis.add(j.id);
                      } else {
                        _jenis.remove(j.id);
                      }
                    }),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const JudulBagian('3 · Berat & cara serah'),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Perkiraan berat',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Ditimbang ulang oleh bank sampah',
                          style: TextStyle(
                            fontSize: 10,
                            color: TemaAplikasi.redup,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kurangi berat',
                    onPressed: _berat <= .5
                        ? null
                        : () => setState(() => _berat -= .5),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text(
                    kg(_berat),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tambah berat',
                    onPressed: () => setState(() => _berat += .5),
                    icon: const Icon(
                      Icons.add_circle,
                      color: TemaAplikasi.hijauPekat,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SegmenReferensi<bool>(
            nilai: _jemput,
            pilihan: const [
              (true, 'Dijemput bentor'),
              (false, 'Antar sendiri'),
            ],
            onUbah: (v) => setState(() => _jemput = v),
          ),
          const SizedBox(height: 12),
          Text(
            _jemput ? 'Lengkapi alamat penjemputan pada langkah berikutnya.' : 'Bawa sampah ke bank tujuan dan sampaikan kepada operator bahwa ini donasi.',
            style: const TextStyle(fontSize: 12, color: TemaAplikasi.redup),
          ),
        ],
      ),
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
                    Text(
                      terpilih?.nama ?? 'Pilih bank tujuan',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${kg(_berat)} · ${_jenis.length} jenis',
                      style: const TextStyle(
                        fontSize: 11,
                        color: TemaAplikasi.redup,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: banks.isLoading || jenis.isLoading
                    ? null
                    : () => _lanjut(daftar, jenis.value ?? []),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 50),
                  backgroundColor: TemaAplikasi.hijauPekat,
                ),
                child: const Text('Donasikan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
