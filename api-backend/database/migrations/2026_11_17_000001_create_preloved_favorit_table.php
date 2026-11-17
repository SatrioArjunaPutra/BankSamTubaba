<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('preloved_favorit', function (Blueprint $table) {
            $table->id();
            $table->foreignId('preloved_item_id')->constrained('preloved_items')->cascadeOnDelete();
            $table->foreignId('warga_id')->constrained('users')->cascadeOnDelete();
            $table->timestamps();

            // Satu warga hanya sekali per barang; dua kiriman bersamaan ditahan di sini
            $table->unique(['preloved_item_id', 'warga_id']);
            $table->index(['warga_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('preloved_favorit');
    }
};
