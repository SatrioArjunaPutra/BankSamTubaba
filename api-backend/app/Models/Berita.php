<?php

namespace App\Models;

use App\Enums\KategoriBerita;
use App\Enums\StatusBerita;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Storage;

class Berita extends Model
{
    protected $table = 'berita';

    protected $fillable = ['judul', 'ringkasan', 'isi', 'kategori'];

    protected function casts(): array
    {
        return [
            'kategori' => KategoriBerita::class,
            'status' => StatusBerita::class,
            'diterbitkan_at' => 'datetime',
            'dibaca' => 'integer',
        ];
    }

    /** Hanya artikel berstatus terbit yang boleh tampil tanpa login. */
    public function scopeTerbit(Builder $query): Builder
    {
        return $query->where('status', StatusBerita::Terbit->value);
    }

    public function urlFoto(): ?string
    {
        return $this->foto_path ? Storage::disk(config('filesystems.upload_disk'))->url($this->foto_path) : null;
    }

    public function hapusFileFoto(): void
    {
        if ($this->foto_path) {
            Storage::disk(config('filesystems.upload_disk'))->delete($this->foto_path);
        }
    }
}
