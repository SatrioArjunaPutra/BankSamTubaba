<?php

namespace App\Console\Commands;

use App\Models\Device;
use Illuminate\Console\Command;

class CreateDevice extends Command
{
    protected $signature = 'device:create {device_id : ID yang dikirim mikrokontroler, maks. 50 karakter} {nama : Nama/lokasi perangkat}';

    protected $description = 'Daftarkan perangkat IoT baru dan tampilkan API key-nya (hanya sekali)';

    public function handle(): int
    {
        $deviceId = $this->argument('device_id');

        if (strlen($deviceId) > 50) {
            $this->error('device_id maksimal 50 karakter.');

            return self::FAILURE;
        }

        if (Device::where('device_id', $deviceId)->exists()) {
            $this->error("Perangkat dengan device_id '{$deviceId}' sudah terdaftar.");

            return self::FAILURE;
        }

        $device = new Device(['device_id' => $deviceId, 'nama' => $this->argument('nama')]);
        $plainKey = $device->issueApiKey();

        $this->info("Perangkat '{$device->device_id}' berhasil didaftarkan.");
        $this->newLine();
        $this->line("  X-Device-Key: <comment>{$plainKey}</comment>");
        $this->newLine();
        $this->warn('Simpan API key ini sekarang. Key tidak akan ditampilkan lagi.');

        return self::SUCCESS;
    }
}
