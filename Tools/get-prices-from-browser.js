/* ============================================================
   Fallback: no Node needed.

   1. Open  https://tcg-corner.com  in Chrome
   2. F12 (or Cmd+Opt+I)  ->  Console tab
   3. Paste this whole file, press Enter, wait for the download
   4. Load the file into the binder:  Prices -> Import .json

   Running it on their own tab means no cross-site blocking.
   ============================================================ */
(async () => {
  const BASE = '/collections/yu-gi-oh-single-card-asia-english/products.json';
  const rows = [];
  const parseTitle = raw => {
    const m = String(raw || '').match(/^\s*([A-Z0-9]{2,6}-AE[SC]?\d{2,3})\s+(.*)$/i);
    if (!m) return null;
    let rest = m[2], rar = '';
    const st = raw.match(/\(\s*Status\s*([A-Za-z])\s*\)/i);
    let cond = st ? st[1].toUpperCase() : '';
    if (/damaged|\bDMG\b|played/i.test(raw)) cond = cond || 'D';
    const rm = rest.replace(/\(\s*Status[^)]*\)/ig, '').match(/\(([A-Za-z]{1,5})\)/);
    if (rm) rar = rm[1].toUpperCase();
    rest = rest.replace(/\((?:Status[^)]*|[A-Za-z]{1,5})\)/gi, '').trim();
    return { code: m[1].toUpperCase(), name: rest, rar, cond };
  };

  for (let page = 1; page <= 60; page++) {
    const res = await fetch(`${BASE}?limit=250&page=${page}`);
    if (!res.ok) break;
    const { products = [] } = await res.json();
    if (!products.length) break;
    for (const p of products) {
      const t = parseTitle(p.title);
      const price = parseFloat(((p.variants || [])[0] || {}).price);
      if (t && price > 0) rows.push([t.code, price, t.name, t.rar, t.cond]);
    }
    console.log(`page ${page}: ${rows.length} prices`);
    if (products.length < 250) break;
  }

  const vals = rows.map(r => r[1]).sort((a, b) => a - b);
  const cur = (vals[Math.floor(vals.length / 2)] || 0) > 60 ? 'PHP' : 'USD';
  const blob = new Blob([JSON.stringify({ t: new Date().toISOString().slice(0, 10), cur, rows })],
                        { type: 'application/json' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = 'tcgc-prices.json';
  a.click();
  console.log(`%c${rows.length} prices saved as tcgc-prices.json (${cur})`, 'color:#0a0;font-weight:bold');
})();
