<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

/**
 * Setiap kelompok route hanya untuk role-nya. Body sengaja kosong: middleware
 * role harus menolak (403) sebelum validasi berjalan.
 */
class AksesRoleTest extends TestCase
{
    use RefreshDatabase;

    private const ROUTE = [
        'warga' => [
            ['GET', '/api/v1/warga/saldo'], ['GET', '/api/v1/warga/setoran'], ['GET', '/api/v1/warga/penjemputan'],
            ['POST', '/api/v1/warga/penjemputan'], ['POST', '/api/v1/warga/penjemputan/1/batal'],
            ['GET', '/api/v1/warga/penarikan'], ['POST', '/api/v1/warga/penarikan'],
            ['GET', '/api/v1/preloved'], ['GET', '/api/v1/preloved/saya'], ['POST', '/api/v1/preloved'],
            ['GET', '/api/v1/preloved/1'], ['PATCH', '/api/v1/preloved/1'], ['DELETE', '/api/v1/preloved/1'],
            ['POST', '/api/v1/preloved/1/terjual'], ['POST', '/api/v1/preloved/1/lapor'], ['POST', '/api/v1/preloved/1/chat'],
            ['GET', '/api/v1/chat'], ['GET', '/api/v1/chat/1/pesan'], ['POST', '/api/v1/chat/1/pesan'], ['POST', '/api/v1/chat/1/baca'],
        ],
        'bank_sampah' => [
            ['GET', '/api/v1/bs/dashboard'], ['GET', '/api/v1/bs/harga'], ['PUT', '/api/v1/bs/harga'],
            ['GET', '/api/v1/bs/nasabah'], ['GET', '/api/v1/bs/setoran'], ['POST', '/api/v1/bs/setoran'],
            ['GET', '/api/v1/bs/penjemputan'], ['PATCH', '/api/v1/bs/penjemputan/1'],
            ['GET', '/api/v1/bs/armada'], ['POST', '/api/v1/bs/armada'], ['PATCH', '/api/v1/bs/armada/1'],
            ['POST', '/api/v1/bs/bentor'], ['PATCH', '/api/v1/bs/bentor/1/status'], ['GET', '/api/v1/bs/penarikan'], ['PATCH', '/api/v1/bs/penarikan/1'],
            ['GET', '/api/v1/bs/penjualan-pengepul'], ['POST', '/api/v1/bs/penjualan-pengepul'],
        ],
        'bentor' => [
            ['GET', '/api/v1/bentor/tugas'], ['PATCH', '/api/v1/bentor/tugas/1/status'], ['GET', '/api/v1/bentor/armada'], ['PATCH', '/api/v1/bentor/armada/status'],
        ],
        'dlh' => [
            ['GET', '/api/v1/dlh/ringkasan'], ['GET', '/api/v1/dlh/kinerja'], ['GET', '/api/v1/dlh/kinerja/1/tren'],
            ['GET', '/api/v1/dlh/bank-sampah'], ['POST', '/api/v1/dlh/bank-sampah'],
            ['GET', '/api/v1/dlh/laporan-preloved'], ['PATCH', '/api/v1/dlh/preloved/1'],
            ['GET', '/api/v1/dlh/bank-sampah/1/akun'], ['PATCH', '/api/v1/dlh/akun/1/status'],
        ],
    ];

    public static function rolePenyusup(): array
    {
        return [
            'warga' => ['warga'],
            'bank_sampah' => ['bankSampah'],
            'bentor' => ['bentor'],
            'dlh' => ['dlh'],
        ];
    }

    #[DataProvider('rolePenyusup')]
    public function test_role_tidak_bisa_mengakses_route_role_lain(string $state): void
    {
        // ID di URI tidak ada: role yang salah tetap harus 403, bukan 404
        $user = User::factory()->{$state}()->create();
        Sanctum::actingAs($user);

        foreach (self::ROUTE as $role => $routes) {
            if ($role === $user->role->value) {
                continue;
            }

            foreach ($routes as [$method, $uri]) {
                $this->json($method, $uri)->assertForbidden();
            }
        }
    }

    public function test_tanpa_login_401(): void
    {
        foreach (self::ROUTE as $routes) {
            foreach ($routes as [$method, $uri]) {
                $this->json($method, $uri)->assertUnauthorized();
            }
        }
    }
}
