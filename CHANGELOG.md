# Changelog

All notable changes to Carter are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [2.1.0] - 2026-09-08

### Added

- **schema.org (JSON-LD) extraction.** `<script type="application/ld+json">` is
  read for `headline`, `author`, `datePublished`, `dateModified`,
  `articleSection`, `keywords`, `image` and `publisher`, including `@graph`
  containers whose article refers to its author and image by `@id` — read
  naively those yield a URL where a name should be. Sampling four unrelated
  news sites, all four published a `NewsArticle` block while only some
  published useful `og:` beyond a title and an image.
- **`tags: [String]`** — gathered from schema.org `keywords`, repeatable
  `article:tag`, `news_keywords`, the `keywords` meta tag and the inline-script
  fallback, deduped case-insensitively with order preserved. Each of those was
  the ONLY source present on at least one site in that sample. `keywords` stays
  as the raw comma-joined string, now quote-stripped.
- **`modifiedAt`**, separate from `publishedAt`.
- **`publisherName`** from schema.org `publisher`, falling back to `og:site_name`.
- `MetaReader.contents(forProperty:)` for repeatable tags; the previous reader
  returned only the first, which lost every `article:tag` after the first one.

### Fixed

- **Inline `var keyword` scripts are found whatever the `type` attribute says.**
  The reader required `type="text/javascript"`. Lazy-loading plugins rewrite it
  (WP Rocket ships `type="text/rocketlazyloadscript"` and moves the real type to
  `data-rocket-type`) and modern HTML omits it altogether, so on those pages the
  tags were silently lost. Every `<script>` is now searched.

### Changed

- **`publishedAt` now prefers FIRST publication over last edit.** It previously
  asked for `article:modified_time` first, so a story corrected years later
  sorted as though it were new. The edit time is still available, as
  `modifiedAt`.
- **`ambiguousTimeZone` defaults to UTC, not to a region.** Carter is a general
  library and must not assume where its caller's publishers are; set it if you
  know. (2.0.1 defaulted to `Asia/Manila`, which was right for the author's
  application and wrong for a public package.)

### Fixed

- A bare host and the same host written with a trailing slash produced
  different dedupe keys — `https://example.com` versus `https://example.com/` —
  which is precisely the duplicate the key exists to catch. An empty path is
  now normalised to `/`.

---

## [2.0.1] - 2026-09-08

Both fixes came from running 2.0 against live news sites.

### Fixed

- **Ambiguous timezone abbreviations are no longer resolved silently.** A
  publisher stamping `Fri, 04 Sep 2026 22:13:46 PST` may mean Pacific Standard
  Time (UTC−8) or Philippine Standard Time (UTC+8) — sixteen hours apart,
  enough to date an article to the wrong day — and `DateFormatter` under
  `en_US_POSIX` quietly picks Pacific. The caller now decides, via
  `CarterConfiguration.ambiguousTimeZone`. Dates carrying an explicit numeric
  offset or a `Z` are never reinterpreted. Handled: PST, CST, IST, BST, AMT, ECT.
- **The inline-keyword scraper no longer runs past the array.** Some CMSes emit
  `var keyword = [...] || []`, and 2.0 took the LAST `]`, which is the empty
  fallback — trailing `] || [` into the tags. It now takes the first `]` after
  the opening `[`. (1.x took the first `]` outright, which was right here and
  crashed elsewhere; this keeps both.)

---

## [2.0.0] - 2026-09-06

### Added

- **Cross-platform.** Runs on Linux as well as Apple platforms, so link
  ingestion can happen server-side — a rule enforced only on the client is not
  enforced.
- **`CanonicalURL.dedupeKey`** — the duplicate-detection key the library was
  believed to have and did not. Folds scheme, `www.`, trailing slash, fragment,
  parameter order and campaign parameters (`utm_*`, `fbclid`, …) while keeping
  parameters that select content. Store it and index it uniquely; a scraper
  cannot enforce uniqueness on its own.
- `URLInformation.canonicalURL`, `.finalURL`, `.host`, `.rejectedURLClaim`,
  `.publishedAt`, `.statusCode`.
- `CarterConfiguration` — timeout, body-size cap, `isHostAllowed`, user-agent.
- `CarterLog` — opt-in diagnostics, silent by default.

### Fixed

- **A page can no longer choose where its own link points.** `og:url` was
  written over the requested URL through a bare `URL(string:)` with no scheme
  or host check, so a page on an allow-listed domain could make a caller store
  a link to anywhere, `javascript:` and `data:` included — and every relative
  image and favicon then resolved against that claim.
- **Crash on hostile HTML.** The inline-keyword scraper sliced
  `item[start...end]` without checking `start <= end`, trapping the process on
  any page whose script text had `]` before `[`.
- Redirects: `response.url` was discarded, so an allow-list only ever saw the
  pre-redirect host.
- `twitter:card` is read from `twitter:card`, not `og:type` — `cardType` was
  `.other` for every page ever parsed.
- Combine bridge removed: it leaked every `Carter` through a strong `self`
  capture, stranded the first caller's continuation forever when a second call
  replaced the stored subscription, and delivered on a `.concurrent` queue.
- Requests have a timeout (`URLSession.shared`'s resource default is seven
  days) and a body-size cap, and honour the declared charset.
- The library no longer prints; 1.x logged fourteen times per fetch and dumped
  the whole model and raw response body into the host app's logs.

### Changed

- `url.carter.getURLInformation()` → `try await url.carterInformation()`.
- Specific `CarterError` cases replace the single
  `failedToGetURLInformation`.
- `imageSize` is `ImageSize`, not `CGSize` (`.cgSize` bridges on Apple).
- `URLInformation` is a struct; equality is by document, not raw URL.

`title`, `descriptionText`, `originalURL`, `imageURL`, `author`, `keywords`,
`publishDate` and `type` keep their 1.x shapes.

---

## [0.1.0]

Initial release. Based on [awkward/Ocarina](https://github.com/awkward/Ocarina)
by Rens Verhoeven (MIT).
