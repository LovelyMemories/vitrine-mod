# Alternate icons

Each `NAME.png` here becomes an app icon that Appearance offers. `scripts/pipeline.sh` scales it for
iPhone and iPad and adds it to Spotify's `Info.plist`.

- Square, 1024 × 1024.
- `NAME` is letters, digits, `_` and `-`. The picker drops an `SGAppIcon` prefix and reads a capital as
  the start of a word, so `SGAppIconArcsLight` shows as "Arcs Light" and an `_` shows as a space.

`SGAppIcon*.png` are the mod's own set, taken from the 1.0.1 build's bundle. That build ships them already
cut to iOS's rounded square at 180 pt, so each is scaled up to 1024 with the colour just inside its edge
behind the cut corners, which the system's own mask then covers. Chroma's own art (`SGAppIconChroma*`)
stays with that build and is not offered here.

`NewYear2027.png` is the 2027 New Year icon. It was replaced with new art (the original file is kept at
`source/NewYear2027-raw.png`) and adapted for iOS as above: scaled to 1024 × 1024 and saved 24-bit and
opaque, with no transparency.

The icon before it, `Vitrine.png`, was drawn by `source/reeded-light.html` (the idea is in
`source/reeded-light.md`). Open the page to try other seeds and settings, or render one headless:

    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --hide-scrollbars \
      --window-size=1024,1024 --virtual-time-budget=60000 --screenshot=icons/Name.png \
      "file://$PWD/icons/source/reeded-light.html?render=1&seed=7"
