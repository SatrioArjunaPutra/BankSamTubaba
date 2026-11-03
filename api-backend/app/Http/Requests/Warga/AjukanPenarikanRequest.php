<?php

namespace App\Http\Requests\Warga;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class AjukanPenarikanRequest extends FormRequest
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
            // Bank nonaktif tidak punya operator yang bisa memproses penarikan
            'bank_sampah_id' => ['required', 'integer', Rule::exists('bank_sampah', 'id')->where('is_aktif', true)],
            'jumlah' => ['required', 'numeric', 'gt:0', 'max:100000000', 'decimal:0,2'],
            'catatan' => ['nullable', 'string', 'max:500'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function attributes(): array
    {
        return ['bank_sampah_id' => 'bank sampah', 'jumlah' => 'jumlah penarikan'];
    }
}
