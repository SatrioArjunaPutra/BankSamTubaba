<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Master jenis sampah, dikelola DLH
        Schema::create('jenis_sampah', function (Blueprint $table) {
            $table->id();
            $table->string('nama')->unique();
            $table->string('satuan')->default('kg');
            $table->boolean('is_aktif')->default(true);
            $table->timestamps();
        });

        // Harga beli tiap bank sampah per jenis sampah
        Schema::create('harga_sampah', function (Blueprint $table) {
            $table->id();
            $table->foreignId('bank_sampah_id')->constrained('bank_sampah')->cascadeOnDelete();
            $table->foreignId('jenis_sampah_id')->constrained('jenis_sampah')->restrictOnDelete();
            $table->decimal('harga_per_kg', 12, 2);
            $table->timestamps();

            $table->unique(['bank_sampah_id', 'jenis_sampah_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('harga_sampah');
        Schema::dropIfExists('jenis_sampah');
    }
};
