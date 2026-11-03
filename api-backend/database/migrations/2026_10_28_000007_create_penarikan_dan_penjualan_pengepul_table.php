<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('penarikan', function (Blueprint $table) {
            $table->id();
            $table->foreignId('warga_id')->constrained('users')->restrictOnDelete();
            $table->foreignId('bank_sampah_id')->constrained('bank_sampah')->restrictOnDelete();
            $table->decimal('jumlah', 15, 2);
            $table->string('status')->default('diajukan'); // diajukan|disetujui|ditolak
            $table->foreignId('diproses_oleh')->nullable()->constrained('users')->nullOnDelete();
            $table->text('catatan')->nullable();
            $table->timestamps();

            $table->index(['bank_sampah_id', 'status']);
            $table->index(['warga_id', 'bank_sampah_id', 'status']);
        });

        Schema::create('penjualan_pengepul', function (Blueprint $table) {
            $table->id();
            $table->foreignId('bank_sampah_id')->constrained('bank_sampah')->restrictOnDelete();
            $table->string('nama_pengepul');
            $table->foreignId('jenis_sampah_id')->constrained('jenis_sampah')->restrictOnDelete();
            $table->decimal('berat_kg', 10, 2);
            $table->decimal('harga_per_kg', 12, 2);
            $table->decimal('total', 15, 2);
            $table->date('tanggal');
            $table->foreignId('dicatat_oleh')->constrained('users')->restrictOnDelete();
            $table->timestamps();

            $table->index(['bank_sampah_id', 'tanggal']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('penjualan_pengepul');
        Schema::dropIfExists('penarikan');
    }
};
