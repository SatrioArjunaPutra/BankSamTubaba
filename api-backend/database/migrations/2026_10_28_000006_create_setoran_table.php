<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('setoran', function (Blueprint $table) {
            $table->id();
            $table->foreignId('bank_sampah_id')->constrained('bank_sampah')->restrictOnDelete();
            $table->foreignId('warga_id')->constrained('users')->restrictOnDelete();
            $table->string('tipe'); // jual|donasi
            $table->decimal('total_kg', 10, 2);
            $table->decimal('total_nilai', 15, 2)->default(0); // 0 untuk donasi
            // Satu penjemputan hanya menghasilkan satu setoran
            $table->foreignId('penjemputan_id')->nullable()->unique()->constrained('penjemputan')->restrictOnDelete();
            $table->foreignId('dicatat_oleh')->constrained('users')->restrictOnDelete();
            $table->text('catatan')->nullable();
            $table->timestamps();

            $table->index(['bank_sampah_id', 'created_at']);
            $table->index(['warga_id', 'bank_sampah_id']);
        });

        Schema::create('setoran_items', function (Blueprint $table) {
            $table->id();
            $table->foreignId('setoran_id')->constrained('setoran')->cascadeOnDelete();
            $table->foreignId('jenis_sampah_id')->constrained('jenis_sampah')->restrictOnDelete();
            $table->decimal('berat_kg', 8, 2);
            $table->decimal('harga_per_kg', 12, 2); // snapshot saat transaksi
            $table->decimal('subtotal', 15, 2);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('setoran_items');
        Schema::dropIfExists('setoran');
    }
};
