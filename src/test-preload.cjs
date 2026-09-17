// Only loaded by the fixed local --self-test fixture; no bridge to page code.
const { ipcRenderer } = require('electron');
ipcRenderer.send('self-test-sandbox', { sandboxed: process.sandboxed, isolated: process.contextIsolated });
