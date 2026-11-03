<?php

namespace App\Support;

use GdImage;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use RuntimeException;
use Throwable;

/**
 * Foto unggahan pengguna di-encode ulang dengan GD sebelum disimpan, sehingga
 * semua metadata (EXIF, termasuk koordinat GPS rumah warga) terbuang.
 * Orientasi dari EXIF diterapkan dulu agar foto HP tidak tersimpan miring,
 * lalu foto besar diperkecil supaya halaman tidak mengunduh file berukuran MB.
 */
final class GambarAman
{
    /** Sisi terpanjang foto yang disimpan, cukup tajam untuk layar sekaligus ringan diunduh. */
    public const SISI_TERPANJANG = 1280;

    private const FORMAT = [
        IMAGETYPE_JPEG => ['ext' => 'jpg', 'mime' => 'image/jpeg'],
        IMAGETYPE_PNG => ['ext' => 'png', 'mime' => 'image/png'],
        IMAGETYPE_WEBP => ['ext' => 'webp', 'mime' => 'image/webp'],
    ];

    /**
     * Dipanggil saat boot aplikasi: tanpa GD (JPEG/PNG/WebP) upload foto tidak
     * boleh berjalan diam-diam tanpa pembersihan metadata.
     */
    public static function pastikanTersedia(): void
    {
        if (! extension_loaded('gd')) {
            throw new RuntimeException('Ekstensi PHP "gd" wajib aktif untuk membersihkan metadata foto unggahan. Aktifkan di php.ini.');
        }

        $info = gd_info();
        $kurang = array_filter(['JPEG Support', 'PNG Support', 'WebP Support'], fn ($fitur) => empty($info[$fitur]));

        if ($kurang) {
            throw new RuntimeException('Ekstensi PHP "gd" tidak mendukung: '.implode(', ', $kurang).'. Pasang GD dengan dukungan JPEG, PNG, dan WebP.');
        }
    }

    /**
     * Encode ulang ke file sementara (JPEG kualitas 85, PNG, WebP).
     * Pemanggil wajib menghapus file sementara setelah dipakai.
     *
     * @throws ValidationException jika bukan gambar valid atau resolusinya terlalu besar
     */
    public static function bersihkan(UploadedFile $file, string $field = 'foto'): UploadedFile
    {
        self::pastikanTersedia();

        $path = $file->getRealPath();
        $info = $path ? @getimagesize($path) : false;
        $format = $info ? (self::FORMAT[$info[2]] ?? null) : null;

        if (! $format) {
            throw ValidationException::withMessages([$field => 'Foto harus berupa gambar JPG, PNG, atau WebP yang valid.']);
        }

        // Cegah "bom dekompresi": file kecil dengan resolusi raksasa menghabiskan memori
        if (config('banksampah.maks_piksel_foto') < $info[0] * $info[1]) {
            throw ValidationException::withMessages([$field => 'Resolusi foto terlalu besar. Perkecil foto lalu coba lagi.']);
        }

        $gambar = match ($info[2]) {
            IMAGETYPE_JPEG => @imagecreatefromjpeg($path),
            IMAGETYPE_PNG => @imagecreatefrompng($path),
            IMAGETYPE_WEBP => @imagecreatefromwebp($path),
        };

        if (! $gambar instanceof GdImage) {
            throw ValidationException::withMessages([$field => 'Foto rusak atau tidak bisa dibaca.']);
        }

        if ($info[2] === IMAGETYPE_JPEG) {
            $gambar = self::luruskan($gambar, $path);
        }

        $gambar = self::perkecil($gambar);

        $sementara = tempnam(sys_get_temp_dir(), 'foto-bersih-');
        imagesavealpha($gambar, true);

        $ok = match ($info[2]) {
            IMAGETYPE_JPEG => imagejpeg($gambar, $sementara, 85),
            IMAGETYPE_PNG => imagepng($gambar, $sementara, 6),
            IMAGETYPE_WEBP => imagewebp($gambar, $sementara, 85),
        };

        if (! $ok) {
            @unlink($sementara);
            throw new RuntimeException('Gagal memproses foto unggahan.');
        }

        return new UploadedFile($sementara, 'foto.'.$format['ext'], $format['mime'], null, true);
    }

    /**
     * Bersihkan lalu simpan ke disk upload dengan nama acak. Mengembalikan path relatif.
     */
    public static function simpan(UploadedFile $file, string $folder, string $field = 'foto'): string
    {
        $bersih = self::bersihkan($file, $field);

        try {
            return $bersih->storeAs(
                $folder,
                Str::uuid().'.'.pathinfo($bersih->getClientOriginalName(), PATHINFO_EXTENSION),
                ['disk' => config('filesystems.upload_disk')],
            );
        } finally {
            @unlink($bersih->getRealPath());
        }
    }

    /**
     * Simpan beberapa foto; jika salah satu gagal, yang sudah tersimpan dihapus lagi.
     *
     * @param  array<int, UploadedFile>  $files
     * @return array<int, string>
     */
    public static function simpanBanyak(array $files, string $folder, string $field = 'foto'): array
    {
        $tersimpan = [];

        try {
            foreach (array_values($files) as $i => $file) {
                $tersimpan[] = self::simpan($file, $folder, "{$field}.{$i}");
            }
        } catch (Throwable $e) {
            Storage::disk(config('filesystems.upload_disk'))->delete($tersimpan);

            throw $e;
        }

        return $tersimpan;
    }

    private static function perkecil(GdImage $gambar): GdImage
    {
        $lebar = imagesx($gambar);
        $tinggi = imagesy($gambar);
        $terpanjang = max($lebar, $tinggi);

        if ($terpanjang <= self::SISI_TERPANJANG) {
            return $gambar;
        }

        $skala = self::SISI_TERPANJANG / $terpanjang;
        imagealphablending($gambar, false);

        return imagescale($gambar, max(1, (int) round($lebar * $skala)), max(1, (int) round($tinggi * $skala)), IMG_BICUBIC) ?: $gambar;
    }

    // Terapkan tag Orientation EXIF (foto HP sering disimpan miring + tag putar)
    private static function luruskan(GdImage $gambar, string $path): GdImage
    {
        if (! function_exists('exif_read_data')) {
            return $gambar;
        }

        $orientasi = (int) (@exif_read_data($path)['Orientation'] ?? 1);
        $sudut = match ($orientasi) {
            3 => 180,
            6 => -90,
            8 => 90,
            default => 0,
        };

        return $sudut === 0 ? $gambar : (imagerotate($gambar, $sudut, 0) ?: $gambar);
    }
}
