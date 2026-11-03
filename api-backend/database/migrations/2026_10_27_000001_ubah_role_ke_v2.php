<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Role Tahap 1 (admin/petugas/nasabah) diganti role desain v2
 * (dlh/bank_sampah/bentor/warga). Data lama ikut dipetakan.
 */
return new class extends Migration
{
    private const LAMA_KE_BARU = [
        'admin' => 'dlh',
        'petugas' => 'bank_sampah',
        'nasabah' => 'warga',
    ];

    public function up(): void
    {
        foreach (self::LAMA_KE_BARU as $lama => $baru) {
            DB::table('users')->where('role', $lama)->update(['role' => $baru]);
        }

        Schema::table('users', function (Blueprint $table) {
            $table->string('role')->default('warga')->change();
        });
    }

    public function down(): void
    {
        // bentor tidak punya padanan di Tahap 1; paling dekat adalah petugas
        $baruKeLama = array_flip(self::LAMA_KE_BARU) + ['bentor' => 'petugas'];

        foreach ($baruKeLama as $baru => $lama) {
            DB::table('users')->where('role', $baru)->update(['role' => $lama]);
        }

        Schema::table('users', function (Blueprint $table) {
            $table->string('role')->default('nasabah')->change();
        });
    }
};
