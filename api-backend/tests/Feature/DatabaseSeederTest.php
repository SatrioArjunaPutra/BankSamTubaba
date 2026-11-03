<?php

namespace Tests\Feature;

use App\Models\Armada;
use App\Models\BankSampah;
use App\Models\Device;
use App\Models\HargaSampah;
use App\Models\JenisSampah;
use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use RuntimeException;
use Tests\TestCase;

class DatabaseSeederTest extends TestCase
{
    use RefreshDatabase;

    public function test_production_hanya_membuat_dlh_dari_env_dan_jenis_sampah(): void
    {
        $this->app->detectEnvironment(fn () => 'production');
        config([
            'banksampah.seed.admin_email' => 'admin@dlh-tubaba.example',
            'banksampah.seed.admin_password' => 'PasswordKuat123',
        ]);

        $this->app->make(DatabaseSeeder::class)->run();

        $this->assertSame(['admin@dlh-tubaba.example'], User::pluck('email')->all());
        $dlh = User::first();
        $this->assertSame('dlh', $dlh->role->value);
        $this->assertTrue(Hash::check('PasswordKuat123', $dlh->password));
        $this->assertSame(6, JenisSampah::count());
        $this->assertSame(0, BankSampah::count());
        $this->assertSame(0, Device::count());
    }

    public function test_production_gagal_jika_email_atau_password_admin_kosong(): void
    {
        $this->app->detectEnvironment(fn () => 'production');
        config([
            'banksampah.seed.admin_email' => 'admin@dlh-tubaba.example',
            'banksampah.seed.admin_password' => null,
        ]);

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('SEED_ADMIN_EMAIL dan SEED_ADMIN_PASSWORD');

        try {
            $this->app->make(DatabaseSeeder::class)->run();
        } finally {
            $this->assertSame(0, User::count());
        }
    }

    public function test_local_membuat_data_demo_lengkap_dan_idempoten(): void
    {
        config(['banksampah.seed.demo_password' => 'DemoRahasia1']);

        $this->app->make(DatabaseSeeder::class)->run();

        $this->assertSame(3, BankSampah::count());
        $this->assertSame(18, HargaSampah::count());
        $this->assertSame(1, User::where('role', 'dlh')->count());
        $this->assertSame(3, User::where('role', 'bank_sampah')->count());
        $this->assertSame(6, User::where('role', 'bentor')->count());
        $this->assertSame(5, User::where('role', 'warga')->count());
        $this->assertSame(6, Armada::count());
        $this->assertSame(1, Device::count());

        // Operator & bentor terikat ke bank sampah; armada milik bank yang sama dengan driver
        $this->assertSame(0, User::whereIn('role', ['bank_sampah', 'bentor'])->whereNull('bank_sampah_id')->count());
        foreach (Armada::with('driver')->get() as $armada) {
            $this->assertSame($armada->bank_sampah_id, $armada->driver->bank_sampah_id);
        }

        $this->postJson('/api/v1/auth/login', ['email' => 'operator1@banksampah.test', 'password' => 'DemoRahasia1'])->assertOk();

        $this->app->make(DatabaseSeeder::class)->run();
        $this->assertSame(15, User::count());
        $this->assertSame(3, BankSampah::count());
        $this->assertSame(6, Armada::count());
        $this->assertSame(1, Device::count());
    }
}
