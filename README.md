# Yugioh Asian-English Binder

A collection tracker for **OCG Asian-English** and **OCG-JP** Yu-Gi-Oh cards.
One HTML file, no build step, no server, no account. Installable to a phone
and works with no signal.

**Live:** https://nobnob-1018.github.io/Yugioh-Asian_English_Binder/

## What it does

- **Two regions, kept apart** — Asian-English and OCG-JP are separate binders
  with separate storage, switched from the header. AE has 11 rarities, JP has
  19, and each region prices against the shops that actually stock it.
- **Binder** — every card, owned or not, so the gaps read as gaps. Cards show
  the rarities you actually hold, with a ring and foil sheen on the good ones.
- **Three piles** — Collection, Selling and Wishlist never mix. A copy filed
  under one is invisible from the other.
- **Sets and Cores** — Asian-English sets and OCG-JP sets from 2013 onward,
  plus archetype cores, each with a completion meter, all scoped to the pile
  you are in.
- **Real prices, matched by printing** — TCG Corner and Players Club for
  Asian-English, Yuyu-tei for OCG-JP, matched by set *and* rarity. Nothing is
  guessed: a card with no match shows no price rather than a wrong one, and an
  in-stock listing beats a cheaper one you cannot buy.
- **Search** — one panel over the page, finding cards and sets together by
  name, rules text or set code. Ranked, so a name match beats a text match.
- **Deals and trades** — buyers send an order code that becomes a pending deal
  with partial reservation; the trade calculator settles both sides.
- **Binder mode** — full screen, no furniture, facing pages and a page turn.
  Desktop only.
- **Transfer** — move your collection between devices as one paste-able code.
- **Sale page** — export the selling binder as a standalone, view-only HTML
  page to send a buyer.

## Your data

Everything you enter lives in **your own browser**, in IndexedDB, with
localStorage as a fallback. It is never uploaded and there is no backend. Two
consequences worth knowing:

- Publishing this app does not publish your collection.
- Storage is per-site, so a collection built on `file:///…` does **not** appear
  when you open the hosted version. Use **Transfer → Copy code** on the old one
  and **Load code** on the new one.

A transfer carries what you own, never what those cards were worth — price
tables belong to the device. It stamps which price set valued it, so the
receiving device says plainly whether it is looking at the same prices.

Clearing site data clears your collection. Keep a copy: Transfer → *Save as
file instead*.

## Offline

After one visit the app opens with no network at all.

- The **shell** is cached by a service worker, so the 1.6 MB file opens
  instantly and updates land silently on the next open.
- The **card pool** is stored locally and refetched once a month, on the first
  launch after the month turns, because sets arrive monthly. On Data Saver or
  a 2G-class connection that refresh is skipped entirely.
- **Prices** are baked into the file, so they are there before anything loads.
- **Card art** is cached as you see it, up to 2,400 thumbnails.

One **Sync** button refreshes all three — cards, prices and the exchange rate —
and the dashboard says how current each one is.

## Running it

Open `index.html`. That is the whole thing.

For local work a plain static server avoids `file://` quirks — some hosts
reject requests carrying a `null` origin, so price syncing behaves better over
http:

```bash
python -m http.server 8787
```

Note the service worker serves the shell from cache, so an edit needs **two
reloads** to appear, or clear the caches.

## What is baked in

| Table | Holds |
| --- | --- |
| `BAKED_PRICES` | TCG Corner listings, per code and rarity, clean stock only |
| `PC_ROWS_RAW` | Players Club HK listings, the second Asian-English shop |
| `JP_PRICES_RAW` | Yuyu-tei listings for OCG-JP |
| `JP_CAT_RAW` | the OCG-JP catalogue, 2013 onward |
| `AE_NAMES` | Asian-English card names, shared by every price table |
| `AE_CAT` | Asian-English sets and printings |
| `AE_CORES` | archetype membership |
| `AE_DATES` | real AE release dates from Yugipedia |
| `AE_EXTRA` | art and text for cards the card database does not carry |

`Tools/README.md` is the substantive technical log — 22 sections covering the
price sources, both regions, storage, deals, the wishlist and the service
worker. It documents how each table was gathered and how to rebuild it.

## Rebuilding the prices

```bash
perl Tools/ae-prices-tcgcorner.pl
perl Tools/pc-prices-playersclub.pl
perl Tools/verify-harvest.pl
perl Tools/ae-bake.pl
```

`verify-harvest.pl` refuses a harvest that looks wrong — row-count floors, a
drop of more than 15% against what is baked, a collapsed rarity spread — so a
half-failed scrape cannot reach the binder. `.github/workflows/prices.yml`
runs the same sequence weekly and commits only if it passes.

OCG-JP is rebuilt by the four `jp-*.pl` scripts and is not yet automated.

## Credits

Card data and art from [YGOPRODeck](https://ygoprodeck.com). Asian-English and
OCG-JP catalogues and release dates from [Yugipedia](https://yugipedia.com).
Prices from [TCG Corner](https://tcg-corner.com),
[Players Club HK](https://playersclubhk.com) and
[Yuyu-tei](https://yuyu-tei.jp). Yu-Gi-Oh is © Konami; this is an unofficial
fan tool with no affiliation.
