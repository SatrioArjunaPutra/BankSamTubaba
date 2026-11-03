<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SetoranItem extends Model
{
    protected $table = 'setoran_items';

    protected $fillable = ['setoran_id', 'jenis_sampah_id', 'berat_kg', 'harga_per_kg', 'subtotal'];

    protected function casts(): array
    {
        return [
            'berat_kg' => 'decimal:2',
            'harga_per_kg' => 'decimal:2',
            'subtotal' => 'decimal:2',
        ];
    }

    public function jenisSampah(): BelongsTo
    {
        return $this->belongsTo(JenisSampah::class);
    }
}
