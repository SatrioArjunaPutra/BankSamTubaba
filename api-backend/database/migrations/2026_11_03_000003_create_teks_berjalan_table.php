<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('teks_berjalan', function (Blueprint $table) {
            $table->id();
            $table->string('teks', 200);
            $table->unsignedSmallInteger('urutan')->default(0);
            $table->boolean('is_aktif')->default(true);
            $table->timestamps();

            $table->index(['is_aktif', 'urutan']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('teks_berjalan');
    }
};
