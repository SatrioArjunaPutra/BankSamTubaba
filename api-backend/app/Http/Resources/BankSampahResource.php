<?php

namespace App\Http\Resources;

use App\Models\BankSampah;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin BankSampah
 */
class BankSampahResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'kode' => $this->kode,
            'nama' => $this->nama,
            'tiyuh' => $this->tiyuh,
            'kecamatan' => $this->kecamatan,
            'alamat' => $this->alamat,
            'lat' => $this->lat,
            'lng' => $this->lng,
            'koordinat_estimasi' => $this->koordinat_estimasi,
            'no_hp_publik' => $this->no_hp_publik,
            'is_aktif' => $this->is_aktif,
            // Hanya ada pada hasil /bank-sampah/nearby
            'jarak_km' => $this->when(isset($this->jarak_km), fn () => $this->jarak_km),
            'harga' => HargaSampahResource::collection($this->whenLoaded('harga')),
            'jumlah_operator' => $this->whenCounted('operator'),
            'sampah_bulan_ini_kg' => $this->when(isset($this->sampah_bulan_ini_kg), fn () => (float) $this->sampah_bulan_ini_kg),
            'jumlah_nasabah' => $this->when(isset($this->jumlah_nasabah), fn () => (int) $this->jumlah_nasabah),
            'jumlah_bentor' => $this->when(isset($this->jumlah_bentor), fn () => (int) $this->jumlah_bentor),
        ];
    }
}
