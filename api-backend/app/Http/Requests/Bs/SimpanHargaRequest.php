<?php

namespace App\Http\Requests\Bs;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * PUT /bs/harga: {"harga": [{"jenis_sampah_id": 1, "harga_per_kg": 3000}, ...]}
 */
class SimpanHargaRequest extends FormRequest
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
            'harga' => ['required', 'array', 'min:1', 'max:100'],
            'harga.*.jenis_sampah_id' => ['required', 'integer', 'distinct', Rule::exists('jenis_sampah', 'id')->where('is_aktif', true)],
            'harga.*.harga_per_kg' => ['required', 'numeric', 'gte:0', 'max:10000000', 'decimal:0,2'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function attributes(): array
    {
        return ['harga.*.jenis_sampah_id' => 'jenis sampah', 'harga.*.harga_per_kg' => 'harga per kg'];
    }
}
