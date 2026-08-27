# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

One collector, who is also a small-scale seller and trader. Two situations,
genuinely different:

- **At home, unhurried.** Looking through the collection, seeing what a set is
  missing, admiring cards, showing someone. This is the *binder* half.
- **In a card shop or mid-negotiation, one-handed, in a hurry, often with no
  signal.** Checking what a card is worth, what is on the selling shelf, what a
  buyer has reserved, whether a trade is fair. This is the *tool* half.

The same person, the same collection, two different jobs. The product has until
now served both with one medium-density interface, which serves neither well —
that is the problem this redesign exists to fix.

## Product Purpose

Track an Asian-English and OCG-JP Yu-Gi-Oh collection, and run the small selling
and trading operation attached to it. Success is that the binder half feels
worth opening for its own sake, and the tool half answers a question in seconds
while standing up.

## Positioning

Priced against the shops that actually stock these cards — TCG Corner and
Players Club for Asian-English, Yuyu-tei for OCG-JP — matched by set *and*
rarity, with stock taking priority over a lower price. A card with no match
shows no price rather than a wrong one. Generic collection trackers price by
card name against Western markets, which is the wrong number for this market.

## Operating Context

- Installed to a phone home screen; opens and works with no network at all.
- Used in shops with poor signal, one-handed, often while holding cards.
- Prices are harvested outside the browser and baked into the file, because the
  shops send no header permitting a browser to read their listings.
- Binders are shared with buyers as a standalone view-only page; buyers send
  back an order code that becomes a pending deal.

## Capabilities and Constraints

**Confirmed capabilities:** two separate regions (Asian-English, OCG-JP) sharing
only a card pool; Collection / Selling / Wishlist piles; sets and archetype
cores with completion; per-printing pricing across three shops; deals with
partial reservation; trade calculator that settles; transfer between devices;
offline via service worker.

**Technical constraints that are facts, not preferences:**
- One HTML file. No build step, no framework, no runtime dependency.
- No external assets — no CDN, no web fonts loaded over the network. A custom
  typeface is only possible embedded in the file itself.
- 1.24 MB of the 1.56 MB file is baked card data. The look is 66 KB of CSS.
- Card art is hotlinked from YGOPRODeck and cached by the service worker.
- 375px is a first-class width, not a fallback.

**Confirmed for this redesign:**
- The app has **two modes**: Binder and Tool, switched by **one global toggle**,
  in the manner of the existing AE/JP region switch.
- The **Wishlist appears in both**, presented differently: as gaps to fill in
  Binder, as a priced buy list with targets in Tool.
- Flows are open to change. No existing screen, division or arrangement is
  preserved by default; the current app is evidence of what it does, not a
  constraint on how it should work.

## Evidence on Hand

Real data throughout — no placeholders anywhere in this product:
- 7,022 Asian-English prices and 22,164 OCG-JP prices, dated, from named shops.
- 454 OCG-JP sets (2013 onward) and 71 Asian-English sets.
- 255 played-stock listings graded A/B/C, kept but never quoted.
- Ten prices verified by hand on the shop's own site (`Tools/README.md` §21).
- The user's own collection lives in the browser and is never uploaded.

No testimonials, customers, benchmarks or press exist. Future work must not
invent them.

## Product Principles

1. **Speed and offline beat everything**, including visual ambition. The moment
   the app matters most is the moment there is no signal.
2. **Never show a number that might be wrong.** No price beats a guessed price;
   stock beats a cheaper listing that cannot be bought.
3. **Rarity is information, not decoration.** Colour and sheen encode what a
   card is worth and cannot be restyled for looks alone.
4. **The two jobs deserve two characters.** Browsing a collection and pricing a
   sale are different activities and should not feel identical.
5. **Nothing is uploaded.** The collection is the user's, held on their device.

## Accessibility & Inclusion

Used one-handed on a phone, frequently in poor light in a shop. Touch targets at
44px minimum, functional text at 11px minimum, all text at 4.5:1 contrast in
both light and dark themes, and `prefers-reduced-motion` honoured.
