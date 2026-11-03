<?php

namespace Database\Seeders;

use App\Enums\StatusArmada;
use App\Enums\UserRole;
use App\Models\Armada;
use App\Models\BankSampah;
use App\Models\HargaSampah;
use App\Models\JenisSampah;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Str;

/**
 * Data DEMO lokal: 3 bank sampah dengan harga, tiap bank 1 operator dan
 * 2 bentor + armada, serta 5 warga. Semua akun memakai satu password
 * (SEED_DEMO_PASSWORD, atau acak dan dicetak sekali). Aman dijalankan ulang.
 *
 * JANGAN dijalankan ke database produksi.
 */
class DemoSeeder extends Seeder
{
    private const BANK = [
        ['kode' => 'BS-DEMO-01', 'nama' => 'Bank Sampah Demo Panaragan', 'tiyuh' => 'Panaragan', 'kecamatan' => 'Tulang Bawang Tengah', 'lat' => -4.4950, 'lng' => 105.0750],
        ['kode' => 'BS-DEMO-02', 'nama' => 'Bank Sampah Demo Daya Murni', 'tiyuh' => 'Daya Murni', 'kecamatan' => 'Tumijajar', 'lat' => -4.5120, 'lng' => 105.1520],
        ['kode' => 'BS-DEMO-03', 'nama' => 'Bank Sampah Demo Gunung Agung', 'tiyuh' => 'Mulya Jaya', 'kecamatan' => 'Gunung Agung', 'lat' => -4.2650, 'lng' => 105.0650],
    ];

    // Harga dasar per kg; tiap bank diberi selisih kecil agar harga antar bank berbeda
    private const HARGA_DASAR = [
        'Plastik' => 3000, 'Kardus' => 2000, 'Kertas' => 1500,
        'Logam' => 6000, 'Botol Kaca' => 500, 'Minyak Jelantah' => 5000,
    ];

    /** @var array<int, array{0: string, 1: string}> */
    private array $akun = [];

    private string $password;

    public function run(): void
    {
        $configured = config('banksampah.seed.demo_password');
        $this->password = $configured ?: Str::password(12, symbols: false);

        $this->call(JenisSampahSeeder::class);
        $this->call(BeritaDemoSeeder::class);

        $this->user('DLH Tubaba', config('banksampah.seed.admin_email') ?: 'dlh@banksampah.test', UserRole::Dlh);

        foreach (self::BANK as $i => $data) {
            $no = $i + 1;
            $bank = BankSampah::updateOrCreate(['kode' => $data['kode']], $data + [
                'alamat' => 'Tiyuh '.$data['tiyuh'].', Kec. '.$data['kecamatan'],
                'koordinat_estimasi' => false,
                'is_aktif' => true,
            ]);

            foreach (JenisSampah::whereIn('nama', array_keys(self::HARGA_DASAR))->get() as $jenis) {
                HargaSampah::updateOrCreate(
                    ['bank_sampah_id' => $bank->id, 'jenis_sampah_id' => $jenis->id],
                    ['harga_per_kg' => self::HARGA_DASAR[$jenis->nama] + ($i * 250)],
                );
            }

            $this->user("Operator Demo {$no}", "operator{$no}@banksampah.test", UserRole::BankSampah, $bank);

            foreach (['a', 'b'] as $j => $huruf) {
                $driver = $this->user("Bentor Demo {$no}".strtoupper($huruf), "bentor{$no}{$huruf}@banksampah.test", UserRole::Bentor, $bank);
                Armada::firstOrCreate(['driver_id' => $driver->id], [
                    'bank_sampah_id' => $bank->id,
                    'plat_nomor' => sprintf('BE %d%02d%d DM', 4, $no, $j + 1),
                    'kapasitas_kg' => 150,
                    'status' => StatusArmada::Siaga,
                ]);
            }
        }

        for ($no = 1; $no <= 5; $no++) {
            $this->user("Warga Demo {$no}", "warga{$no}@banksampah.test", UserRole::Warga);
        }

        $this->cetakKredensial($configured !== null && $configured !== '');
    }

    private function user(string $name, string $email, UserRole $role, ?BankSampah $bank = null): User
    {
        $user = User::where('email', $email)->first();

        if (! $user) {
            $user = new User(['name' => $name, 'email' => $email, 'password' => $this->password, 'phone' => '0812'.random_int(10000000, 99999999)]);
            $user->forceFill([
                'role' => $role,
                'bank_sampah_id' => $bank?->id,
                'is_aktif' => true,
                'email_verified_at' => now(),
            ])->save();
            $this->akun[] = [$role->value, $email];
        }

        return $user;
    }

    private function cetakKredensial(bool $dariEnv): void
    {
        if (! $this->command || $this->akun === []) {
            return;
        }

        $this->command->info('  Akun demo baru (password sama untuk semua):');
        $this->command->table(['Role', 'Email'], $this->akun);
        $this->command->info('  Password: '.($dariEnv ? '(dari SEED_DEMO_PASSWORD)' : $this->password));
    }
}
