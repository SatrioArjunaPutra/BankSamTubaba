import 'package:flutter/material.dart';

bool _tanpaGerak(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Isi muncul pelan dari bawah saat pertama tampil. Pengaturan kurangi gerak di HP dihormati.
class MunculBertahap extends StatefulWidget {
  const MunculBertahap({super.key, this.urutan = 0, required this.child});

  final int urutan;
  final Widget child;

  @override
  State<MunculBertahap> createState() => _MunculBertahapState();
}

class _MunculBertahapState extends State<MunculBertahap> with SingleTickerProviderStateMixin {
  static const _lama = 340;
  static const _jeda = 55;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _lama + widget.urutan * _jeda),
  );
  late final Animation<double> _nilai = CurvedAnimation(
    parent: _c,
    curve: Interval(widget.urutan * _jeda / (_lama + widget.urutan * _jeda), 1, curve: Curves.easeOutCubic),
  );
  bool _mulai = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_mulai) return;
    _mulai = true;
    if (_tanpaGerak(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _nilai,
    builder: (_, child) => Opacity(
      opacity: _nilai.value,
      child: Transform.translate(offset: Offset(0, (1 - _nilai.value) * 14), child: child),
    ),
    child: widget.child,
  );
}

/// Peralihan halus saat pindah tab, tanpa membuang keadaan isi tab.
class PindahTab extends StatefulWidget {
  const PindahTab({super.key, required this.indeks, required this.child});

  final int indeks;
  final Widget child;

  @override
  State<PindahTab> createState() => _PindahTabState();
}

class _PindahTabState extends State<PindahTab> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );

  @override
  void didUpdateWidget(PindahTab lama) {
    super.didUpdateWidget(lama);
    if (lama.indeks != widget.indeks && !_tanpaGerak(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) {
      final t = Curves.easeOutCubic.transform(_c.value);
      return Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 8), child: child),
      );
    },
    child: widget.child,
  );
}

/// Sedikit mengecil saat ditekan, supaya terasa ada yang merespons sentuhan.
class TekanSkala extends StatefulWidget {
  const TekanSkala({super.key, required this.child});

  final Widget child;

  @override
  State<TekanSkala> createState() => _TekanSkalaState();
}

class _TekanSkalaState extends State<TekanSkala> {
  bool _ditekan = false;

  void _atur(bool nilai) {
    if (_ditekan != nilai) setState(() => _ditekan = nilai);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _atur(true),
    onPointerUp: (_) => _atur(false),
    onPointerCancel: (_) => _atur(false),
    child: AnimatedScale(
      scale: _ditekan ? .95 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: widget.child,
    ),
  );
}

/// Angka yang naik dari nol, lalu bergerak ke nilai baru saat datanya berubah.
class AngkaNaik extends StatelessWidget {
  const AngkaNaik({super.key, required this.nilai, required this.format, this.style});

  final double nilai;
  final String Function(double) format;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Semantics(
    label: format(nilai),
    child: ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: nilai),
        duration: _tanpaGerak(context) ? Duration.zero : const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(format(v), maxLines: 1, style: style),
        ),
      ),
    ),
  );
}
