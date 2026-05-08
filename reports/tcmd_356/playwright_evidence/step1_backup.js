const { chromium } = require('/home/shuirein928/.npm/_npx/e41f203b7505f1fb/node_modules/playwright');
const fs = require('fs');
const EVIDENCE_DIR = '/home/shuirein928/multi-agent-shogun/reports/tcmd_356/playwright_evidence';
(async () => {
  const browser = await chromium.launch({ headless: true, args: ['--use-fake-ui-for-media-stream', '--use-fake-device-for-media-stream'] });
  const page = await (await browser.newContext({ permissions: ['microphone'], viewport: { width: 1280, height: 800 } })).newPage();
  page.on('dialog', d => d.accept());
  await page.goto('http://localhost:8000/?mock=1&name=inmogy&v=' + Date.now(), { waitUntil: 'load', timeout: 30000 });
  await page.waitForFunction(() => window.MG_FIREBASE && window.MG_FIREBASE.ready, { timeout: 15000 });
  await page.waitForTimeout(5000);
  const result = await page.evaluate(async () => {
    const fb = window.MG_FIREBASE;
    const { doc, getDoc, setDoc, serverTimestamp } = fb.api;
    const main = (await getDoc(doc(fb.db, 'maps', 'genshiken', 'config', 'main'))).data();
    const dump = { furniture: (main.furniture || []).length, zones: (main.zones || []).length, decorations: (main.decorations || []).length, floor: (main.floor || []).length, mapW: main.mapW, mapH: main.mapH };
    await setDoc(doc(fb.db, 'maps', 'genshiken', 'config', 'main_backup_tcmd356_pre_video_recording'), { ...main, backupSourceTcmd: 'tcmd_356', backupTimestamp: new Date().toISOString(), updatedAt: serverTimestamp() });
    const verify = (await getDoc(doc(fb.db, 'maps', 'genshiken', 'config', 'main_backup_tcmd356_pre_video_recording'))).data();
    const match = (main.furniture || []).length === (verify.furniture || []).length;
    const lineage = {};
    for (const t of ['main_backup_tcmd329', 'main_backup_tcmd337b_pre_doorfix', 'main_backup_tcmd338_pre_basesystem', 'main_backup_tcmd339_pre_coffee', 'main_backup_tcmd348_pre_6fixes', 'main_backup_tcmd350_pre_hightouch_cat_hints', 'main_backup_tcmd351_pre_coffee_button_icons', 'main_backup_tcmd352_pre_drink_sound_hint', 'main_backup_tcmd354_pre_label_pickup', 'main_backup_tcmd355_pre_minecraft_door']) {
      lineage[t] = (await getDoc(doc(fb.db, 'maps', 'genshiken', 'config', t))).exists();
    }
    return { ok: true, dump, match, backupPath: 'maps/genshiken/config/main_backup_tcmd356_pre_video_recording', restoreLineage26_sample: lineage };
  });
  fs.writeFileSync(EVIDENCE_DIR + '/backup_dump.json', JSON.stringify(result, null, 2));
  console.log('[step1]', JSON.stringify(result));
  await browser.close();
})();
