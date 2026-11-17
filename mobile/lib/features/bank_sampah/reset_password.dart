import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Reset password warga atau bentor oleh pengelola. Password sementara dari
/// server hanya tampil sekali di dialog, lalu pemilik akun wajib menggantinya.
Future<void> resetPasswordAkun(
  BuildContext context, {
  required String nama,
  required Future<String> Function() reset,
}) async {
  if (!await konfirmasi(
    context,
    'Reset password $nama?',
    'Pastikan pemilik akun ada di depanmu. Semua perangkatnya akan dikeluarkan dan ia wajib membuat password baru saat masuk.',
    ya: 'Reset',
  )) {
    return;
  }
  if (!context.mounted) return;

  String? sandi;
  final ok = await jalankan(context, () async => sandi = await reset());
  if (!ok || sandi == null || !context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (c) => DialogAplikasi(
      judul: 'Password sementara',
      isi: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Berikan langsung kepada $nama:', style: const TextStyle(height: 1.4)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: TemaAplikasi.hijauLembut,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              sandi!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
                color: TemaAplikasi.hijauPekat,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Password ini hanya tampil sekali dan wajib diganti saat ia masuk.',
            style: TextStyle(fontSize: 12, color: TemaAplikasi.redup),
          ),
        ],
      ),
      aksi: [
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: sandi!));
            tampilPesan(c, 'Password disalin.');
          },
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('Salin'),
        ),
        FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Selesai')),
      ],
    ),
  );
}
