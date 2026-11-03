<?php

namespace App\Models;

use App\Enums\StatusPenjemputan;
use App\Models\Concerns\BelongsToBankSampah;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Penjemputan extends Model
{
    use BelongsToBankSampah;

    protected $table = 'penjemputan';

    protected $fillable = [
        'warga_id', 'bank_sampah_id', 'alamat', 'lat', 'lng',
        'perkiraan_kg', 'catatan', 'foto_path',
    ];

    protected function casts(): array
    {
        return [
            'status' => StatusPenjemputan::class,
            'lat' => 'float',
            'lng' => 'float',
            'perkiraan_kg' => 'decimal:2',
            'jadwal_at' => 'datetime',
            'dijadwalkan_at' => 'datetime',
            'diambil_at' => 'datetime',
            'selesai_at' => 'datetime',
        ];
    }

    public function warga(): BelongsTo
    {
        return $this->belongsTo(User::class, 'warga_id');
    }

    public function armada(): BelongsTo
    {
        return $this->belongsTo(Armada::class);
    }

    public function setoran(): HasOne
    {
        return $this->hasOne(Setoran::class);
    }
}
