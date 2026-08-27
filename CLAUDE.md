# Yu-Gi-Oh Binder

A collection tracker for **Asian-English** and **OCG-JP** Yu-Gi-Oh cards. One
HTML file, no build step, no server, no account. Installable to a phone and
works with no signal.

Live: https://nobnob-1018.github.io/Yugioh-Asian_English_Binder/

## Design stack

The global rule in `~/.claude/CLAUDE.md` applies here in full: `impeccable` for
the product experience, `frontend-design` for structure and direction,
`taste-skill` for visual language, `ui-ux-pro-max` for layout, type, colour and
UX patterns, and Emil Kowalski's set for motion. Lower number wins on conflict.

What follows is what those skills need to know about **this** project before
they suggest anything.

## Constraints a design skill must not break

- **One file.** Everything ships inside `index.html` — markup, CSS, JS and about
  1.1 MB of baked card data. There is no build step, no bundler, no framework,
  no npm dependency at runtime. A suggestion that needs Tailwind, React, or a
  package is not usable here.
- **No external assets.** No web fonts, no CDN, no icon package. Fonts are
  system stacks; icons are inline SVG. Card art is the one exception — it is
  hotlinked from YGOPRODeck and cached by the service worker.
- **The design tokens already exist.** `--fs-3xs`…`--fs-3xl`, `--sp-1`…`--sp-6`,
  `--r-xs`/`--r-sm`/`--r`/`--r-pill`, `--surface`/`-2`/`-3`, `--sh-1`/`-2`/`-3`.
  Extend that system rather than introducing a parallel one.
- **Light and dark are both real.** Every colour is a token with a
  `:root[data-theme="light"]` counterpart. A hard-coded colour breaks one theme.
- **Rarity colour is meaning, not decoration.** The foil classes (`f-common`
  through `f-holo`, plus the OCG-only `f-millennium`, `f-gold`, `f-par`) encode
  what a card is worth. They are not a palette to restyle for looks.
- **Two regions, two rarity ladders.** Asian-English has 11 rarities, OCG-JP has
  19. Anything that renders rarity has to hold both.
- **375 px is a first-class width**, not an afterthought. It is used on a phone
  in a card shop. Below 920 px the sidebar stacks under the grid, which is why
  the pile and owned switches relocate into the toolbar.
- **Offline is the point.** A service worker serves the app from cache first.
  Anything that assumes a live network will fail exactly when the app matters
  most.

## Priorities

**Speed and offline availability come before maintainability**, and before
visual ambition. This is stated and settled — see `roadmap-and-priorities` in
memory. A change that looks better but costs first paint or offline capability
is the wrong trade here.

## Motion, specifically

- The app already animates: page turns in binder mode, a view cross-fade, a
  number roll-up on the dashboard, tab sliding.
- `prefers-reduced-motion` is honoured and must stay honoured.
- The binder is used **one-handed on a phone, quickly, in a shop**. Motion that
  delays a tap being answered is worse than no motion.

## Where things are

- `index.html` — the whole app, ~9,000 lines of script plus baked data
- `sw.js` — offline caching
- `Tools/` — harvest scripts (Perl) and `Tools/README.md`, the real technical log
- `graphify-out/` — generated knowledge graph, gitignored

`Tools/README.md` is the substantive documentation: 22 sections covering price
sources, both regions, storage, deals, the wishlist and the service worker. The
root `README.md` is **out of date** — it still describes the single-region,
localStorage version.

## Verifying a change

There is no test suite. Changes are verified in the browser:

- Open the app and check both regions, both themes, at 375 px and desktop.
- Ten hand-checked prices and a console snippet live in `Tools/README.md`
  section 21. Re-run it after anything touching price matching.
- The service worker serves the shell from cache, so an edit needs **two
  reloads** to appear, or clear the caches.
