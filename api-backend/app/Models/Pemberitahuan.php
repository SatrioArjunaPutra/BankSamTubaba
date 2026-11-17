<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Prunable;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Pemberitahuan untuk satu pengguna. Dibuat oleh PemberitahuanService di
 * dalam transaksi kejadiannya, sehingga ikut batal bila transaksi gagal.
 */
class Pemberitahuan extends Model
{
    use Prunable;

    /** Umur maksimal sebelum dihapus oleh model:prune. */
    public const SIMPAN_HARI = 90;

    protected $table = 'pemberitahuan';

    protected $fillable = ['user_id', 'jenis', 'judul', 'isi', 'tujuan'];

    protected function casts(): array
    {
        return [
            'tujuan' => 'array',
            'dibaca_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function prunable(): Builder
    {
        return static::where('created_at', '<', now()->subDays(self::SIMPAN_HARI));
    }
}
