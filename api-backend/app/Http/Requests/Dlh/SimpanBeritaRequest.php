<?php

namespace App\Http\Requests\Dlh;

use App\Enums\KategoriBerita;
use App\Enums\StatusBerita;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * POST /dlh/berita dan PATCH /dlh/berita/{id}. Untuk mengganti foto saat ubah,
 * kirim multipart lewat POST dengan _method=PATCH.
 */
class SimpanBeritaRequest extends FormRequest
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
        $wajib = $this->route('berita') ? ['sometimes', 'required'] : ['required'];

        return [
            'judul' => [...$wajib, 'string', 'max:150'],
            'ringkasan' => [...$wajib, 'string', 'max:300'],
            'isi' => [...$wajib, 'string', 'max:20000'],
            'kategori' => [...$wajib, Rule::enum(KategoriBerita::class)],
            'status' => [...$wajib, Rule::enum(StatusBerita::class)],
            'foto' => ['nullable', 'file', 'mimes:jpg,jpeg,png,webp', 'max:2048'],
            'hapus_foto' => ['sometimes', 'boolean'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function attributes(): array
    {
        return ['judul' => 'judul', 'ringkasan' => 'ringkasan', 'isi' => 'isi berita', 'kategori' => 'kategori', 'status' => 'status', 'foto' => 'foto'];
    }
}
