<?php

namespace App\Http\Requests\Preloved;

use App\Enums\KondisiBarang;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * POST /preloved (multipart, foto[] 1–5) dan PATCH /preloved/{id}.
 *
 * Untuk mengganti foto saat ubah, kirim multipart lewat POST dengan
 * _method=PATCH (PHP tidak membaca multipart pada request PATCH asli).
 * Jika foto[] dikirim saat ubah, semua foto lama diganti.
 */
class SimpanBarangRequest extends FormRequest
{
    public const MAKS_FOTO = 5;

    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, \Illuminate\Contracts\Validation\ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        $wajib = $this->route('prelovedItem') ? ['sometimes', 'required'] : ['required'];

        return [
            'judul' => [...$wajib, 'string', 'max:100'],
            'deskripsi' => [...$wajib, 'string', 'max:2000'],
            'kategori' => [...$wajib, 'string', 'max:50'],
            'kondisi' => [...$wajib, Rule::enum(KondisiBarang::class)],
            'harga' => [...$wajib, 'numeric', 'gt:0', 'max:1000000000', 'decimal:0,2'],
            'kecamatan' => [...$wajib, 'string', 'max:100'],
            'foto' => [...$wajib, 'array', 'min:1', 'max:'.self::MAKS_FOTO],
            'foto.*' => ['file', 'mimes:jpg,jpeg,png,webp', 'max:2048'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function attributes(): array
    {
        return ['foto.*' => 'foto', 'judul' => 'judul', 'deskripsi' => 'deskripsi', 'kategori' => 'kategori', 'kondisi' => 'kondisi', 'harga' => 'harga'];
    }
}
