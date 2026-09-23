# Contributing translations

EllesmereUI keeps English strings as the stable source keys and translates only
when text is rendered. Missing entries intentionally fall back to English.

## Updating an existing language

1. Find or add the English key in `Locales/<locale>.lua`:

   ```lua
   L["Quick Keybind Mode"] = "Translated text"
   ```

2. Keep runtime code language-neutral. Direct rendering calls must use the
   localization API:

   ```lua
   title:SetText(EllesmereUI.L("Quick Keybind Mode"))
   message:SetText(EllesmereUI.Lf("Keyring (%d)", count))
   ```

   Shared option widgets translate their `text`, `label`, `title`, `message`,
   and `tooltip` fields at the render boundary, so their source values should
   remain English and normally do not need an explicit `L()` call.

3. Preserve format placeholders exactly. Positional placeholders such as
   `%1$s` and `%2$d` may be reordered in the translated value. Use `true` as
   the value when a key should intentionally remain English.

4. Save locale files as UTF-8 without a byte-order mark.

## Finding keys

Run the static extractor after adding or changing literal `L()`/`Lf()` calls:

```sh
bash .tools/extract-locale-keys.sh
```

Dynamic keys cannot be found statically. In game, use the runtime harvester:

```text
/euiloc on
...open the relevant pages, popups, and tooltips...
/euiloc dump zhCN
/euiloc off
```

The dump is written to `EllesmereUIDB._localeDump` in the addon's saved
variables after logout or `/reload`.

## Adding a locale

WoW's standard locales are already registered. For a new supported client
locale, add it to `SUPPORTED` in `EllesmereUI_Locale.lua`, create
`Locales/<code>.lua` using `EllesmereUI.RegisterLocale("<code>")`, add the file
to `EllesmereUI.toc`, and expose it in the language selector.

Before submitting, run both checks:

```sh
bash .tools/extract-locale-keys.sh
bash .tools/check-hardcoded-translations.sh
```
