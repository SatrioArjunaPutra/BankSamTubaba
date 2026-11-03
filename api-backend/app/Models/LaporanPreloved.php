<?php

namespace App\Models;

use App\Enums\StatusLaporan;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class LaporanPreloved extends Model
{
    protected $table = 'laporan_preloved';

    protected $fillable = ['preloved_item_id', 'pelapor_id', 'alasan'];

    protected function casts(): array
    {
        return [
            'status' => StatusLaporan::class,
        ];
    }

    public function item(): BelongsTo
    {
        return $this->belongsTo(PrelovedItem::class, 'preloved_item_id');
    }

    public function pelapor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'pelapor_id');
    }
}
