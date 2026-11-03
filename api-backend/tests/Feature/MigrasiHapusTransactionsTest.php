<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use RuntimeException;
use Tests\TestCase;

class MigrasiHapusTransactionsTest extends TestCase
{
    use RefreshDatabase;

    private function migrasi(): object
    {
        return require database_path('migrations/2026_10_28_000008_hapus_transactions_table.php');
    }

    private function siapkanTransactionsBerisi(): void
    {
        $this->migrasi()->down();
        $user = User::factory()->create();
        DB::table('transactions')->insert(['user_id' => $user->id, 'weight_kg' => 1, 'points_earned' => 5000]);
    }

    protected function tearDown(): void
    {
        putenv('IZINKAN_HAPUS_TRANSACTIONS');
        unset($_ENV['IZINKAN_HAPUS_TRANSACTIONS'], $_SERVER['IZINKAN_HAPUS_TRANSACTIONS']);
        parent::tearDown();
    }

    public function test_production_menolak_menghapus_transactions_berisi_data(): void
    {
        $this->siapkanTransactionsBerisi();
        $this->app->detectEnvironment(fn () => 'production');

        try {
            $this->migrasi()->up();
            $this->fail('Migration seharusnya menolak berjalan.');
        } catch (RuntimeException $e) {
            $this->assertStringContainsString('IZINKAN_HAPUS_TRANSACTIONS', $e->getMessage());
        }

        $this->assertTrue(Schema::hasTable('transactions'));
    }

    public function test_production_boleh_menghapus_jika_diizinkan(): void
    {
        $this->siapkanTransactionsBerisi();
        $this->app->detectEnvironment(fn () => 'production');
        $_ENV['IZINKAN_HAPUS_TRANSACTIONS'] = $_SERVER['IZINKAN_HAPUS_TRANSACTIONS'] = 'true';
        putenv('IZINKAN_HAPUS_TRANSACTIONS=true');

        $this->migrasi()->up();

        $this->assertFalse(Schema::hasTable('transactions'));
    }

    public function test_lokal_langsung_menghapus(): void
    {
        $this->siapkanTransactionsBerisi();

        $this->migrasi()->up();

        $this->assertFalse(Schema::hasTable('transactions'));
    }
}
