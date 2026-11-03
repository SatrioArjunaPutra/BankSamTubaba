<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('berita', function (Blueprint $table) {
            $table->id();
            $table->string('judul', 150);
            $table->string('ringkasan', 300);
            $table->text('isi');
            $table->string('kategori'); // berita|pengumuman|kegiatan
            $table->string('foto_path')->nullable();
            $table->string('status')->default('draf'); // draf|terbit
            $table->timestamp('diterbitkan_at')->nullable();
            $table->foreignId('dibuat_oleh')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->index(['status', 'diterbitkan_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('berita');
    }
};
