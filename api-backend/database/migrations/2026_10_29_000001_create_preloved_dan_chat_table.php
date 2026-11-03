<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('preloved_items', function (Blueprint $table) {
            $table->id();
            $table->foreignId('penjual_id')->constrained('users')->restrictOnDelete();
            $table->string('judul');
            $table->text('deskripsi');
            $table->string('kategori');
            $table->string('kondisi'); // baru|seperti_baru|bekas_baik|bekas
            $table->decimal('harga', 12, 2);
            $table->string('kecamatan');
            $table->json('foto'); // array path relatif di upload_disk, maks 5
            $table->string('status')->default('tersedia'); // tersedia|terjual|disembunyikan
            $table->timestamps();

            $table->index(['status', 'created_at']);
            $table->index('penjual_id');
        });

        Schema::create('percakapan', function (Blueprint $table) {
            $table->id();
            // Barang dihapus pemiliknya → percakapan & pesannya ikut terhapus
            $table->foreignId('preloved_item_id')->constrained('preloved_items')->cascadeOnDelete();
            $table->foreignId('pembeli_id')->constrained('users')->restrictOnDelete();
            $table->foreignId('penjual_id')->constrained('users')->restrictOnDelete();
            $table->timestamp('last_message_at')->nullable();
            $table->timestamps();

            $table->unique(['preloved_item_id', 'pembeli_id']);
            $table->index(['pembeli_id', 'last_message_at']);
            $table->index(['penjual_id', 'last_message_at']);
        });

        Schema::create('pesan', function (Blueprint $table) {
            $table->id();
            $table->foreignId('percakapan_id')->constrained('percakapan')->cascadeOnDelete();
            $table->foreignId('pengirim_id')->constrained('users')->restrictOnDelete();
            $table->text('isi')->nullable();
            $table->decimal('tawaran_harga', 12, 2)->nullable();
            $table->timestamp('dibaca_at')->nullable();
            $table->timestamps();

            // Polling ?after_id= : WHERE percakapan_id = ? AND id > ? ORDER BY id
            $table->index(['percakapan_id', 'id']);
        });

        Schema::create('laporan_preloved', function (Blueprint $table) {
            $table->id();
            $table->foreignId('preloved_item_id')->constrained('preloved_items')->cascadeOnDelete();
            $table->foreignId('pelapor_id')->constrained('users')->restrictOnDelete();
            $table->string('alasan', 500);
            $table->string('status')->default('baru'); // baru|ditindak|diabaikan
            $table->timestamps();

            // Satu pelapor satu laporan per barang
            $table->unique(['preloved_item_id', 'pelapor_id']);
            $table->index(['status', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('laporan_preloved');
        Schema::dropIfExists('pesan');
        Schema::dropIfExists('percakapan');
        Schema::dropIfExists('preloved_items');
    }
};
