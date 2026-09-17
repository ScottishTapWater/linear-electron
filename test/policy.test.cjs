const test = require('node:test');
const assert = require('node:assert/strict');
const { WEB_PREFERENCES, isLinearURL, isExternalURL, windowSize } = require('../src/policy.cjs');

test('only the exact HTTPS Linear origin stays in-app', () => {
  assert.equal(isLinearURL('https://linear.app/login?next=%2F'), true);
  for (const url of ['https://linear.app.evil.test', 'https://evil.test@linear.app', 'http://linear.app', 'https://linear.app:8443', 'javascript:alert(1)', 'file:///tmp/test', 'garbage'])
    assert.equal(isLinearURL(url), false, url);
});
test('external handoff rejects dangerous protocols and credentials', () => {
  assert.equal(isExternalURL('https://example.org/path'), true);
  for (const url of ['javascript:alert(1)', 'file:///etc/passwd', 'linear://test', 'https://user:pass@example.org', 'data:text/html,hello'])
    assert.equal(isExternalURL(url), false, url);
});
test('renderer sandbox and isolation stay enabled', () => {
  assert.equal(WEB_PREFERENCES.sandbox, true);
  assert.equal(WEB_PREFERENCES.contextIsolation, true);
  assert.equal(WEB_PREFERENCES.webSecurity, true);
  assert.equal(WEB_PREFERENCES.nodeIntegration, false);
  assert.equal(WEB_PREFERENCES.webviewTag, false);
});
test('window dimensions have sensible bounds', () => {
  assert.deepEqual(windowSize(), { width: 1100, height: 800 });
  assert.deepEqual(windowSize(null), { width: 1100, height: 800 });
  assert.deepEqual(windowSize({ width: -1, height: 1e8 }), { width: 640, height: 1600 });
});
