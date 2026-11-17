<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Pemberitahuan di dalam aplikasi (bukan push notification): aplikasi
     * mengambilnya lewat polling. Dihapus otomatis setelah 90 hari.
     */
    public function up(): void
    {
        Schema::create('pemberitahuan', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('jenis', 40);
            $table->string('judul', 120);
            $table->string('isi', 500);
            $table->json('tujuan')->nullable();
            $table->timestamp('dibaca_at')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'dibaca_at']);
            $table->index('created_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('pemberitahuan');
    }
};
