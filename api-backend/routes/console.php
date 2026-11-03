<?php

use App\Support\GambarAman;
use Illuminate\Foundation\Inspiring;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;
use Illuminate\Support\Facades\Storage;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// Hapus token Sanctum yang sudah kedaluwarsa lebih dari 24 jam
Schedule::command('sanctum:prune-expired --hours=24')->daily();

// Foto yang diunggah sebelum ada batas ukuran. Nama file tetap, jadi data di database tidak berubah.
Artisan::command('foto:perkecil', function () {
    $disk = Storage::disk(config('filesystems.upload_disk'));
    $jumlah = 0;

    foreach (['preloved', 'berita', 'penjemputan'] as $folder) {
        foreach ($disk->allFiles($folder) as $path) {
            $info = @getimagesizefromstring((string) $disk->get($path));
            if (! $info || max($info[0], $info[1]) <= GambarAman::SISI_TERPANJANG) {
                continue;
            }

            $sumber = tempnam(sys_get_temp_dir(), 'foto-lama-');
            file_put_contents($sumber, $disk->get($path));
            $bersih = GambarAman::bersihkan(new UploadedFile($sumber, basename($path), $info['mime'], null, true));
            $disk->put($path, (string) file_get_contents($bersih->getRealPath()));
            @unlink($sumber);
            @unlink($bersih->getRealPath());
            $jumlah++;
        }
    }

    $this->info("{$jumlah} foto diperkecil.");
})->purpose('Memperkecil foto lama yang melebihi batas ukuran');
