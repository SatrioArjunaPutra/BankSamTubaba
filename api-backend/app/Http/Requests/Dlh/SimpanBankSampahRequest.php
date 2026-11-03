<?php

namespace App\Http\Requests\Dlh;

use App\Http\Requests\RegisterRequest;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * Tambah (POST) dan ubah sebagian (PATCH) bank sampah oleh DLH.
 */
class SimpanBankSampahRequest extends FormRequest
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
        $bankSampah = $this->route('bankSampah');
        // Saat PATCH semua field opsional, tapi jika dikirim tetap wajib valid
        $wajib = $bankSampah ? ['sometimes', 'required'] : ['required'];

        return [
            // Kosong saat tambah = dibuat otomatis (BS-TUBABA-xx berikutnya)
            'kode' => ['sometimes', 'required', 'string', 'max:30', Rule::unique('bank_sampah', 'kode')->ignore($bankSampah)],
            'nama' => [...$wajib, 'string', 'max:150'],
            'tiyuh' => [...$wajib, 'string', 'max:100'],
            'kecamatan' => [...$wajib, 'string', 'max:100'],
            'alamat' => ['sometimes', 'nullable', 'string', 'max:255'],
            'lat' => ['nullable', 'numeric', 'between:-90,90', 'required_with:lng'],
            'lng' => ['nullable', 'numeric', 'between:-180,180', 'required_with:lat'],
            'no_hp_publik' => ['sometimes', 'nullable', 'string', 'regex:'.RegisterRequest::POLA_HP],
            'is_aktif' => ['sometimes', 'boolean'],
        ];
    }
}
