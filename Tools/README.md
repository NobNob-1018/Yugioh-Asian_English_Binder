# Binder tools

Three small scripts: two that get TCG Corner's price list out, one that tests
the binder's price matching against it. No dependencies.

## 1. Get the price list

**Easiest — no install.** Open <https://tcg-corner.com> in Chrome, press F12,
open the **Console** tab, paste the whole of `get-prices-from-browser.js` and
press Enter. It pages through their catalogue and downloads `tcgc-prices.json`.
Running it on their own tab means nothing can block it.

**Or from a terminal**, needing nothing beyond Perl and curl:

```bash
perl Tools/ae-prices-tcgcorner.pl
```

This replaced `fetch-tcgc-prices.js`, which needed Node and so could never run
on this machine while the OCG-JP scripts beside it could. It writes the same
file, plus `Tools/played-stock.json` for the graded copies.

**Or from the app itself:** Prices → Sync, then Export .json. *(Export is
currently disabled — see the warning under "Load it back".)*

All three produce the same file:

```json
{ "t": "2026-08-18", "cur": "PHP",
  "rows": [ ["ES02-AE005", 1765.13, "Droll & Lock Bird", "UL", ""] ] }
```

`rows` are `[code, price, name, rarity, condition, available]`. Condition is
`""` for a clean copy, or a letter for played/damaged stock — that distinction
matters, because a `(Status B)` listing can be a third of the clean price.
`available` is `1` when the shop says it is in stock; the app prefers an
in-stock listing over a cheaper one it cannot buy, and could not apply that
rule to Asian-English until the harvest started recording it.

### The second shop

```bash
perl Tools/pc-prices-playersclub.pl
```

Writes `pc-prices.json` from Players Club HK, in the same shape minus the
condition column: `[code, rarity, price, name, available]`. Section 9 has
described this endpoint since the shop was added, but the harvester itself was
never written and its rows were produced by hand — which is why the
Asian-English side could not be refreshed without a person.

Neither harvester maps a rarity. Both pass the shop's own tag through
untouched, because `ourRar()` in the app already owns every spelling both
shops use and a second mapping would be a second thing to keep in step. This
is also why the tag is read by *position* — the last bracket on the line — and
not by length: capping it at five letters silently dropped `(Overframe)` and
left it glued to the card name, so the card vanished from the binder entirely
rather than merely arriving without a rarity.

## 2. Load it back

Prices → **Import .json**.

> ⚠️ **Do not use "Copy as code" or "Export .json" to re-bake.** Both are
> disabled in the app as of 2026-08-19. They build their output from
> `Object.keys(PX)`, one row per card code — but 1,283 codes hold more than one
> printing, so the 7,277-row list collapses to 4,584. That silently drops 2,693
> printings and breaks rarity matching, which is the whole basis of the match
> key. Re-enable only once both emit from `PX_ROWS` and `pricesAsCode()` also
> writes `BAKED_CUR`.

**Or bake it, the way OCG-JP always could:**

```bash
perl Tools/ae-prices-tcgcorner.pl     # -> tcgc-prices.json
perl Tools/pc-prices-playersclub.pl   # -> pc-prices.json
perl Tools/ae-bake.pl                 # -> rewrites index.html
```

`ae-bake.pl` writes both shops between their existing markers —
`BAKED_PRICES_START` / `_END` and `PC_PRICES_START` / `_END` — refreshing
`BAKED_STAMP`, `BAKED_CUR`, `PC_STAMP` and `PC_CUR` as it goes. The OCG-JP
side has had `jp-bake.pl` since it was added; this is its counterpart, and it
is why the hand-paste below is no longer the only route.

Two things it deliberately does not do:

- **It does not collapse duplicate rows.** A shop really does list the same
  printing twice. An earlier draft kept one row per code+rarity and lost 43
  printings the file already held; `indexPrices()` already chooses between
  them at runtime, in stock over cheaper, so choosing here would mean choosing
  twice by two different rules.
- **It does not re-encode.** The file is read and written as characters, not
  bytes, and encoded exactly once. Mixing the two is what corrupted the
  em-dash in `<title>` on an earlier bake.

Verify a bake by re-baking a copy and comparing: 7,022 TCG Corner printings
and 3,699 Players Club rows must survive unchanged, and `<title>` must still
read `Asian-English Binder — OCG Collection` with a real em-dash.

To hardwire a list by hand instead, use the browser scraper in step 1 and
paste its `rows` over the `BAKED_PRICES` array between the markers.

### Refusing a bad harvest

```bash
perl Tools/verify-harvest.pl            # the JSON the harvests wrote
perl Tools/verify-harvest.pl --baked    # what is already in index.html
```

Exits non-zero on failure, so nothing downstream runs. It checks four things:

- **Floors** — 6,000 TCG Corner rows, 3,000 Players Club, 18,000 Yuyu-tei.
  Set below the known-good counts (7,022 / 3,699 / 22,164) with room for a
  real week of stock movement. Raise them when the catalogues genuinely grow;
  a floor that never moves stops meaning anything.
- **A drop of more than 15%** against what is currently baked.
- **Rarity spread** — if every row carries the same tag, the parser stopped
  reading titles and is returning a default.
- **A stamp from the future**, which means a clock or a cache problem.

The half-failure is the case worth guarding: a shop changes a page, the parser
matches less, and a smaller but perfectly well-formed file lands in the binder.
Nothing looks wrong until a number is quoted at a table.

### Running it on a schedule

`.github/workflows/prices.yml` does the Asian-English harvest weekly (Sunday
19:00 UTC, so Monday morning in Manila) and can be run by hand from the
Actions tab. It verifies before baking *and* after, and only commits when
`index.html` actually changed. A failure changes nothing and says so — stale
prices you know about beat stale prices you do not.

Nothing to install: Perl, curl and JSON::PP are all on `ubuntu-latest`.

The OCG-JP side is not wired in yet. Its four scripts write to `/tmp` and
assume a working directory; they want a tidy-up before a robot runs them.

## 3. Test the matching

Open the app, press F12, and run the snippet in section 21 in the Console. It
calls the app's own `bestMatch` on cards whose prices were checked by hand, so
it tests what actually ships rather than a copy of it.

This used to be `node test-prices.js`, which loaded the functions out of the
HTML with a stubbed DOM. It needed Node, which is not installed here, so it
had quietly stopped being runnable. The console does the same job with nothing
to install, and the hand-checked prices it relied on now live in section 21
rather than buried inside a script.

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

### Closing a deal, and putting it back

Marking a deal done is the moment stock leaves. `closeDeal()` decrements the
copy rows it takes from and deletes any row that empties - and a copy row is
more than a count: it carries **the asking price and the condition you graded**,
and the entry around it carries the date you added the card.

It used to record only `it.took`, the number that went out. A reopen therefore
had nothing to rebuild the rows from: the copies came back priced at whatever
the buyer's order code happened to say, or at nothing, always ungraded, and
dated today. A reopen exists because the sale fell through, so *nothing* should
have changed - and this was silent, on a selling shelf, which is the worst
place for it.

`closeDeal()` now records `it.from` - a `{n, price, cond}` slice per row it
drew from - and `it.was` when the whole entry goes. `reopenDeal()` rebuilds from
those, matching each slice back to a row with the same price *and* condition, so
two rows of one printing listed at two prices stay two listings instead of
merging into one. A deal closed before this shipped has no `it.from` and falls
back to the old behaviour, which is the best that can be known about it.

## 11. OCG-JP, the second region

The app holds two collections that share nothing but a card pool. The switch
sits on the wordmark: **AE** for Asian-English, **JP** for Japanese OCG.

What is separate:

| | Asian-English | OCG-JP |
|---|---|---|
| Saved under | `ygo-binder-v1` | `ygo-binder-v1-ocg` |
| Catalogue | `AE_CAT`, 71 sets | `JP_CAT_RAW`, 454 sets |
| Prices | TCG Corner + Players Club | Yuyu-tei |
| Quoted in | USD / HKD, shown in pesos | yen, shown in pesos |
| Rarities | 11 | 19 |

Binder, collection, selling shelf, wishlist, deals and sales history are all
per region. Nothing merges across: a transfer code and an exported file each
carry the region they came from and are refused by the other side, because a
`ROTA-JP079` means nothing in an Asian-English binder.

### Scope

Japanese sets released **2013 onwards** — 455 prefixes off Yugipedia's
`Japanese release date`. Anything earlier is the same two harvests over a longer
prefix list: move `` in `jp-sets.pl` and re-run.

### Where the data comes from

**Yuyu-tei** (`yuyu-tei.jp/sell/ygo/s/<lowercase-prefix>`) is a plain
server-rendered site, not Shopify, and sends no CORS header — so prices are
baked, exactly as the other two shops are. One request returns a whole set.
Of the 455 sets, **259 are stocked**; the rest are promos they do not carry.

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
regions share one name table: of the Japanese names, well over a third were
already there and only 4,153 had to be added.

### Rarities

Yuyu-tei tags rarities its own way (`N SE SR UR UL QCSE PSE CR HR NR M PG
GMR EXSE`) and Yugipedia writes them both in full and abbreviated. `RARMAP` (jp-rarity-map.pl) in
the harvest script covers all three spellings. OCG-JP prints eight the
Asian-English side never sees: Normal Rare, the four Parallel grades, 20th
Secret, Millennium and Premium Gold.

Rarity comes from the catalogue where the wiki lists it (67.6%), otherwise
from whatever Yuyu-tei stocked (28.5%). The remaining 4% falls back to Common.

### Scale

15,530 printings across 454 sets, 22,164 priced rows, 95.7% with art already on
YGOPRODeck. Baked, that is 107 KB of catalogue, 166 KB of prices and 68 KB of
names — about 340 KB raw, 100 KB gzipped.

### Re-harvesting

```bash
perl Tools/jp-sets.pl                 # prefixes and dates -> /tmp/jp_sets.tsv
perl Tools/jp-prices-yuyutei.pl       # walks Yuyu-tei     -> /tmp/yt_rows.tsv
perl Tools/jp-catalogue-yugipedia.pl  # walks Yugipedia    -> /tmp/jp_cat.json
perl Tools/jp-bake.pl                 # builds the blocks  -> /tmp/jp_blocks.json
perl Tools/jp-write.pl --dry-run      # what would change, writes nothing
perl Tools/jp-write.pl                # rewrites index.html
```

`jp-bake.pl` stops at `/tmp/jp_blocks.json` and always has; the four blocks
were then pasted into `index.html` by hand, which is why OCG-JP could not be
refreshed without a person. `jp-write.pl` is the missing step.

**These are HTML scrapes, not JSON endpoints.** A layout change does not raise
an error — it quietly returns less. So `jp-write.pl` checks shape before it
writes anything, and a failure writes nothing:

- **Floors** — 380 catalogue sets, 18,000 priced rows, 200 priced sets, 2,000
  extra names. Yuyu-tei carries 257 of the 454 sets, not all of them; a first
  guess of 300 for that floor failed on perfectly good data, which is what a
  floor set by hope rather than measurement always does.
- **A drop of more than 15%** against what is already in `index.html`.
- **The rarity ladder is exactly 19.** A scrape that suddenly knows a
  different number has found a page it does not understand.
- **Price lines still look like `PRE|num,rarIdx,yen,qty`**, and no more than a
  fifth of rows may be zero yen and zero stock — both selectors breaking at
  once produces well-formed rows full of nothing.
- **Orphans**: every priced code should be one the catalogue knows. This check
  was described here in prose for a long time; it is enforced now.
- **A backtick or `${` in scraped text is refused outright** — either would
  end the template literal early and turn the rest of the file into syntax
  errors.

Verified by damaging the blocks in each of those ways: all seven are refused
and `index.html` is left untouched. On good data all four blocks round-trip
identically and the rewritten file boots, switches to OCG-JP and indexes
22,164 priced codes.

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

## 16. The wishlist holds printings, not cards

One card can be worth hunting in more than one rarity — the Secret at a price
you would pay today, the Quarter Century only if it falls a long way. So an
entry is `{rows:[…], added}`, one row per printing, each with its own set,
count and target. **Add another rarity** opens a new row on a rarity not
already listed that a shop actually stocks.

Card-level questions still have card-level answers: the grid badge and the
"met" state read the **cheapest** row, since that is the one you would buy
first. The dashboard counts both — "1 card · 3 printings".

Old entries carried a single rarity; `slimWant()` turns each into a list of
one. Transfer codes write one line per row and gather them back by card id, so
several rows sharing a card no longer overwrite each other.

### Add to wishlist, on a selection

`bulkWant()` called `addWant()`, which has never existed in this file. The call
sat inside `if (c && typeof addWant === 'function')`, so the guard was always
false: selecting twenty cards and pressing **Add to wishlist** added nothing,
counted nothing, and reported "Nothing added" - which is true, and reads exactly
like an empty selection. A guard around a name that is never defined is not a
safety net, it is a silent no-op that nothing will ever report.

It now does what the detail panel does: `addWantRow()` on the printing you would
actually buy (`cheapestRarity()`, falling back to the only rarity or the only
code there is), and it refuses to make a second identical line, the same way
**Add another rarity** does. The toast distinguishes "added" from "already on
it", so a no-op says which kind it was.

### What the shops are asking

`srpRange` used to read TCG Corner's rows directly. That made it disagree with
the row underneath it — quoting ₱126 while the line below said ₱79 at Players
Club — and return nothing at all in OCG-JP, where that shop has no rows. It now
asks `bestMatch` once per rarity the card was printed in, which is the same
question a single printing is asked, so the range and the lines cannot
contradict each other. The figure is shown **before** anything is added, so the
decision to hunt a card is made against a real number.

## 17. Working without a signal

`sw.js` is a service worker; `manifest.webmanifest` and `icon.svg` make the
binder installable. Together they mean that after **one** visit the app opens
with no network at all — which matters, because the place you most want it open
is a card shop with no bars.

Three caches, each with a different rule:

| Cache | Holds | Rule |
|---|---|---|
| `-shell` | index.html, manifest, icon | stale-while-revalidate |
| `-img` | card art from YGOPRODeck and Yuyu-tei | cache-first, capped at 600 |
| `-data` | the card pool and the exchange rate | network-first, cache as fallback |

**The shell is served from cache first.** That is what makes a 1.6 MB file open
instantly, and it is why an update lands silently on the *next* open rather
than making you wait for it on this one. A fresh copy is fetched in the
background every time.

The pool response is about 24 MB and is cached whole. That sounds like a lot
until you look at the quota: measured at 26.6 MB against 6.1 GB, or 0.4%. It is
what lets the app start up with no connection at all rather than starting up
empty.

`VERSION` at the top of `sw.js` names all three caches. Bump it and the old
ones are deleted on activate. There is no build step and nothing to configure —
it is registered with a relative path, so it scopes itself correctly whether it
is served from the root or from a project subpath on Pages.

It cannot run from `file://`, where there is no origin to scope to. The app
notices and carries on without it.

**Verified** by stopping the web server outright and reloading: the app booted,
the pool was there, prices resolved, and both regions worked.

### Nothing in OCG-JP is legacy

Asian-English runs back to 2004 and the shops stock almost none of it, so
anything before `AE_MODERN_FROM` (2018) sits behind the legacy switch. OCG-JP
has no such tail — the catalogue was deliberately cut at 2013, so everything in
it was chosen to be there. `modernFrom()` returns an unreachable date in OCG,
which puts nothing in the legacy bucket.

Without that, extending the catalogue back to 2013 would have added 168 sets
and shown none of them: the pool stayed at 7,740 instead of 10,393, and a card
from 2013 was invisible unless you found the legacy toggle.

### The pre-2018 switch is Asian-English only

Since nothing in OCG-JP is legacy, the switch would toggle nothing there and
only invites a pointless click. `paintLegacySwitch()` hides the whole row when
the Japanese binder is open. `[hidden]` needed a rule of its own, because a
`.switch` is `display:flex` and would otherwise ignore the attribute.

### Keeping the binder on the device

Browsers clear "best effort" storage when a device runs low, and a binder is
exactly what would go quietly: it is only ever written by you and can never be
fetched back. `askPersist()` asks for persistent storage at boot, and Settings
shows the honest answer — how much is used, whether the app works offline yet,
and whether the browser has agreed to keep it.

Chrome grants persistence on its own once the app is **installed** or visited
often; asking on a first visit is usually declined, which is why the Settings
row offers a **Keep offline** button rather than pretending it is settled.

## 18. Three piles, not four views

Collection, Selling and Wishlist are three answers to the same question — where
does this card sit for me — so they are one control. The wishlist used to sit in
the view strip beside Binder, Sets and Cores, which are not piles at all but
ways of looking at one, and it read as a peer of things it had nothing in
common with.

Internally the wishlist still rides on `VIEW==='wants'` rather than on
`F.binder`, because nothing in it is owned and a binder filter would be wrong.
`pickPile()` maps the third segment onto the view; `paintBinders()` lights the
segment from whichever of the two is in play, and `paintViewTabs()` falls back
to Binder while the wishlist is open. Both reset points — switching region and
restoring from the address bar — go through those two painters, so the strips
cannot drift apart.

### 18a. Switching a pile off

Most people do not do all three. A binder that is only ever a collection still
carried a Selling tab, a Keep/Sell switch on every copy row, a deals board, a
shareable sale list and a margin figure that would never say anything - and at
375px that is a third of the chrome earning nothing, on the screen where chrome
is the scarce thing.

**Settings -> What this binder is for** switches each pile off. Three switches
rather than an *Only Collection / Only Selling / Only Wishlist* menu, because the
three are not exclusive: switch two off and you have the "only" the menu would
have offered, and you can also have the pair the menu had no room for. One of
the three has to stay on; trying to clear the last one snaps the switch back and
says why.

It is a **preference of the device**, held in `PREFS` beside the theme and the
card size (`PREF_FIELDS` carries `piles`), so it survives a region swap and does
not travel with a shared binder. Absent means all three, so an existing device is
not changed by the setting arriving.

Nothing is deleted. Copies filed under a hidden pile stay exactly where they are
and come back untouched - which is why each switch counts them out loud
(`pileCount`) before you flip it, and says "hidden, not deleted" afterwards.
Import, merge and the shared-sale-list reader are untouched for the same reason:
the setting hides surfaces, it never edits data.

Two functions do the work:

- `fitPiles()` moves where you are **standing** - out of a view or a pile that is
  no longer switched on. Three things can strand you there, so all three call it:
  the setting changing, a region swap (which resets `VIEW` and `F.binder`), and
  the address bar (a link from a desktop where all three are on).
- `applyPiles()` decides what is on the **screen**: the pile tabs (and the whole
  switch, plus its phone host `#pilebar`, when one pile is left), Select mode and
  the three bulk-bar buttons, Deals, the Selling list button, the Trade
  calculator, the "At the table" group, and Show owned.

The rest is read at render time from `pileOn()`, `bothPiles()`, `ownPiles()` and
`wantsOnly()`:

| Where | With the pile off |
|---|---|
| Detail panel | Keep/Sell segment and the new-copy segment go; the copy lands in `defaultPile()`. "Copies held" goes when neither binder pile is on; "Wishlist" goes with the wishlist. |
| Bulk add | Three shapes. Both piles on: the Sell tick unlocks the price. Selling only: no tick, price always live, everything is a listing, and the tally drops its *keep* half. Collection only: neither column. |
| Dashboard | `dashSub` stops naming the other pile; the margin footer and the wishlist line stand down with theirs. |
| Settings | The seller name and contact exist so a buyer can reach you, so they go with Selling. |

Two things create copies rather than reading them, and both had `b-main`
written into them: a settled trade (`applyTrade`) and **Paste a list**. With
Collection switched off, both filed into a pile that is not on screen, so the
cards arrived and vanished. Both now use `defaultPile()`, and Paste a list only
offers the Collection/Selling choice when there are two piles to choose between
- otherwise it says where they are going. In wishlist-only neither can do
anything useful, so both leave the rail along with the trade calculator.

**Wishlist only** is the one that changes shape rather than just losing parts.
Binder, Sets and Cores are all lenses on copies you hold and there are none, so
the view strip goes and `VIEW` is pinned to `wants`. The headline has no value to
total either, so it becomes the one figure that means something there - what the
list would cost to clear, with *N of M at or under target* under it.

## 18b. What belongs to the device, not the collection

Switching region replaces `DB` wholesale - a different saved file, a different
collection - so anything living in `DB` that is really a *display* setting gets
swapped along with it. That is what `PREFS` and `PREF_FIELDS` exist to prevent,
and four settings were simply missed when the list was written:

| Field | Symptom before |
|---|---|
| `railHidden` | AE→JP un-folded the sidebar |
| `per` | cards per page reset |
| `setSort` | the Sets board reordered |
| `coreSort` | the Cores board reordered |

Switching back restored them from the other file, which is what made it look
random rather than broken. All four are in `PREF_FIELDS` now, and the three
controls that write them (`#rail-tog`, `#t-per`, `#t-sort`, plus Clear filters)
call `savePrefs()` so the device file hears about it at once rather than waiting
for the next save of something else to carry it.

### Binder mode's settings are not your settings

Binder mode forces facing pages **on** and hands the page size to the window,
remembering yours to put back on the way out. But `paintDash()` calls
`savePrefs()` on every render - for `wantSeen` - so a save landing while binder
mode was open adopted both of them, and leaving restored `DB` and not `PREFS`.

The result: open binder mode once and **Facing pages** was switched on in your
saved settings permanently, by something you never touched. It came back at the
next reload looking like a setting you had chosen.

`savePrefs()` now writes the remembered pre-binder values for those two fields
while `BM` is true, and `exitBinderMode()` calls `savePrefs()` once it has put
them back. This mattered before `per` joined the list and would have got worse
with it, which is why the two were fixed together.

## 18c. Which printings this device carries

Asian-English and OCG-JP are two binders that share a card pool and nothing
else. Plenty of people collect one of them, and for those people the AE / JP
switch is a control that can only ever put them somewhere they did not want to
be — sitting next to the wordmark, which is where a mis-tap is most likely.

**Settings → Which printings you collect** switches either off. Same shape as
the piles and for the same reasons: a preference of the device (`DB.regions`,
carried in `PREF_FIELDS`), absent means both, and it hides a surface rather
than touching a collection. The other region's binder stays in its own saved
file and comes back untouched.

- `applyRegions()` hides `#regsw` when only one is on; `paintRegion()` calls it,
  so it cannot drift.
- `setRegions()` refuses the last one standing, and switches region when you
  turn off the one you are standing in.
- `setRegion()` refuses a region this device does not carry, because a stale
  tap on a hidden switch is still a tap.

### The region switch must not move backwards

It went wrong twice, and the second way is the interesting one.

First it was simply inverted. Both controls cancelled the click and re-set the
checkbox only once the swap landed, so a refusal could never leave it lying —
and that needs `cb.checked` **as read in the handler**, which is the state being
asked for, since the browser toggles it before handlers run and
`preventDefault()` puts it back *after* the event rather than undoing it now.
Written as `!cb.checked` it did nothing at all.

Fixing that exposed the real problem: **the control moved backwards before it
moved forwards.** Cancelling the click snaps the switch back to where it was,
and it stays there until `setRegions()` resolves — but switching region rebuilds
a five-thousand card pool. Measured at **146ms on a warm desktop**, and far
worse on a phone with a cold pool, with the main thread too busy for the switch
to even animate. For that whole time it shows the opposite of what was just
pressed, which reads as a control that does not work — and the second tap it
invites is the one that gets refused, because by then the first has landed.

There is exactly one refusal and it is knowable up front, so it is settled
before the switch moves:

```js
if(!want && regionsOn().length<2){ cb.checked=true; toast(...); return; }
```

After that the switch stays where it was put, both are `disabled` (at half
opacity) until the swap lands, and the note underneath says *Switching…*. A
control that is doing something slow should look busy, not look wrong.

## 18d. The setup, one question a screen

Settings used to open itself on a first run. It showed every control without
ever saying what any of them were for — which is the wrong shape for a first
look, because a list of everything is what you want when you already know what
you are looking for.

`openSetup()` asks four questions instead, one screen each, in the order that
decides how much of the app is left standing:

1. **What do you do with cards?** — the three piles, each with what it actually
   gives you, and a line underneath saying what the current answer means.
2. **Which printings do you collect?** — AE, OCG-JP or both.
3. **Light or dark**, and card size.
4. **A summary**, plus where search, Menu, Filters and Sync live.

The first two come first because they switch whole sections off: answer them
and the app behind the sheet is already the size you wanted by the time you
see it. Every change applies live rather than on a Finish button, so the app
is visibly smaller behind the question that shrank it.

Nothing in it is one-way. Each question is a Settings row, the last screen says
so, and **Settings → Run the setup again** reopens the whole thing.

## 18e. One sync button, and a bar with a denominator

Three different things came down one button: the card list, the prices and the
exchange rate. They cost wildly different amounts — the card list is megabytes,
the rate is one small request — and you want them for different reasons, but
pressing the button fetched all three or nothing. Beside it sat a caret opening
a panel that held a second, different Sync. Two controls a thumb apart, one of
them a 24px caret, both about the same job.

`openSync()` is one sheet: a row per job with what it is, when it last landed,
and a switch. The picks are remembered in `PREFS.syncPick`, because which ones
you want is a fact about this connection rather than about the collection.

`runSync()` draws one bar across the run. Each job takes an equal share; a job
that can say how far along it is moves inside its own share. Prices can:
`pxFull()` knows what a whole catalogue comes to, so `refreshPrices()` now takes
an `onProg` callback and reports a real fraction. `"Fetching 3,214"` was a
number with no denominator — it said something was happening and nothing about
how much was left. A job that has no denominator at all leaves the bar
indeterminate for its share rather than inventing one.

Two things that had to change with it:

- **A finished run and a successful one are different.** The bar tracks
  attempts, so when none of them land it turns `--down` rather than sitting
  full and green over three failures.
- **A job must not take the sheet away from the run using it.** `modal()`
  clears the layer before drawing, and `refreshPrices()` opened the
  explanation modal on failure — which destroyed the sync sheet mid-run, so
  the jobs after it wrote into detached nodes and the bar vanished at the
  moment it had something to report. It now opens that only when `SYNCING` is
  false; inside the sheet the failed row and the toast carry the message, and
  **Price options** leads to the same explanation.

## 19. Getting the newest version on a phone

The saved copy is what makes the app open instantly and work with no signal,
but it also means a new version arrives one open late. On a phone there is no
obvious way to force it, so **Settings → App version → Get the newest** deletes
the caches, unregisters the worker and reloads.

It does **not** touch your binder. The collection lives in IndexedDB under its
own name; only the caches the service worker owns are cleared. The confirmation
says so, and it is verified: a marked card with 7 copies came back untouched.

## 20. On a phone, the scoping controls move up

Below 920px the rail stacks underneath the card grid. That left the two
controls you reach for most — which pile you are in, and whether to show only
what you own — roughly **1,500px down the page**, past everything they scope.
A control you scroll past a hundred cards to reach is not a control.

`placePiles()` moves both into `#pilebar` in the toolbar when the rail has
stacked, and back to the rail when there is room. **Moved, not duplicated**, so
there is still one of each and nothing can fall out of step.

The order that leaves reads outward-in: what you are looking at (Binder / Sets
/ Cores), then which pile, then how to sort it, then paging. Everything lands
above the first card at 375×812.

| | Before | After |
|---|---|---|
| Show owned | 1,479px | **465px** |
| Collection / Selling / Wishlist | 1,518px | **451px** |

Two things this got wrong first, both worth remembering:

- The switch was looked up as `.switch-row .switch`, a **positional** selector.
  It stopped matching the moment the switch moved, so the guard bailed and it
  could never move back. It is found by its checkbox id now, which is true
  wherever it sits.
- The breakpoint was read from `window.innerWidth`, which some shells report as
  `0`. It asks `matchMedia('(max-width:920px)')` instead — the same query the
  stylesheet uses, so the two cannot disagree. `placePiles()` also runs on every
  render, because not every shell delivers resize or mediaquery events; the call
  returns immediately when nothing needs moving.

### 20a. The fold is a sidebar control

Below 920px the rail is not a column beside the cards - it is a bottom sheet
that slides up over them, opened by the Menu button. The fold handle (`«`)
stayed in it, and it had CSS waiting from the older design where the rail
merely stacked under the grid and folding collapsed it to a sticky strip.

Pressing the handle from inside the open Menu therefore did three things at
once: `.shell.no-rail>.rail` re-pointed the sheet at `position:sticky`, which
took it out of its fixed frame and wedged it into the page above the dashboard;
`.shell.no-rail>.rail>.grp:not(:first-of-type)` hid every panel in it; and
`.no-rail .grp:first-of-type>*:not(.switch-row)` hid the rest of the first one.
The Menu stayed open showing nothing but its own handle and *Show results*.

The fix is to stop the class arriving at a width where it means nothing.
`applyRail()` reads `RAIL_STACKED` - the same query `placePiles()` uses, so the
two cannot disagree - and applies `no-rail` only where there is a column to
fold, hiding the handle otherwise. The **saved preference is untouched**: a
desktop that was folded is still folded when the window is wide again, and
visiting the same binder on a phone in between changes nothing. The empty
`.switch-row` left behind is hidden too, since on a phone the owned switch has
already moved into the toolbar.

The stale `.no-rail` rules in the `max-width:920px` block are gone rather than
left dormant. A rule that can no longer be reached is the thing that sprang
this trap in the first place, and the block carries a note saying so.

Crossing the breakpoint has to re-decide: `railBreak()` and `reflow()` both run
`placePiles()` then `applyRail()`, in that order, because `applyRail` reads where
the switch ended up.

## 20b. Three things the phone bar got wrong

**Cards per page was half-removed.** Below 760px `autoLayout` fits the sheet to
the window and `PER` comes out the same whatever the control says - it is a dead
control, and the stylesheet had always meant to drop it:

```css
@media (max-width:759px){ #t-per,.more-row{display:none} }
```

But `.more-row{display:flex}` is declared later and unconditionally, and a media
query adds no specificity - so only the `<select>` went. The label stayed behind
over an empty gap, which reads as a control that failed to load. With the row
gone, and Bulk add and Clear filters each only applying somewhere, the overflow
menu is empty most of the time on a phone - so `paintMore()` now owns all of it
and takes the `...` button away when there is nothing behind it. It is called
from `paintTools()`, not only from `openMore()`, or it could only ever be right
after you had already pressed it.

**Stacked settings rows left their segments a third full.** At 560px `.set-row`
turns into a column and hands the control the whole width, but `.tabs button` is
sized to its text - so Dark/Light sat in the left third of a full-width box with
the lit pill covering a quarter of it. The options split the row now.

**Show owned was seventh of seven in the filter sheet.** It is a filter, which is
why it was put there, but not the same kind: sort and rarity narrow a list, this
one decides whether you are looking at your cards or at every card there is -
the same class of question as which pile. It now sits at the right of the pile
row, labelled just **Owned** (the row is 354px and the word *Show* was doing
nothing), as a switch in smaller type against tabs so it does not read as a
fourth pile - which is what sent it into the sheet the first time.

Two consequences worth knowing:

- `paintPilebar()` hides that row only when *everything* on it is hidden. Either
  tenant can go on its own - the tabs when one pile is left, the switch on the
  wishlist - and the row has to survive losing one.
- The wishlist is the cards you do **not** own, and `visible()` has always
  ignored the switch there. Buried in a sheet that was a dead control you had to
  go looking for; beside a lit Wishlist tab it would read as something that
  ought to work, so `paintBinders()` takes it away while you are in there.

## 21. Prices checked by hand

These were verified on the TCG Corner site by eye, and are the reference the
price matching is judged against. They lived inside `test-prices.js`, which
needed Node and so could never run here; the file is gone, the knowledge is not.

Checked 2026-08-18, in pesos:

| Card | Set | Rarity | Price |
|---|---|---|---|
| Ash Blossom & Joyous Spring | RC04 | UtR | 1,260.81 |
| Ash Blossom & Joyous Spring | RC04 | UR | 252.16 |
| Ash Blossom & Joyous Spring | RC04 | ScR | 945.61 |
| Ash Blossom & Joyous Spring | RC04 | QCSR | 11,347.29 |
| Ash Blossom & Joyous Spring | RC04 | CR | 1,134.73 |
| Ash Blossom & Joyous Spring | RC04 | ExSR | 1,576.01 |
| Ash Blossom & Joyous Spring | RC04 | HGR | 8,825.67 |
| Droll & Lock Bird | ES02 | UtR | 1,765.13 |
| Droll & Lock Bird | ES02 | UR | 630.40 |
| Droll & Lock Bird | ES02 | ScR | 1,134.73 |

**These figures are in pesos, and the peso figure is not a constant.** The
baked list is in USD (`PX_CUR==='USD'`), so `bestMatch` returns
`price x DB.fx` and every number in the table above moves the moment the rate
does. The table was captured at `DB.fx = 63.04`; at the 62.67 of a later
session all ten come out 0.59% low - the *same* 0.59%, which is the tell that
nothing is wrong.

A check that fails on every correct build is worse than no check: it teaches
you to ignore the one test this project has for price matching. So the check
below pins the rate it was captured at, and asserts the part that is actually
a fact about the code - **which printing, at which shop, by which route** -
with the peso figure as a tolerance.

```js
(() => {
  const FX_WHEN_CHECKED = 63.04;          // DB.fx on 2026-08-18
  const cases = [
    ['Ash Blossom & Joyous Spring','RC04','UtR' , 1260.81,'RC04-AE009'],
    ['Ash Blossom & Joyous Spring','RC04','UR'  ,  252.16,'RC04-AE009'],
    ['Ash Blossom & Joyous Spring','RC04','ScR' ,  945.61,'RC04-AE009'],
    ['Ash Blossom & Joyous Spring','RC04','QCSR',11347.29,'RC04-AE009'],
    ['Ash Blossom & Joyous Spring','RC04','CR'  , 1134.73,'RC04-AE009'],
    ['Ash Blossom & Joyous Spring','RC04','ExSR', 1576.01,'RC04-AE009'],
    ['Ash Blossom & Joyous Spring','RC04','HGR' , 8825.67,'RC04-AE009'],
    ['Droll & Lock Bird'          ,'ES02','UtR' , 1765.13,'ES02-AE005'],
    ['Droll & Lock Bird'          ,'ES02','UR'  ,  630.40,'ES02-AE005'],
    ['Droll & Lock Bird'          ,'ES02','ScR' , 1134.73,'ES02-AE005'],
  ];
  const live = DB.fx; DB.fx = FX_WHEN_CHECKED;   // pin, so this tests matching
  let bad = 0;
  for (const [name,set,rar,want,code] of cases) {
    const m = bestMatch({set,rarity:rar},{name});
    const got = m ? Math.round(m.peso*100)/100 : null;
    // proportional: the rate is held to 2 decimals, so the error scales with
    // the price. A wrong printing is out by multiples, never by 0.02%.
    const tol = Math.max(0.02, want * 0.0002);
    const ok = m && m.code===code && m.how==='set + rarity'
               && Math.abs(got-want) <= tol;
    if (!ok) bad++;
    console.log(ok?'ok  ':'FAIL', name, rar, '->', m&&m.code, m&&m.how, got, '(want', want + ')');
  }
  DB.fx = live;
  console.log(bad ? bad+' of '+cases.length+' FAILED' : 'all '+cases.length+' ok');
})();
```

If every line fails by one identical percentage, the rate moved or the list was
re-baked - re-pin `FX_WHEN_CHECKED` and move on. If *some* lines fail, or a
`code` or `how` is wrong, the matching has broken and that is the real thing
this check exists to catch.

## 22. Played stock

`Tools/played-stock.json` holds the 255 listings TCG Corner grades A, B or C -
cards someone has played with. The app never quotes them: a scratched copy at a
third off is a different product, and quoting it would make a collection read
as worth less than it is.

They are kept because they answer two questions the clean prices cannot: what a
used copy would cost you to buy, and what one of your own played cards is
actually worth. `ae-prices-tcgcorner.pl` writes this file on every harvest.

Grades in the 2026-08-18 pull: 59 A, 131 B, 65 C.
