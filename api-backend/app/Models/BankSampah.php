<?php

namespace App\Models;

use App\Enums\UserRole;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class BankSampah extends Model
{
    use HasFactory;

    protected $table = 'bank_sampah';

    protected $fillable = [
        'kode',
        'nama',
        'tiyuh',
        'kecamatan',
        'alamat',
        'lat',
        'lng',
        'koordinat_estimasi',
        'no_hp_publik',
        'is_aktif',
    ];

    protected function casts(): array
    {
        return [
            'lat' => 'float',
            'lng' => 'float',
            'koordinat_estimasi' => 'boolean',
            'is_aktif' => 'boolean',
        ];
    }

    public function scopeAktif(Builder $query): Builder
    {
        return $query->where('is_aktif', true);
    }

    public function harga(): HasMany
    {
        return $this->hasMany(HargaSampah::class);
    }

    public function operator(): HasMany
    {
        return $this->hasMany(User::class)->where('role', UserRole::BankSampah->value);
    }

    /**
     * Kode berikutnya dengan format BS-TUBABA-xx (minimal 2 digit).
     */
    public static function kodeBerikutnya(): string
    {
        $terbesar = static::where('kode', 'like', 'BS-TUBABA-%')->pluck('kode')
            ->map(fn (string $kode) => (int) substr($kode, strlen('BS-TUBABA-')))
            ->max() ?? 0;

        return 'BS-TUBABA-'.str_pad((string) ($terbesar + 1), 2, '0', STR_PAD_LEFT);
    }
}
