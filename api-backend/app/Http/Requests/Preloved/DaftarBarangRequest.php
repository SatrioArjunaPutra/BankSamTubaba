<?php

namespace App\Http\Requests\Preloved;

use App\Enums\KondisiBarang;
use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class DaftarBarangRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'q' => ['nullable', 'string', 'max:100'],
            'kategori' => ['nullable', 'string', 'max:50'],
            'kecamatan' => ['nullable', 'string', 'max:100'],
            'kondisi' => ['nullable', Rule::enum(KondisiBarang::class)],
            'urut' => ['nullable', 'in:terbaru,termurah,termahal'],
            'page' => ['nullable', 'integer', 'min:1'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function attributes(): array
    {
        return ['q' => 'kata kunci', 'urut' => 'urutan'];
    }
}
