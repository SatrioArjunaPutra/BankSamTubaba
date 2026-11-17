<?php

namespace Tests\Feature;

use App\Models\BankSampah;
use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Illuminate\Testing\PendingCommand;
use Mockery;
use PDO;
use RuntimeException;
use Tests\TestCase;

class SalinDataLokalTest extends TestCase
{
    use RefreshDatabase;

    private string $sumber;

    private string $folderFoto;

    protected function setUp(): void
    {
        parent::setUp();

        // Sumber selalu SQLite yang dimigrasi sendiri, jadi test ini juga berjalan saat database uji PostgreSQL
        $this->sumber = tempnam(sys_get_temp_dir(), 'salin').'.sqlite';
        touch($this->sumber);
        config(['database.connections.sumber_uji' => [
            'driver' => 'sqlite', 'database' => $this->sumber, 'prefix' => '', 'foreign_key_constraints' => false,
        ]]);
        Artisan::call('migrate', ['--database' => 'sumber_uji', '--force' => true]);
        DB::purge('sumber_uji');

        $pdo = new PDO('sqlite:'.$this->sumber);
        $waktu = '2026-11-01 08:00:00';
        $pdo->prepare('insert into bank_sampah (id, kode, nama, tiyuh, kecamatan, alamat, lat, lng, koordinat_estimasi, is_aktif, created_at, updated_at) values (7, ?, ?, ?, ?, ?, ?, ?, 0, 1, ?, ?)')
            ->execute(['BS-TUBABA-66', 'Randu indah', 'Cahyou randu', 'Pagar Dewa', 'Cahyou randu', -4.3299, 105.228, $waktu, $waktu]);
        $pdo->prepare("insert into users (id, name, email, phone, password, role, bank_sampah_id, is_aktif, created_at, updated_at) values (9, 'Operator', 'op@contoh.test', '0811', ?, 'bank_sampah', 7, 1, ?, ?)")
            ->execute([Hash::make('rahasia-lama'), $waktu, $waktu]);
        $pdo->exec("insert into personal_access_tokens (tokenable_type, tokenable_id, name, token, created_at, updated_at) values ('App\\Models\\User', 9, 'hp', 'hash-token', '{$waktu}', '{$waktu}')");
        $pdo = null;

        $this->folderFoto = sys_get_temp_dir().'/salin-foto-'.uniqid();
        File::ensureDirectoryExists($this->folderFoto.'/preloved');
        File::put($this->folderFoto.'/preloved/a.jpg', 'isi-foto');
    }

    protected function tearDown(): void
    {
        DB::purge('sumber_salin');
        @unlink($this->sumber);
        File::deleteDirectory($this->folderFoto);
        parent::tearDown();
    }

    private function salin(array $opsi = []): PendingCommand
    {
        return $this->artisan('banksampah:salin-data', ['sqlite' => $this->sumber, '--foto-dari' => $this->folderFoto] + $opsi);
    }

    public function test_menyalin_data_dan_foto_tanpa_token_login(): void
    {
        Storage::fake('public');

        $this->salin()->expectsConfirmation('Salin data ini ke tujuan di atas?', 'yes')->assertSuccessful();

        $bank = BankSampah::where('kode', 'BS-TUBABA-66')->first();
        $this->assertSame(7, $bank->id);
        $this->assertEqualsWithDelta(-4.3299, $bank->lat, 0.000001);
        $this->assertTrue($bank->is_aktif);

        $user = User::where('email', 'op@contoh.test')->first();
        $this->assertSame(7, $user->bank_sampah_id);
        $this->assertTrue(Hash::check('rahasia-lama', $user->password));
        $this->assertDatabaseCount('personal_access_tokens', 0);

        Storage::disk('public')->assertExists('preloved/a.jpg');
    }

    public function test_tanpa_persetujuan_tidak_ada_yang_disalin(): void
    {
        Storage::fake('public');

        $this->salin()->expectsConfirmation('Salin data ini ke tujuan di atas?', 'no')->assertFailed();

        $this->assertDatabaseCount('bank_sampah', 0);
        Storage::disk('public')->assertMissing('preloved/a.jpg');
    }

    public function test_tujuan_yang_sudah_berisi_ditolak(): void
    {
        Storage::fake('public');
        BankSampah::factory()->create();

        $this->salin()->expectsOutputToContain('sudah berisi data')->assertFailed();

        $this->assertDatabaseCount('bank_sampah', 1);
        Storage::disk('public')->assertMissing('preloved/a.jpg');
    }

    public function test_opsi_tanpa_foto_tidak_mengunggah_foto(): void
    {
        Storage::fake('public');

        $this->salin(['--tanpa-foto' => true])->expectsConfirmation('Salin data ini ke tujuan di atas?', 'yes')->assertSuccessful();

        $this->assertDatabaseCount('bank_sampah', 1);
        Storage::disk('public')->assertMissing('preloved/a.jpg');
    }

    public function test_foto_gagal_dilaporkan_dan_data_tetap_tersimpan(): void
    {
        $disk = Mockery::mock(Filesystem::class);
        $disk->shouldReceive('path')->andReturn('/disk-lain');
        $disk->shouldReceive('put')->once()->andThrow(new RuntimeException('Bucket tidak ditemukan'));
        Storage::shouldReceive('disk')->andReturn($disk);

        $this->salin()
            ->expectsConfirmation('Salin data ini ke tujuan di atas?', 'yes')
            ->expectsOutputToContain('Bucket tidak ditemukan')
            ->expectsOutputToContain('--hanya-foto')
            ->assertFailed();
        $this->assertDatabaseCount('bank_sampah', 1);
    }

    public function test_hanya_foto_berjalan_meski_database_tujuan_sudah_berisi(): void
    {
        Storage::fake('public');
        BankSampah::factory()->create();

        $this->salin(['--hanya-foto' => true])->assertSuccessful();

        $this->assertDatabaseCount('bank_sampah', 1);
        Storage::disk('public')->assertExists('preloved/a.jpg');
    }

    private function cadanganUji(): string
    {
        return $this->folderFoto.'-cadangan.json';
    }

    public function test_ganti_mencadangkan_lalu_mengganti_isi_tujuan_dan_token_lama(): void
    {
        Storage::fake('public');
        $lama = BankSampah::factory()->create(['kode' => 'BS-LAMA-01']);
        User::factory()->warga()->create(['email' => 'lama@contoh.test'])->createToken('hp');

        $this->salin(['--ganti' => true, '--cadangan' => $this->cadanganUji()])
            ->expectsConfirmation('HAPUS isi tujuan di atas, lalu ganti dengan data sumber?', 'yes')
            ->assertSuccessful();

        $this->assertDatabaseMissing('bank_sampah', ['id' => $lama->id, 'kode' => 'BS-LAMA-01']);
        $this->assertDatabaseMissing('users', ['email' => 'lama@contoh.test']);
        $this->assertDatabaseCount('bank_sampah', 1);
        $this->assertDatabaseHas('users', ['email' => 'op@contoh.test']);
        $this->assertDatabaseCount('personal_access_tokens', 0);
        Storage::disk('public')->assertExists('preloved/a.jpg');

        $cadangan = json_decode(File::get($this->cadanganUji()), true);
        $this->assertSame('BS-LAMA-01', $cadangan['bank_sampah'][0]['kode']);
        $this->assertSame('lama@contoh.test', $cadangan['users'][0]['email']);
        File::delete($this->cadanganUji());
    }

    public function test_ganti_tanpa_persetujuan_tidak_menghapus_apa_pun(): void
    {
        Storage::fake('public');
        BankSampah::factory()->create(['kode' => 'BS-LAMA-01']);

        $this->salin(['--ganti' => true, '--cadangan' => $this->cadanganUji()])
            ->expectsConfirmation('HAPUS isi tujuan di atas, lalu ganti dengan data sumber?', 'no')
            ->assertFailed();

        $this->assertDatabaseHas('bank_sampah', ['kode' => 'BS-LAMA-01']);
        $this->assertFileDoesNotExist($this->cadanganUji());
    }

    public function test_ganti_yang_gagal_mengembalikan_isi_tujuan(): void
    {
        Storage::fake('public');
        BankSampah::factory()->create(['kode' => 'BS-LAMA-01']);
        // Baris sumber yang melanggar foreign key membuat penyalinan gagal di tengah jalan
        $pdo = new PDO('sqlite:'.$this->sumber);
        $pdo->exec('update users set bank_sampah_id = 999 where id = 9');
        $pdo = null;

        try {
            $this->salin(['--ganti' => true, '--cadangan' => $this->cadanganUji()])
                ->expectsConfirmation('HAPUS isi tujuan di atas, lalu ganti dengan data sumber?', 'yes')
                ->run();
            $this->fail('Penyalinan seharusnya gagal.');
        } catch (QueryException) {
            $this->assertDatabaseHas('bank_sampah', ['kode' => 'BS-LAMA-01']);
            $this->assertDatabaseMissing('bank_sampah', ['kode' => 'BS-TUBABA-66']);
            Storage::disk('public')->assertMissing('preloved/a.jpg');
        } finally {
            File::delete($this->cadanganUji());
        }
    }

    public function test_sumber_yang_tidak_ada_ditolak(): void
    {
        $this->artisan('banksampah:salin-data', ['sqlite' => '/tidak/ada.sqlite'])->assertFailed();
    }
}
