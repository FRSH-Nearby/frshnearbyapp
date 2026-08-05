# FRSH nearby — Project Guidelines

Companion to [DESIGN_GUIDELINES.md](DESIGN_GUIDELINES.md) (visual design system —
**always follow it** for colors, typography, spacing, and components). This file
covers localization, brand assets, and the approved library set. All future work
must follow both documents.

---

## 1. Localization (i18n)

The app supports **three languages**:

| Language | Locale code | ARB file |
|---|---|---|
| English (default) | `en` | `lib/l10n/app_en.arb` |
| Finnish | `fi` | `lib/l10n/app_fi.arb` |
| Swedish | `sv` | `lib/l10n/app_sv.arb` |

### Locale resolution

The app language follows the **device / browser language setting**:

- Phone or browser set to Finnish (`fi`) → Finnish UI
- Phone or browser set to Swedish (`sv`) → Swedish UI
- Set to English (`en`) → English UI
- **Any other language → English** (English is the fallback/default)

This is implemented in `lib/main.dart` via `localeResolutionCallback` on
`MaterialApp`. Do not change the fallback away from English.

### How it works

- Localization uses Flutter's official **gen-l10n** workflow
  (`flutter_localizations` + `intl`), configured in [`l10n.yaml`](../l10n.yaml)
  and enabled with `generate: true` in `pubspec.yaml`.
- `app_en.arb` is the **template** file. Every key must exist there first, with
  an `@key` description so translators have context.
- Generated classes live in `lib/l10n/app_localizations*.dart` — never edit
  those by hand; run `flutter gen-l10n` (also runs automatically on build).
- Missing translations are listed in `l10n_untranslated.txt` after generation —
  keep it empty before release.

### Rules for adding strings

1. **Never hardcode user-visible text** in widgets. Add the key to all three ARB
   files and use `AppLocalizations.of(context)!.yourKey`.
2. Key naming: camelCase, prefixed by area — `actionContinue`, `errorGeneric`,
   `homeWelcomeTitle`.
3. Finnish and Swedish strings run **~30% longer** than English — buttons,
   chips, and labels must tolerate this (see DESIGN_GUIDELINES.md §8).
4. Dates, numbers, currency: format with `intl` (`DateFormat`, `NumberFormat`)
   using the active locale — never string-concatenate them.
5. Fonts must support å ä ö (Nunito Sans, the brand font, does).

---

## 2. Brand assets / logo

Logos live in `assets/images/` (registered in `pubspec.yaml`):

| File | Use |
|---|---|
| `assets/images/logo.png` | Logo on its own background — splash, app icon source, places where a solid backdrop is fine |
| `assets/images/logo_transparent.png` | **Preferred in-app** — transparent background, use on any app surface (headers, empty states, about screen) |

Rules:

- Use `logo_transparent.png` inside the UI; `logo.png` only where a boxed logo
  is intended.
- Never stretch, recolor, or add effects to the logo. Scale with `width` only,
  keep aspect ratio.
- New image assets go under `assets/images/` — the whole folder is bundled.

---

## 3. Libraries

Installed and approved (see `pubspec.yaml`):

| Package | Purpose |
|---|---|
| `flutter_localizations` (SDK) | Framework-level localization delegates for en/fi/sv |
| `intl` | Message formatting, dates, numbers, currency per locale |
| `dio` | **HTTP/API client** — all backend calls go through Dio (interceptors, timeouts, error mapping). Create one shared client, don't instantiate per call |
| `shared_preferences` | Small local key-value storage (e.g. a manual language override, onboarding flags) |
| `google_fonts` | Nunito Sans — the brand font per DESIGN_GUIDELINES.md §2 |
| `flutter_svg` | Render lightweight brand illustrations and vector assets |
| `cached_network_image` | Produce/farm photos with caching + `mist`-colored placeholders (DESIGN_GUIDELINES.md §7) |
| `flutter_map` + `latlong2` | OpenStreetMap-based farm location selection and latitude/longitude coordinates |
| `cupertino_icons` | iOS-style icons |
| `flutter_lints` (dev) | Lint rules — keep `dart analyze` at zero issues |

Rules:

- **Adding a library**: prefer the packages above; if a new one is truly needed,
  it must be actively maintained, null-safe, and added to this table.
- All API/network code uses **Dio** — do not mix in `http` or raw
  `HttpClient`.
- Do not add a second state-management or storage package without updating this
  document first.

---

## 4. Working agreements

- `dart analyze` must report **No issues found** before committing.
- Run `flutter test` before committing; keep the widget smoke test green.
- UI work: tokens, radii, spacing, and type come from DESIGN_GUIDELINES.md —
  never introduce new hex values or radii inline.
