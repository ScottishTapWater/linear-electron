const fs = require('node:fs/promises');
const path = require('node:path');
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

module.exports = async (win, root) => {
  const wc = win.webContents;
  let crashed = false;
  wc.on('render-process-gone', () => { crashed = true; });
  async function evaluate(code) {
    if (crashed) throw new Error('Renderer exited');
    return Promise.race([
      wc.executeJavaScript(code, true),
      delay(10000).then(() => { throw new Error('Renderer response timed out'); }),
    ]);
  }
  async function until(code) {
    for (let i = 0; i < 45; i++) {
      if (await evaluate(code)) return;
      await delay(1000);
    }
    throw new Error('Expected login element was not found');
  }
  await until(`document.readyState === 'complete' && location.origin === 'https://linear.app'`);
  const isolation = await evaluate(`({ node: !!globalThis.process?.versions?.node, require: typeof globalThis.require, locks: !!navigator.locks })`);
  if (isolation.node || isolation.require !== 'undefined' || !isolation.locks)
    throw new Error('Unexpected renderer isolation or Web Locks state: ' + JSON.stringify(isolation));
  console.log('PASS: Node APIs absent; Web Locks available');
  await until(`(() => {
    const button = [...document.querySelectorAll('button')].find(b => /continue with email/i.test(b.textContent));
    if (!button) return false;
    button.click(); return true;
  })()`);
  await until(`(() => {
    const input = document.querySelector('input[type="email"]');
    if (!input) return false;
    input.focus(); return true;
  })()`);
  await delay(1000);
  await evaluate(`document.querySelector('input[type="email"]').focus()`);
  await wc.insertText('test@example.invalid');
  await delay(20000);
  const value = await evaluate(`document.querySelector('input[type="email"]')?.value`);
  if (value !== 'test@example.invalid') throw new Error('Email typing did not persist');
  await evaluate(`document.querySelector('input[type="email"]').focus()`);
  await wc.insertText('x');
  await delay(1000);
  if (await evaluate(`document.querySelector('input[type="email"]')?.value`) !== 'test@example.invalidx')
    throw new Error('Email field stopped responding');
  const dir = path.join(require('electron').app.getPath('userData'), 'artifacts');
  await fs.mkdir(dir, { recursive: true });
  await fs.writeFile(path.join(dir, 'email-smoke.png'), (await wc.capturePage()).toPNG());
  console.log('PASS: Continue with email, typing, and editing after 20 seconds; no email submitted');
};
