<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rules\Password;

/**
 * Pendaftaran mandiri, selalu sebagai warga (role tidak bisa dipilih).
 */
class RegisterRequest extends FormRequest
{
    public const POLA_HP = '/^(\+62|62|0)8[0-9]{7,12}$/';

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
            'phone' => ['required', 'string', 'regex:'.self::POLA_HP],
            'password' => ['required', 'string', 'confirmed', Password::min(8)],
            'alamat' => ['required', 'string', 'max:255'],
            'lat' => ['required', 'numeric', 'between:-90,90'],
            'lng' => ['required', 'numeric', 'between:-180,180'],
            'device_name' => ['nullable', 'string', 'max:100'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'phone.regex' => 'Nomor HP harus diawali 08, 628, atau +628 (contoh 081234567890).',
            'lat.required' => 'Tandai titik rumah Anda di peta.',
            'lng.required' => 'Tandai titik rumah Anda di peta.',
        ];
    }
}
