<?php

namespace App\Http\Requests\Dlh;

use App\Enums\UserRole;
use Illuminate\Contracts\Validation\ValidationRule;

class PantauanRequest extends KinerjaRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        return $this->user()?->hasRole(UserRole::Dlh) ?? false;
    }

    /**
     * Get the validation rules that apply to the request.
     *
     * @return array<string, ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return parent::rules() + [
            'q' => ['nullable', 'string', 'max:100'],
            'bank_sampah_id' => ['nullable', 'integer', 'exists:bank_sampah,id'],
            'tipe' => ['nullable', 'in:jual,donasi,penarikan'],
            'status' => ['nullable', 'in:aktif,nonaktif,siaga,terjadwal,bertugas'],
            'page' => ['nullable', 'integer', 'min:1'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ];
    }
}
