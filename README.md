# YGO Collect

A collection tracker for **OCG Asian-English** Yu-Gi-Oh cards. One HTML file, no
build step, no server, no account.

**Live:** https://imyan16.github.io/YGO-Collect/

## What it does

- **Binder** — every AE card, owned or not, so the gaps read as gaps. Cards show
  the rarities you actually hold, with a ring and foil sheen on the good ones.
- **Two binders, kept apart** — Collection and Selling never mix. A copy filed
  under one is invisible from the other.
- **Sets and Cores** — 71 Asian-English sets and 302 archetype cores, each with a
  completion meter.
- **Real AE prices** — a TCG Corner price list is baked into the file, matched by
  set *and* rarity, clean copies only. Nothing is guessed: a card with no match
  shows no price rather than a wrong one.
- **Binder mode** — full screen, no furniture, facing pages and a page turn.
  Desktop only.
- **Transfer** — move your collection between devices as one paste-able code.
- **Sale page** — export the selling binder as a standalone, view-only HTML page
  to send a buyer.

## Your data

Everything you enter lives in **your own browser**, in that site's local storage.
It is never uploaded and there is no backend. Two consequences worth knowing:

- Publishing this app does not publish your collection.
- Storage is per-site, so a collection built on `file:///…` does **not** appear
  when you open the hosted version. Use **Transfer → Copy code** on the old one
  and **Load code** on the new one.

Clearing site data clears your collection. Keep a copy: Transfer → *Save as file
instead*.

## Running it

Open `index.html`. That is the whole thing.

For local work a plain static server avoids `file://` quirks — some hosts reject
requests carrying a `null` origin, so the price sync behaves better over http:

```bash
python -m http.server 8787
```

## What is baked in

| Table | Holds |
| --- | --- |
| `BAKED_PRICES` | TCG Corner listings, per code and rarity, clean stock only |
| `AE_NAMES` | 5,792 Asian-English card names |
| `AE_CAT` | 71 sets, 6,569 printings |
| `AE_CORES` | archetype membership |
| `AE_DATES` | real AE release dates from Yugipedia |
| `AE_EXTRA` | art and text for cards the card database does not carry |

`Tools/` documents how each was gathered and how to rebuild them.

## Credits

Card data and art from [YGOPRODeck](https://ygoprodeck.com). Asian-English
catalogue and release dates from [Yugipedia](https://yugipedia.com). Prices from
[TCG Corner](https://tcg-corner.com). Yu-Gi-Oh is © Konami; this is an unofficial
fan tool with no affiliation.
