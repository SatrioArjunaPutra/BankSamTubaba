<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Database\Connection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Storage;
use Throwable;

/**
 * Menyalin data SQLite lokal dan foto unggahan ke database dan disk aktif (Supabase).
 *
 * Token login, sesi, cache, antrean, serta data sensor sengaja TIDAK disalin.
 * Hanya berjalan pada database tujuan yang sudah dimigrasi dan masih kosong,
 * dan semua baris masuk dalam satu transaksi.
 */
class SalinDataLokal extends Command
{
    protected $signature = 'banksampah:salin-data
        {sqlite : Path database SQLite sumber}
        {--foto-dari= : Folder foto sumber (bawaan storage/app/public)}
        {--tanpa-foto : Hanya menyalin isi database}
        {--hanya-foto : Mengulang unggahan foto tanpa menyentuh database}';

    protected $description = 'Salin data SQLite lokal dan foto ke database dan disk aktif';

    private const KONEKSI_SUMBER = 'sumber_salin';

    // Urutan mengikuti foreign key: tabel induk lebih dulu
    private const TABEL = [
        'bank_sampah', 'users', 'jenis_sampah', 'harga_sampah', 'nasabah', 'armada', 'penjemputan',
        'setoran', 'setoran_items', 'penarikan', 'penjualan_pengepul', 'preloved_items',
        'percakapan', 'pesan', 'laporan_preloved', 'berita', 'teks_berjalan',
    ];

    public function handle(): int
    {
        $path = realpath((string) $this->argument('sqlite'));

        if (! $path || ! is_file($path)) {
            $this->error('Database SQLite sumber tidak ditemukan.');

            return self::FAILURE;
        }

        if ($this->option('hanya-foto')) {
            return $this->salinFoto();
        }

        $tujuan = DB::connection();

        if ($tujuan->getDriverName() === 'sqlite' && realpath((string) $tujuan->getDatabaseName()) === $path) {
            $this->error('Database tujuan sama dengan sumber.');

            return self::FAILURE;
        }

        config(['database.connections.'.self::KONEKSI_SUMBER => [
            'driver' => 'sqlite', 'database' => $path, 'prefix' => '', 'foreign_key_constraints' => false,
        ]]);
        $sumber = DB::connection(self::KONEKSI_SUMBER);

        if ($masalah = $this->periksa($sumber, $tujuan)) {
            $this->error($masalah);

            return self::FAILURE;
        }

        $this->info('Tujuan: '.$tujuan->getDriverName().' / '.($tujuan->getConfig('host') ?? '-').' / '.$tujuan->getDatabaseName());
        $this->table(['Tabel', 'Baris'], array_map(fn (string $t): array => [$t, $sumber->table($t)->count()], self::TABEL));

        if (! $this->confirm('Salin data ini ke tujuan di atas?')) {
            $this->warn('Dibatalkan, tidak ada yang disalin.');

            return self::FAILURE;
        }

        $tujuan->transaction(function () use ($sumber, $tujuan) {
            foreach (self::TABEL as $tabel) {
                $this->salinTabel($sumber, $tujuan, $tabel);
            }
        });
        $this->info('Data berhasil disalin.');

        return $this->option('tanpa-foto') ? self::SUCCESS : $this->salinFoto();
    }

    private function periksa(Connection $sumber, Connection $tujuan): ?string
    {
        foreach (self::TABEL as $tabel) {
            if (! Schema::connection($sumber->getName())->hasTable($tabel)) {
                return "Tabel {$tabel} tidak ada di sumber.";
            }

            if (! Schema::connection($tujuan->getName())->hasTable($tabel)) {
                return "Tabel {$tabel} belum ada di tujuan. Jalankan php artisan migrate --force dahulu.";
            }

            if ($tujuan->table($tabel)->exists()) {
                return "Tabel {$tabel} di tujuan sudah berisi data. Penyalinan hanya untuk database kosong.";
            }

            $lebih = array_diff(
                Schema::connection($sumber->getName())->getColumnListing($tabel),
                Schema::connection($tujuan->getName())->getColumnListing($tabel),
            );

            if ($lebih) {
                return "Kolom {$tabel}.".implode(', ', $lebih).' tidak ada di tujuan. Samakan migrasi dahulu.';
            }
        }

        return null;
    }

    private function salinTabel(Connection $sumber, Connection $tujuan, string $tabel): void
    {
        // SQLite menyimpan boolean sebagai 0/1, sedangkan PostgreSQL menolak angka untuk kolom boolean
        $boolean = $tujuan->getDriverName() === 'pgsql'
            ? collect(Schema::connection($tujuan->getName())->getColumns($tabel))
                ->filter(fn (array $k): bool => in_array($k['type_name'], ['bool', 'boolean'], true))
                ->pluck('name')->all()
            : [];

        $sumber->table($tabel)->orderBy('id')->chunk(200, function ($baris) use ($tujuan, $tabel, $boolean) {
            $tujuan->table($tabel)->insert($baris->map(function (object $b) use ($boolean): array {
                $isi = (array) $b;

                foreach ($boolean as $kolom) {
                    if (isset($isi[$kolom])) {
                        $isi[$kolom] = $isi[$kolom] ? 'true' : 'false';
                    }
                }

                return $isi;
            })->all());
        });

        // Tanpa ini, baris baru di PostgreSQL bentrok dengan id yang baru disalin
        if ($tujuan->getDriverName() === 'pgsql' && $tujuan->table($tabel)->exists()) {
            $tujuan->statement("select setval(pg_get_serial_sequence('{$tabel}', 'id'), (select max(id) from {$tabel}))");
        }
    }

    private function salinFoto(): int
    {
        $folder = $this->option('foto-dari') ?: storage_path('app/public');
        $namaDisk = config('filesystems.upload_disk');
        $disk = Storage::disk($namaDisk);

        if (config("filesystems.disks.{$namaDisk}.driver") === 'local' && realpath($disk->path('')) === realpath($folder)) {
            $this->info('Foto sudah berada di disk tujuan.');

            return self::SUCCESS;
        }

        $gagal = 0;
        $berkas = File::isDirectory($folder) ? File::allFiles($folder) : [];

        foreach ($berkas as $foto) {
            $relatif = str_replace('\\', '/', $foto->getRelativePathname());

            // Disk Supabase melempar error saat gagal, sedangkan disk lain mengembalikan false
            try {
                $terunggah = $disk->put($relatif, File::get($foto->getPathname()));
                $alasan = '';
            } catch (Throwable $e) {
                $terunggah = false;
                $alasan = ': '.$e->getMessage();
            }

            if (! $terunggah) {
                $gagal++;
                $this->error("Gagal mengunggah {$relatif}{$alasan}");
            }
        }

        $this->info((count($berkas) - $gagal).' dari '.count($berkas).' foto disalin ke disk '.$namaDisk.'.');

        if ($gagal) {
            $this->warn('Data di database tetap tersimpan. Perbaiki penyebabnya, lalu ulangi dengan --hanya-foto.');
        }

        return $gagal ? self::FAILURE : self::SUCCESS;
    }
}
