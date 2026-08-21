# Binder tools

Three small scripts: two that get TCG Corner's price list out, one that tests
the binder's price matching against it. No dependencies.

## 1. Get the price list

**Easiest — no install.** Open <https://tcg-corner.com> in Chrome, press F12,
open the **Console** tab, paste the whole of `get-prices-from-browser.js` and
press Enter. It pages through their catalogue and downloads `tcgc-prices.json`.
Running it on their own tab means nothing can block it.

**Or with Node** (18+, for `fetch`):

```bash
node fetch-tcgc-prices.js
```

**Or from the app itself:** Prices → Sync, then Export .json. *(Export is
currently disabled — see the warning under "Load it back".)*

All three produce the same file:

```json
{ "t": "2026-08-18", "cur": "PHP",
  "rows": [ ["ES02-AE005", 1765.13, "Droll & Lock Bird", "UL", ""] ] }
```

`rows` are `[code, price, name, rarity, condition]`. Condition is `""` for a
clean copy, or a letter for played/damaged stock — that distinction matters,
because a `(Status B)` listing can be a third of the clean price.

## 2. Load it back

Prices → **Import .json**.

> ⚠️ **Do not use "Copy as code" or "Export .json" to re-bake.** Both are
> disabled in the app as of 2026-08-19. They build their output from
> `Object.keys(PX)`, one row per card code — but 1,283 codes hold more than one
> printing, so the 7,277-row list collapses to 4,584. That silently drops 2,693
> printings and breaks rarity matching, which is the whole basis of the match
> key. Re-enable only once both emit from `PX_ROWS` and `pricesAsCode()` also
> writes `BAKED_CUR`.

To hardwire a new list until then, use the browser scraper in step 1 and paste
its `rows` over the `BAKED_PRICES` array between the `BAKED_PRICES_START` /
`BAKED_PRICES_END` markers near the top of the HTML.

## 3. Test the matching

```bash
node test-prices.js ../ygo_binder.html tcgc-prices.json
```

It loads the app's own functions straight out of the HTML — so it tests what
actually ships, not a copy — then checks each card in the `EXPECTED` list at the
top of `test-prices.js`. Add cards you have price-checked by hand:

```js
{ name: 'Maxx "C"', set: 'RC04', rarity: 'ScR', peso: 2400.00 },
```

Output tells you the matched listing and how it was found (`code`,
`set + rarity`, or `rarity`), plus every rarity tag present in the feed — useful
for spotting tags the app does not yet map, which are the usual cause of a
wrong price.

## Why prices go wrong

Three causes so far, all now handled, all worth re-checking if a figure looks off:

1. **Currency** — their feed is in pesos; converting it again gives a figure
   58x too high. Prices panel has a PHP/USD toggle.
2. **Condition** — a `(Status B)` played copy undercutting the clean one.
   Clean listings now always win.
3. **Rarity** — the same card exists from Common to Prismatic Secret. A match
   now requires rarity agreement, and returns nothing rather than guessing.

## 4. The Asian-English catalogue

`ygo_binder.html` also carries a baked catalogue scraped from Yugipedia, between
the `AE_CATALOGUE_START` / `AE_CATALOGUE_END` markers: **71 sets, 6,569
printings, 5,792 distinct cards**.

TCG Corner can only ever tell you what it *stocks*. It cannot answer "does this
card have an Asian-English printing at all", which is why cards such as Dominus
Impulse were missing from the binder entirely. The catalogue answers that, and
gives real set sizes for the completion bars.

To rebuild it, page the Yugipedia API for the OCG-AE set lists:

```
https://yugipedia.com/api.php?action=query&list=allpages&apnamespace=3006&aplimit=500&format=json
```

Keep the titles ending `(OCG-AE)` (140 pages at the time of writing), then fetch
each page's wikitext in batches of 40 with
`action=query&prop=revisions&rvprop=content`. The card lines are
`CODE; Card Name; Rarity`. Encode as three tables — `AE_NAMES`, `AE_RARS` and
`AE_CAT` (`[setCode,[[num,nameIdx,rarIdx],…]]`) — which is what keeps it to
218 KB rather than 337 KB.

Two notes. Yugipedia refuses cross-origin requests, so this cannot be fetched
from the app itself; it has to be baked. And send a normal browser User-Agent —
the default one is blocked.

## 5. Moving a binder between devices

Two ways out of the app, for different jobs:

- **Transfer → Copy code** gives one unbroken `YGOB1.…` token you can paste into
  a note, email or chat and load on the other device. Only what you typed
  travels — copies, prices, conditions, binder assignment and deck membership.
  Card art, text and prices are rebuilt on arrival from the baked tables, so a
  three-card binder is ~430 characters and 500 cards is ~44 KB.
- **Transfer -> Save as file instead** writes the full `ygo-binder-YYYY-MM-DD.json`.
  Prefer it for large collections, since some chat apps truncate long messages.
  **Transfer -> Load a file instead** reads one back. Transfer is the only door:
  the separate Export and Import header icons were removed as of 2026-08-19,
  since all three routes now live in that one panel.

Both land in the same merge: a copy is the same copy when card, rarity, set and
binder all agree, and quantities take the higher of the two. Loading the same
code twice is a no-op, so it is safe to re-paste if you are unsure it took.

## 6. Binder mode

"View as a binder" in the sidebar hides the header, sidebar, dashboard and
board tabs, and gives the sheet the whole screen. It requests fullscreen, but
works without it — the request is refused in some embedded contexts and that is
not treated as an error.

The toolbar is **moved**, not duplicated, into a floating strip at the top:
`.binder>.bar` is reparented into `#bm-chrome` on entry and put back on exit.
That keeps every handler bound to the elements it was already bound to. The
strip stays off-screen until you sweep into the top 56px (`#bm-hot`), hover it,
tab into it, or — on a touch screen — tap the strip, which calls `bmPeek()`.

Three things must not depend on an animation running, because a page turn or a
reveal that never composites would otherwise strand the mode with no way out:

1. **Escape always exits**, whether or not the bar is on screen. The Exit
   button rides inside the moved bar, so it cannot be the only route.
2. **`fullscreenchange` exits too**, so leaving fullscreen by the browser's own
   chrome does not leave the app with its header hidden.
3. **The turning leaf removes itself** on `animationend` *and* on a 900ms
   timer behind it, so it can never be left standing on the page.

The leaf is decoration over a page that has already been redrawn — it carries
no card content, so if it never appears the collection still reads correctly.

## 7. The shareable sale page

The **Sale list** button saves `cards-for-sale-YYYY-MM-DD.html`: the binder as a
buyer sees it. Same sleeves, rarity rings and foil bands, same caption line, and
the same detail panel when a card is clicked - every copy held with its rarity,
set, condition and price - minus every control that would change anything. No
inputs, no Keep/Sell, no quantity steppers. A search box filters by card name,
set or rarity. About 13 KB for three cards.

**Card art is referenced by URL, not embedded.** Embedding would mean pulling
every image through a canvas at export time, which fails outright when the image
host sends no CORS header, and turns a 200-card list into several megabytes. A
URL that 404s costs one placeholder; a failed embed costs the whole file. Each
image carries an `onerror` fallback that keeps the card name readable, so a
missing picture degrades to a labelled box.

Prices are a snapshot, dated in the footer - the page fetches nothing.

One trap when editing the generator: the page own `<script>` is built inside a
`String.raw` template, so a backslash written there survives verbatim. An escape
meant for the emitted script needs a *single* backslash, not two.

## 8. How the price tables are encoded

Both price tables point into `AE_NAMES` rather than repeating card names.

- `BAKED_PRICES` is `[code, nameIndex, [[rarity, price], ...]]`. 4,346 of 4,584
  rows use an index; 238 keep a spelled-out name because their spelling is not
  in the catalogue (`Retaliating C`, `Spell Card Monster Reborn`, and similar).
  `expandBaked()` unfolds either form, so everything downstream sees a name.
- `PC_ROWS_RAW` is `[code, rarity, priceHKD, nameIndex]`, with a fifth element
  carrying the name where it did not match.

This is worth keeping if you rebuild either table. Spelling the names out costs
81 KB raw and, less obviously, 29 KB gzipped - a 3-4 digit index gives the
compressor less to chew on than a repeated string does.

## 9. Players Club HK, the second shop

A Shopify store whose Asian-English stock is already one collection, so the
whole catalogue comes from a single endpoint rather than a shop-wide crawl:

```
https://playersclubhk.com/en/collections/ygoae1/products.json?limit=250&page=N
```

18 pages, 4,275 products, 3,699 usable rows. Three things to know:

1. **Rarity is in the title, not a field.** `25AT-AE304 (SR)Lose 1 Turn`, or
   sometimes glued on: `DUNE-AE107(UR)`. Their abbreviations differ from ours -
   `UTR` is Ultimate, `SER` is Secret, `PSER` is Prismatic Secret, `QCSE` is
   Quarter Century. `NPR` and `AA` have no equivalent here and are dropped
   rather than filed under a rarity they are not.
2. **299 listings cover several rarities at one price** - `(UR/UTR/SER/QCSE)`.
   Those are skipped: one figure cannot be attributed to four printings.
3. **A title with no rarity marker is treated as the base printing.** The risk
   is contained, because matching is keyed on rarity: a listing recorded as
   Common can only ever price a Common copy.

Prices are HKD. The rate is **not** baked - `refreshRate()` already fetches
every currency in one call, so the HKD cross rate refreshes alongside the peso
one. A stale file therefore cannot quietly make one shop look cheaper. With no
rate available the shop is skipped rather than guessed at.

`bestMatch()` returns whichever shop is cheaper, in pesos, naming the winner so
a figure can be traced back to a listing.

## 10. Deals: cart, order codes and reservations

A buyer works through a shared binder, presses **Send an order**, and gets a
`YGOD1.â¦` code. They send it however they already chat; the seller pastes it
into **Deals** and it becomes a pending deal.

**Reservation is a quantity, not a flag.** A copy row keeps `qty: 5` while a
deal claims 3 of them. Nothing is moved or deleted, so postponing a deal is a
status change rather than an attempt to restore inventory exactly.

- `reservedQty(id, rarity, set)` counts only **ticked** items in **pending**
  deals. Untick a line or postpone a deal and those copies are free at once.
- `freeCopiesIn(id)` is deliberately separate from `copiesIn()`. The two dozen
  places asking "what do I own" keep the same answer; only the shared binder
  asks "what can I still offer".
- The deal helpers read `sellCopies()`, not `copiesIn()`. `copiesIn()` answers
  for whichever binder is open, which made reservations read as zero whenever
  the Collection happened to be on screen.

**Over-committing is never silent.** An order asking for more than is free
shows the clash and names the deals already holding those copies, then offers
"accept what is free" or "accept anyway". There is no server, so the app cannot
know who asked first - it puts the facts up and the seller decides.

Reserved copies still count towards Selling value and Total assets: they are
someone else's intention, not a sale. The dashboard shows them as a separate
"reserved" figure, and shared binders exclude them so the same card is never
promised to two people.

The seller's name and contact come from Settings and are baked into each
exported binder, which is what puts the "Message the seller" button on it.

## 11. OCG-JP, the second region

The app holds two collections that share nothing but a card pool. The switch
sits on the wordmark: **AE** for Asian-English, **JP** for Japanese OCG.

What is separate:

| | Asian-English | OCG-JP |
|---|---|---|
| Saved under | `ygo-binder-v1` | `ygo-binder-v1-ocg` |
| Catalogue | `AE_CAT`, 71 sets | `JP_CAT_RAW`, 223 sets |
| Prices | TCG Corner + Players Club | Yuyu-tei |
| Quoted in | USD / HKD, shown in pesos | yen, shown in pesos |
| Rarities | 11 | 19 |

Binder, collection, selling shelf, wishlist, deals and sales history are all
per region. Nothing merges across: a transfer code and an exported file each
carry the region they came from and are refused by the other side, because a
`ROTA-JP079` means nothing in an Asian-English binder.

### Scope

Japanese sets released **2020 onwards** — 224 prefixes off Yugipedia's
`Japanese release date`. Earlier sets are deliberately left out; adding them is
the same two harvests over a longer prefix list.

### Where the data comes from

**Yuyu-tei** (`yuyu-tei.jp/sell/ygo/s/<lowercase-prefix>`) is a plain
server-rendered site, not Shopify, and sends no CORS header — so prices are
baked, exactly as the other two shops are. One request returns a whole set.
Of the 224 sets, **130 are stocked**; the rest are promos they do not carry.

A set they have never stocked still answers with a generic 40-row page rather
than a 404, so a miss is detected by looking for the set's own `PREFIX-JP`
codes in the response. Without that check the harvest silently fills with
another set's cards.

The same code and rarity can be listed twice — a played copy beside a clean
one. The row kept is the one a buyer would actually get: **in stock first,
then cheapest**. A sold-out listing keeps its last price, since it is still the
best guide available, but its count is zero so nothing reads it as buyable.

**Yugipedia** supplies the catalogue, from `Set Card Lists:… (OCG-JP)` in
namespace 3006. Those lists carry **English** names, which is what lets both
regions share one name table: of 6,478 Japanese names, 3,733 were already
there and only 2,801 had to be added.

### Rarities

Yuyu-tei tags rarities its own way (`N SE SR UR UL QCSE PSE CR HR NR M PG
GMR EXSE`) and Yugipedia writes them both in full and abbreviated. `RARMAP` (jp-rarity-map.pl) in
the harvest script covers all three spellings. OCG-JP prints eight the
Asian-English side never sees: Normal Rare, the four Parallel grades, 20th
Secret, Millennium and Premium Gold.

Rarity comes from the catalogue where the wiki lists it (67.6%), otherwise
from whatever Yuyu-tei stocked (28.5%). The remaining 4% falls back to Common.

### Scale

8,473 printings across 223 sets, 14,210 priced rows, 95.7% with art already on
YGOPRODeck. Baked, that is 107 KB of catalogue, 166 KB of prices and 68 KB of
names — about 340 KB raw, 100 KB gzipped.

### Re-harvesting

`jp-sets.pl` lists the prefixes and dates, `jp-prices-yuyutei.pl` walks Yuyu-tei,
`jp-catalogue-yugipedia.pl` walks Yugipedia, and `jp-bake.pl` writes the two tables. Sanity
check afterwards: every priced code should be one the catalogue knows —
orphans mean a parser drifted.

### One code, several set-list pages

A code appears on more than one Yugipedia page — a set and its `+1 Bonus Pack`,
a reprint listing — and **each page names only the rarities it covers**. The
first harvest kept whichever page it met first and dropped the others, which
silently threw real rarities away: `INFO-JP006` kept the bonus pack's Ultra and
Quarter Century and lost the main set's Ultimate and Secret.

The rarities are now merged across every page a code appears on. That is 819
printings affected, and the number of printings known in more than one rarity
went from 2,970 to 3,055.

Belt and braces on top of that: at runtime, any rarity Yuyu-tei actually has on
the shelf for a code is treated as existing whatever the wiki page says. A
listing you can buy is not a rarity that needs arguing about.

## 12. Settling a trade

The trade calculator weighs two piles against each other; **Trade done** applies
the result. What you gave leaves the binder, what you got arrives in Collection,
and anything you received that was on the wishlist has its wanted count reduced.

It refuses rather than improvises. If a row asks for more copies than you hold,
the whole trade stops — a half-applied trade is worse than none, because you
would have to work out yourself what had already moved. Copies promised to a
buyer in a pending deal do not block the trade but are named in the confirmation.

A give row records **which binder** the copy came from, because the same
printing can sit in Collection and on the selling shelf, and the settlement has
to take it out of the one that was actually picked. That is why the search
results read `Rare · ROTA-JP002 · Selling`.

## 13. Storage, and why entries are thin

Binders live in **IndexedDB**, falling back to localStorage where it is not
available. A binder saved by an older version is still read from localStorage
on first load and written back to IndexedDB.

An owned entry is `{n, copies, added}` — the name, the copies you typed in, and
when it arrived. It used to carry a whole card beside every entry: text, art
urls, stats, the lot. That was **842 bytes a card against 104 now**, and at 842
about six thousand cards filled the 5 MB localStorage quota shared by both
regions.

Everything else about a card is rebuilt from the pool by id. A card the pool no
longer carries resolves to a **name stub** — enough to list it and file copies
against, marked `ghost` so nothing mistakes it for a real pool entry. That is
what the name is kept for.

`migrate()` reshapes old binders on the way in and drops `decks`, which the
deck builder left behind when it was removed.

### A failed save is never silent

`Store.set` returns false when nothing could be written. `save()` checks it and
raises a banner that does not go away, because the risk does not either: every
edit since the last good write dies on the next refresh. The banner offers the
export button directly.

## 14. Undo, and the address bar

`markUndo(label)` snapshots the binder before a destructive change; `toastUndo`
offers it back for six seconds. One slot, deliberately — the mistake worth
recovering is nearly always the one just made. Wired to clearing copies and to
settling a trade.

Where you are — region, view, drilled set or core, binder tab, search, page —
lives in the hash, written from `renderBinder` since every navigation ends
there. A change that is only a search keystroke replaces rather than pushes, so
Back does not walk the search back a letter at a time. `readUrl` runs at boot
when there is a hash, so a shared link opens where it points.

## 15. Asking a shop for a price

All three shops are asked the same question in the same order — this exact
printing, then this card in this set, then this card at all — and answer it the
same way: **stocked beats cheaper**. That order and those tie-breaks live once,
in `pickPrinting` and `rowsForCard`. A shop supplies only its index and its
currency. TCG Corner additionally drops played stock, which is a different
product at a third of the price.

The exported sale page is a second application built by pasting strings
together, so its script is **compiled with `new Function` before the file is
handed over**. If it will not parse, nothing downloads and the reason is named.
A stray quote in a card name used to produce a file that looked fine here and
rendered an empty grid on the buyer's machine.
