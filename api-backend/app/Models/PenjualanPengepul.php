<?php

namespace App\Models;

use App\Models\Concerns\BelongsToBankSampah;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PenjualanPengepul extends Model
{
    use BelongsToBankSampah;

    protected $table = 'penjualan_pengepul';

    protected $fillable = [
        'bank_sampah_id', 'nama_pengepul', 'jenis_sampah_id', 'berat_kg',
        'harga_per_kg', 'total', 'tanggal', 'dicatat_oleh',
    ];

    protected function casts(): array
    {
        return [
            'berat_kg' => 'decimal:2',
            'harga_per_kg' => 'decimal:2',
            'total' => 'decimal:2',
            'tanggal' => 'date',
        ];
    }

    public function jenisSampah(): BelongsTo
    {
        return $this->belongsTo(JenisSampah::class);
    }
}
