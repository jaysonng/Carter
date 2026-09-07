# Carter

Carter reads Open Graph, schema.org and Twitter-card metadata from a web page,
and works out when two links point at **the same document**.

Based on [awkward/Ocarina](https://github.com/awkward/Ocarina) by Rens Verhoeven (MIT).

## Requirements

- Swift 5.9
- iOS 14+ / macOS 11+ / tvOS 14+ / watchOS 7+, and **Linux**
- [Kanna](https://github.com/tid-kijyun/Kanna) (`libxml2-dev` on Linux)

## Usage

```swift
import Carter

let url = URL(string: "https://example.com/some-article")!
let info = try await url.carterInformation()

info.title          // schema.org headline, else og:title, else <title>
info.author         // resolved through the page's @graph if it uses one
info.canonicalURL   // the document's real address
info.dedupeKey      // the string to store and uniquely index
info.tags           // [String], gathered from four possible sources
info.publishedAt    // Date?  — first publication
info.modifiedAt     // Date?  — last edit, kept separate
```

### Configuration

```swift
var config = CarterConfiguration()
config.isHostAllowed = { allowedHosts.contains($0) }   // re-checked AFTER redirects
config.timeout = 10
config.maximumBodyBytes = 2 * 1024 * 1024
config.ambiguousTimeZone = TimeZone(identifier: "Asia/Manila")   // see below

let info = try await Carter(configuration: config).information(for: url)
```

Carter is silent by default:

```swift
CarterLog.handler = { level, message in myLogger.log("\(message)") }
```

### Set `ambiguousTimeZone` if you can

`PST` means Pacific Standard Time in North America and Philippine Standard Time
in Manila — sixteen hours apart, enough to date an article to the wrong day.
Foundation resolves the abbreviation against the formatter's locale and will
pick a continent for you. Carter refuses to guess: unqualified abbreviations are
read as **UTC** unless you say otherwise. Dates with an explicit offset (`+08:00`)
or a `Z` are never affected. Same ambiguity applies to `CST`, `IST`, `BST`,
`AMT` and `ECT`.

## Where it reads from

Precedence is deliberate — schema.org is what a CMS populates properly, Open
Graph is the lowest common denominator, `<title>` is the last resort.

| field | sources, in order |
|---|---|
| `title` | `NewsArticle.headline` · `og:title` · `twitter:title` · `<title>` |
| `author` | `NewsArticle.author` (via `@graph`) · `author` · `article:author` |
| `descriptionText` | `og:description` · `NewsArticle.description` · `description` |
| `tags` | `NewsArticle.keywords` · `article:tag`(×n) · `news_keywords` · `keywords` · inline script |
| `publishedAt` | `datePublished` · `article:published_time` · `og:pubdate` · … |
| `imageURL` | `og:image:secure_url` · `og:image:url` · `og:image` · `twitter:image` · `NewsArticle.image` |

Sampling four unrelated news sites, all four published a schema.org
`NewsArticle` while only some published useful `og:` beyond a title and an
image — and each of the three tag sources was the *only* one present on at
least one site.

## Duplicate detection

Carter does not talk to your storage. It gives you the key to ask with.

```swift
let key = info.dedupeKey   // "https://example.com/some-article"
```

`dedupeKey` folds the spellings that mean one document: `http`/`https`, `www.`,
a trailing slash, a bare host versus `/`, `#fragment`, query-parameter order,
and campaign parameters (`utm_*`, `fbclid`, `gclid`, …). It deliberately keeps
parameters that select content (`?id=`, `?p=`), because collapsing two
different documents into one is worse than missing a duplicate.

**Store it and put a unique index on it.** A scraper cannot enforce uniqueness:
two callers submitting the same link at the same moment both pass any
"check, then insert" written in application code. Let the database refuse it.

## Safety

- Only `http` and `https` are fetched or stored — never `javascript:`, `data:`
  or `file:`, wherever a URL enters, including one the page supplies itself.
- A page's `rel="canonical"` / `og:url` is a **claim**. It is honoured only when
  it stays on the same host; a refused claim is surfaced as `rejectedURLClaim`
  rather than dropped silently.
- `isHostAllowed` is consulted again after redirects, so an allow-list sees
  where the request actually ended up.
- Requests carry a timeout and a body-size cap.

## Migrating from 1.x

| 1.x | 2.x |
|---|---|
| `url.carter.getURLInformation()` | `try await url.carterInformation()` |
| returns `URLInformation?` | returns `URLInformation`, throws a specific `CarterError` |
| `information.url` | `information.canonicalURL` (`.url` still works, deprecated) |
| `imageSize: CGSize?` | `imageSize: ImageSize?` (`.cgSize` on Apple platforms) |
| `Carter.Mode.basic` / `.byURL` | removed — one path, charset-aware |
| `.failedToGetURLInformation` | `.httpError` · `.transport` · `.notHTML` · `.hostNotAllowed` · … |

`title`, `descriptionText`, `originalURL`, `imageURL`, `author`, `keywords`
(now comma-joined and quote-stripped) and `type` keep their 1.x shapes.

## Known limits

- **Some sites refuse automated fetches.** Both patterns exist in the wild: a
  challenge that allowlists named social crawlers, and an edge that demands a
  complete browser header set and refuses even `facebookexternalhit`. Carter
  reports these as `CarterError.httpError(statusCode: 403, url:)` so a caller
  can degrade instead of failing. It does not impersonate a browser or another
  company's crawler, and adding a user-agent that does is your decision, not a
  default.
- `normalizedHost` strips `www.` but does not implement the public suffix list,
  so `a.example.co.uk` and `b.example.co.uk` remain distinct hosts.
