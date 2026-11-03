<?php

namespace App\Http\Requests\Bs;

use Illuminate\Foundation\Http\FormRequest;

/**
 * PATCH /bs/penjemputan/{id}: {aksi: jadwalkan|tolak, armada_id?, jadwal_at?, alasan?}
 */
class ProsesPenjemputanRequest extends FormRequest
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
            'aksi' => ['required', 'in:jadwalkan,tolak'],
            'armada_id' => ['required_if:aksi,jadwalkan', 'nullable', 'integer'],
            'jadwal_at' => ['required_if:aksi,jadwalkan', 'nullable', 'date'],
            'alasan' => ['required_if:aksi,tolak', 'nullable', 'string', 'max:255'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function attributes(): array
    {
        return ['armada_id' => 'armada', 'jadwal_at' => 'jadwal', 'alasan' => 'alasan'];
    }
}
