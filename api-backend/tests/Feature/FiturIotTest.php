<?php

namespace Tests\Feature;

use App\Models\Device;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class FiturIotTest extends TestCase
{
    use RefreshDatabase;

    public function test_default_fitur_iot_mati(): void
    {
        $this->assertFalse(config('banksampah.fitur_iot'));
    }

    public function test_saat_mati_route_sensor_tidak_ada(): void
    {
        $device = new Device(['device_id' => 'BS-TEST-01', 'nama' => 'Sensor Uji']);
        $apiKey = $device->issueApiKey();

        $this->postJson('/api/sensor', ['device_id' => 'BS-TEST-01', 'volume_percentage' => 50], ['X-Device-Key' => $apiKey])
            ->assertNotFound()
            ->assertJsonPath('status', 'gagal');

        Sanctum::actingAs(User::factory()->dlh()->create());
        $this->getJson('/api/sensor')->assertNotFound();

        $this->assertDatabaseCount('sensor_data', 0);
    }

    public function test_saat_menyala_route_sensor_terdaftar(): void
    {
        $this->aktifkanFiturIot();

        // Tanpa X-Device-Key: 401 dari middleware device.auth, bukan 404
        $this->postJson('/api/sensor', ['device_id' => 'BS-TEST-01', 'volume_percentage' => 50])
            ->assertUnauthorized();
    }
}
