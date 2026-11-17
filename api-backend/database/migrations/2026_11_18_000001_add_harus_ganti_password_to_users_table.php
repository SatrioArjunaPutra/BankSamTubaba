<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Tanda bahwa akun sedang memakai password sementara dari petugas
     * dan wajib menggantinya sebelum bisa memakai fitur lain.
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->boolean('harus_ganti_password')->default(false)->after('is_aktif');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('harus_ganti_password');
        });
    }
};
