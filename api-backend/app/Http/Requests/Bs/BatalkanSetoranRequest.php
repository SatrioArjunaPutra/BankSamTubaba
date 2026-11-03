<?php

namespace App\Http\Requests\Bs;

use Illuminate\Foundation\Http\FormRequest;

class BatalkanSetoranRequest extends FormRequest
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
        return ['alasan' => ['required', 'string', 'min:3', 'max:500']];
    }

    /**
     * @return array<string, string>
     */
    public function attributes(): array
    {
        return ['alasan' => 'alasan pembatalan'];
    }
}
