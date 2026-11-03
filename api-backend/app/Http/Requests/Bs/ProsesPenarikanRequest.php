<?php

namespace App\Http\Requests\Bs;

use Illuminate\Foundation\Http\FormRequest;

class ProsesPenarikanRequest extends FormRequest
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
            'aksi' => ['required', 'in:setujui,tolak'],
            'catatan' => ['nullable', 'string', 'max:500'],
        ];
    }
}
