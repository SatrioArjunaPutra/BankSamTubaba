<?php

namespace App\Http\Requests\Bs;

use App\Http\Requests\RegisterRequest;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rules\Password;

/**
 * POST /bs/bentor: buat akun driver. Jika plat_nomor diisi, armadanya
 * sekalian dibuat.
 */
class BuatBentorRequest extends FormRequest
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
            'name' => ['required', 'string', 'max:100'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'phone' => ['required', 'string', 'regex:'.RegisterRequest::POLA_HP],
            'password' => ['required', 'string', 'confirmed', Password::min(8)],
            'plat_nomor' => ['nullable', 'string', 'max:20'],
            'kapasitas_kg' => ['nullable', 'numeric', 'gt:0', 'max:10000', 'decimal:0,2'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return ['phone.regex' => 'Nomor HP harus diawali 08, 628, atau +628 (contoh 081234567890).'];
    }

    /**
     * @return array<string, string>
     */
    public function attributes(): array
    {
        return ['plat_nomor' => 'plat nomor', 'kapasitas_kg' => 'kapasitas'];
    }
}
