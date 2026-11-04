# Что осталось по страницам мода

Записано 2026-11-04, после захода, в котором Player, Home, Albums и Appearance были приведены к виду
сборки 1.0.1 (`chroma.ipa`) настолько, насколько это переносится из скомпилированного dylib.

## Что уже есть

| Страница | Коммит | Что сделано |
|---|---|---|
| Appearance | `7c60c14` | 24 иконки видны, подписи «Arcs Light», страница выбора (`2045aa4`), полоса акцентов с недавними цветами (`21c533c`), «Accent from the cover» (`b60c869`) |
| Home | `efececc` | карточка показывает настоящий фид Главной; квадратные обложки артистов (`8021997`) |
| Albums | `f531f25` | hero-карточка: обложка во всю ширину, название/артист/`Album · 2024`, shuffle · ▶ Play · +; порядок секций как у них (`b78c02a`) |
| Player | `fc60af2` | карточки фонов с превью обложки вместо строки названий; Sources (`eb94429`); Buttons и Volume slider (`8db311b`); шейдерное поле Fluid на карточке (`5704955`, прозрачность `ea3d034`) |

## Что осталось

### 1. Artist picture (Albums)

В нашем redesign шапка альбома заменена целиком, поэтому «фото артиста» показывать нечем: строку Spotify
`ParentRow` (артист с фейспайлом) мы подавляем.

План: не подавлять `ParentRow`, а **взять из неё `UIImageView`** (фейспайл), уменьшить и поставить кругом
24 pt слева от имени артиста в нашей шапке. Ключ `spotifyglass.redesign.album.artistPicture`, строка в
`AlbumSettings.m`. Скрывать через `alpha`, не `hidden` — внутри Encore-стека `hidden` роняет приложение.

Файлы: `Redesigned/Album/AlbumHeader.x`, `AlbumSettings.m`.

### 2. Play count on every track (Albums)

Чисел прослушиваний у нас нет ни в одном заголовке (`Headers/`, `AlbumRows.x`). У chroma они есть
(`SGRAlbumPreviewTrackList` с `_plays`), значит Spotify их отдаёт.

Первый шаг — **дамп ключей метаданных**: в `AutoMixCue.x` есть хук на `SPTPlayerTrack.metadata`; добавить
однократный `SGLog(@"metadata keys: %@", metadata.allKeys)`, собрать, открыть альбом, посмотреть имя поля
(`playcount` и подобные), затем вставить число в трейлинг строки трека (`AlbumRows.x`), ключ + строка
`Play count on every track` (меню `Off / Show`).

### 3. Full screen cover (Albums) как переключатель

Сейчас полное покрытие обложкой — **поведение по умолчанию** (`AlbumHeader.x`: «The cover runs full bleed
across the top of the page and dissolves into the page's color»). Чтобы это стало выключателем, нужен
второй путь раскладки — обычная шапка Spotify с маленькой обложкой. Работа средняя, затрагивает
`AlbumHeader.x` целиком.

### 4. Мелочи из их Player, которых у нас нет механики

`Shuffle` / `Repeat` (нужны ключи и скрытие кнопок), `Music app style`, `Glass behind the top buttons` —
это их собственные настройки, не оформление.

## Как проверять локально (macOS-VM)

```
~/build.sh                      # вся сборка, 12–16 с, печатает ошибки только наших файлов
~/check.sh Sources/<путь>.m     # один файл, секунды
```

Ограничения VM: clang 12 читает только SDK 14.5, поэтому `Backup.m`, `Tour.m`, `ModSettings.x` (API iOS 15/26)
локально не компилируются — это ожидаемо и в вердикт скрипта не входит. Swift (5 файлов) отложен в
`~/swift-parked`, для него нужен Xcode.
