<?php

namespace App\Models;

use App\Enums\KondisiBarang;
use App\Enums\StatusPreloved;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Facades\Storage;

class PrelovedItem extends Model
{
    protected $table = 'preloved_items';

    protected $fillable = ['judul', 'deskripsi', 'kategori', 'kondisi', 'harga', 'kecamatan'];

    protected $attributes = [
        'foto' => '[]',
    ];

    protected function casts(): array
    {
        return [
            'kondisi' => KondisiBarang::class,
            'status' => StatusPreloved::class,
            'harga' => 'decimal:2',
            'foto' => 'array',
        ];
    }

    /** Barang yang boleh tampil tanpa login: tersedia dan penjualnya masih aktif. */
    public function scopeTayang(Builder $query): Builder
    {
        return $query->where('status', StatusPreloved::Tersedia->value)
            ->whereHas('penjual', fn ($q) => $q->where('is_aktif', true));
    }

    public function penjual(): BelongsTo
    {
        return $this->belongsTo(User::class, 'penjual_id');
    }

    public function percakapan(): HasMany
    {
        return $this->hasMany(Percakapan::class);
    }

    public function laporan(): HasMany
    {
        return $this->hasMany(LaporanPreloved::class);
    }

    public function favoritOleh(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'preloved_favorit', 'preloved_item_id', 'warga_id')->withTimestamps();
    }

    /** Menambahkan jumlah_favorit dan difavoritkan (oleh $warga) ke setiap barang. */
    public function scopeDenganFavorit(Builder $query, User $warga): Builder
    {
        return $query->withCount('favoritOleh as jumlah_favorit')
            ->withExists(['favoritOleh as difavoritkan' => fn ($q) => $q->whereKey($warga->id)]);
    }

    public function muatFavorit(User $warga): static
    {
        return $this->loadCount('favoritOleh as jumlah_favorit')
            ->loadExists(['favoritOleh as difavoritkan' => fn ($q) => $q->whereKey($warga->id)]);
    }

    public function milik(User $user): bool
    {
        return (int) $this->penjual_id === (int) $user->id;
    }

    /**
     * @return array<int, string>
     */
    public function urlFoto(): array
    {
        $disk = Storage::disk(config('filesystems.upload_disk'));

        return array_map(fn (string $path) => $disk->url($path), $this->foto ?? []);
    }

    public function hapusFileFoto(): void
    {
        if ($this->foto) {
            Storage::disk(config('filesystems.upload_disk'))->delete($this->foto);
        }
    }
}
