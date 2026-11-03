<?php

namespace App\Http\Requests\Preloved;

use Illuminate\Foundation\Http\FormRequest;

class KirimPesanRequest extends FormRequest
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
            'isi' => ['nullable', 'string', 'max:1000', 'required_without:tawaran_harga'],
            'tawaran_harga' => ['nullable', 'numeric', 'gt:0', 'max:1000000000', 'decimal:0,2', 'required_without:isi'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'isi.required_without' => 'Isi pesan atau tawaran harga wajib diisi.',
            'tawaran_harga.required_without' => 'Isi pesan atau tawaran harga wajib diisi.',
        ];
    }

    /**
     * @return array<string, string>
     */
    public function attributes(): array
    {
        return ['isi' => 'isi pesan', 'tawaran_harga' => 'tawaran harga'];
    }
}
