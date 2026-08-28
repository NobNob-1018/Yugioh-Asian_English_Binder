# Design

Written from the built result, not from intentions. Every value below was read
out of the running app.

## The world

**Score Notation.** A dance score — white paper, one ink, and meaning carried
by fill, length and position rather than by colour.

The idea it refuses is the card-art grid with filter chips that every
collection tracker ships. The idea it commits to is that **colour means
exactly one thing here**: rarity. Nothing else on the page is coloured, which
is what makes a foil chip readable at a glance in a shop.

Four rules from the source, applied:

| Notation says | Here it means |
| --- | --- |
| Level is shown by **fill** | Condition and state are hatch and stipple, never hue |
| Time is shown by **length** | A price bar reads before the number does |
| **Symmetry** guides the eye | Holding on one side of the line, market on the other |
| The **staff** is the structure | A hairline rules every column |

The direction contract sits at the top of `<body>` in `index.html` and is the
authority if this file and the build ever disagree.

## Colour

Paper is the default rendition, because the app is read under a shop's
fluorescent light with glare on the glass. The dark theme is the same score
printed in reverse — a polarity flip, not a recolour.

| Token | Paper | Negative |
| --- | --- | --- |
| `--bg` | `#F1F1EE` | `#0B0B0B` |
| `--surface` | `#FFFFFF` | `#141414` |
| `--surface-2` | `#FAFAF8` | — |
| `--text` | `#111111` | `#F2F2EE` |
| `--muted` | `#55555A` | `#A8A8A2` |
| `--faint` | `#666669` | `#94948D` |
| `--line` | `#D6D6D2` | `#333330` |
| `--line-soft` | `#E8E8E4` | — |
| `--band` | `#E6E6E6` | `#2A2A28` |
| `--accent` | `#111111` | `#F2F2EE` |
| `--on-accent` | `#FFFFFF` | `#0B0B0B` |

**The accent is the ink.** Emphasis is inversion, not hue — a pressed control
is a solid ink block with paper lettering, which reads with colour removed
entirely.

`--muted` and `--faint` are set from contrast, not taste. Both clear 4.5:1 on
every surface they appear on **including `--band`**, which is the tightest:
`--faint` measures 4.59:1 on paper and 4.71:1 on the negative.

### The one exception

The foil classes — `f-common` through `f-holo`, plus the OCG-only
`f-millennium`, `f-gold`, `f-par` and `f-overframe` — are **information, not
palette**. They encode what a card is worth across two ladders (11 rarities in
Asian-English, 19 in OCG-JP) and must not be restyled for looks.

`f-holo` carries a glow the design detector flags. It stays: Holographic Rare
*is* a glow in the hand. Every other glow in the file was removed.

## Type

```
--display  ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, …
--body     (the same stack)
--mono     ui-monospace, "SF Mono", "Cascadia Mono", "Segoe UI Mono", …
```

**A named concession.** This world wants a tall condensed display face. No web
fonts are permitted — one file, no external assets — and none is installed. So
the display register is carried by **tracked caps at scale**, and the identity
lives in the staff, the fills and the beat band. The staff is the structure,
not the lettering.

An earlier build named *Nunito* and never loaded it, so it rendered only on
machines that happened to have it. These are real stacks; every device gets
what was designed.

**Numerals are their own voice.** Prices, set codes, counts and dates are
measurement, so they are mono with `tabular-nums` and hold a column that does
not reflow while being read.

| Step | Size | Used for |
| --- | --- | --- |
| `--fs-3xs` | 11px | the floor for anything you must read and act on |
| `--fs-2xs` | 11.5px | captions, keys |
| `--fs-xs` | 12px | secondary rows |
| `--fs-sm` | 13px | controls |
| `--fs-md` | 14px | body, the wordmark |
| `--fs-lg` | 15px | emphasis |
| `--fs-xl` | 19px | panel headings, search query |
| `--fs-2xl` | 26px | the dashboard value |
| `--fs-3xl` | 40px | reserved |

Nothing functional goes below 11px. It is read at arm's length in a shop.

## Space, edges, depth

`--sp-1` 4 · `--sp-2` 8 · `--sp-3` 12 · `--sp-4` 16 · `--sp-5` 24 · `--sp-6` 32

**Every radius is 0.** A score is square, `--r-pill` included.

**There are no shadows.** The `--sh-*` tokens survive because ~600 rules call
them; they now draw the hairline that replaced the blur.

```
--sh-1  none
--sh-2  0 0 0 1px var(--line)
--sh-3  0 0 0 1px var(--text)
```

## Motion

One authored moment, not scattered effects.

```
--ease  cubic-bezier(.16, 1, .3, 1)    exponential, leaves fast and settles
--fast  120ms
--slow  220ms
```

The world's own motion is a **playhead**: a band travelling down a score while
the score holds still. So the **beat band** is the only thing that animates —
it sweeps in from the left across the active row.

**The rule that outranks the rest:** this is used one-handed in a shop, so
nothing may delay a tap being answered. Every control inverts on `:active`
with **no transition at all**. Motion is spent on telling you where you are,
never on whether the button heard you.

`prefers-reduced-motion` is honoured throughout.

## Components

- **Active is inversion** — solid ink, paper lettering. Readable with colour
  removed, which keeps rarity's channel clear.
- **The beat band** marks the row you are on, covering exactly its own row.
  An earlier version bled 16px past each edge and showed as a grey strip
  hanging outside lists inside modals.
- **The legend** (`How to read this`) names the four channels — colour is
  rarity, fill is condition, inverted is selected, the band is your row. A
  notation only works if the reader learns it, and the app cannot teach.
- **Search is a panel**, not a live filter. It opens over the page, which is
  desaturated and blurred behind it, and the page does not move until you pick
  a result.
- **Nothing in the toolbar moves.** Navigation owns the left edge, the pager
  the right, and the caption holds a fixed slot between them. Hidden controls
  keep their slot only where it does not cost a row.

## Responsive

**375px is a first-class width**, not a fallback — it is used on a phone in a
card shop.

- Below 920px the **list is the default**, because a nine-pocket sheet does not
  fit; a list row carries code, rarity and price on one readable line.
- In grid mode below 920px the **caption sits on the card art**. Under a 110px
  card, three values competing for one 22px line are unreadable and cost the
  art its height.
- Filters become a **bottom sheet** over the grid, reached from one
  thumb-reachable button carrying a count.
- Controls that cannot work on a phone — facing pages, cards-per-page — are
  **removed, not disabled**. A dead control is one you can still mis-tap.
- The **row count is measured**, not guessed: a card is 1.458× as tall as it is
  wide, so the grid takes the rows that actually fit the window.
- Every tap target is **44×44** minimum.

## What this file is not

It does not restate product truth — see `PRODUCT.md` — or the technical log,
which is `Tools/README.md`.
