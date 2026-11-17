<?php

namespace Tests\Feature;

use App\Enums\StatusPenjemputan;
use App\Enums\StatusPreloved;
use App\Models\Nasabah;
use App\Models\Penarikan;
use App\Models\Penjemputan;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\Concerns\MembuatDataBankSampah;
use Tests\Concerns\MembuatPreloved;
use Tests\TestCase;

class HapusAkunTest extends TestCase
{
    use MembuatDataBankSampah, MembuatPreloved, RefreshDatabase;

    public function test_akun_warga_dianonimkan_dan_tidak_bisa_login_lagi(): void
    {
        $bank = $this->bank();
        $warga = User::factory()->warga()->create(['email' => 'siti@example.com', 'phone' => '081234567890', 'alamat' => 'Jl. Melati']);
        $this->beriSaldo($warga, $bank, 0);
        $barang = $this->barang($warga);
        $warga->createToken('HP lama');
        Sanctum::actingAs($warga);

        $this->deleteJson('/api/v1/me', ['password' => 'password'])
            ->assertOk()
            ->assertJsonPath('status', 'sukses');

        $warga->refresh();
        $this->assertSame('Warga terhapus', $warga->name);
        $this->assertNotSame('siti@example.com', $warga->email);
        $this->assertNull($warga->phone);
        $this->assertNull($warga->alamat);
        $this->assertFalse($warga->is_aktif);
        $this->assertSame(0, $warga->tokens()->count());
        $this->assertSame(StatusPreloved::Disembunyikan, $barang->refresh()->status);
        // Riwayat tabungan tetap ada untuk kinerja bank sampah
        $this->assertTrue(Nasabah::where('warga_id', $warga->id)->exists());

        $this->app['auth']->forgetGuards();
        $this->postJson('/api/v1/auth/login', ['email' => 'siti@example.com', 'password' => 'password'])
            ->assertUnauthorized();
    }

    public function test_password_salah_ditolak(): void
    {
        $warga = User::factory()->warga()->create();
        Sanctum::actingAs($warga);

        $this->deleteJson('/api/v1/me', ['password' => 'bukan-password'])
            ->assertUnprocessable()
            ->assertJsonPath('errors.password.0', 'Password salah.');

        $this->assertTrue($warga->refresh()->is_aktif);
    }

    public function test_masih_punya_saldo_ditolak(): void
    {
        $warga = User::factory()->warga()->create();
        $this->beriSaldo($warga, $this->bank(), 0);
        $this->beriSaldo($warga, $this->bank(), 5000);
        Sanctum::actingAs($warga);

        $this->deleteJson('/api/v1/me', ['password' => 'password'])
            ->assertUnprocessable()
            ->assertJsonPath('errors.akun.0', 'Saldo Anda masih Rp 5.000. Tarik saldo terlebih dahulu sebelum menghapus akun.');

        $this->assertTrue($warga->refresh()->is_aktif);
    }

    public function test_penarikan_menunggu_ditolak(): void
    {
        $bank = $this->bank();
        $warga = User::factory()->warga()->create();
        $this->beriSaldo($warga, $bank, 0);
        Penarikan::create(['warga_id' => $warga->id, 'bank_sampah_id' => $bank->id, 'jumlah' => 1000]);
        Sanctum::actingAs($warga);

        $this->deleteJson('/api/v1/me', ['password' => 'password'])
            ->assertUnprocessable()
            ->assertJsonPath('errors.akun.0', 'Masih ada penarikan saldo yang menunggu persetujuan.');
    }

    public function test_penjemputan_berjalan_ditolak_tetapi_yang_selesai_tidak(): void
    {
        $bank = $this->bank();
        $warga = User::factory()->warga()->create();
        $jemput = new Penjemputan(['warga_id' => $warga->id, 'bank_sampah_id' => $bank->id, 'alamat' => 'x', 'lat' => -4.5, 'lng' => 105.1]);
        $jemput->forceFill(['status' => StatusPenjemputan::Menuju])->save();
        Sanctum::actingAs($warga);

        $this->deleteJson('/api/v1/me', ['password' => 'password'])
            ->assertUnprocessable()
            ->assertJsonPath('errors.akun.0', 'Masih ada penjemputan yang berjalan. Batalkan atau tunggu sampai selesai.');

        $jemput->forceFill(['status' => StatusPenjemputan::Selesai])->save();
        $this->deleteJson('/api/v1/me', ['password' => 'password'])->assertOk();
    }

    public function test_akun_petugas_tidak_bisa_menghapus_diri_sendiri(): void
    {
        $operator = $this->operator($this->bank());
        Sanctum::actingAs($operator);

        $this->deleteJson('/api/v1/me', ['password' => 'password'])
            ->assertForbidden()
            ->assertJsonPath('pesan', 'Akun petugas hanya bisa dihapus oleh pengelola bank sampah atau DLH.');

        $this->assertTrue($operator->refresh()->is_aktif);
    }
}
