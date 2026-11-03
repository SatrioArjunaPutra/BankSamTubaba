<?php

namespace App\Http\Requests\Bs;

use App\Enums\StatusArmada;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * POST /bs/armada (driver_id wajib) dan PATCH /bs/armada/{id} (sebagian).
 * Kepemilikan driver dicek di controller (harus bentor bank yang sama).
 */
class SimpanArmadaRequest extends FormRequest
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
        $baru = $this->route('armada') === null;

        return [
            'driver_id' => $baru ? ['required', 'integer', 'unique:armada,driver_id'] : ['prohibited'],
            'plat_nomor' => [$baru ? 'required' : 'sometimes', 'string', 'max:20'],
            'kapasitas_kg' => ['sometimes', 'nullable', 'numeric', 'gt:0', 'max:10000', 'decimal:0,2'],
            'status' => ['sometimes', Rule::enum(StatusArmada::class)],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return ['driver_id.unique' => 'Driver ini sudah memiliki armada.'];
    }

    /**
     * @return array<string, string>
     */
    public function attributes(): array
    {
        return ['driver_id' => 'driver', 'plat_nomor' => 'plat nomor', 'kapasitas_kg' => 'kapasitas'];
    }
}
