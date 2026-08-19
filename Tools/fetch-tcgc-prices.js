#!/usr/bin/env node
/**
 * Pull the TCG Corner Asia-English singles list into tcgc-prices.json
 *
 *   node fetch-tcgc-prices.js
 *
 * No dependencies. Node 18+ (needs built-in fetch).
 * Output rows are [code, price, name, rarity, condition] — the same shape the
 * binder app imports, so you can feed it straight into Prices > Import.
 */
const fs = require('fs');

const COLLECTION = 'yu-gi-oh-single-card-asia-english';
const BASE = `https://tcg-corner.com/collections/${COLLECTION}/products.json`;
const OUT = 'tcgc-prices.json';

function parseTitle(raw) {
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
}

(async () => {
  const rows = [];
  let skipped = 0;
  for (let page = 1; page <= 60; page++) {
    const url = `${BASE}?limit=250&page=${page}`;
    process.stdout.write(`page ${page}… `);
    const res = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
    if (!res.ok) { console.log(`HTTP ${res.status} — stopping`); break; }
    const { products = [] } = await res.json();
    if (!products.length) { console.log('empty — done'); break; }
    for (const p of products) {
      const t = parseTitle(p.title);
      if (!t) { skipped++; continue; }
      const v = (p.variants || [])[0] || {};
      const price = parseFloat(v.price);
      if (!price || price <= 0) { skipped++; continue; }
      rows.push([t.code, price, t.name, t.rar, t.cond]);
    }
    console.log(`${products.length} products, ${rows.length} priced so far`);
    if (products.length < 250) break;
    await new Promise(r => setTimeout(r, 400));   // be polite to their server
  }

  // guess the currency the same way the app does
  const vals = rows.map(r => r[1]).sort((a, b) => a - b);
  const median = vals[Math.floor(vals.length / 2)] || 0;
  const cur = median > 60 ? 'PHP' : 'USD';

  const out = { t: new Date().toISOString().slice(0, 10), cur, rows };
  fs.writeFileSync(OUT, JSON.stringify(out));
  console.log(`\n${rows.length} prices -> ${OUT}  (currency looks like ${cur}, median ${median})`);
  if (skipped) console.log(`${skipped} listings skipped (no AE code or no price)`);
})();
