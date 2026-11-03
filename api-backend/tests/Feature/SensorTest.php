<?php

namespace Tests\Feature;

use App\Http\Middleware\AuthenticateDevice;
use App\Models\Device;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class SensorTest extends TestCase
{
    use RefreshDatabase;

    private Device $device;

    private string $apiKey;

    protected function setUp(): void
    {
        parent::setUp();

        // Fitur ditunda, tapi perilaku lamanya tetap harus benar saat dinyalakan
        $this->aktifkanFiturIot();

        $this->device = new Device(['device_id' => 'BS-TEST-01', 'nama' => 'Sensor Uji']);
        $this->apiKey = $this->device->issueApiKey();
    }

    public function test_tanpa_api_key_ditolak(): void
    {
        $this->postJson('/api/sensor', ['device_id' => 'BS-TEST-01', 'volume_percentage' => 50])
            ->assertUnauthorized()
            ->assertJson(['status' => 'gagal']);

        $this->assertDatabaseCount('sensor_data', 0);
    }

    public function test_api_key_salah_ditolak(): void
    {
        $this->postJson('/api/sensor', ['device_id' => 'BS-TEST-01', 'volume_percentage' => 50], ['X-Device-Key' => 'salah'])
            ->assertUnauthorized();
    }

    public function test_api_key_milik_device_lain_ditolak(): void
    {
        $lain = new Device(['device_id' => 'BS-TEST-02', 'nama' => 'Sensor Lain']);
        $lain->issueApiKey();

        $this->postJson('/api/sensor', ['device_id' => 'BS-TEST-02', 'volume_percentage' => 50], ['X-Device-Key' => $this->apiKey])
            ->assertUnauthorized();
    }

    public function test_device_nonaktif_ditolak(): void
    {
        $this->device->forceFill(['is_active' => false])->save();

        $this->postJson('/api/sensor', ['device_id' => 'BS-TEST-01', 'volume_percentage' => 50], ['X-Device-Key' => $this->apiKey])
            ->assertUnauthorized();
    }

    public function test_api_key_benar_menyimpan_data_dan_update_last_seen(): void
    {
        $this->postJson('/api/sensor', ['device_id' => 'BS-TEST-01', 'volume_percentage' => 85.5], ['X-Device-Key' => $this->apiKey])
            ->assertCreated()
            ->assertJsonPath('status', 'sukses')
            ->assertJsonPath('data.volume_percentage', 85.5)
            ->assertJsonPath('data.status', 'penuh');

        $this->assertNotNull($this->device->fresh()->last_seen_at);
    }

    public static function ambangStatus(): array
    {
        return [
            'tepat 80 penuh' => [80, 'penuh'],
            '79.9 aman' => [79.9, 'aman'],
        ];
    }

    #[DataProvider('ambangStatus')]
    public function test_status_penuh_mulai_80_persen(float $volume, string $status): void
    {
        $this->postJson('/api/sensor', ['device_id' => 'BS-TEST-01', 'volume_percentage' => $volume], ['X-Device-Key' => $this->apiKey])
            ->assertCreated()
            ->assertJsonPath('data.status', $status);
    }

    public function test_volume_di_luar_rentang_ditolak(): void
    {
        $this->postJson('/api/sensor', ['device_id' => 'BS-TEST-01', 'volume_percentage' => 150], ['X-Device-Key' => $this->apiKey])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('volume_percentage');
    }

    public function test_spam_key_salah_atas_nama_device_korban_tidak_memblokir_device_asli(): void
    {
        for ($i = 0; $i < 61; $i++) {
            $this->postJson('/api/sensor', ['device_id' => 'BS-TEST-01', 'volume_percentage' => 50], ['X-Device-Key' => 'tebakan-salah'])
                ->assertUnauthorized();
        }

        $this->postJson('/api/sensor', ['device_id' => 'BS-TEST-01', 'volume_percentage' => 50], ['X-Device-Key' => $this->apiKey])
            ->assertCreated();
    }

    public function test_percobaan_gagal_dibatasi_per_ip(): void
    {
        for ($i = 0; $i < AuthenticateDevice::MAX_FAILED_PER_MINUTE; $i++) {
            $this->postJson('/api/sensor', ['device_id' => 'BS-ACAK-'.$i, 'volume_percentage' => 50], ['X-Device-Key' => 'salah'])
                ->assertUnauthorized();
        }

        $this->postJson('/api/sensor', ['device_id' => 'BS-ACAK-X', 'volume_percentage' => 50], ['X-Device-Key' => 'salah'])
            ->assertTooManyRequests()
            ->assertJsonPath('status', 'gagal');
    }

    public function test_kuota_per_device_terautentikasi(): void
    {
        for ($i = 0; $i < 60; $i++) {
            $this->postJson('/api/sensor', ['device_id' => 'BS-TEST-01', 'volume_percentage' => 50], ['X-Device-Key' => $this->apiKey])
                ->assertCreated();
        }

        $this->postJson('/api/sensor', ['device_id' => 'BS-TEST-01', 'volume_percentage' => 50], ['X-Device-Key' => $this->apiKey])
            ->assertTooManyRequests();

        // Device lain tidak ikut terkena kuota BS-TEST-01
        $lain = new Device(['device_id' => 'BS-TEST-02', 'nama' => 'Sensor Lain']);
        $keyLain = $lain->issueApiKey();

        $this->postJson('/api/sensor', ['device_id' => 'BS-TEST-02', 'volume_percentage' => 50], ['X-Device-Key' => $keyLain])
            ->assertCreated();
    }

    public function test_api_key_disimpan_sebagai_sha256(): void
    {
        $this->assertSame(hash('sha256', $this->apiKey), $this->device->fresh()->api_key_hash);
    }

    public function test_get_sensor_wajib_login(): void
    {
        $this->getJson('/api/sensor')->assertUnauthorized();

        // Klien tanpa header Accept: application/json juga harus dapat 401 JSON
        $this->get('/api/sensor')->assertUnauthorized()->assertJson(['status' => 'gagal']);

        Sanctum::actingAs(User::factory()->dlh()->create());
        $this->getJson('/api/sensor')->assertOk()->assertJsonPath('status', 'sukses');
    }

    public function test_device_create_command(): void
    {
        $this->artisan('device:create', ['device_id' => 'BS-TEST-03', 'nama' => 'Sensor Baru'])
            ->expectsOutputToContain('X-Device-Key')
            ->assertSuccessful();

        $this->assertDatabaseHas('devices', ['device_id' => 'BS-TEST-03', 'is_active' => true]);

        $this->artisan('device:create', ['device_id' => 'BS-TEST-03', 'nama' => 'Duplikat'])
            ->assertFailed();
    }
}
