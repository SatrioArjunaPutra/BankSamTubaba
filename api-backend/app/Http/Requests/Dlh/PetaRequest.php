<?php

namespace App\Http\Requests\Dlh;

use App\Enums\UserRole;

class PetaRequest extends KinerjaRequest
{
    public function authorize(): bool
    {
        return $this->user()?->role === UserRole::Dlh;
    }

    public function rules(): array
    {
        return parent::rules() + [
            'q' => ['nullable', 'string', 'max:100'],
            'kecamatan' => ['nullable', 'string', 'max:100'],
            'tiyuh' => ['nullable', 'string', 'max:100'],
            'sumber' => ['nullable', 'in:registri,demo,semua'],
            'koordinat' => ['nullable', 'in:terisi,estimasi,kosong'],
            'is_aktif' => ['nullable', 'boolean'],
        ];
    }
}
