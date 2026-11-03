<?php

namespace App\Http\Requests\Bentor;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Dipakai untuk status tugas (menuju|diambil) dan status armada
 * (siaga|nonaktif); pilihan yang sah ditentukan oleh route.
 */
class UbahStatusRequest extends FormRequest
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
        $pilihan = $this->routeIs('bentor.armada.status') ? 'siaga,nonaktif' : 'menuju,diambil';

        return [
            'status' => ['required', 'in:'.$pilihan],
        ];
    }
}
