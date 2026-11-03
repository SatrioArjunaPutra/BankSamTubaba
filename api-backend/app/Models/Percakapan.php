<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Percakapan extends Model
{
    protected $table = 'percakapan';

    protected $fillable = ['preloved_item_id', 'pembeli_id', 'penjual_id'];

    protected function casts(): array
    {
        return [
            'last_message_at' => 'datetime',
        ];
    }

    public function item(): BelongsTo
    {
        return $this->belongsTo(PrelovedItem::class, 'preloved_item_id');
    }

    public function pembeli(): BelongsTo
    {
        return $this->belongsTo(User::class, 'pembeli_id');
    }

    public function penjual(): BelongsTo
    {
        return $this->belongsTo(User::class, 'penjual_id');
    }

    public function pesan(): HasMany
    {
        return $this->hasMany(Pesan::class);
    }

    public function pesanTerakhir(): BelongsTo
    {
        return $this->belongsTo(Pesan::class, 'pesan_terakhir_id');
    }

    public function scopeMelibatkan(Builder $query, User $user): Builder
    {
        return $query->where(fn ($q) => $q->where('pembeli_id', $user->id)->orWhere('penjual_id', $user->id));
    }

    public function peserta(User $user): bool
    {
        return (int) $this->pembeli_id === (int) $user->id || (int) $this->penjual_id === (int) $user->id;
    }
}
