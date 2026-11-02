# Flow

Flow is Vitrine's third look, after Native and the redesign (`AGENTS.md`). It is not a new skin in
passing: it is the redesign's screens taken further, from the player out, and it is what `SGKeyLook`'s
third value picks (`Core/SGUIMode.h`).

This file is the design. It is deliberately smaller than `docs/tweaks.md`: it says what Flow looks like,
what it draws from, and what it may not pretend to have.

## The idea

The redesign is Spotify's screens, restyled. Flow is the mod's own player, with the rest of the app
arriving behind it. Where the redesign keeps one player screen, Flow has three, switched in place:

- **Aura** — the song as a mood. The cover floating over the color it casts, the lines around the one
  being sung, and a badge of what the song is, in numbers it actually has.
- **B-Side** — the song taken apart. What the separation model hears (the voice, the rest), and the
  song's own credits, where the screen used to hold a lyric preview.
- **Synesthesia** — the song as light. The spectrum the player already reads, drawn as a field that
  answers a touch.

The three are one screen's worth of room, not three pages: Spotify's title, progress and controls stay
where the redesign puts them, and the band between the header and the title carries the mode.

## Color

Black throughout, as the redesign is, but the light is the cover's, not an accent color's: the same
color `SGRFlow`-style extraction gives the redesign's Fluid field and Follow the cover, at two levels —
a deep wash for the field, a bright one for strokes and the badge. A gray cover gives the mod's accent
back, as Follow the cover does.

Text keeps 4.5:1 over whatever is behind it (7:1 with Increase Contrast). The dim behind the lyrics and
behind a mode's dense text is the player's existing dim, scaled by mode rather than a second layer over it.

## What each mode draws

### Aura

The band is Flow's, not Spotify's: the band's own background is the cover's wash, Flow draws the artwork
itself — 240 pt at most, rounded, never the full square — and the sung line and its neighbours go under it.
Spotify's own cover and the lyric preview it draws are *behind* that background, so nothing Flow draws can
land on them and nothing of Spotify's can land on Flow. That is the whole reason the band is painted
opaque rather than layered over.

The lines are `Shared/Lyrics`' own (`SGKaraokeLeadLine`), the same ones the lock screen reads. How many fit
is measured from the room left under the cover: three, then two, then one.

The tempo badge waits for a tempo: `SGMusicAnalyzer` hears hits, not a beat, and Flow does not print a
number it has not measured.

### B-Side

What the separation model hears, as it hears it: two rows, **Voice** and **Rest**, each with a slider and
a meter. The meters come from Sing's own voice/rest split (`Shared/Sing`) through `SGSingReadLevels`;
nothing is read while Sing is off, since reading the levels is itself what makes the model separate and
running the Neural Engine for a meter is not a trade worth making.

The sliders are real gains. The voice's is Sing's own level (`SGSetSingLevel`); the rest's is
`SGSingEngineSetRestLevel`, a second gain on the engine's rest path whose default of 1 leaves today's sound
exactly as it was. Both are put back where they were when the mode lets go — a player's control, not a
setting — so leaving B-Side cannot leave a song half mixed.

Four stems do not exist and are not claimed: the model gives the voice and everything else.

The credits half of the mode waits on a way to read the player's credits card; where Spotify has none,
the mode shows nothing rather than invented names.

### Synesthesia

The spectrum, not a timer: `SGRSpectrum`'s bands, drawn as a field whose crests are the loud bands and
whose color follows the cover, with the kick a mound in the middle (the two bands under 80 Hz left out,
as the Visualizer does). Three styles — Fluid, Rings, Orbs — differ in geometry, not in data.

A touch distorts the field: the crest nearest the finger is lifted and pushed aside, easing back over
about a second. It is a drawing, not a simulation; nothing here is fluid dynamics.

The bars stand on the foot of the band over a gradient into black, the way Aura's lines do: the cover stays
Spotify's, and the scrim is what makes the row read as part of the player rather than as marks on the
artwork. The cover is not hidden — `SGRPlayerSetCoverHidden` would be the tidier picture, but if the band's
own frame is measured from that cover, hiding it can leave the band without a frame, and then the switch
goes with it.

## What is real, and what is not

| Shown | Source | Honest? |
|---|---|---|
| Spectrum, crests | `SGRSpectrum` over `SGAudioSetOutputReader` | yes |
| Tempo, onsets | `SGMusicAnalyzer` on the same tap | yes |
| Voice / Rest levels | `Sing`'s separation (Mel-Band RoFormer) | yes, and only two stems |
| Voice / Rest gains | Sing's level, and the engine's rest gain | yes, both real; put back when the mode leaves |
| Cover color | the artwork's own pixels | yes |
| Credits | Spotify's credits card, where present | yes, and absent otherwise |
| BPM "vibe" words | — | **no**: no mood data exists; show the number, not a mood |
| Producer feed, "verified" notes | — | **no**: nothing in the app has this; omit |
| Whole-track waveform | — | **no**: the tap sees only what played |

Flow must not ship a screen that invents content. A mode that has nothing to show shows nothing.

## Limits, inherited

- 120 Hz is the player's; a `CADisplayLink` of the mod's is capped at 60 Hz (30 behind the lyrics, 15
  under Reduce Motion), and stops when the player is off screen, Spotify is not in front, or a paused
  song's field has settled.
- Low Power Mode and Reduce Motion take the motion out, not the layout.
- The separation runs on the Neural Engine, two seconds at a time: a gain change is heard a lead later,
  never at once. The screen says so where it matters.
- iOS 26 floor, as the redesign's.

## Where the code goes

```
tweak/Sources/Flow/
  Kit/       SGFColor (the cover's wash and glow, black base, accent fallback)
  Player/    FlowPlayer.x (the band put on Spotify's player), FlowPlayerPanel.m (the switch and the
             modes' host), FlowAura.m (three lines, under the cover), FlowBside.m (the model's two
             halves, metered), FlowSynesthesia.m (the bars)
```

Flow imports `Core`/`Settings`/`Shared` only; it never imports `Redesigned`, and `Redesigned` never
imports it (`scripts/check-layers.sh`). The redesign's player files hold themselves off under Flow with
`!SGFlowUI()` where they would draw the same band.

Three things Flow needs from the redesign and cannot import. Each goes through the mechanism `AGENTS.md`
names for this — a function declared low, in `Core`, and defined high — rather than through a move of the
redesign's files, which would also move `harness/visualiser`'s paths:

1. **The spectrum.** Done: `Core/SGSpectrum.h` declares the bands, `Redesigned/Player/SGRSpectrum.h` is
   now a line that imports it, and `SGRSpectrum.m` still owns the FFT. Flow feeds
   `SGAudioSetOutputReader` itself while Synesthesia is on screen, so only the player being looked at
   installs the tap.
2. **The player's geometry.** Done: `Core/SGPlayerGeometry.h` declares the artwork band, the cover's
   frame and its scale and the way to keep the cover out of the way, all defined by
   `Redesigned/Player/PlayerArtwork.x`. Flow's player draws in the band Spotify already gives the cover.
3. **The lyrics view, still open.** Aura needs lines, not the redesign's whole view. Either
   `SGRKaraokeView` is reached through a `Core` door the same way, or Aura draws its own preview from the
   lyrics the mod already holds. The second is cheaper and is what Aura ships first.
