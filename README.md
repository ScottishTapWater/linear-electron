# Linear Electron (local prototype)

Unofficial Linux wrapper for https://linear.app, using a project-local Electron
and its bundled Chromium instead of the system WebKitGTK. No system library
replacement, launcher installation, or Tauri profile migration.

Created as an Electron-based alternative to the Tauri-based `linear-desktop`,
after encountering WebKitGTK freezes during sign-in on Linux.

The official Linear icon is used unchanged to identify the service. This wrapper
is not affiliated with or endorsed by Linear. The icon belongs to Linear and is
not MIT-licensed; see [brand attribution](packaging/LINEAR-BRAND-NOTICE) and
[Linear's brand guidelines](https://linear.app/brand).

## Run

```sh
pnpm install --frozen-lockfile
pnpm start
```

The initial install downloads Electron. Its version is pinned; keep it updated
for Chromium security fixes. This is not a fully static or universally portable
Linux binary: Electron still requires normal host desktop/graphics libraries.

## Test

```sh
pnpm test
pnpm test:smoke
```

The smoke test opens a real window in a separate `.smoke-profile`, clicks
Continue with email, types a reserved invalid email address, waits 20 seconds,
and checks editing still works. It does not submit an email or authenticate.
Screenshot: `.artifacts/email-smoke.png`. Run from your desktop session.

## Scope and security

- Login cookies stay in `.profile/` in this repo. Treat it as private data.
- Sandboxed renderers, context isolation, no Node integration or preload bridge.
- Only the exact HTTPS `linear.app` origin may navigate inside the app.
- Other HTTP(S) destinations require confirmation before opening in your browser.
- Other schemes and all permission requests are denied in this prototype.
- Email login is the first target. Google/SSO flows and external-browser magic-link
  handoff are not implemented or verified; browser cookies are not shared.
- Ctrl+Shift+N opens another window (while the app is focused); size is remembered.
- No global shortcuts, automatic updater, protocol registration, or notification
  permissions yet. No remote debugging port is opened by the test.

## Arch packaging (not yet published)

All packaging automation is Bash, with `jq` for JSON. `pnpm` is only needed to
fetch the pinned Electron dependency and run app tests, not to build the source
AUR packages. Prerequisites: Bash, jq, curl, git, tar, bsdtar, sha256sum, and makepkg.

```sh
pnpm install --frozen-lockfile
pnpm test
bash scripts/create-source.sh 0.1.0
bash scripts/create-tarball.sh 0.1.0 x64
bash scripts/create-tarball.sh 0.1.0 arm64
bash scripts/create-appimage.sh x64
bash scripts/create-appimage.sh arm64
bash scripts/generate-pkgbuilds.sh 0.1.0 dist
```

Four recipes are generated under `dist/aur/`: `linear-electron` (tagged source
and system Electron), `linear-electron-git` (Git main and system Electron),
`linear-electron-bin` (bundled runtime), and `linear-electron-appimage`.
System variants depend on `electron44`; ARM64 can use AUR `electron44-bin`.
All variants conflict with each other, not with the Tauri app.

For local candidate builds without publishing:

```sh
LINEAR_GIT_SOURCE="$(bash scripts/create-git-fixture.sh 0.1.0)" \
  bash scripts/generate-pkgbuilds.sh 0.1.0 dist --local-source
# In each dist/aur/<variant>: makepkg --nodeps --noconfirm
# --nodeps builds without installing missing runtime dependencies; it does NOT
# validate dependency resolution. Do not add -i/-s until installation is approved.
```

AppImages retain the Chromium sandbox and require usable user namespaces. No
automatic `--no-sandbox` fallback is provided. Packaging tools are pinned by
SHA256; if upstream replaces a mutable download, builds deliberately fail until
the new tool is reviewed and its checksum updated. AppImages still depend on
normal host graphics/desktop libraries; they are not universally static binaries.

Installed variants share `~/.config/linear-electron` (or `$XDG_CONFIG_HOME`),
independently of this checkout's `.profile`. Existing credentials are not copied.
`linear-electron --self-test` uses a fixed loopback fixture and a temporary profile;
`--smoke-test` checks the live login form without submitting an email.

CI builds and tests each package on both architectures and tests AppImages on
Ubuntu and Arch. CD follows sudo-mcp's semantic-version conventions and publishes
tested artifacts then AUR recipes on main changes. Configure `AUR_USERNAME` and
`AUR_SSH_PRIVATE_KEY` before activation; commit email is fixed to
`james@jamesmcmahon.co.uk`. Pushing the workflow to main activates releases.
No COPR or Flatpak publication is configured.
