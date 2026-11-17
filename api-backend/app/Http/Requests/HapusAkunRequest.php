<?php

namespace App\Http\Requests;

use App\Enums\UserRole;
use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;

class HapusAkunRequest extends FormRequest
{
    /**
     * Akun petugas dikelola oleh pengelola bank sampah atau DLH, bukan dihapus sendiri.
     */
    public function authorize(): bool
    {
        return $this->user()?->hasRole(UserRole::Warga) ?? false;
    }

    /**
     * @return array<string, ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'password' => ['required', 'string', 'current_password:sanctum'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'password.current_password' => 'Password salah.',
        ];
    }

    protected function failedAuthorization(): void
    {
        abort(response()->json([
            'status' => 'gagal',
            'pesan' => 'Akun petugas hanya bisa dihapus oleh pengelola bank sampah atau DLH.',
        ], 403));
    }
}
