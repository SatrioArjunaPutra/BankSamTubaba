<?php

namespace App\Models;

use App\Enums\StatusPenarikan;
use App\Models\Concerns\BelongsToBankSampah;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Penarikan extends Model
{
    use BelongsToBankSampah;

    protected $table = 'penarikan';

    protected $fillable = ['warga_id', 'bank_sampah_id', 'jumlah', 'catatan'];

    protected function casts(): array
    {
        return [
            'status' => StatusPenarikan::class,
            'jumlah' => 'decimal:2',
        ];
    }

    public function warga(): BelongsTo
    {
        return $this->belongsTo(User::class, 'warga_id');
    }

    public function pemroses(): BelongsTo
    {
        return $this->belongsTo(User::class, 'diproses_oleh');
    }
}
