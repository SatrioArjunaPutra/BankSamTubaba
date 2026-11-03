<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Route;
use InvalidArgumentException;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class RoleMiddlewareTest extends TestCase
{
    use RefreshDatabase;

    public function test_role_tidak_dikenal_di_route_adalah_error_developer(): void
    {
        Route::middleware(['api', 'auth:sanctum', 'role:superadmin'])
            ->get('/api/_uji-role-salah', fn () => 'ok');

        Sanctum::actingAs(User::factory()->dlh()->create());

        $this->withoutExceptionHandling();
        $this->expectException(InvalidArgumentException::class);
        $this->expectExceptionMessage("Role 'superadmin'");

        $this->getJson('/api/_uji-role-salah');
    }

    public function test_role_yang_diizinkan_lolos(): void
    {
        Route::middleware(['api', 'auth:sanctum', 'role:dlh,bank_sampah'])
            ->get('/api/_uji-role', fn () => response()->json(['status' => 'sukses']));

        Sanctum::actingAs(User::factory()->bankSampah()->create());
        $this->getJson('/api/_uji-role')->assertOk();

        Sanctum::actingAs(User::factory()->warga()->create());
        $this->getJson('/api/_uji-role')->assertForbidden();
    }
}
