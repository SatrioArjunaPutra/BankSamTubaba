<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Tenancy (bank_sampah_id) dan data lokasi warga. Saldo pindah ke tabel
 * nasabah (per bank sampah), jadi kolom users.saldo dihapus.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            // Wajib untuk role bank_sampah & bentor, NULL untuk dlh & warga
            $table->foreignId('bank_sampah_id')->nullable()->after('role')
                ->constrained('bank_sampah')->restrictOnDelete();
            $table->string('alamat')->nullable()->after('phone');
            $table->decimal('lat', 10, 7)->nullable()->after('alamat');
            $table->decimal('lng', 10, 7)->nullable()->after('lat');
            $table->boolean('is_aktif')->default(true)->after('lng');
            $table->index('phone');
        });

        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('saldo');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->decimal('saldo', 15, 2)->default(0)->after('phone');
        });

        Schema::table('users', function (Blueprint $table) {
            $table->dropIndex(['phone']);
            $table->dropConstrainedForeignId('bank_sampah_id');
            $table->dropColumn(['alamat', 'lat', 'lng', 'is_aktif']);
        });
    }
};
