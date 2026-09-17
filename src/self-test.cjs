const { app, BrowserWindow, ipcMain, session, nativeImage } = require('electron');
const http = require('node:http');
const path = require('node:path');
const assert = require('node:assert/strict');
const { WEB_PREFERENCES } = require('./policy.cjs');
module.exports = async () => {
  const icon = nativeImage.createFromPath(path.join(__dirname, '..', 'packaging', 'linear-electron.png'));
  assert.equal(icon.isEmpty(), false, 'Official app icon must be included and readable');
  assert.deepEqual(icon.getSize(), { width: 1024, height: 1024 });
  const timeout = setTimeout(() => { console.error('Self-test timed out'); app.exit(1); }, 30000);
  const server = http.createServer((_req, res) => {
    res.setHeader('Content-Type', 'text/html');
    res.end('<!doctype html><button onclick="document.querySelector(\'input\').hidden=false">Continue with email</button><input type="email" hidden>');
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  session.defaultSession.setPermissionRequestHandler((_wc, _p, cb) => cb(false));
  session.defaultSession.setPermissionCheckHandler(() => false);
  const win = new BrowserWindow({ show: false, webPreferences: {
    ...WEB_PREFERENCES, preload: path.join(__dirname, 'test-preload.cjs'),
  } });
  win.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
  const sandbox = new Promise(resolve => {
    ipcMain.on('self-test-sandbox', (event, value) => {
      if (event.sender === win.webContents) resolve(value);
    });
  });
  try {
    await win.loadURL(`http://127.0.0.1:${server.address().port}/`);
    assert.deepEqual(await sandbox, { sandboxed: true, isolated: true });
    const run = code => win.webContents.executeJavaScript(code, true);
    assert.equal(await run('typeof require'), 'undefined');
    assert.equal(await run('!!globalThis.process?.versions?.node'), false);
    assert.equal(await run('navigator.locks.request("test", () => true)'), true);
    await run('document.querySelector("button").click(); document.querySelector("input").focus()');
    await win.webContents.insertText('test@example.invalid');
    assert.equal(await run('document.querySelector("input").value'), 'test@example.invalid');
    await run('localStorage.setItem("self-test", "persisted")');
    await win.loadURL(`http://127.0.0.1:${server.address().port}/`);
    assert.equal(await run('localStorage.getItem("self-test")'), 'persisted');
    const second = new BrowserWindow({ show: false, webPreferences: { ...WEB_PREFERENCES } });
    await second.loadURL('about:blank');
    second.destroy();
    console.log(JSON.stringify({ result: 'PASS', version: app.getVersion(), electron: process.versions.electron,
      executable: process.execPath, profile: app.getPath('userData'), sandbox: true, contextIsolation: true }));
  } finally { win.destroy(); server.close(); clearTimeout(timeout); }
};
