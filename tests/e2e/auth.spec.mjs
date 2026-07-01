// Tès END-TO-END otantifye sou app la (deplwaye OSWA sèvi lokalman kont
// vrè Supabase la — gade README anba). Yo kouri SÈLMAN lè idantifyan yo
// bay (AYM_E2E_URL / AYM_E2E_EMAIL / AYM_E2E_PASSWORD), otreman yo skip —
// konsa `npm test` lokal ak CI smoke a pa kase.
//
// Kouri: npx playwright test --config playwright.e2e.config.mjs
//
// NÒT: paske index.html gen URL + kle anon Supabase la ekri ladan l,
// nou ka sèvi l lokalman (python3 -m http.server) epi mete
// AYM_E2E_URL=http://127.0.0.1:5173 — konsa QA a frape vrè backend la
// san pase pa Vercel (evite rate-limit 429).

import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

const URL = process.env.AYM_E2E_URL;
const EMAIL = process.env.AYM_E2E_EMAIL;
const PASSWORD = process.env.AYM_E2E_PASSWORD;
const ready = Boolean(URL && EMAIL && PASSWORD);

test.skip(!ready,
    'E2E idantifyan absan — mete AYM_E2E_URL / AYM_E2E_EMAIL / AYM_E2E_PASSWORD (gade .env.example)');

// Menm règ dezaktive ak tests/a11y.spec.mjs pou konsistans (baseline
// fòm ki poko gen label). Vize: diminye lis sa a piti piti.
const A11Y_DISABLE = ['aria-hidden-focus', 'color-contrast', 'label', 'select-name'];

// Konekte yon achtè atravè vrè UI a.
async function login(page, email, password) {
    await page.goto('/');
    await expect(page.locator('#authEmail')).toBeVisible();

    // Fòm nan louvri an mòd "Kreye Kont" pa default — bascule an "Konekte".
    const btn = page.locator('#emailSignUpBtn');
    if ((await btn.textContent())?.trim() !== 'Konekte') {
        await page.locator('#authToggleLink').click();
        await expect(btn).toHaveText(/Konekte/);
    }

    await page.locator('#authEmail').fill(email);
    await page.locator('#authPassword').fill(password);
    await btn.click();

    // Login reyisi -> app shell la (bottom nav) parèt.
    await expect(page.locator('#bottomNav')).toBeVisible({ timeout: 20_000 });
}

// Scan aksesiblite sou ekran aktyèl la (kritik/grav sèlman).
async function axeScan(page, label) {
    const res = await new AxeBuilder({ page })
        .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
        .disableRules(A11Y_DISABLE)
        .analyze();
    const blocking = (res.violations || []).filter(
        v => v.impact === 'critical' || v.impact === 'serious');
    if (blocking.length) {
        console.log(`\n[axe ${label}]\n` + blocking.map(
            v => `- [${v.impact}] ${v.id}: ${v.description} (${v.nodes.length})`).join('\n'));
    }
    expect(blocking, `Vyolasyon a11y sou ekran "${label}"`).toEqual([]);
}

test('achtè ka konekte ak email/modpas', async ({ page }) => {
    const errors = [];
    page.on('pageerror', e => errors.push(String(e.message || e)));

    await login(page, EMAIL, PASSWORD);

    // Fòm otantifikasyon an disparèt apre login.
    await expect(page.locator('#emailAuthForm')).toBeHidden();
    expect(errors, `Erè JS pandan login:\n${errors.join('\n')}`).toEqual([]);
});

// axe-core sou nouvo ekran otantifye yo (feed / komand / pwofil / pibliye).
// Itilize navTo() global la pou chanje ekran — chak `#s-<tab>` se yon
// vue distenk.
test('axe: ekran otantifye yo pa gen vyolasyon kritik', async ({ page }) => {
    await login(page, EMAIL, PASSWORD);
    for (const tab of ['feed', 'order', 'profile', 'pub']) {
        await page.evaluate((t) => window.navTo && window.navTo(t), tab);
        await expect(page.locator('#s-' + tab)).toHaveClass(/on/);
        await page.waitForTimeout(600);
        await axeScan(page, tab);
    }
});

// ── Skelèt flux end-to-end (P0) ─────────────────────────────
// Sa yo mande done runtime (kòmand nan bon eta) e/oswa plizyè wòl
// (vandè + admin). Yo makè `fixme` — y ap ranpli ANSANM ak achtè a
// pandan premye run live la (pou pa livre tès ki pa verifye).

test.fixme('kòd pwomo: aplike yon kòd valab sou yon kòmand', async () => {
    // Achtè -> checkout -> #orderPromoInput = kòd valab -> total redwi.
    // Verifye tou: kòd ekspire/deja itilize -> rejte ak mesaj.
    // (Antre: checkoutCart(), applyPromoToOrder())
});

test.fixme('litij: achtè ouvri yon litij ak yon rezon', async () => {
    // Sou yon kòmand elijib -> openDispute(orderId) ak yon rezon ->
    // status 'disputed'. (Antre: openDispute() ~L10939)
});

test.fixme('flux escrow konplè (bezwen kont vandè + admin)', async () => {
    // kòmand -> payment_submitted -> payment_verified (admin) ->
    // ready_for_pickup (vandè) -> otp_confirmed -> released (admin).
    // Verifye idempotans: 2èm "Lage lajan" = no-op.
});
