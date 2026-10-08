# firefox-fullscreen-fix

Stops Firefox from showing its toolbar and tabs when the mouse touches the top edge in F11 fullscreen. They stay hidden until you press F11 again.

## Requirements

- Linux (Fedora, Debian, Ubuntu, or a derivative)
- Firefox 69 or newer, installed from the system package manager or Flatpak
- bash, awk and coreutils (already installed on these distros)

## Usage

```sh
git clone https://github.com/wleeaf/firefox-fullscreen-fix.git
cd firefox-fullscreen-fix
./fix-firefox-fullscreen.sh
```

Then restart Firefox, press F11, and move the cursor to the top of the screen.

The script applies the fix to every Firefox profile it finds. It:

- writes `chrome/userChrome.css` to hide the invisible mouseover trigger
- adds two preferences to `user.js` in each profile, so they apply on every start

If a `userChrome.css` already exists and is different, it is saved as `userChrome.css.bak.<timestamp>` first.

## Uninstall

```sh
./fix-firefox-fullscreen.sh --uninstall
```

This removes the stylesheet and the lines the script added to `user.js`. Backup files are left in place.

## License

[MIT](LICENSE)
