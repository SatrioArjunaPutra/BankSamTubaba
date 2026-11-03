<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Tabel transactions Tahap 1 digantikan setoran/setoran_items.
 *
 * Di production migration ini menolak berjalan jika tabel masih berisi data,
 * agar data asli tidak terhapus diam-diam saat deploy. Setelah dipastikan
 * (dan di-backup), set IZINKAN_HAPUS_TRANSACTIONS=true lalu migrate ulang.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('transactions')) {
            return;
        }

        $jumlah = DB::table('transactions')->count();
        $diizinkan = filter_var(env('IZINKAN_HAPUS_TRANSACTIONS', false), FILTER_VALIDATE_BOOL);

        if ($jumlah > 0 && app()->environment('production') && ! $diizinkan) {
            throw new RuntimeException(
                "Tabel transactions masih berisi {$jumlah} baris. Backup dulu, lalu set "
                .'IZINKAN_HAPUS_TRANSACTIONS=true jika data ini memang boleh dihapus.'
            );
        }

        Schema::drop('transactions');
    }

    public function down(): void
    {
        Schema::create('transactions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->onDelete('cascade');
            $table->decimal('weight_kg', 8, 2);
            $table->decimal('points_earned', 15, 2);
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
        });
    }
};
