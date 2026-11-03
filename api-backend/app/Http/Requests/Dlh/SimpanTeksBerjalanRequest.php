<?php

namespace App\Http\Requests\Dlh;

use Illuminate\Foundation\Http\FormRequest;

/**
 * POST /dlh/teks-berjalan dan PATCH /dlh/teks-berjalan/{id}.
 */
class SimpanTeksBerjalanRequest extends FormRequest
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
            'teks' => [$this->route('teksBerjalan') ? 'sometimes' : 'required', 'required', 'string', 'max:200'],
            'urutan' => ['sometimes', 'integer', 'min:0', 'max:9999'],
            'is_aktif' => ['sometimes', 'boolean'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function attributes(): array
    {
        return ['teks' => 'teks', 'urutan' => 'urutan', 'is_aktif' => 'status tayang'];
    }
}
