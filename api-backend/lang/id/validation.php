<?php

/*
|--------------------------------------------------------------------------
| Pesan validasi Bahasa Indonesia
|--------------------------------------------------------------------------
|
| Hanya aturan yang dipakai aplikasi ini; aturan lain jatuh ke bahasa
| fallback (en). Nama field diterjemahkan lewat 'attributes'.
|
*/

return [

    'accepted' => ':Attribute harus disetujui.',
    'after' => ':Attribute harus setelah :date.',
    'after_or_equal' => ':Attribute harus sama dengan atau setelah :date.',
    'array' => ':Attribute harus berupa daftar.',
    'before' => ':Attribute harus sebelum :date.',
    'before_or_equal' => ':Attribute harus sama dengan atau sebelum :date.',
    'between' => [
        'array' => ':Attribute harus berisi :min sampai :max item.',
        'file' => ':Attribute harus berukuran :min sampai :max kilobyte.',
        'numeric' => ':Attribute harus bernilai :min sampai :max.',
        'string' => ':Attribute harus terdiri dari :min sampai :max karakter.',
    ],
    'boolean' => ':Attribute harus bernilai benar atau salah.',
    'confirmed' => 'Konfirmasi :attribute tidak cocok.',
    'current_password' => 'Password lama salah.',
    'date' => ':Attribute bukan tanggal yang valid.',
    'date_format' => ':Attribute harus berformat :format.',
    'decimal' => ':Attribute maksimal :decimal angka di belakang koma.',
    'different' => ':Attribute harus berbeda dengan :other.',
    'distinct' => ':Attribute tidak boleh duplikat.',
    'email' => 'Format :attribute tidak valid.',
    'enum' => ':Attribute yang dipilih tidak valid.',
    'exists' => ':Attribute tidak ditemukan.',
    'file' => ':Attribute harus berupa file.',
    'gt' => [
        'numeric' => ':Attribute harus lebih dari :value.',
    ],
    'gte' => [
        'numeric' => ':Attribute minimal :value.',
    ],
    'image' => ':Attribute harus berupa gambar.',
    'in' => ':Attribute yang dipilih tidak valid.',
    'integer' => ':Attribute harus berupa bilangan bulat.',
    'lt' => [
        'numeric' => ':Attribute harus kurang dari :value.',
    ],
    'lte' => [
        'numeric' => ':Attribute maksimal :value.',
    ],
    'max' => [
        'array' => ':Attribute maksimal berisi :max item.',
        'file' => ':Attribute maksimal :max kilobyte.',
        'numeric' => ':Attribute maksimal :max.',
        'string' => ':Attribute maksimal :max karakter.',
    ],
    'mimes' => ':Attribute harus berupa file bertipe: :values.',
    'min' => [
        'array' => ':Attribute minimal berisi :min item.',
        'file' => ':Attribute minimal :min kilobyte.',
        'numeric' => ':Attribute minimal :min.',
        'string' => ':Attribute minimal :min karakter.',
    ],
    'numeric' => ':Attribute harus berupa angka.',
    'password' => [
        'letters' => ':Attribute harus mengandung huruf.',
        'mixed' => ':Attribute harus mengandung huruf besar dan huruf kecil.',
        'numbers' => ':Attribute harus mengandung angka.',
        'symbols' => ':Attribute harus mengandung simbol.',
        'uncompromised' => ':Attribute ini pernah bocor di internet. Gunakan :attribute lain.',
    ],
    'present' => ':Attribute wajib ada.',
    'prohibited' => ':Attribute tidak boleh diisi.',
    'regex' => 'Format :attribute tidak valid.',
    'required' => ':Attribute wajib diisi.',
    'required_if' => ':Attribute wajib diisi jika :other bernilai :value.',
    'required_with' => ':Attribute wajib diisi jika :values diisi.',
    'required_without' => ':Attribute wajib diisi jika :values tidak diisi.',
    'string' => ':Attribute harus berupa teks.',
    'unique' => ':Attribute sudah terdaftar.',
    'uploaded' => ':Attribute gagal diunggah.',

    'attributes' => [
        'name' => 'nama',
        'nama' => 'nama',
        'email' => 'email',
        'phone' => 'nomor HP',
        'password' => 'password',
        'password_lama' => 'password lama',
        'alamat' => 'alamat',
        'lat' => 'latitude',
        'lng' => 'longitude',
        'radius_km' => 'radius',
        'kode' => 'kode',
        'tiyuh' => 'tiyuh',
        'kecamatan' => 'kecamatan',
        'no_hp_publik' => 'nomor HP publik',
        'is_aktif' => 'status aktif',
        'satuan' => 'satuan',
        'device_name' => 'nama perangkat',
    ],

];
