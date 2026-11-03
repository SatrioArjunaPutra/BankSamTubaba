<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Saldo warga di satu bank sampah, dibuat otomatis saat setoran pertama
        Schema::create('nasabah', function (Blueprint $table) {
            $table->id();
            $table->foreignId('warga_id')->constrained('users')->restrictOnDelete();
            $table->foreignId('bank_sampah_id')->constrained('bank_sampah')->restrictOnDelete();
            $table->decimal('saldo', 15, 2)->default(0);
            $table->timestamps();

            $table->unique(['warga_id', 'bank_sampah_id']);
        });

        Schema::create('armada', function (Blueprint $table) {
            $table->id();
            $table->foreignId('bank_sampah_id')->constrained('bank_sampah')->restrictOnDelete();
            $table->foreignId('driver_id')->unique()->constrained('users')->restrictOnDelete();
            $table->string('plat_nomor');
            $table->decimal('kapasitas_kg', 8, 2)->nullable();
            $table->string('status')->default('siaga'); // siaga|bertugas|nonaktif
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('armada');
        Schema::dropIfExists('nasabah');
    }
};
