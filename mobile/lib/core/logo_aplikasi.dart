import 'package:flutter/material.dart';

class LogoAplikasi extends StatelessWidget {
  const LogoAplikasi({super.key, this.ukuran = 44});

  final double ukuran;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/branding/logo-satker.png',
    width: ukuran,
    height: ukuran,
    fit: BoxFit.contain,
    semanticLabel: 'Lambang Kabupaten Tulang Bawang Barat',
  );
}
