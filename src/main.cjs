const { app, BrowserWindow, Menu, session, dialog, shell } = require('electron');
const fs = require('node:fs');
const path = require('node:path');
const { WEB_PREFERENCES, isLinearURL, isExternalURL, windowSize } = require('./policy.cjs');

const smoke = process.argv.includes('--smoke-test');
const root = path.resolve(__dirname, '..');
// No reuse of the Tauri app's cookies, credentials, or settings.
app.setPath('userData', path.join(root, smoke ? '.smoke-profile' : '.profile'));
app.setName('Linear Electron (local)');
app.enableSandbox();
const statePath = path.join(app.getPath('userData'), 'window-state.json');

function readState() {
  try { return JSON.parse(fs.readFileSync(statePath, 'utf8')); } catch { return {}; }
}

function createWindow(url = 'https://linear.app/login') {
  const win = new BrowserWindow({
    ...windowSize(readState()),
    title: 'Linear Electron (local)',
    autoHideMenuBar: true,
    webPreferences: { ...WEB_PREFERENCES },
  });
  let externalPrompt = false;
  async function offerExternal(url) {
    if (smoke || externalPrompt || !isExternalURL(url)) return;
    externalPrompt = true;
    try {
      const { response } = await dialog.showMessageBox(win, {
        type: 'question', title: 'Open in your browser?',
        message: `Leave Linear for ${new URL(url).origin}?`,
        detail: 'This prototype keeps non-Linear pages in your default browser. Browser login sessions are not shared with this app.',
        buttons: ['Cancel', 'Open browser'], defaultId: 0, cancelId: 0,
      });
      if (response === 1) await shell.openExternal(url);
    } catch (error) { console.error('Could not open browser:', error.message); }
    finally { externalPrompt = false; }
  }
  for (const event of ['will-navigate', 'will-redirect']) {
    win.webContents.on(event, (e, target) => {
      if (!isLinearURL(target)) { e.preventDefault(); void offerExternal(target); }
    });
  }
  win.webContents.setWindowOpenHandler(({ url: target }) => {
    if (isLinearURL(target)) createWindow(target);
    else void offerExternal(target);
    return { action: 'deny' };
  });
  win.webContents.on('will-attach-webview', e => e.preventDefault());
  win.webContents.on('render-process-gone', (_event, details) => {
    console.error('Renderer exited:', details.reason);
  });
  win.on('close', () => {
    try {
      fs.mkdirSync(path.dirname(statePath), { recursive: true, mode: 0o700 });
      fs.writeFileSync(statePath, JSON.stringify(win.getNormalBounds()), { mode: 0o600 });
    } catch (error) { console.error('Could not save window size:', error.message); }
  });
  win.loadURL(url).catch(error => console.error('Page load failed:', error.message));
  return win;
}

if (!app.requestSingleInstanceLock()) app.quit();
else {
  app.on('second-instance', () => {
    const win = BrowserWindow.getAllWindows()[0];
    if (win) { if (win.isMinimized()) win.restore(); win.show(); win.focus(); }
  });
  app.whenReady().then(async () => {
    // No implicit grants to remote content; optional desktop features can be
    // added with explicit permission prompts after the login prototype works.
    session.defaultSession.setPermissionRequestHandler((_wc, _permission, callback) => callback(false));
    session.defaultSession.setPermissionCheckHandler(() => false);
    Menu.setApplicationMenu(Menu.buildFromTemplate([
      { label: 'File', submenu: [
        { label: 'New Window', accelerator: 'CommandOrControl+Shift+N', click: () => createWindow() },
        { role: 'close' }, { role: 'quit' },
      ] },
      { role: 'editMenu' },
      { label: 'View', submenu: [{ role: 'reload' }, { role: 'resetZoom' }, { role: 'zoomIn' }, { role: 'zoomOut' }, { role: 'togglefullscreen' }] },
    ]));
    const win = createWindow();
    if (smoke) {
      try { await require('./smoke.cjs')(win, root); app.exit(0); }
      catch (error) { console.error('SMOKE FAIL:', error.message); app.exit(1); }
    }
  }).catch(error => { console.error(error); app.exit(1); });
  app.on('window-all-closed', () => app.quit());
}
