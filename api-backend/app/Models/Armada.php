<?php

namespace App\Models;

use App\Enums\StatusArmada;
use App\Enums\StatusPenjemputan;
use App\Models\Concerns\BelongsToBankSampah;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Armada extends Model
{
    use BelongsToBankSampah;

    protected $table = 'armada';

    protected $fillable = ['bank_sampah_id', 'driver_id', 'plat_nomor', 'kapasitas_kg', 'status'];

    protected function casts(): array
    {
        return [
            'kapasitas_kg' => 'decimal:2',
            'status' => StatusArmada::class,
        ];
    }

    public function driver(): BelongsTo
    {
        return $this->belongsTo(User::class, 'driver_id');
    }

    // Penjemputan yang sudah ditugaskan dan belum selesai
    public function tugasAktif(): HasMany
    {
        return $this->hasMany(Penjemputan::class)->whereIn('status', [
            StatusPenjemputan::Dijadwalkan->value,
            StatusPenjemputan::Menuju->value,
            StatusPenjemputan::Diambil->value,
        ]);
    }
}
