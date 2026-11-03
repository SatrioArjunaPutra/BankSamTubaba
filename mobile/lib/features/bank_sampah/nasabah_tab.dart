import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/daftar_berhalaman.dart';
import '../../core/format.dart';
import '../../core/models/operasional.dart';
import '../../core/repositories.dart';
import '../../core/theme.dart';
import 'bs_providers.dart';

class NasabahTab extends ConsumerStatefulWidget {
  const NasabahTab({super.key});
  @override
  ConsumerState<NasabahTab> createState() => _NasabahTabState();
}

class _NasabahTabState extends ConsumerState<NasabahTab> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final d = ref.watch(dashboardBsProvider).value;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nasabah',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _angka('Total', angka(d?.jumlahNasabah ?? 0)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _angka(
                      'Saldo nasabah',
                      rupiah(d?.totalSaldoNasabah ?? 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _angka(
                      'Minta tarik',
                      angka(d?.penarikanDiajukan ?? 0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Cari nasabah',
                  prefixIcon: Icon(Icons.search),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (v) => setState(() => _q = v.trim()),
              ),
            ],
          ),
        ),
        Expanded(
          child: DaftarBerhalaman<WargaNasabah>(
            key: ValueKey(_q),
            muat: (hal) => ref
                .read(bankSampahRepositoryProvider)
                .cariNasabah(_q.isEmpty ? null : _q, halaman: hal),
            kosong: 'Belum ada nasabah. Nasabah dibuat saat setoran pertama.',
            itemBuilder: (context, w, segarkan) => Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: TemaAplikasi.hijauLembut,
                          child: Text(w.name.isEmpty ? 'W' : w.name[0]),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                w.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                w.phone ?? 'No. nasabah ${w.id}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: TemaAplikasi.redup,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              rupiah(w.saldo),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Text(
                              'saldo',
                              style: TextStyle(
                                fontSize: 11,
                                color: TemaAplikasi.redup,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if ((d?.penarikanDiajukan ?? 0) > 0)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.push('/bs/penarikan'),
                          child: const Text('Lihat permintaan penarikan'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _angka(String label, String nilai) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: TemaAplikasi.garis),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: TemaAplikasi.redup),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            nilai,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}
