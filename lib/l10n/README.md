# Localization

The app ships **French only** (`fr_BE`) in Phase 1, but is wired for more from the start.

## Rules

- **Every user-facing string lives in an `.arb` file.** Never hardcode display text in a widget.
  `core/constants/app_strings.dart` is for non-translatable constants only (route names,
  asset paths, debug labels).
- **Keys are English, values are French.** `"addItem": "Ajouter un article"`. Keys are code;
  values are content. French keys become confusing the moment a Dutch file exists.
- **Every key gets an `@key` entry with a `description`.** It is the only context a future
  translator will have.

## Adding a language

Drop a sibling file — `app_nl.arb` for Dutch — with the same keys, then add the locale to
`supportedLocales` in `app/app.dart`. No screen code changes.

## Regenerating

`AppLocalizations` is generated on `flutter run` / `flutter build`, driven by `l10n.yaml` at
the project root. To regenerate by hand:

```
flutter gen-l10n
```

Output lands **in this folder** as `app_localizations.dart` + `app_localizations_<locale>.dart`.
As of Flutter 3.32 the old synthetic `package:flutter_gen/...` import no longer exists — import
`package:stock_inventory/l10n/app_localizations.dart` instead. The generated files are checked
in; regenerate and commit them whenever an `.arb` changes.

## fr_BE conventions

Formatting (currency `12,50 €`, dates `22/08/2026`) is **not** handled here — it lives in
`core/utils/formatters.dart` and comes from `intl` with the `fr_BE` locale. Don't hand-roll it.

Copy style: vouvoiement throughout, and French typographic spacing — a narrow no-break space
(U+202F) before `?`, `!`, `:` and inside `« »`.
