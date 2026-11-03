import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Token visual dari referensi HTML Bank Sampah.
class TemaAplikasi {
  static const hijau = Color(0xFF15803D);
  static const hijauPekat = Color(0xFF0E3B26);
  static const limau = Color(0xFFBEF264);
  static const latar = Color(0xFFF5F7F5);
  static const hijauLembut = Color(0xFFEAF7EE);
  static const teks = Color(0xFF101B15);
  static const redup = Color(0xFF6B7770);
  static const garis = Color(0xFFE3E8E4);

  static ThemeData terang() {
    final skema = ColorScheme.fromSeed(seedColor: hijau).copyWith(
      primary: hijau,
      onPrimary: Colors.white,
      primaryContainer: hijauLembut,
      onPrimaryContainer: hijauPekat,
      secondary: hijauPekat,
      secondaryContainer: limau,
      onSecondaryContainer: hijauPekat,
      surface: Colors.white,
      onSurface: teks,
      onSurfaceVariant: const Color(0xFF4B5852),
      outline: redup,
      outlineVariant: garis,
      surfaceContainerHighest: hijauLembut,
    );
    final dasar = ThemeData(
      useMaterial3: true,
      colorScheme: skema,
      fontFamily: 'Plus Jakarta Sans',
    );
    final bentuk = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    );
    final input = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: garis),
    );
    return dasar.copyWith(
      scaffoldBackgroundColor: latar,
      // Halaman masuk dari samping seperti aplikasi HP pada umumnya
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: hijauPekat,
        contentTextStyle: const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      textTheme: dasar.textTheme.copyWith(
        headlineSmall: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
          color: teks,
        ),
        titleLarge: const TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: teks,
        ),
        titleMedium: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: teks,
        ),
        titleSmall: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: teks,
        ),
        bodyMedium: const TextStyle(fontSize: 14, height: 1.5, color: teks),
        bodySmall: const TextStyle(fontSize: 12, height: 1.5, color: redup),
      // Gaya di atas dibuat baru, jadi font tema harus dipasang lagi
      ).apply(fontFamily: 'Plus Jakarta Sans'),
      appBarTheme: const AppBarTheme(
        backgroundColor: latar,
        foregroundColor: teks,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleSpacing: 20,
        titleTextStyle: TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: teks,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 1.5,
        shadowColor: hijauPekat.withValues(alpha: .10),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: garis),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: latar,
        border: input,
        enabledBorder: input,
        focusedBorder: input.copyWith(
          borderSide: const BorderSide(color: hijau, width: 1.5),
        ),
        errorBorder: input.copyWith(borderSide: BorderSide(color: skema.error)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        isDense: true,
        labelStyle: const TextStyle(color: redup, fontSize: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: bentuk,
          textStyle: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          foregroundColor: hijauPekat,
          side: const BorderSide(color: garis),
          shape: bentuk,
          textStyle: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: hijau,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: bentuk,
      ),
      dividerTheme: const DividerThemeData(
        color: garis,
        thickness: 1,
        space: 24,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: hijau,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        titleTextStyle: TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.3,
          color: teks,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 12.5,
          height: 1.35,
          color: redup,
        ),
      ),
      chipTheme: dasar.chipTheme.copyWith(
        backgroundColor: Colors.white,
        selectedColor: hijauLembut,
        side: const BorderSide(color: garis),
        shape: const StadiumBorder(),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: hijauPekat,
        unselectedLabelColor: redup,
        indicatorColor: hijau,
        dividerColor: garis,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: hijau),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
