<?php

namespace App\Models;

use App\Models\Concerns\BelongsToBankSampah;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Saldo seorang warga di satu bank sampah. Ubah saldo hanya lewat
 * SetoranService / PenarikanService (dalam transaksi + lockForUpdate).
 */
class Nasabah extends Model
{
    use BelongsToBankSampah;

    protected $table = 'nasabah';

    protected $fillable = ['warga_id', 'bank_sampah_id'];

    protected function casts(): array
    {
        return [
            'saldo' => 'decimal:2',
        ];
    }

    public function warga(): BelongsTo
    {
        return $this->belongsTo(User::class, 'warga_id');
    }
}
