# Installing on Ubuntu

Ubuntu does not package Quickshell, so you build it once yourself. The rest is
the normal installer.

## Which Ubuntu

| Ubuntu | Qt | Hyprland in apt | Works? |
| --- | --- | --- | --- |
| 26.04 LTS | 6.10 | 0.53 | Yes, after building Quickshell. |
| 25.10 | 6.9 | 0.41 | Yes, after building Quickshell. Hyprland is old; build a newer one if you can. |
| 25.04 | 6.8 | 0.41 | Should match 25.10. Not tried. |
| 24.04 LTS | 6.4 | none | No. Quickshell needs Qt 6.6 or later, and 24.04 has 6.4 with no QtQuick.Effects. Building Hyprland does not change that. Upgrade to 26.04. |

On 26.04 and 25.10 these steps were run in a fresh container: Quickshell
0.3.2 built, the installer finished with nothing failed, and every QML file
in the shell compiled. Nobody has used it day to day on Ubuntu yet, so treat
it as new ground and report what breaks.

## 1. Build Quickshell

```sh
sudo apt install build-essential cmake ninja-build pkg-config git \
  qt6-base-dev qt6-base-private-dev qt6-declarative-dev qt6-declarative-private-dev \
  qt6-shadertools-dev qt6-wayland-dev qt6-wayland-private-dev qt6-svg-dev \
  libcli11-dev spirv-tools libdrm-dev libgbm-dev libvulkan-dev libwayland-dev \
  wayland-protocols libpipewire-0.3-dev libpam0g-dev libxcb1-dev libjemalloc-dev \
  libpolkit-agent-1-dev libglib2.0-dev libegl-dev libgl-dev libgles-dev

git clone -b v0.3.2 https://github.com/quickshell-mirror/quickshell
cd quickshell
cmake -GNinja -B build -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCRASH_HANDLER=OFF
cmake --build build
sudo cmake --install build
qs --version
```

Quickshell uses private Qt interfaces. After an Ubuntu upgrade moves Qt to a
new version, rebuild Quickshell, or it crashes on start.

## 2. Hyprland

`sudo apt install hyprland` works on 25.04 and later. That Hyprland reads the
old `hyprland.conf`, and banditshell supports it: copy the binds from
`docs/hyprland-binds.example.conf`.

The shell's newer extras, custom window layouts among them, need Hyprland
0.56 or later with a `hyprland.lua` config. For those, build Hyprland from
source by following the Hyprland wiki, then use
`docs/hyprland-binds.example.lua` instead.

## 3. banditshell

```sh
git clone https://github.com/marcusbandit/banditshell.git
cd banditshell
./install.sh
bin/banditshell start
```

The installer skips Quickshell because it is already on your PATH, and fetches
the Material Symbols font itself, since Ubuntu does not package it.
