<?php

namespace App\Models;

use App\Models\Concerns\BelongsToBankSampah;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class HargaSampah extends Model
{
    use BelongsToBankSampah;

    protected $table = 'harga_sampah';

    protected $fillable = ['bank_sampah_id', 'jenis_sampah_id', 'harga_per_kg'];

    protected function casts(): array
    {
        return [
            'harga_per_kg' => 'decimal:2',
        ];
    }

    public function jenisSampah(): BelongsTo
    {
        return $this->belongsTo(JenisSampah::class);
    }
}
