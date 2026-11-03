<?php

namespace App\Http\Requests\Dlh;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class SimpanJenisSampahRequest extends FormRequest
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
        $jenisSampah = $this->route('jenisSampah');

        return [
            'nama' => [
                ...($jenisSampah ? ['sometimes', 'required'] : ['required']),
                'string',
                'max:100',
                Rule::unique('jenis_sampah', 'nama')->ignore($jenisSampah),
            ],
            'satuan' => ['sometimes', 'required', 'string', 'max:20'],
            'is_aktif' => ['sometimes', 'boolean'],
        ];
    }
}
