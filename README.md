# Carter

Carter is a Swift library for retrieving Open Graph / metadata information from
web pages, and for deciding when two links are **the same article**.

Based on [awkward/Ocarina](https://github.com/awkward/Ocarina) by Rens Verhoeven (MIT).

## Requirements

- Swift 5.9
- iOS 14+ / macOS 11+ / tvOS 14+ / watchOS 7+, **and Linux**
- [Kanna](https://github.com/tid-kijyun/Kanna) (needs `libxml2-dev` on Linux)

## Usage

```swift
import Carter

let url = URL(string: "https://newsinfo.inquirer.net/some-article")!
let info = try await url.carterInformation()

info.title          // "…"
info.canonicalURL   // the article's real address
info.dedupeKey      // the string to store + uniquely index
info.host           // "inquirer.net" — check this against your allow-list
info.publishedAt    // Date?, parsed
```

With a publisher allow-list and tighter limits:

```swift
var config = CarterConfiguration()
config.isHostAllowed = { allowedPublishers.contains($0) }   // also applied AFTER redirects
config.timeout = 10
config.maximumBodyBytes = 2 * 1024 * 1024

let info = try await Carter(configuration: config).information(for: url)
```

Carter is silent by default. To see diagnostics:

```swift
CarterLog.handler = { level, message in logger.log("\(message)") }
```

## Duplicate detection

Carter does not talk to your database — it gives you the key to ask with.

```swift
let key = info.dedupeKey          // e.g. "https://inquirer.net/news/story-123"
```

`dedupeKey` folds the spellings that mean one article: `http`/`https`, `www.`,
trailing slash, `#fragment`, parameter order, and campaign parameters
(`utm_*`, `fbclid`, `gclid`, …). It deliberately keeps parameters that select
content (`?id=`, `?p=`), because collapsing two different articles into one is
worse than missing a duplicate.

**Store it and put a UNIQUE INDEX on it.** A scraper cannot enforce uniqueness:
two people pasting the same link at the same moment both pass any
"check, then insert" written in application code. Let the database refuse it.

## Migrating from 1.x

| 1.x | 2.0 |
|---|---|
| `url.carter.getURLInformation()` | `try await url.carterInformation()` |
| returns `URLInformation?` | returns `URLInformation`, throws a specific `CarterError` |
| `information.url` | `information.canonicalURL` (`.url` still works, deprecated) |
| `imageSize: CGSize?` | `imageSize: ImageSize?` (`.cgSize` on Apple platforms) |
| `Carter.Mode.basic` / `.byURL` | removed — one path, charset-aware |
| `CarterError.failedToGetURLInformation` | specific cases: `.httpError`, `.transport`, `.notHTML`, `.hostNotAllowed`, … |

`title`, `descriptionText`, `originalURL`, `imageURL`, `author`, `keywords`,
`publishDate` (still the raw `String`) and `type` are unchanged, so a call site
that only reads those needs no edit beyond the call itself.

### What changed and why

- **Runs on Linux.** 1.x imported UIKit under `#if !os(macOS)` — true on Linux —
  plus SwiftUI, AVFoundation and `os.log`, so it could not compile server-side.
  Ingestion belongs on the server: a publisher allow-list enforced only in the
  app is not enforcement.
- **A page can no longer choose where its own link points.** 1.x wrote `og:url`
  over the requested URL with a bare `URL(string:)` — no scheme or host check —
  so a page on an allowed domain could make you store a link to anywhere, including
  `javascript:` and `data:`. Claims are now accepted only from the same host,
  and a refused one is surfaced as `rejectedURLClaim`.
- **Redirects are followed to a URL the allow-list actually sees.** 1.x discarded
  `response.url`.
- **A crash is gone.** The inline-keyword scraper sliced `item[start...end]`
  with no ordering check, so any page whose script had `]` before `[` trapped
  the process on attacker-controlled HTML.
- **`twitter:card` is read from `twitter:card`**, not `og:type` — so `cardType`
  is no longer `.other` for every page in existence.
- **No `print`.** 1.x printed fourteen times per fetch and dumped the whole
  model plus the raw response body into the host app's logs.
- **Async, not Combine.** The old bridge leaked every `Carter` (a strong `self`
  capture), stranded the first caller's continuation forever if a second call
  arrived, and delivered on a `.concurrent` queue.
