<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * Klausa using() hanya dipakai PostgreSQL agar konversi tipe eksplisit;
     * SQLite dan MySQL mengabaikannya.
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->decimal('saldo', 15, 2)->default(0)->using('saldo::numeric(15,2)')->change();
        });

        Schema::table('transactions', function (Blueprint $table) {
            $table->decimal('weight_kg', 8, 2)->using('weight_kg::numeric(8,2)')->change();
            $table->decimal('points_earned', 15, 2)->using('points_earned::numeric(15,2)')->change();
        });

        Schema::table('transactions', function (Blueprint $table) {
            // Petugas/admin yang menginput transaksi
            $table->foreignId('created_by')->nullable()->after('points_earned')
                ->constrained('users')->nullOnDelete();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('transactions', function (Blueprint $table) {
            $table->dropConstrainedForeignId('created_by');
        });

        Schema::table('transactions', function (Blueprint $table) {
            $table->float('weight_kg')->using('weight_kg::double precision')->change();
            $table->integer('points_earned')->using('round(points_earned)::integer')->change();
        });

        Schema::table('users', function (Blueprint $table) {
            $table->integer('saldo')->default(0)->using('round(saldo)::integer')->change();
        });
    }
};
