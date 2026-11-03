<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('penjemputan', function (Blueprint $table) {
            $table->id();
            $table->foreignId('warga_id')->constrained('users')->restrictOnDelete();
            $table->foreignId('bank_sampah_id')->constrained('bank_sampah')->restrictOnDelete();
            $table->foreignId('armada_id')->nullable()->constrained('armada')->nullOnDelete();
            $table->string('alamat');
            $table->decimal('lat', 10, 7);
            $table->decimal('lng', 10, 7);
            $table->decimal('perkiraan_kg', 8, 2)->nullable();
            $table->text('catatan')->nullable();
            $table->string('foto_path')->nullable();
            $table->timestamp('jadwal_at')->nullable();
            // diajukan|dijadwalkan|menuju|diambil|selesai|ditolak|dibatalkan
            $table->string('status')->default('diajukan');
            $table->string('alasan_tolak')->nullable();
            $table->timestamp('dijadwalkan_at')->nullable();
            $table->timestamp('diambil_at')->nullable();
            $table->timestamp('selesai_at')->nullable();
            $table->timestamps();

            $table->index(['bank_sampah_id', 'status']);
            $table->index(['armada_id', 'status']);
            $table->index('warga_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('penjemputan');
    }
};
