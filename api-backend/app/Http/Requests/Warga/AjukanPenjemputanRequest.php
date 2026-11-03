<?php

namespace App\Http\Requests\Warga;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class AjukanPenjemputanRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, \Illuminate\Contracts\Validation\ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'bank_sampah_id' => ['required', 'integer', Rule::exists('bank_sampah', 'id')->where('is_aktif', true)],
            'alamat' => ['required', 'string', 'max:255'],
            'lat' => ['required', 'numeric', 'between:-90,90'],
            'lng' => ['required', 'numeric', 'between:-180,180'],
            'perkiraan_kg' => ['nullable', 'numeric', 'gt:0', 'max:1000', 'decimal:0,2'],
            'catatan' => ['nullable', 'string', 'max:500'],
            'foto' => ['nullable', 'file', 'mimes:jpg,jpeg,png,webp', 'max:2048'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function attributes(): array
    {
        return ['bank_sampah_id' => 'bank sampah', 'perkiraan_kg' => 'perkiraan berat', 'foto' => 'foto'];
    }
}
