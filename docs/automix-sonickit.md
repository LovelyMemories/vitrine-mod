# AutoMix через SonicKit (разбор сборки 1.0.1)

Что лежит в `chroma-1.0.1.ipa` (`com.kdt.livecontainer`, Spotify 9.1.90) и как повторить это в Vitrine.

## Что там есть

Два крошечных Swift-хелпера рядом с основным твиком:

| Файл | Размер | Линкуется к |
|---|---|---|
| `SpotifyGlassAutoMix.dylib` | 100 КБ | `_SonicKit_MusicKit.framework` |
| `SpotifyGlassAutoMix26.dylib` | 80 КБ | `_SonicKit_MusicKit_Packages.framework` |

`SonicKit` — приватный фреймворк Apple, движок AutoMix из Apple Music. Два варианта нужны потому,
что на iOS 26 модуль переехал в `_Packages` и раскладка типов другая: в старом варианте есть строка
`this system's planner types differ from Interface27.swift:` — то есть интерфейс объявлен руками
(`Interface27.swift`) и версия проверяется в рантайме.

## Как это связано с твиком

В `spotifyglass.dylib` лежат строки:

```
SpotifyGlassAutoMix.dylib
SpotifyGlassAutoMix26.dylib
SGAutoMixPlan
no SGAutoMixPlan
```

То есть основной твик **dlopen-ит** хелпер и ищет символ `SGAutoMixPlan`; если его нет — пишет в лог
`no SGAutoMixPlan`. Прямой линковки нет, поэтому сборка не падает там, где приватного фреймворка нет.

## Что делает сам хелпер

Экспортируется одна C-функция (мангал:

```
$s19SpotifyGlassAutoMix06SGAutoD4PlanySpys4Int8VGSgSPyADG_AGSpyAFGSgtF
SGAutoMixPlan(UnsafePointer<Int8>?, …, …) -> UnsafeMutablePointer<Int8>?
```

три указателя на байты, возвращает C-строку). Внутри — вызовы SonicKit:

```
TransitionPlanner.transition(from: Song, to: Song, criterias: Criteria)
    -> Result<Transition, FailureReason>
TransitionPlanner.Configuration.default
TransitionPlanner.Song(id:duration:analysis:context:)   // analysis — опциональный
Transition.Criteria.IncomingPlacement / OutgoingPlacement (Early/LateConstraint)
Transition: Complexity, DSPGraph, SongPlaybackState, TimeStretchingState
TransitionSchedulingPolicy
```

Плюс `JSONObjectWithData:options:error:` — вход разбирается из JSON, а `dump(_:to:name:)` в старом
варианте говорит, что наружу отдаётся текстовый дамп результата.

**Вывод:** хелпер — чистый планировщик. Он не рендерит звук, а считает: где войти, на какой бит,
насколько растянуть, когда начать. Никакого DSP-перехода внутри Spotify он не делает.

## Чего не хватает для повтора

1. **Интерфейс приватного фреймворка.** Его нет в публичном SDK; `Interface27.swift` в сборке
   скомпилирован, но исходника нет. Восстанавливать надо на Mac, компилятором: ошибки типов и есть
   документация. Без iOS 26 SDK это не сделать.
2. **Данные анализа.** `Song.analysis` опционален, но именно он даёт качество: без него планировщик
   работает по длительностям и ограничениям. А анализа у нас нет — аудио-выход Spotify на текущей
   сборке недоступен (`AudioOutputUnitStart`).
3. **Что делать с планом.** План — это числа. Применять их надо к **родному** кроссфейду Spotify
   (когда начать и сколько длить). Apple-овского морфа звука не будет: для него нужен
   декодированный звук обоих треков, которого у нас нет.

## Порядок работ, если делаем

1. На Mac: Swift-таргет в Theos (`.swift` уже попадает в `find` в `tweak/Makefile`).
2. Объявить минимальный интерфейс SonicKit, добиться компиляции под iOS 26 SDK и под старым.
3. `@_cdecl("SGAutoMixPlan")`: на вход JSON `{id, duration}` двух треков, на выход — `dump` плана.
4. В твике: `dlopen` нужного варианта, `dlsym`, разбор плана, применение к кроссфейду.
5. Проверка на телефоне: план для пары треков, затем реальное поведение перехода.

## Риски

- Приватный API: ломается на обновлениях iOS, отсюда и два варианта.
- Без анализа план будет грубым — это не AutoMix из Apple Music, а его расписание.
- Копировать скомпилированный код из чужой подписи нельзя; здесь речь только о повторении
  архитектуры в своём проекте.

## Что уже в репозитории

- `Shared/AutoMix/AutoMix.{h,m}` — загрузчик: `dlopen` нужного варианта, `dlsym("SGAutoMixPlan")`,
  вызов с тремя JSON и возврат строки. Компилируется обычной сборкой; без хелпера
  `SGAutoMixAvailable()` отвечает NO и мод ведёт себя как раньше.
- `tweak/AutoMix/` — черновик Swift-хелпера (`SGAutoMix.swift`), ручной интерфейс SonicKit
  (`Interface26.swift`), отдельный `Makefile` и `README.md`. **В обычную сборку не входит**:
  `tweak/Makefile` читает только `tweak/Sources`.

