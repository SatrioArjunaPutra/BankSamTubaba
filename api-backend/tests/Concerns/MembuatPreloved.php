<?php

namespace Tests\Concerns;

use App\Enums\StatusPreloved;
use App\Models\PrelovedItem;
use App\Models\User;

trait MembuatPreloved
{
    protected function barang(User $penjual, array $ubah = [], StatusPreloved $status = StatusPreloved::Tersedia): PrelovedItem
    {
        $barang = new PrelovedItem($ubah + [
            'judul' => 'Kursi rotan',
            'deskripsi' => 'Masih kokoh, cocok untuk teras.',
            'kategori' => 'Perabot',
            'kondisi' => 'bekas_baik',
            'harga' => 150000,
            'kecamatan' => 'Tumijajar',
        ]);
        $barang->penjual_id = $penjual->id;
        $barang->status = $status;
        $barang->foto = ['preloved/contoh.jpg'];
        $barang->save();

        return $barang;
    }
}
