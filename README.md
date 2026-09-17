# Linear Electron (local prototype)

Unofficial Linux wrapper for https://linear.app, using a project-local Electron
and its bundled Chromium instead of the system WebKitGTK. No system library
replacement, launcher installation, or Tauri profile migration.

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

The next milestone is a real successful login, before choosing AppImage/Flatpak
packaging. Packaging will not by itself solve authentication issues.
