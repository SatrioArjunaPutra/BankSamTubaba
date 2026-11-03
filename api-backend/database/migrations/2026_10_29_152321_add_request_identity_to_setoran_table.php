<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('setoran', function (Blueprint $table) {
            $table->uuid('request_id')->nullable();
            $table->char('request_hash', 64)->nullable();
            $table->decimal('saldo_setelah', 15, 2)->nullable();
            $table->unique(['dicatat_oleh', 'request_id'], 'setoran_operator_request_unique');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('setoran', function (Blueprint $table) {
            $table->dropUnique('setoran_operator_request_unique');
            $table->dropColumn(['request_id', 'request_hash', 'saldo_setelah']);
        });
    }
};
