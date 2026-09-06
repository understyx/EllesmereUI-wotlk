# EllesmereUI for Wrath of the Lich King

An in-progress port of EllesmereUI for World of Warcraft: Wrath of the Lich King
3.3.5a. It is experimental and not yet ready for general use.

NB! This isn't trying to be 1 to 1 backport of EllesmereUI. Sorry if somethings don't work. Somethings simply aren't possible on default WoTLK client..

## Installation

1. Clone or copy this repository into your WoW `Interface/AddOns` directory as
   `EllesmereUI`.
2. From the `EllesmereUI` directory, run the platform-appropriate installer:
   - Windows: `install.bat`
   - macOS/Linux: `./install.sh`
3. Start the game and enable EllesmereUI and its linked modules in the AddOns
   menu.

The installers create links in the parent `AddOns` directory for each module.
This is required because the WotLK client does not load add-ons from nested
directories.

## Project layout

- `EllesmereUI.toc` and the root Lua files provide the shared framework.
- `EllesmereUI*/` directories contain feature modules such as action bars,
  bags, chat, nameplates, raid frames, and unit frames.
- `EllesmereUIPallyPower/` contains the PallyPower module, exposed through
  `EllesmereUI.PallyPower` for use by sibling modules and listed under QoL
  Addons in the EllesmereUI settings.
- `Compatibility/` contains WotLK 3.3.5a compatibility shims.
- `Locales/` contains translations.
- `Libs/` contains bundled libraries.

## Development

Contributions are welcome. Please read the
[contribution guide](.github/CONTRIBUTING.md) before opening a pull request.

Addon versions use the format `8.6.4-wotlk.YYYYMMDD`, where the suffix is the
UTC date of the latest commit. Run `.tools/update-version.sh` to synchronize all
addon TOCs, or `.tools/update-version.sh --check` to verify them without making
changes. Pushes to `main` synchronize the version automatically, and release
packaging runs the updater again before building artifacts.

## License

This project uses a custom license. See [license.txt](license.txt).

The bundled PallyPower module is derived from PallyPower Improved for 3.3.5.
Its source revision and attribution are recorded in
`EllesmereUIPallyPower/UPSTREAM.md`.
