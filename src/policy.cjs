const WEB_PREFERENCES = Object.freeze({
  nodeIntegration: false,
  nodeIntegrationInWorker: false,
  nodeIntegrationInSubFrames: false,
  contextIsolation: true,
  sandbox: true,
  webSecurity: true,
  allowRunningInsecureContent: false,
  webviewTag: false,
});

function isLinearURL(value) {
  try {
    const url = new URL(value);
    return url.protocol === 'https:' && url.hostname === 'linear.app'
      && !url.username && !url.password && (!url.port || url.port === '443');
  } catch { return false; }
}

function isExternalURL(value) {
  try {
    const url = new URL(value);
    return ['https:', 'http:'].includes(url.protocol) && !url.username && !url.password;
  } catch { return false; }
}

function windowSize(state = {}) {
  if (!state || typeof state !== 'object') state = {};
  return {
    width: Number.isFinite(state.width) ? Math.max(640, Math.min(2560, state.width)) : 1100,
    height: Number.isFinite(state.height) ? Math.max(480, Math.min(1600, state.height)) : 800,
  };
}

module.exports = { WEB_PREFERENCES, isLinearURL, isExternalURL, windowSize };
