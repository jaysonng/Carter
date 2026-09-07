# Changelog

All notable changes to Carter are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [2.0.1] - 2026-09-08

Both fixes came from running 2.0 against real Philippine publishers, and both
were introduced by the 2.0 rewrite.

### Fixed

- **`PST` is read as Philippine Standard Time, not Pacific.** inquirer.net
  stamps articles `Fri, 04 Sep 2026 22:13:46 PST` meaning UTC+8;
  `DateFormatter` under `en_US_POSIX` reads PST as Pacific, UTC−8. That is a
  16-hour error, and it moves an article onto the wrong DAY — the article above
  was dated 5 Sep when its own byline reads "September 04, 2026" and its
  `dateModified` is the following morning.
  Carter cannot infer which is meant, so it no longer guesses silently:
  `CarterConfiguration.ambiguousTimeZone` decides, defaulting to `Asia/Manila`
  because this library's consumers are Philippine publishers. Dates carrying an
  explicit numeric offset (`+08:00`) or a `Z` are never reinterpreted —
  manilatimes.net and tribune.net.ph were unaffected either way.
  Ambiguous abbreviations handled: PST, CST, IST, BST, AMT, ECT.
- **The inline-keyword scraper no longer runs past the array.** WordPress emits
  `var keyword = [...] || []`, and 2.0 took the LAST `]`, which is the empty
  fallback — so tags arrived as `…"sustainability"] || [`. It now takes the
  first `]` after the opening `[`. (1.x took the first `]` outright, which was
  right here and crashed elsewhere; this keeps both correct.)

### Notes

- Publishers behind a Cloudflare challenge (mb.com.ph) return **403** to any
  user-agent that is not an allowlisted social crawler — a real Chrome string is
  refused too, so this is not something a UA tweak fixes honestly. Carter
  reports it as `CarterError.httpError(statusCode: 403, url:)` so a caller can
  tell "blocked" from "broken" and degrade rather than fail. Ask the publisher
  to allowlist your crawler; do not impersonate `facebookexternalhit`.

---

## [2.0.0] - 2026-09-06

### Added

- **Cross-platform.** Runs on Linux as well as Apple platforms, so link
  ingestion can happen on the server — a publisher allow-list enforced only in
  the client is not enforcement.
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
  or host check, so a page on an allowed domain could make a caller store a
  link to anywhere, `javascript:` and `data:` included — and every relative
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
