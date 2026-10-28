<div align="center">

<img src="docs/readme/wordmark.svg" alt="banditshell" width="820">

<br>
<br>

[![for hyprland](https://img.shields.io/badge/for-hyprland-7FB3D4?style=for-the-badge&logo=hyprland&logoColor=B8DCF0&labelColor=0F1114)](https://hypr.land)
[![built with quickshell](https://img.shields.io/badge/built_with-quickshell-7FB3D4?style=for-the-badge&logo=qt&logoColor=B8DCF0&labelColor=0F1114)](https://quickshell.org)
[![last commit](https://img.shields.io/github/last-commit/marcusbandit/banditshell?style=for-the-badge&logo=git&logoColor=B8DCF0&labelColor=0F1114&color=5B8FB0)](https://github.com/marcusbandit/banditshell/commits/main)
[![stars](https://img.shields.io/github/stars/marcusbandit/banditshell?style=for-the-badge&logo=github&logoColor=EEF2F5&labelColor=0F1114&color=D8C48C)](https://github.com/marcusbandit/banditshell/stargazers)
[![license](https://img.shields.io/github/license/marcusbandit/banditshell?style=for-the-badge&labelColor=0F1114&color=A5AEB8)](LICENSE)
[![ko-fi](https://img.shields.io/badge/ko--fi-buy_me_a_coffee-FF7A4D?style=for-the-badge&logo=kofi&logoColor=FF7A4D&labelColor=0F1114)](https://ko-fi.com/marcusbandit)

</div>

<br>

<div align="center">
<img src="docs/readme/hero.webp" alt="banditshell at rest, then the island, the launcher and a panel melting out of the frame and back" width="100%">
<br>
<sub><a href="docs/readme/hero.mp4">the same clip at 1080p</a></sub>
</div>

<br>

banditshell is a desktop shell for Hyprland, written from scratch in
[Quickshell](https://quickshell.org) and QML. While you work, nothing sits on
screen. A thin slate frame holds the wallpaper, and the rest comes out of that
frame when you reach for it, then goes back where it came from.

Everything is alive. Panels melt out of the frame as metaballs drawn in a
fragment shader, numbers glide to their new value instead of jumping, and the
text is set in Monocraft, a pixel font. I use it every day, so it changes
almost every day.

> [!NOTE]
> Made on Arch with Hyprland, and used there every day. Other distros get the
> same installer, which knows six package managers, but so far the shell has
> only been seen running on Arch. This is a personal shell that a few
> other people run too. Things move around, and the What's new card tells you
> when they do.

> [!TIP]
> On Omarchy, keep Omarchy's own shell and add
> [banditshell island](https://github.com/marcusbandit/banditshell-island)
> instead: the notification, music and lyrics pill from banditshell, as a
> plugin from the
> [Omarchy plugin marketplace](https://plugins.omarchy.org/plugin.html?id=banditshell.island).

## What's in it

- A launcher that answers as you type. Sums, units, dates and colours go
  through qalc. It finds open windows, emoji, your scripts, Wi-Fi networks and
  SSH hosts, translates and defines words, starts a pomodoro, and asks a local
  AI model through Ollama when you want one.
- The island at the top of the screen. A notification, a song change, a
  finished download, a kernel update waiting for a reboot: the newest takes
  the big spot and the rest wait as bubbles beside it.
- Settings that grow out of the sidebar, sorted into ten categories. Every
  page drives the real thing, from Wi-Fi and Bluetooth to monitors, sound,
  power and the night light schedule.
- A lock screen with your wallpaper blurred behind a large clock, media
  controls and power buttons you hold to confirm.
- Quick controls, a calendar, notifications with do not disturb, a clipboard
  history, a calculator and a media card. With Spotify, the media card shows
  word-timed lyrics.
- A wallpaper picker, bare mode that turns all of the chrome off at once, and
  a streamer mode with an OBS deck.
- A memory. Restart the shell and the panels you had open come back, Settings
  on the page you left it.
- Updates from the inside. The update menu fetches the new version, and the
  What's new card says what changed in plain words.

## Install

You need Hyprland and Quickshell. The installer brings them where your distro
packages them, along with the Monocraft font, the icon fonts, every tool the
shell calls, its small C helpers and tab completion for zsh and bash. It uses
whichever of pacman, apt, dnf, zypper, xbps or apk the machine has, asks for
sudo only when a package needs installing, and a second run retries only the
steps that failed.

banditshell is written and used every day on Arch. Everywhere else it has
only been tried in fresh containers: the installer ran, and on Ubuntu the
whole shell compiled. Nobody uses it daily there yet, so expect rough edges
and please open an issue when you hit one.

| Distro | Support | Quickshell | Hyprland | What to know |
| --- | --- | --- | --- | --- |
| Arch | daily use | yes | yes | Everything installs. |
| Debian 13 | tried | backports | backports | Add `trixie-backports` to your apt sources first. |
| openSUSE Tumbleweed | tried | yes | yes | |
| Ubuntu 26.04, 25.10 | tried | build it | yes, older | Build Quickshell once; see [docs/install-ubuntu.md](docs/install-ubuntu.md). |
| Fedora 44 | tried | yes, 0.2 | COPR | Hyprland comes from a COPR. Quickshell 0.2 is older than the 0.3 this is built on. |
| Void | tried | yes | build it | Build Hyprland yourself. |
| Alpine | tried | build it | yes | Build Quickshell yourself, and `apk add bash` before the installer. |
| Ubuntu 24.04 | no | | | Its Qt 6.4 is older than the 6.6 Quickshell needs. Upgrade to 26.04. |

What people on other distros run into:

- Quickshell is new, so many distros do not package it yet. Building it takes
  a few minutes, and it has to be rebuilt whenever the distro moves Qt to a
  new version.
- The packaged Hyprland is often older and reads `hyprland.conf`. That works:
  copy the binds from `docs/hyprland-binds.example.conf`. Custom window
  layouts and the Lua binds need Hyprland 0.56 or later with `hyprland.lua`.
- Qt 6.6 is the floor. Anything older cannot run Quickshell at all.

On NixOS, Gentoo or anything else, `./install.sh --list` names every package
the shell needs, by its Arch name, for you to install your own way. The
installer then still sets up the fonts, the helpers and the rest.

```sh
git clone https://github.com/marcusbandit/banditshell.git
cd banditshell
./install.sh
bin/banditshell start
```

`./install.sh --dry-run` walks every step without installing anything, and
`--list` prints the steps. A fresh clone is moved to the newest release first,
and `banditshell update` takes it to each new one. To follow every merge to
`main` instead, on any version, run:

```sh
mkdir -p ~/.local/state/banditshell && echo main > ~/.local/state/banditshell/keep-channel && banditshell config set updates.channel main
```

`install.sh` links the command into `~/bin/banditshell`. To bring the shell
up with Hyprland, add it to your config:

```ini
exec-once = ~/bin/banditshell start
```

For keybinds, open Settings, go to About and let banditshell manage the binds.
It writes its own file and adds one line to `hyprland.lua`. If you would
rather wire them by hand, start from
[`docs/hyprland-binds.example.conf`](docs/hyprland-binds.example.conf).

## Driving it

Everything the shell does is a command. A keybind, a script and a terminal
all drive it the same way, and Tab completes every word.

```sh
banditshell panel launcher toggle
banditshell wallpaper next
banditshell clock timer start 10m
banditshell screen border off
banditshell help
```

`banditshell doctor` checks the setup, and `banditshell log` shows what the
shell has been saying.

## Updating

The update menu handles it. If an update touches a file you edited yourself,
your edit is set aside in `git stash` first and the menu names the file. From
a terminal, `git pull` and `banditshell restart` do the same.

## Credits

- [Quickshell](https://quickshell.org), the toolkit everything here is built on.
- [Hyprland](https://hypr.land), the compositor it lives in.
- [Monocraft](https://github.com/IdreesInc/Monocraft) by Idrees Hassan, the
  pixel font, and Google's
  [Material Symbols](https://fonts.google.com/icons) for the icons.
- [Spicy Lyrics](https://github.com/Spikerko/spicy-lyrics) and
  [Spicetify](https://spicetify.app), for the word-timed lyrics.
- [caelestia](https://github.com/caelestia-dots/shell), where this started.
  It is finished and excellent, and banditshell exists because I wanted to
  know how every part of a shell works. A few ideas came from it, the metaball
  frame first of all. The code is written here.

## Support

banditshell is free and stays free. If it made your desktop a little nicer
and you feel like buying me a coffee, there is a
[Ko-fi](https://ko-fi.com/marcusbandit). It is entirely optional, and a star
or a good bug report helps just as much.

<div align="center">

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/marcusbandit)

</div>

## Star history

<a href="https://star-history.com/#marcusbandit/banditshell&Date">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=marcusbandit/banditshell&type=Date&theme=dark">
    <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=marcusbandit/banditshell&type=Date">
    <img alt="Star history of banditshell" src="https://api.star-history.com/svg?repos=marcusbandit/banditshell&type=Date">
  </picture>
</a>

## License

[GPL-3.0](LICENSE).
