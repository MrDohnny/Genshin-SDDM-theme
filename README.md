# Genshin Login WebGL — SDDM Theme

A Genshin Impact–inspired 3D login screen for [SDDM](https://github.com/sddm/sddm). Instead of a static login form, you land on a fully 3D scene rendered live in WebGL: click anywhere and the camera walks toward an ornate floating door, which swings open with its own sound effect before the login card fades in over the scene — the same "click to begin" rhythm as the game's own title screen, not a video loop or a static background image.

Built with [SDDM 3D Platform](https://github.com/MrDohnny/3d-sddm-theme-maker), a modular editor and runtime for building animated 3D/WebGL SDDM login screens — it's the tool this theme was authored and packaged with, and it's what lets a theme like this run its own live WebGL scene, real system session/user/power integration, and animation timeline underneath a normal SDDM greeter.

<!--
  Add real screenshots here before publishing — none are included yet.
  Suggested shots (see the "What each screenshot should show" section below
  for exactly what to capture):
    screenshots/01-click-to-begin.png
    screenshots/02-door-opening.png
    screenshots/03-login-panel-users.png
    screenshots/04-power-menu.png
    screenshots/05-session-picker.png
    screenshots/06-notices-journal.png
    screenshots/07-caps-lock-warning.png
-->
![Click to begin](screenshots/01-click-to-begin.png)
![Door opening](screenshots/02-door-opening.png)
![Login panel with real users](screenshots/03-login-panel-users.png)
![Power menu](screenshots/04-power-menu.png)
![Session picker](screenshots/05-session-picker.png)
![Notices / journal panel](screenshots/06-notices-journal.png)

## How it works

Nothing on screen reacts until you click. This is by design — it mirrors the game's own title screen instead of dumping a login form on you immediately.

1. **Click anywhere** (or the "Conta" button in the corner) — the camera walks toward an ornate door. The first click always plays this entrance sequence; every following click on the corner button just shows or hides the panel instead of replaying it.
2. **The door opens**, with its own sound effect, and the login panel fades in.
3. **The login panel lists your machine's real user accounts** (from SDDM's own user list), each with their real avatar picture when the system has one on file. Clicking an account that has no password configured logs straight in — no password field ever shown for it. Any other account expands into a password field, with a Caps Lock warning that appears automatically while typing.
4. **Corner buttons open the rest of the interface**, each as its own animated panel:
   - **Conta** — the account/login panel described above.
   - **Avisos** (Notices) — a tabbed announcements/journal board, styled after the game's own in-game news feed, with a list on the left and the selected entry's full text on the right.
   - **Selecionar ambiente** (bottom bar) — a real session picker listing every desktop session actually installed on the machine (Plasma, GNOME, etc. — whatever SDDM itself detects), not a hardcoded list.
   - **Power menu** (shutdown / restart / suspend / hibernate) — each action only appears if the system actually supports it, using SDDM's own capability checks (e.g. hibernate is hidden on a machine with no resume-configured swap instead of showing a button that would just fail).
   - **Volume** — mutes/unmutes the background music independently of the ambient scene sound.
5. Background music, UI click sounds, and the door's own opening sound effect play throughout — all toggleable, all routed through Qt Multimedia, not just embedded in the WebGL page.

## Requirements

- SDDM >= 0.21 (Theme-API 2.0 — declared in `metadata.desktop`; tested against 0.21.0)
- Qt >= 6.5, with these QML modules installed — none of them are pulled in by a typical SDDM/Plasma install by default, since most themes don't need any of them:
  - **Qt Quick 3D** (with its AssetUtils and Helpers submodules) — on Debian/Ubuntu: `qml6-module-qtquick3d qml6-module-qtquick3d-assetutils qml6-module-qtquick3d-helpers`
  - **Qt WebEngine** — on Debian/Ubuntu: `qml6-module-qtwebengine libqt6webenginequick6`
  - **Qt Multimedia** (with a working backend — FFmpeg or GStreamer) — on Debian/Ubuntu: `qml6-module-qtmultimedia`
  - On Arch, Fedora, openSUSE etc. the equivalent packages are usually named `qt6-quick3d`, `qt6-webengine`, `qt6-multimedia` (or similar) — check your distro's package search if the theme fails to load at all (a QML import error, not a blank/broken scene) rather than a rendering problem.
- A working audio session for the `sddm` system user specifically (not just your own login) — this needs `pam_systemd` wired into whichever PAM service SDDM's greeter uses (this is the default on any systemd-based distro, but worth knowing if you're troubleshooting silence — see "Known limitations" below).
- No particular display server requirement — nothing in this theme's own code depends on Wayland specifically, X11-based SDDM setups should work the same way, though this has mainly been tested under a Wayland (KWin) greeter session.

## Installation

1. Copy this repository's contents into a theme directory, e.g.:
   ```sh
   sudo cp -r . /usr/share/sddm/themes/genshin-login-webgl
   ```
2. Point SDDM at it, e.g. in `/etc/sddm.conf.d/theme.conf`:
   ```ini
   [Theme]
   Current=genshin-login-webgl
   ```
3. **Required, manual step — this can't be automated by any installer, including the KDE Store's own:** this theme's WebGL scene needs a couple of environment variables set for the greeter process specifically. These have to exist *before* the greeter process starts, which is controlled entirely by SDDM itself — no theme package, GHNS installer, or `metadata.desktop` setting can set them from the inside. Add this to `/etc/sddm.conf.d/` (a new file, or your existing `[General]` section):
   ```ini
   [General]
   GreeterEnvironment=QML_XHR_ALLOW_FILE_READ=1,QTWEBENGINE_CHROMIUM_FLAGS=--allow-file-access-from-files --disable-web-security --autoplay-policy=no-user-gesture-required --force-color-profile=srgb
   ```
   - `QML_XHR_ALLOW_FILE_READ=1` lets the theme's QML read its own local `theme.json`/assets.
   - `--allow-file-access-from-files` / `--disable-web-security` let the WebGL page load its own local images/audio (it's served from a `file://` URL, which Chromium otherwise sandboxes from itself).
   - `--autoplay-policy=no-user-gesture-required` lets the door sound / background music autoplay without a prior click *inside the WebEngine page itself* (our own click on the SDDM side doesn't count as one from Chromium's perspective).
   - `--force-color-profile=srgb` is just for consistent colors.

   You may also see `--no-sandbox --disable-gpu-sandbox` recommended elsewhere for this exact scenario (SDDM's `sddm` user is normally too restricted for Chromium's own sandbox). On Ubuntu/Debian-based systems specifically, this is very likely unnecessary — they ship `/etc/apparmor.d/QtWebEngineProcess`, an AppArmor profile that already grants the WebEngine process the `userns` permission it needs regardless of which user runs it (verified on a real SDDM greeter, both with and without these two flags). If you're on a distro without an equivalent AppArmor allowance, add them back to the line above.
4. Restart SDDM (or reboot) to see it.

## Known limitations

- **Audio can go silent on some machines.** If you see "No audio device detected" in `journalctl` right after the greeter starts, this is a Qt Multimedia / PipeWire device-enumeration bug triggered by specific audio hardware (confirmed, in one case, with a USB microphone whose format description Qt's PipeWire backend couldn't parse — which took down detection for every audio device on the system, speakers included). It isn't something this theme's QML code can detect or route around; if you hit it, check `journalctl` for "No audio device detected" / "spaVisitChoice: parse error" near "Using Qt multimedia" at greeter startup, identify whichever audio device is involved, and try removing/disabling it followed by a full reboot (not just a logout — the greeter's own PipeWire session only fully reinitializes on a fresh boot).
- Multi-monitor setups are not specifically handled.

## Credits

The 3D door-opening scene is adapted from [gamemcu/www-genshin](https://github.com/gamemcu/www-genshin), a Three.js recreation of Genshin Impact's title screen, MIT licensed (Copyright (c) 2023 gamemcu). That project's own README states it as a non-commercial technical demonstration, not affiliated with or endorsed by miHoYo/HoYoverse, made for learning/research purposes.

The SDDM integration layer — the login panel, real system user/session/power support, the notices board, sound bridging, and every interaction described above — was built specifically for this theme.

Some UI textures and icons are sourced from Genshin Impact's own game files. This project is a fan-made, non-commercial derivative work; it is not affiliated with, endorsed by, or sponsored by miHoYo/HoYoverse, and all Genshin Impact assets, characters, and trademarks remain the property of their respective owners.
