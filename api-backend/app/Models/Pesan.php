<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Pesan extends Model
{
    protected $table = 'pesan';

    protected $fillable = ['percakapan_id', 'pengirim_id', 'isi', 'tawaran_harga'];

    protected function casts(): array
    {
        return [
            'tawaran_harga' => 'decimal:2',
            'dibaca_at' => 'datetime',
        ];
    }

    public function percakapan(): BelongsTo
    {
        return $this->belongsTo(Percakapan::class);
    }
}
