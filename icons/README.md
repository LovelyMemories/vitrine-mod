# Alternate icons

Each `NAME.png` here becomes an app icon that Appearance > App icon offers. `scripts/pipeline.sh`
scales it for iPhone and iPad and adds it to Spotify's `Info.plist`.

- Square, 1024 × 1024, no transparency.
- `NAME` is letters, digits, `_` and `-`. An `_` shows as a space in the list.

`NewYear2027.png` is the 2027 New Year icon. It was replaced with new art (the original file is kept at
`source/NewYear2027-raw.png`) and adapted for iOS as above: scaled to 1024 × 1024 and saved 24-bit and
opaque, with no transparency.

The icon before it, `Vitrine.png`, was drawn by `source/reeded-light.html` (the idea is in
`source/reeded-light.md`). Open the page to try other seeds and settings, or render one headless:

    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --hide-scrollbars \
      --window-size=1024,1024 --virtual-time-budget=60000 --screenshot=icons/Name.png \
      "file://$PWD/icons/source/reeded-light.html?render=1&seed=7"
