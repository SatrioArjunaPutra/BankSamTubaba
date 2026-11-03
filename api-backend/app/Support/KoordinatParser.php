<?php

namespace App\Support;

/**
 * Port dari parseCoord() di parseTubaba.js: membaca teks koordinat bebas dari
 * formulir (DMS, desimal, terbalik, atau angka tanpa pemisah).
 *
 * Bedanya dengan versi JS: jika teks tidak terbaca, titik tengah kecamatan
 * diberi geseran yang diturunkan dari nama bank sampah (bukan Math.random),
 * sehingga import ulang menghasilkan titik yang sama.
 */
class KoordinatParser
{
    public const PUSAT_KECAMATAN = [
        'GUNUNG AGUNG' => [-4.2650, 105.0650],
        'TULANG BAWANG TENGAH' => [-4.5850, 105.1320],
        'TULANG BAWANG UDIK' => [-4.6150, 105.0450],
        'BATU PUTIH' => [-4.3290, 105.0120],
        'LAMBU KIBANG' => [-4.3570, 105.1480],
        'TUMIJAJAR' => [-4.5120, 105.1520],
        'PAGAR DEWA' => [-4.3380, 105.1930],
        'WAY KENANGA' => [-4.1520, 105.2510],
        'GUNUNG TERANG' => [-4.2250, 105.1220],
    ];

    /**
     * @return array{lat: float, lng: float, estimasi: bool}|null
     */
    public static function parse(?string $teks, ?string $kecamatan, string $kunciGeseran): ?array
    {
        $str = trim((string) $teks);

        if ($str !== '' && ($hasil = self::dariTeks($str))) {
            return $hasil + ['estimasi' => false];
        }

        $pusat = self::PUSAT_KECAMATAN[mb_strtoupper(trim((string) $kecamatan))] ?? null;

        if (! $pusat) {
            return null;
        }

        return [
            'lat' => round($pusat[0] + self::geseran($kunciGeseran.'|lat'), 6),
            'lng' => round($pusat[1] + self::geseran($kunciGeseran.'|lng'), 6),
            'estimasi' => true,
        ];
    }

    /**
     * @return array{lat: float, lng: float}|null
     */
    private static function dariTeks(string $str): ?array
    {
        // Pola 1: DMS, mis. 4°35'12.3"S 105°07'55.1"E
        if (preg_match('/(\d+)[*°\s](\d+)[\'’\s](\d+(?:\.\d+)?)[^\d]*(?:S)?.*?(\d+)[*°\s](\d+)[\'’\s](\d+(?:\.\d+)?)/iu', $str, $m)) {
            $lat = -((int) $m[1] + (int) $m[2] / 60 + (float) $m[3] / 3600);
            $lng = (int) $m[4] + (int) $m[5] / 60 + (float) $m[6] / 3600;

            return ['lat' => round($lat, 6), 'lng' => round($lng, 6)];
        }

        // Koma desimal: -4,5762732 -> -4.5762732
        $bersih = preg_replace('/(\d+),(\d+)/', '$1.$2', $str);

        // Pola 2: desimal -4.xxx, 105.xxx
        if (preg_match('/(-?\s*4\.\d{3,})[^\d.-]+(10[45]\.\d{3,})/', $bersih, $m)) {
            return ['lat' => round(-abs((float) preg_replace('/\s+/', '', $m[1])), 6), 'lng' => round((float) $m[2], 6)];
        }

        // Pola 3: terbalik 105.xxx, -4.xxx
        if (preg_match('/(10[45]\.\d{3,})[^\d.-]+(-?\s*4\.\d{3,})/', $bersih, $m)) {
            return ['lat' => round(-abs((float) preg_replace('/\s+/', '', $m[2])), 6), 'lng' => round((float) $m[1], 6)];
        }

        // Pola 4: tanpa pemisah, mis. -4113410536489 -> -4.1134, 105.3648
        if (preg_match('/-4(\d{4})105(\d{4})/', $str, $m)) {
            return ['lat' => (float) ('-4.'.$m[1]), 'lng' => (float) ('105.'.$m[2])];
        }

        return null;
    }

    // Geseran tetap dalam rentang ±0.01 derajat (sama dengan jitter versi JS)
    private static function geseran(string $kunci): float
    {
        return ((crc32($kunci) % 1000) / 1000 - 0.5) * 0.02;
    }
}
