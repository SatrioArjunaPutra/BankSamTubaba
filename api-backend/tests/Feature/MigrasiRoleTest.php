<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class MigrasiRoleTest extends TestCase
{
    use RefreshDatabase;

    private function migrasi(): object
    {
        return require database_path('migrations/2026_10_27_000001_ubah_role_ke_v2.php');
    }

    private function buatUser(string $email, ?string $role = null): void
    {
        DB::table('users')->insert(array_filter([
            'name' => $email,
            'email' => $email,
            'password' => 'x',
            'role' => $role,
        ]));
    }

    private function roleDari(string $email): string
    {
        return DB::table('users')->where('email', $email)->value('role');
    }

    public function test_role_lama_dipetakan_ke_role_v2_dan_default_warga(): void
    {
        $this->migrasi()->down();

        $this->buatUser('admin@x.test', 'admin');
        $this->buatUser('petugas@x.test', 'petugas');
        $this->buatUser('nasabah@x.test', 'nasabah');

        $this->migrasi()->up();

        $this->assertSame('dlh', $this->roleDari('admin@x.test'));
        $this->assertSame('bank_sampah', $this->roleDari('petugas@x.test'));
        $this->assertSame('warga', $this->roleDari('nasabah@x.test'));

        $this->buatUser('baru@x.test');
        $this->assertSame('warga', $this->roleDari('baru@x.test'));
    }

    public function test_rollback_mengembalikan_role_lama(): void
    {
        $this->buatUser('dlh@x.test', 'dlh');
        $this->buatUser('bentor@x.test', 'bentor');

        $this->migrasi()->down();

        $this->assertSame('admin', $this->roleDari('dlh@x.test'));
        $this->assertSame('petugas', $this->roleDari('bentor@x.test'));

        $this->buatUser('baru@x.test');
        $this->assertSame('nasabah', $this->roleDari('baru@x.test'));
    }
}
