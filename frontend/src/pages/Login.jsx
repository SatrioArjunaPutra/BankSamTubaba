import { useState } from 'react';
import { Eye, EyeOff } from 'lucide-react';
import { login, logout, token } from '../services/api';
import { Field, Input, Modal, Tombol } from '../components/ui';
import LogoAplikasi from '../components/LogoAplikasi';

export default function Login({ onMasuk, onTutup, pesanAwal }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [galat, setGalat] = useState(pesanAwal || '');
  const [galatField, setGalatField] = useState({});
  const [lihatSandi, setLihatSandi] = useState(false);

  const kirim = async (e) => {
    e.preventDefault();
    setLoading(true);
    setGalat('');
    setGalatField({});

    try {
      const { data } = await login(email, password);

      // Web ini khusus DLH; token role lain langsung dicabut
      if (data.user.role !== 'dlh') {
        await logout(data.token).catch(() => {});
        setGalat('Akun ini bukan akun DLH. Operator, bentor, dan warga menggunakan aplikasi mobile.');
        return;
      }

      token.simpan(data.token);
      onMasuk(data.user);
    } catch (err) {
      setGalat(err.message);
      setGalatField(err.pesanField ?? {});
    } finally {
      setLoading(false);
    }
  };

  return (
    <Modal
      judul="Masuk ke panel DLH"
      keterangan="Gunakan akun dinas yang diberikan administrator."
      logo={<span className="login-logo"><LogoAplikasi /></span>}
      onTutup={onTutup}
      lebar="max-w-md"
    >
      <form onSubmit={kirim} className="login-form">
        {galat && (
          <div role="alert" className="text-sm rounded-md border px-3 py-2 bg-red-500/10 border-red-500/30 text-red-700 dark:text-red-300">
            {galat}
          </div>
        )}

        <Field label="Email dinas" error={galatField.email}>
          <Input data-fokus-awal type="email" autoComplete="username" placeholder="nama@dinas.go.id" required value={email} onChange={(e) => setEmail(e.target.value)} />
        </Field>
        <div>
          <label className="field-label" htmlFor="login-password">Kata sandi</label>
          <div className="login-sandi">
            <Input id="login-password" type={lihatSandi ? 'text' : 'password'} autoComplete="current-password" required value={password} onChange={(e) => setPassword(e.target.value)} />
            <button type="button" className="password-toggle" aria-label={lihatSandi ? 'Sembunyikan kata sandi' : 'Tampilkan kata sandi'} onClick={() => setLihatSandi(!lihatSandi)}>
              {lihatSandi ? <EyeOff size={17} /> : <Eye size={17} />}
            </button>
          </div>
          {galatField.password && <p className="text-xs text-red-600 mt-1">{galatField.password}</p>}
        </div>

        <Tombol type="submit" loading={loading} className="login-submit w-full">Masuk</Tombol>
        <p className="login-help">Pengelola bank sampah, bentor, dan warga masuk melalui aplikasi mobile. Lupa kata sandi? Hubungi administrator sistem DLH.</p>
      </form>
    </Modal>
  );
}
