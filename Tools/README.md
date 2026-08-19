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
