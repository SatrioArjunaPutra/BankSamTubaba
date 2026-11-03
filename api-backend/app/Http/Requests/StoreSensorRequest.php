<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreSensorRequest extends FormRequest
{
    /**
     * Perangkat sudah diverifikasi oleh middleware 'device.auth'.
     */
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
            'device_id' => ['required', 'string', 'max:50'],
            'volume_percentage' => ['required', 'numeric', 'between:0,100'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'device_id.required' => 'device_id wajib dikirim.',
            'device_id.max' => 'device_id maksimal 50 karakter.',
            'volume_percentage.required' => 'Persentase volume wajib dikirim.',
            'volume_percentage.numeric' => 'Persentase volume harus berupa angka.',
            'volume_percentage.between' => 'Persentase volume harus antara 0 sampai 100.',
        ];
    }
}
