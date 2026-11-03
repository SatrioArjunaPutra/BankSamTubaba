<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;

class PetaBankSampahResource extends BankSampahResource
{
    public function toArray(Request $request): array
    {
        return parent::toArray($request) + [
            'sumber' => str_starts_with($this->kode, 'BS-DEMO-') ? 'demo' : 'registri',
            'total_kg' => (float) $this->total_kg,
            'kg_donasi' => (float) $this->kg_donasi,
            'nilai_setoran' => (float) $this->nilai_setoran,
            'jemput_aktif' => (int) $this->jemput_aktif,
        ];
    }
}
