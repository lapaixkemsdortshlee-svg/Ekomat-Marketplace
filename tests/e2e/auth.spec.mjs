// Tès END-TO-END otantifye sou app la deplwaye. Yo kouri SÈLMAN lè
// idantifyan yo bay (AYM_E2E_URL / AYM_E2E_EMAIL / AYM_E2E_PASSWORD),
// otreman yo skip — konsa `npm test` lokal ak CI smoke a pa kase.
//
// Kouri: npx playwright test --config playwright.e2e.config.mjs

import { test, expect } from '@playwright/test';

const URL = process.env.AYM_E2E_URL;
const EMAIL = process.env.AYM_E2E_EMAIL;
const PASSWORD = process.env.AYM_E2E_PASSWORD;
const ready = Boolean(URL && EMAIL && PASSWORD);

test.skip(!ready,
    'E2E idantifyan absan — mete AYM_E2E_URL / AYM_E2E_EMAIL / AYM_E2E_PASSWORD (gade .env.example)');

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

test('achtè ka konekte ak email/modpas', async ({ page }) => {
    const errors = [];
    page.on('pageerror', e => errors.push(String(e.message || e)));

    await login(page, EMAIL, PASSWORD);

    // Fòm otantifikasyon an disparèt apre login.
    await expect(page.locator('#emailAuthForm')).toBeHidden();
    expect(errors, `Erè JS pandan login:\n${errors.join('\n')}`).toEqual([]);
});

// ── Skelèt flux end-to-end (P0) ─────────────────────────────
// Flux sa yo mande plizyè kont (achtè + vandè + admin) ak done seed,
// donk yo makè `fixme` (yo pa kouri, yo pa echwe) jiskaske kont test
// yo pare. Chak gen etap yo dokimante pou fasilite ranplisaj la.

test.fixme('flux escrow konplè: kòmand -> peman -> livrezon -> lage', async () => {
    // 1. Achtè: ajoute pwodwi nan panye, kreye kòmand   -> awaiting_payment
    // 2. Achtè: kole ref MonCash                          -> payment_submitted
    // 3. Admin: verifye peman                             -> payment_verified
    // 4. Vandè: make "pare pou kolèk"                     -> ready_for_pickup
    // 5. Vandè: antre OTP kòrèk                           -> otp_confirmed
    // 6. Admin: lage lajan                                -> released
    // Verifye: kat "Sante Escrow" reflete montan an, epi
    // yon dezyèm klik "Lage lajan" se yon no-op (garde idempotans).
});

test.fixme('kòd pwomo: aplike yon kòd valab sou yon kòmand', async () => {
    // Achtè: sou paj checkout, antre yon kòd pwomo valab -> total redwi.
    // Verifye tou: kòd ekspire / deja itilize -> rejte ak mesaj kòrèk.
});

test.fixme('litij: achtè ouvri yon litij ak yon rezon', async () => {
    // Achtè: sou yon kòmand elijib, ouvri yon litij ak yon rezon ->
    // status 'disputed' + antre nan admin_actions (odit).
});
