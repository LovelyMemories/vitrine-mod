# AutoMix planner helper

The Swift library that asks Apple's SonicKit for a transition plan. It is a **draft**: it does not build yet,
and nothing in the normal tweak build depends on it.

## Why it is here and not in `Sources`

`tweak/Makefile` collects every `.m` and `.x` under `tweak/Sources` (`find Sources …`), so anything put there is
compiled by every build. This helper cannot compile without a Mac, the iOS 26 SDK and a completed
`Interface26.swift`, and it must not break the phone build in the meantime. Hence its own directory and its own
Makefile.

## Building it

On a Mac with Theos and the iOS 26 SDK:

```sh
make -C tweak/AutoMix
```

Then copy the product into the app's Frameworks before packaging, next to `spotifyglass.dylib`:

```
Spotify.app/Frameworks/SpotifyGlassAutoMix26.dylib   # iOS 26
Spotify.app/Frameworks/SpotifyGlassAutoMix.dylib     # below it, against SonicKit_MusicKit
```

`Shared/AutoMix/AutoMix.m` finds them there with `dlopen`, and answers `SGAutoMixAvailable() == NO` when they are
absent — the mod then behaves exactly as it does today.

## What is known and what is not

Known, from the symbols in the 1.0.1 build (docs/automix-sonickit.md):

- the entry point is `SGAutoMixPlan(const char *, const char *, const char *) -> char *`;
- it calls `TransitionPlanner.transition(from:to:criterias:)` and hands back a textual dump;
- two variants exist because iOS 26 moved the framework to `_SonicKit_MusicKit_Packages`;
- `Transition` is **Encodable** (`…VSEAAMc`) and `Song.Analysis` is **Decodable** (`…OSeAAMc`), so the plan is
  JSON and an analysis can be handed to the planner as JSON.

Not known:

- the real shape of `Song.Analysis`, `Criteria` and `Transition` — `Interface26.swift` guesses them from names;
- whether the planner is any use without analysis (it plans from durations and criteria alone);
- how a plan is meant to be applied to Spotify's crossfade.

## Order of work

1. Complete `Interface26.swift` until `SGAutoMixPlan` compiles against the real framework.
2. Check the plan on a phone: two tracks, log the returned JSON.
3. Decide what the plan changes: the crossfade length, the moment the next track starts, or both.
