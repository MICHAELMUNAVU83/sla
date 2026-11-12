// Captures the screenshots used by the in-app user manual (/manual).
//
//   1. Start the app with demo data:  mix ecto.reset && mix phx.server
//   2. cd scripts/manual && npm install && npm run screenshots
//
// Images are captured to a temp folder and then copied into
// priv/static/images/manual. Writing straight into priv/static makes the dev
// live-reloader refresh the page mid-capture, which breaks tab and popup shots.
// When you add a feature, add its shots below and reference them in
// lib/sla_web/live/manual_live/index.ex.
const fs = require('fs'), os = require('os'), path = require('path');
const puppeteer = require('puppeteer-core');
const B = process.env.APP_URL || 'http://localhost:4000';
const CHROME = process.env.CHROME_PATH || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const DEST = path.resolve(__dirname, '../../priv/static/images/manual');
const OUT = fs.mkdtempSync(path.join(os.tmpdir(), 'sla-manual-'));
const wait = ms => new Promise(r => setTimeout(r, ms));
(async () => {
  const b = await puppeteer.launch({executablePath: CHROME, headless: 'new'});
  const p = await b.newPage(); await p.setViewport({width: 1440, height: 900, deviceScaleFactor: 1});
  await p.goto(B + '/users/log-in', {waitUntil: 'networkidle0'});
  await p.type('#login_form_password_email', 'staff.demo@sichangi.africa');
  await p.type('#login_form_password input[type=password]', 'SlaDemo!2026');
  await Promise.all([p.waitForNavigation({waitUntil: 'networkidle0'}), p.click('#login_form_password button')]);
  await p.goto(B + '/clients', {waitUntil: 'networkidle0'});
  const go = async path => { await p.goto(B + path, {waitUntil: 'networkidle0'}); await p.waitForFunction(() => window.liveSocket && window.liveSocket.main && window.liveSocket.main.isConnected()); await wait(600); };
  const click = async (sel, expect) => {
    for (let i = 0; i < 10; i++) {
      await p.waitForSelector(sel); await p.$eval(sel, el => el.click()); await wait(800);
      if (!expect || await p.$eval(expect, el => getComputedStyle(el).display !== 'none').catch(() => false)) return;
    }
    throw new Error('click did not take effect: ' + sel);
  };
  const snap = async name => { await p.screenshot({path: `${OUT}/${name}.png`}); console.log('saved', name); };
  await go('/clients'); await snap('clients');
  const c = await p.$eval('#clients a[id^=clients-]', a => a.getAttribute('href'));
  await go('/clients/new'); await snap('client-new');
  await go(c); await click('#client-tab-compliance', '#edit-client-kyc'); await snap('client-kyc');
  await go('/matters'); await snap('matters');
  const m = await p.$eval('#matters a[id^=matters-]', a => a.getAttribute('href'));
  await go(m); await snap('matter-overview');
  await click('#matter-tab-activity', '#open-activity-modal'); await snap('matter-activity');
  await click('#open-activity-modal', '#activity-modal-container'); await snap('log-activity');
  await go('/diary'); await snap('diary');
  await go('/calendar'); await snap('calendar');
  await click('#new-calendar-event', '#calendar-event-modal-container'); await snap('calendar-new-event');
  await go('/documents'); await snap('documents');
  await click('#open-upload', '#upload-modal-container'); await snap('documents-upload');
  const d = await p.$eval('#documents a.document-card', a => a.getAttribute('href'));
  await go(d); await snap('document-view');
  await go(m); await click('#matter-tab-billing', '#open-time-modal'); await snap('matter-billing');
  await click('#open-time-modal', '#time-modal-container'); await snap('add-time');
  await go('/billing'); await snap('billing');
  await go('/allocation'); await snap('allocation');
  await click('#open-reassign', '#reassign-modal-container'); await snap('reassign');
  await go('/intake'); await snap('intake');
  await go('/admin/users'); await snap('team');
  await b.close();
  fs.mkdirSync(DEST, {recursive: true});
  for (const f of fs.readdirSync(OUT)) fs.copyFileSync(path.join(OUT, f), path.join(DEST, f));
  console.log('copied screenshots to', DEST);
})().catch(e => { console.error(e); process.exit(1); });
