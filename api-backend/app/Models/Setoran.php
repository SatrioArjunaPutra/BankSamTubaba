<?php

namespace App\Models;

use App\Enums\TipeSetoran;
use App\Models\Concerns\BelongsToBankSampah;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Setoran extends Model
{
    use BelongsToBankSampah;

    protected $table = 'setoran';

    protected $fillable = [
        'bank_sampah_id', 'warga_id', 'tipe', 'total_kg', 'total_nilai',
        'penjemputan_id', 'dicatat_oleh', 'catatan', 'request_id', 'request_hash', 'saldo_setelah',
    ];

    protected function casts(): array
    {
        return [
            'tipe' => TipeSetoran::class,
            'total_kg' => 'decimal:2',
            'total_nilai' => 'decimal:2',
            'saldo_setelah' => 'decimal:2',
            'dibatalkan_at' => 'datetime',
        ];
    }

    /**
     * Setoran batal tidak ikut dihitung di mana pun, kecuali lewat denganBatal()
     * untuk riwayat dan pemeriksaan permintaan ulang.
     */
    protected static function booted(): void
    {
        static::addGlobalScope('berlaku', fn (Builder $query) => $query->whereNull($query->qualifyColumn('dibatalkan_at')));
    }

    public static function denganBatal(): Builder
    {
        return static::withoutGlobalScope('berlaku');
    }

    public function items(): HasMany
    {
        return $this->hasMany(SetoranItem::class);
    }

    public function warga(): BelongsTo
    {
        return $this->belongsTo(User::class, 'warga_id');
    }

    public function pencatat(): BelongsTo
    {
        return $this->belongsTo(User::class, 'dicatat_oleh');
    }
}
