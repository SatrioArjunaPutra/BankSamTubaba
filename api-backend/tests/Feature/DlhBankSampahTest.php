<?php

namespace Tests\Feature;

use App\Models\BankSampah;
use App\Models\JenisSampah;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DlhBankSampahTest extends TestCase
{
    use RefreshDatabase;

    public function test_selain_dlh_ditolak_di_semua_endpoint_dlh(): void
    {
        $bank = BankSampah::factory()->create();
        $jenis = JenisSampah::factory()->create();

        foreach (['warga', 'bankSampah', 'bentor'] as $state) {
            Sanctum::actingAs(User::factory()->{$state}()->create());

            $this->getJson('/api/v1/dlh/bank-sampah')->assertForbidden()->assertJsonPath('status', 'gagal');
            $this->postJson('/api/v1/dlh/bank-sampah', ['nama' => 'X', 'tiyuh' => 'X', 'kecamatan' => 'X'])->assertForbidden();
            $this->patchJson("/api/v1/dlh/bank-sampah/{$bank->id}", ['is_aktif' => false])->assertForbidden();
            $this->postJson("/api/v1/dlh/bank-sampah/{$bank->id}/operator", [])->assertForbidden();
            $this->getJson('/api/v1/dlh/jenis-sampah')->assertForbidden();
            $this->postJson('/api/v1/dlh/jenis-sampah', ['nama' => 'Baru'])->assertForbidden();
            $this->patchJson("/api/v1/dlh/jenis-sampah/{$jenis->id}", ['is_aktif' => false])->assertForbidden();
        }

        $this->assertTrue($bank->fresh()->is_aktif);
        $this->assertTrue($jenis->fresh()->is_aktif);
    }

    public function test_dlh_melihat_termasuk_yang_nonaktif_dengan_jumlah_operator(): void
    {
        $bank = BankSampah::factory()->create(['kode' => 'BS-TUBABA-01']);
        BankSampah::factory()->nonaktif()->create(['kode' => 'BS-TUBABA-02']);
        User::factory()->bankSampah()->create(['bank_sampah_id' => $bank->id]);
        Sanctum::actingAs(User::factory()->dlh()->create());

        $this->getJson('/api/v1/dlh/bank-sampah')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.jumlah_operator', 1);

        $this->getJson('/api/v1/dlh/bank-sampah?is_aktif=0')
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.kode', 'BS-TUBABA-02');
    }

    public function test_dlh_tambah_bank_sampah_dengan_kode_otomatis(): void
    {
        BankSampah::factory()->create(['kode' => 'BS-TUBABA-09']);
        Sanctum::actingAs(User::factory()->dlh()->create());

        $this->postJson('/api/v1/dlh/bank-sampah', [
            'nama' => 'Bank Sampah Baru',
            'tiyuh' => 'Panaragan',
            'kecamatan' => 'Tulang Bawang Tengah',
            'lat' => -4.58,
            'lng' => 105.13,
        ])
            ->assertCreated()
            ->assertJsonPath('data.kode', 'BS-TUBABA-10')
            ->assertJsonPath('data.is_aktif', true)
            ->assertJsonPath('data.koordinat_estimasi', false);
    }

    public function test_dlh_tambah_validasi(): void
    {
        BankSampah::factory()->create(['kode' => 'BS-TUBABA-01']);
        Sanctum::actingAs(User::factory()->dlh()->create());

        $this->postJson('/api/v1/dlh/bank-sampah', ['kode' => 'BS-TUBABA-01', 'lat' => -4.5])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['kode', 'nama', 'tiyuh', 'kecamatan', 'lng'])
            ->assertJsonPath('errors.nama.0', 'Nama wajib diisi.');
    }

    public function test_dlh_ubah_sebagian_dan_koordinat_baru_bukan_estimasi(): void
    {
        $bank = BankSampah::factory()->create(['koordinat_estimasi' => true, 'nama' => 'Lama']);
        Sanctum::actingAs(User::factory()->dlh()->create());

        $this->patchJson("/api/v1/dlh/bank-sampah/{$bank->id}", ['lat' => -4.6, 'lng' => 105.2, 'is_aktif' => false])
            ->assertOk()
            ->assertJsonPath('data.nama', 'Lama')
            ->assertJsonPath('data.is_aktif', false)
            ->assertJsonPath('data.koordinat_estimasi', false);
    }

    public function test_dlh_buat_akun_operator_terikat_ke_bank_sampah(): void
    {
        $bank = BankSampah::factory()->create();
        Sanctum::actingAs(User::factory()->dlh()->create());

        $this->postJson("/api/v1/dlh/bank-sampah/{$bank->id}/operator", [
            'name' => 'Operator Baru',
            'email' => 'op@example.com',
            'phone' => '081200001111',
            'password' => 'Rahasia123',
            'password_confirmation' => 'Rahasia123',
            'role' => 'dlh',
            'bank_sampah_id' => 999,
        ])
            ->assertCreated()
            ->assertJsonPath('data.role', 'bank_sampah')
            ->assertJsonPath('data.bank_sampah_id', $bank->id);

        $this->postJson('/api/v1/auth/login', ['email' => 'op@example.com', 'password' => 'Rahasia123'])
            ->assertOk()
            ->assertJsonPath('data.user.bank_sampah.id', $bank->id);
    }

    public function test_dlh_buat_operator_email_duplikat_ditolak(): void
    {
        $bank = BankSampah::factory()->create();
        User::factory()->create(['email' => 'ada@example.com']);
        Sanctum::actingAs(User::factory()->dlh()->create());

        $this->postJson("/api/v1/dlh/bank-sampah/{$bank->id}/operator", [
            'name' => 'X', 'email' => 'ada@example.com', 'phone' => '081200001111',
            'password' => 'Rahasia123', 'password_confirmation' => 'Rahasia123',
        ])->assertUnprocessable()->assertJsonValidationErrors('email');
    }

    public function test_dlh_kelola_jenis_sampah(): void
    {
        JenisSampah::factory()->create(['nama' => 'Plastik']);
        JenisSampah::factory()->create(['nama' => 'Arsip', 'is_aktif' => false]);
        Sanctum::actingAs(User::factory()->dlh()->create());

        $this->getJson('/api/v1/dlh/jenis-sampah')->assertOk()->assertJsonCount(2, 'data');

        $id = $this->postJson('/api/v1/dlh/jenis-sampah', ['nama' => 'Elektronik'])
            ->assertCreated()
            ->assertJsonPath('data.satuan', 'kg')
            ->assertJsonPath('data.is_aktif', true)
            ->json('data.id');

        $this->postJson('/api/v1/dlh/jenis-sampah', ['nama' => 'Plastik'])
            ->assertUnprocessable()
            ->assertJsonPath('errors.nama.0', 'Nama sudah terdaftar.');

        $this->patchJson("/api/v1/dlh/jenis-sampah/{$id}", ['is_aktif' => false])
            ->assertOk()
            ->assertJsonPath('data.nama', 'Elektronik')
            ->assertJsonPath('data.is_aktif', false);
    }
}
