#!/usr/bin/env node
/**
 * Test the binder's price matching against real TCG Corner data.
 *
 *   node test-prices.js ../ygo_binder.html tcgc-prices.json
 *
 * Loads the app's own code (no copy-paste, so it always tests what ships),
 * feeds it the price list, then checks known cards and reports anomalies.
 */
require('./domstub.js');
const fs = require('fs');

const htmlPath   = process.argv[2] || '../ygo_binder.html';
const pricesPath = process.argv[3] || 'tcgc-prices.json';

const src = fs.readFileSync(htmlPath, 'utf8').match(/<script>([\s\S]*)<\/script>/)[1];
global.fetch = async () => ({ ok: false });          // no network during tests

// EXPECTED: cards you have checked on the site by hand. Add your own.
const EXPECTED = [
  { name: 'Ash Blossom & Joyous Spring', set: 'RC04', rarity: 'UtR',  peso: 1260.81 },
  { name: 'Ash Blossom & Joyous Spring', set: 'RC04', rarity: 'UR',   peso: 252.16  },
  { name: 'Ash Blossom & Joyous Spring', set: 'RC04', rarity: 'ScR',  peso: 945.61  },
  { name: 'Ash Blossom & Joyous Spring', set: 'RC04', rarity: 'QCSR', peso: 11347.29 },
  { name: 'Ash Blossom & Joyous Spring', set: 'RC04', rarity: 'CR',   peso: 1134.73 },
  { name: 'Ash Blossom & Joyous Spring', set: 'RC04', rarity: 'ExSR', peso: 1576.01 },
  { name: 'Ash Blossom & Joyous Spring', set: 'RC04', rarity: 'HGR',  peso: 8825.67 },
  { name: 'Droll & Lock Bird',           set: 'ES02', rarity: 'UtR',  peso: 1765.13 },
  { name: 'Droll & Lock Bird',           set: 'ES02', rarity: 'UR',   peso: 630.40  },
  { name: 'Droll & Lock Bird',           set: 'ES02', rarity: 'ScR',  peso: 1134.73 },
];

let api;
const probe = `global.__api={tcgcMatch,copyValue,indexPrices,guessCurrency,aeSets,parseTitle,ourRar,
  get PX_ROWS(){return PX_ROWS},
  set PX_CUR(v){PX_CUR=v}, get PX_CUR(){return PX_CUR},
  get PX(){return PX}, get PX_NAME(){return PX_NAME}, get DB(){return DB}};`;
new Function(src + probe)();
api = global.__api;

const file = JSON.parse(fs.readFileSync(pricesPath, 'utf8'));
const rows = file.rows || file;
api.indexPrices(rows);
api.PX_CUR = file.cur || api.guessCurrency(rows);
api.DB.fx = 58;

console.log(`\nloaded ${rows.length} rows · currency ${api.PX_CUR} · ${Object.keys(api.PX).length} unique codes`);
console.log(`AE sets found: ${api.aeSets().size}\n`);

let fails = 0;
for (const t of EXPECTED) {
  const card = { name: t.name, usd: 0 };
  const got = api.copyValue({ set: t.set, rarity: t.rarity, qty: 1 }, card);
  const m = api.tcgcMatch({ set: t.set, rarity: t.rarity }, card);
  const ok = Math.abs(got - t.peso) < 1;
  if (!ok) fails++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${t.name} [${t.set} ${t.rarity}]`);
  console.log(`      expected ${t.peso}   got ${got}   ${m ? `via ${m.how} ${m.code}${m.cond ? ' (played)' : ''}` : 'NO MATCH'}`);
}

// anomalies worth eyeballing
const codes = Object.keys(api.PX);
const dear = codes.map(c => [c, api.PX[c]]).sort((a, b) => b[1] - a[1]).slice(0, 5);
const rarTags = {};
rows.forEach(r => { const k = r[3] || '(none)'; rarTags[k] = (rarTags[k] || 0) + 1; });

console.log(`\nrarity tags in the feed: ${Object.entries(rarTags).sort((a,b)=>b[1]-a[1]).map(([k,v])=>`${k}:${v}`).join('  ')}`);
console.log(`priciest: ${dear.map(([c,p])=>`${c} ${p}`).join(', ')}`);
console.log(`\n${fails ? fails + ' FAILURES' : 'all checks passed'}\n`);
process.exit(fails ? 1 : 0);
