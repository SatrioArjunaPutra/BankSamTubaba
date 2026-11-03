export function unduhCsv(kolom, baris, nama) {
  const cell=v=>'"'+String(v??'').replace(/^[=+@-]/,"'$&").replaceAll('"','""')+'"';
  const blob=new Blob(['\uFEFF'+[kolom,...baris].map(r=>r.map(cell).join(',')).join('\r\n')],{type:'text/csv;charset=utf-8'});
  const url=URL.createObjectURL(blob); const a=document.createElement('a'); a.href=url; a.download=nama+'.csv'; a.click(); setTimeout(()=>URL.revokeObjectURL(url),1000);
}
