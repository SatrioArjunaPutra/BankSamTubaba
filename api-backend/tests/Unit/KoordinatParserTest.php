<?php

namespace Tests\Unit;

use App\Support\KoordinatParser;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

class KoordinatParserTest extends TestCase
{
    public static function formatKoordinat(): array
    {
        return [
            'dms' => ['4°35\'12.0"S 105°07\'55.0"E', -4.586667, 105.131944],
            'desimal titik' => ['-4.5762732, 105.1234567', -4.576273, 105.123457],
            'desimal koma' => ['-4,5762732 105,1234567', -4.576273, 105.123457],
            'lintang positif' => ['4.5762732, 105.1234567', -4.576273, 105.123457],
            'terbalik' => ['105.1234567, -4.5762732', -4.576273, 105.123457],
            'tanpa pemisah' => ['-4113410536489m', -4.1134, 105.3648],
        ];
    }

    #[DataProvider('formatKoordinat')]
    public function test_format_yang_dikenali(string $teks, float $lat, float $lng): void
    {
        $hasil = KoordinatParser::parse($teks, 'TUMIJAJAR', 'X');

        $this->assertEqualsWithDelta($lat, $hasil['lat'], 0.000001);
        $this->assertEqualsWithDelta($lng, $hasil['lng'], 0.000001);
        $this->assertFalse($hasil['estimasi']);
    }

    public function test_tidak_terbaca_pakai_pusat_kecamatan_yang_deterministik(): void
    {
        $a = KoordinatParser::parse('lihat maps', 'Tumijajar', 'BS-TUBABA-07');
        $b = KoordinatParser::parse('', 'TUMIJAJAR', 'BS-TUBABA-07');
        $lain = KoordinatParser::parse('', 'TUMIJAJAR', 'BS-TUBABA-08');

        $this->assertTrue($a['estimasi']);
        $this->assertSame($a, $b);
        $this->assertNotSame($a, $lain);
        $this->assertEqualsWithDelta(-4.5120, $a['lat'], 0.0101);
        $this->assertEqualsWithDelta(105.1520, $a['lng'], 0.0101);
    }

    public function test_kecamatan_tidak_dikenal_tanpa_koordinat(): void
    {
        $this->assertNull(KoordinatParser::parse('', 'ENTAH', 'X'));
    }
}
