<?php

namespace Tests\Feature;

use App\Models\BankSampah;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    private function dataDaftar(array $ubah = []): array
    {
        return $ubah + [
            'name' => 'Siti Warga',
            'email' => 'siti@example.com',
            'phone' => '081234567890',
            'password' => 'Rahasia123',
            'password_confirmation' => 'Rahasia123',
            'alamat' => 'Jl. Melati 1, Panaragan',
            'lat' => -4.495,
            'lng' => 105.075,
        ];
    }

    public function test_register_membuat_warga_dan_token(): void
    {
        $this->postJson('/api/v1/auth/register', $this->dataDaftar(['role' => 'dlh', 'device_name' => 'android-siti']))
            ->assertCreated()
            ->assertJsonPath('status', 'sukses')
            ->assertJsonPath('data.user.role', 'warga')
            ->assertJsonPath('data.user.bank_sampah_id', null)
            ->assertJsonStructure(['data' => ['user' => ['id', 'name', 'email', 'phone', 'role', 'is_aktif'], 'token', 'expires_at']])
            ->assertJsonMissingPath('data.user.password');

        $user = User::where('email', 'siti@example.com')->first();
        $this->assertSame('warga', $user->role->value);
        $this->assertSame('android-siti', $user->tokens()->first()->name);
    }

    public function test_register_validasi_dengan_pesan_indonesia(): void
    {
        User::factory()->create(['email' => 'siti@example.com']);

        $this->postJson('/api/v1/auth/register', $this->dataDaftar([
            'phone' => '12345',
            'password_confirmation' => 'beda',
        ]))
            ->assertUnprocessable()
            ->assertJsonPath('status', 'gagal')
            ->assertJsonPath('errors.email.0', 'Email sudah terdaftar.')
            ->assertJsonPath('errors.phone.0', 'Nomor HP harus diawali 08, 628, atau +628 (contoh 081234567890).')
            ->assertJsonPath('errors.password.0', 'Konfirmasi password tidak cocok.');
    }

    public function test_register_dibatasi_per_ip(): void
    {
        for ($i = 1; $i <= 5; $i++) {
            $this->postJson('/api/v1/auth/register', $this->dataDaftar(['email' => "w{$i}@example.com"]))->assertCreated();
        }

        $this->postJson('/api/v1/auth/register', $this->dataDaftar(['email' => 'w6@example.com']))
            ->assertTooManyRequests()
            ->assertJsonPath('status', 'gagal');
    }

    public function test_login_berhasil_mengembalikan_user_bank_sampah_dan_token(): void
    {
        $bank = BankSampah::factory()->create();
        $user = User::factory()->bankSampah()->create(['email' => 'operator@example.com', 'bank_sampah_id' => $bank->id]);

        $response = $this->postJson('/api/v1/auth/login', [
            'email' => 'operator@example.com',
            'password' => 'password',
            'device_name' => 'android-budi',
        ]);

        $response->assertOk()
            ->assertJsonPath('data.user.id', $user->id)
            ->assertJsonPath('data.user.role', 'bank_sampah')
            ->assertJsonPath('data.user.bank_sampah.kode', $bank->kode)
            ->assertJsonMissingPath('data.user.saldo');

        $token = $user->tokens()->first();
        $this->assertSame('android-budi', $token->name);
        $this->assertTrue($token->expires_at->between(now()->addDays(7)->subMinute(), now()->addDays(7)->addMinute()));
    }

    public function test_login_password_salah_dan_email_tidak_ada_responsnya_sama(): void
    {
        User::factory()->create(['email' => 'ada@example.com']);

        $tidakAda = $this->postJson('/api/v1/auth/login', ['email' => 'tidak-ada@example.com', 'password' => 'salah']);
        $salah = $this->postJson('/api/v1/auth/login', ['email' => 'ada@example.com', 'password' => 'salah']);

        $salah->assertUnauthorized()->assertJson(['status' => 'gagal']);
        $this->assertSame($salah->json(), $tidakAda->json());
    }

    public function test_login_akun_nonaktif_ditolak(): void
    {
        User::factory()->create(['email' => 'nonaktif@example.com', 'is_aktif' => false]);

        $this->postJson('/api/v1/auth/login', ['email' => 'nonaktif@example.com', 'password' => 'password'])
            ->assertForbidden()
            ->assertJsonPath('status', 'gagal');
    }

    public function test_login_dengan_peran_yang_cocok_berhasil(): void
    {
        $bank = BankSampah::factory()->create();
        User::factory()->warga()->create(['email' => 'warga@example.com']);
        User::factory()->bankSampah()->create(['email' => 'operator@example.com', 'bank_sampah_id' => $bank->id]);
        User::factory()->bentor()->create(['email' => 'bentor@example.com', 'bank_sampah_id' => $bank->id]);

        foreach (['warga', 'operator' => 'bank_sampah', 'bentor'] as $nama => $peran) {
            $email = (is_string($nama) ? $nama : $peran).'@example.com';

            $this->postJson('/api/v1/auth/login', ['email' => $email, 'password' => 'password', 'role' => $peran])
                ->assertOk()
                ->assertJsonPath('data.user.role', $peran);
        }
    }

    public function test_login_peran_tidak_cocok_ditolak_tanpa_membuat_token(): void
    {
        $bank = BankSampah::factory()->create();
        $operator = User::factory()->bankSampah()->create(['email' => 'operator@example.com', 'bank_sampah_id' => $bank->id]);
        $warga = User::factory()->warga()->create(['email' => 'warga@example.com']);

        $this->postJson('/api/v1/auth/login', ['email' => 'operator@example.com', 'password' => 'password', 'role' => 'warga'])
            ->assertForbidden()
            ->assertJsonPath('status', 'gagal')
            ->assertJsonPath('pesan', "Akun ini terdaftar sebagai Bank sampah. Pilih 'Bank sampah' lalu coba lagi.")
            ->assertJsonMissingPath('data');

        $this->postJson('/api/v1/auth/login', ['email' => 'warga@example.com', 'password' => 'password', 'role' => 'bentor'])
            ->assertForbidden()
            ->assertJsonPath('pesan', "Akun ini terdaftar sebagai Warga. Pilih 'Warga' lalu coba lagi.");

        $this->assertSame(0, $operator->tokens()->count());
        $this->assertSame(0, $warga->tokens()->count());
    }

    public function test_login_akun_dlh_di_aplikasi_diarahkan_ke_web(): void
    {
        $dlh = User::factory()->dlh()->create(['email' => 'dlh@example.com']);

        $this->postJson('/api/v1/auth/login', ['email' => 'dlh@example.com', 'password' => 'password', 'role' => 'warga'])
            ->assertForbidden()
            ->assertJsonPath('pesan', 'Akun DLH hanya bisa masuk lewat web dashboard.');

        $this->assertSame(0, $dlh->tokens()->count());
    }

    public function test_login_peran_salah_tidak_membocorkan_peran_akun_tanpa_password_benar(): void
    {
        User::factory()->bankSampah()->create(['email' => 'operator@example.com']);

        $this->postJson('/api/v1/auth/login', ['email' => 'operator@example.com', 'password' => 'salah', 'role' => 'warga'])
            ->assertUnauthorized()
            ->assertExactJson(['status' => 'gagal', 'pesan' => 'Email atau password salah.']);
    }

    public function test_login_akun_nonaktif_tetap_ditolak_sebagai_nonaktif_walau_peran_salah(): void
    {
        User::factory()->warga()->create(['email' => 'nonaktif@example.com', 'is_aktif' => false]);

        $this->postJson('/api/v1/auth/login', ['email' => 'nonaktif@example.com', 'password' => 'password', 'role' => 'bentor'])
            ->assertForbidden()
            ->assertJsonPath('pesan', 'Akun Anda dinonaktifkan. Hubungi pengelola.');
    }

    public function test_login_peran_tidak_dikenal_ditolak_validasi(): void
    {
        User::factory()->warga()->create(['email' => 'warga@example.com']);

        $this->postJson('/api/v1/auth/login', ['email' => 'warga@example.com', 'password' => 'password', 'role' => 'admin'])
            ->assertUnprocessable()
            ->assertJsonPath('status', 'gagal')
            ->assertJsonPath('errors.role.0', 'Peran tidak valid.');
    }

    public function test_login_salah_enam_kali_kena_rate_limit(): void
    {
        User::factory()->create(['email' => 'warga@example.com']);

        for ($i = 1; $i <= 5; $i++) {
            $this->postJson('/api/v1/auth/login', ['email' => 'warga@example.com', 'password' => 'salah'])->assertUnauthorized();
        }

        $this->postJson('/api/v1/auth/login', ['email' => 'warga@example.com', 'password' => 'salah'])
            ->assertTooManyRequests()
            ->assertJson(fn ($json) => $json->where('pesan', fn ($pesan) => str_contains($pesan, 'Terlalu banyak percobaan'))->etc());
    }

    public function test_password_spraying_dari_satu_ip_kena_rate_limit(): void
    {
        for ($i = 1; $i <= 20; $i++) {
            $this->postJson('/api/v1/auth/login', ['email' => "korban{$i}@example.com", 'password' => 'Password123'])->assertUnauthorized();
        }

        $this->postJson('/api/v1/auth/login', ['email' => 'korban21@example.com', 'password' => 'Password123'])
            ->assertTooManyRequests();
    }

    public function test_me_update_profil_dan_logout(): void
    {
        User::factory()->warga()->create(['email' => 'warga@example.com']);

        $token = $this->postJson('/api/v1/auth/login', ['email' => 'warga@example.com', 'password' => 'password'])->json('data.token');

        $this->withToken($token)->getJson('/api/v1/me')->assertOk()->assertJsonPath('data.email', 'warga@example.com');

        $this->withToken($token)->patchJson('/api/v1/me', [
            'name' => 'Nama Baru',
            'alamat' => 'Jl. Merdeka 1',
            'lat' => -4.58,
            'lng' => 105.13,
            'email' => 'ganti@example.com',
        ])
            ->assertOk()
            ->assertJsonPath('data.name', 'Nama Baru')
            ->assertJsonPath('data.lat', -4.58)
            ->assertJsonPath('data.email', 'warga@example.com');

        $this->withToken($token)->postJson('/api/v1/auth/logout')->assertOk();
        $this->app['auth']->forgetGuards();

        $this->withToken($token)->getJson('/api/v1/me')->assertUnauthorized();
    }

    public function test_ubah_password_mencabut_token_lain(): void
    {
        $user = User::factory()->create();
        $tokenLain = $user->createToken('hp-lama');
        $tokenIni = $user->createToken('hp-baru');

        $this->withToken($tokenIni->plainTextToken)->putJson('/api/v1/me/password', [
            'password_lama' => 'salah',
            'password' => 'PasswordBaru1',
            'password_confirmation' => 'PasswordBaru1',
        ])->assertUnprocessable()->assertJsonPath('errors.password_lama.0', 'Password lama salah.');

        $this->withToken($tokenIni->plainTextToken)->putJson('/api/v1/me/password', [
            'password_lama' => 'password',
            'password' => 'PasswordBaru1',
            'password_confirmation' => 'PasswordBaru1',
        ])->assertOk();

        $this->assertSame([$tokenIni->accessToken->id], $user->tokens()->pluck('id')->all());
        $this->assertNotNull($tokenLain);
        $this->postJson('/api/v1/auth/login', ['email' => $user->email, 'password' => 'PasswordBaru1'])->assertOk();
    }

    public function test_route_lama_non_v1_sudah_tidak_ada(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/login', ['email' => 'a@example.com', 'password' => 'x'])->assertNotFound();
        $this->getJson('/api/me')->assertNotFound();
        $this->getJson('/api/transaksi')->assertNotFound();
    }

    public function test_health_publik(): void
    {
        $this->getJson('/api/health')->assertOk()->assertExactJson(['status' => 'sukses', 'pesan' => 'API aktif']);
    }
}
