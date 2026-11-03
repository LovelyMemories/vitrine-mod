# AutoMix в 1.0.1: что там на самом деле

Разбор сборки `chroma-1.0.1.ipa` (Spotify 9.1.90). Это отвечает на вопрос «почему у них работает, а у нас
нет» и почему SonicKit — не то, о чём стоит начинать.

## Состав

| Файл | Что это |
|---|---|
| `spotifyglass.dylib` | сам мод, 10 МБ; **здесь живёт AutoMix** |
| `SpotifyGlassAutoMix26.dylib` / `SpotifyGlassAutoMix.dylib` | 80–100 КБ, тонкая обёртка над SonicKit |

Обёртка умеет одно: спросить у Apple `TransitionPlanner.transition(from:to:criterias:)` и вернуть план.
Всё остальное — в основном дюлибе.

## Механизм в дюлибе (по строкам)

**Свои ключи настроек.**

```
spotifyglass.automix                 — общий выключатель
spotifyglass.automix.mode            — Apple Music Automix | Spotify Automix
spotifyglass.automix.style           — стиль перехода
spotifyglass.automix.length          — длина
spotifyglass.automix.effects         — кривые эффекты Apple
spotifyglass.automix.premium         — «Needs Spotify Premium»
spotifyglass.automix.granted
spotifyglass.automix.crossfade.saved / .crossfade-setting
spotifyglass.automix.playlists / .albums / .likedsongs / .radio / .queue / .autoplay
spotifyglass.automix.show-progress / .show-queue / .artwork
```

**Флаги, которые оно прокручивает в Spotify.**

```
ios-feature-settings.automix_enabled
ios-playlistcuration-mats.automix_track_order_context_menu_enabled
autofix.*  — service.config(core-automix) / (audio-automix)
automix.ignore_setting        — чтобы серверное «выключено» не мешало
automix.mode / automix.queue / automix.autoplay / automix.mode_on_tracks
```

**Ключи, которые Spotify понимает в **состоянии трека** (cue points).** Это главное:

```
automix.playable_uri            automix.transition_uri
automix.fade_in_cuepoint.position / .origin / .tempo
automix.fade_out_cuepoint.position / .origin / .tempo
automix.beats_hash              automix.auto_transition_recipe
automix.auto_preset_id          automix.backend_auto_transition
audio.automix_mode              audio.automix
```

То есть Spotify **уже умеет** плавные переходы: ему надо подложить cue points в состояние трека и включить
режим. Никакого своего DSP не нужно — звук смешивает он сам.

**Своя страница настроек и превью.**

```
SGAutoMixWatch   SGAutoMixCrossfade   SGAutoMixInfoView   SGAutoMixPreview
```

**Своё состояние в обход сервера.** Ключи `spotipw.*` (`spotipw.account.automix`,
`spotipw.automix.marked`) — их собственная схема, к нашему форку не относится.

**Кроссфейд.** Строка `Spotify's crossfade is still at AutoMix's length, putting back the user's own (%@, %@ ms)`
говорит, что AutoMix на время подставляет свою длину в `audio.crossfade` и потом возвращает исходную.

## Что это значит для нас

1. **SonicKit — необязателен.** Он даёт только план для режима «Apple Music Automix». Режим
   «Spotify Automix» работает без него: cue points + флаги.
2. **Тот же лог, что мы видели, это подтверждает:** `no SGAutoMixPlan` — их сборка тоже стартует без
   планировщика, если дюлиба нет рядом, и продолжает работать на Spotify-переходах.
3. **Наша полоса «Переходы между треками» пустая не из-за AutoMix, а из-за того, что Spotify не
   показывает эти строки.** Значит нужен путь, который не зависит от страницы настроек: включить
   `ios-feature-settings.automix_enabled` и/или `automix.ignore_setting`, и посмотреть, появятся ли
   строки или начнут ли работать переходы.

## Порядок для повтора

1. Проверить, прокручиваются ли флаги: `automix_enabled` в `ios-feature-settings` (в нашей таблице
   `Premium.m` он уже есть) — и снять лог `premium: out …`.
2. Если строки не появляются — добавить `automix.ignore_setting` и повторить.
3. Если и это не помогает — cue points как путь: подложить `automix.fade_in_cuepoint.*` в состояние
   трека и посмотреть, воспримет ли их плеер 9.1.90.
4. SonicKit — последним, и только для режима Apple Music.

Пока пункт 1 не проверен, переписывать планировщик бессмысленно: неизвестно, включён ли AutoMix вообще.
