<?php

namespace Database\Seeders;

use App\Enums\UserRole;
use App\Models\Device;
use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use RuntimeException;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     *
     * - production: hanya 1 akun dlh dari SEED_ADMIN_EMAIL + SEED_ADMIN_PASSWORD
     *   (wajib) dan master jenis sampah.
     * - local/testing: data DEMO (lihat DemoSeeder) dan 1 device contoh.
     *
     * Data yang sudah ada dilewati.
     */
    public function run(): void
    {
        if (app()->environment('production')) {
            $this->seedProductionDlh();
            $this->call(JenisSampahSeeder::class);

            return;
        }

        $this->call(DemoSeeder::class);
        $this->seedDevice('BS-TUBABA-01', 'Sensor Contoh BS-TUBABA-01');
    }

    private function seedProductionDlh(): void
    {
        $email = config('banksampah.seed.admin_email');
        $password = config('banksampah.seed.admin_password');

        if (! $email || ! $password) {
            throw new RuntimeException(
                'Seeder production membutuhkan SEED_ADMIN_EMAIL dan SEED_ADMIN_PASSWORD. '
                .'Isi keduanya di .env lalu jalankan `php artisan config:clear` sebelum db:seed.'
            );
        }

        if (User::where('email', $email)->exists()) {
            $this->command?->line("  Lewati {$email} (sudah ada)");

            return;
        }

        $user = new User(['name' => 'DLH Tubaba', 'email' => $email, 'password' => $password]);
        $user->forceFill(['role' => UserRole::Dlh, 'is_aktif' => true, 'email_verified_at' => now()])->save();

        $this->command?->info("  dlh: {$email} (password dari env)");
    }

    private function seedDevice(string $deviceId, string $nama): void
    {
        if (Device::where('device_id', $deviceId)->exists()) {
            $this->command?->line("  Lewati device {$deviceId} (sudah ada)");

            return;
        }

        $device = new Device(['device_id' => $deviceId, 'nama' => $nama]);
        $plainKey = $device->issueApiKey();

        $this->command?->info("  device: {$deviceId} / X-Device-Key: {$plainKey}");
    }
}
