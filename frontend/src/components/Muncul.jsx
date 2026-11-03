import { useEffect, useRef, useState } from 'react';

// Isi muncul perlahan saat mulai masuk layar, sekali saja. urutan memberi jeda antarkartu sebaris.
export default function Muncul({ as: Tag = 'div', urutan = 0, className = '', children, ...props }) {
  const elemen = useRef(null);
  const [terlihat, setTerlihat] = useState(false);

  useEffect(() => {
    const pengamat = new IntersectionObserver(([masuk]) => {
      if (masuk.isIntersecting) {
        setTerlihat(true);
        pengamat.disconnect();
      }
    }, { rootMargin: '0px 0px -6% 0px' });
    pengamat.observe(elemen.current);
    return () => pengamat.disconnect();
  }, []);

  return (
    <Tag ref={elemen} className={`muncul ${terlihat ? 'terlihat' : ''} ${className}`} style={{ '--urutan': urutan }} {...props}>
      {children}
    </Tag>
  );
}
