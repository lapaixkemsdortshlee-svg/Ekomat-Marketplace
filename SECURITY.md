# Sekirite — Ekomat

## Rapòte yon vilnerabilite

Si w jwenn yon vilnerabilite sekirite, **pa kreye yon GitHub Issue
piblik**. Pito sa:

1. Voye yon imèl bay **lapaixkemsdortshlee@gmail.com** ak detay
2. Tann konfimasyon — n ap reponn nan 72 èdtan
3. N ap travay ak ou pou kowòdone yon disclosure responsab

Nou **pa peye bug bounties** kounye a, men nou rekonèt kontribitè yo
piblikman lè yo dakò.

## Sa ki pwoteje aplikasyon an

### Bò kliyan (browser)
- **Content Security Policy** strik nan `vercel.json` — script/style/
  connect sous limite a domèn ki nesesè
- **HSTS** (1 ane + includeSubDomains + preload) → fòs HTTPS pou tout
  vizit fiti
- **X-Frame-Options + frame-ancestors** → pwoteksyon kont clickjacking
- **Cross-Origin-Opener-Policy** → izolasyon kont kèk atak window-
  level
- **Permissions-Policy** → kamera/mik/GPS sèlman pou `self`, peman/
  USB/sansè dezaktive
- **Aksè baz done** → Supabase JWT + Row Level Security; kliyan an
  **pa jwenn data** li pa otorize wè
- Tès Playwright + axe-core sou chak PR → tès rengresyon a11y

### Bò sèvè (Supabase)
- **Row Level Security** aktif sou tout tab kliyan-aksesib:
  `profiles`, `products`, `orders`, `cart_items`, `messages`,
  `notifications`, `user_devices`, `user_addresses`, `promo_codes`,
  `promo_redemptions`, etc.
- **Edge Functions** (`send-push`, `send-email`) — pwoteje pa
  `WEBHOOK_SECRET` header obligatwa
- **Sekrè** (FCM service account, Resend API key) **janm** nan kòd
  kliyan an — sove sèlman kòm sekrè Supabase Edge Function
- **Service-role key** Supabase pa janm voye nan kliyan — sèvi
  sèlman nan Edge Functions

### Anvan ou deplwaye nouvèl chanjman
- Tès Playwright + axe-core dwe pase sou GitHub Actions
- CodeQL scan otomatik nan `.github/workflows/codeql.yml` pou bug JS/TS
- Dependabot ap kreye PR otomatik pou mete dependansi yo a jou (nimewo
  nan `.github/dependabot.yml`)

## Sa ki **pa** garanti

Pa gen aplikasyon ki 100% endestriktib. Nou aplike defans miltip
kouch men:

- **Kle Firebase Web piblik** (apiKey, etc.) parèt nan kòd kliyan a —
  sa **se** konsepsyon Firebase (sekirite a chita sou règ Firebase + auth).
  GitHub Secret Scanning te louvri alèt #1 (« Google API Key », 2026-06)
  sou kle sa a : **fo pozitif konnen** — kle a fèt pou ale nan navigatè a.
  Tretman 2026-07-11 : restriksyon kle a nan Google Cloud Console
  (referrers HTTP + API limite a FCM/Installations sèlman), epi fèmen
  alèt la kòm « False positive ». Pa gen rotasyon nesesè : yon fwa kle a
  restrenn, li initil andeyò domèn nou yo.
- **Anon key Supabase** parèt nan kòd kliyan an — RLS pwoteje aksè a.
- **CDN tyès pati** (Tailwind, Supabase JS, Firebase) **pa gen SRI** kounye a
  (yo deplwaye san pin) — yon konpwomi sou yon CDN ka enjekte kòd. TODO:
  pin vèsyon + ajoute SRI sou tout `<script src>`.
- **Tès e2e** pa kouvri tout flow — sèlman smoke + a11y. Atak business-
  logik (peman, eskwo) bezwen revizyon manyèl.

## Odit sekirite — 2026-07-02

Odit konplè (kòd estatik + advisors Supabase live). Rezilta yo trete pa lo :

**P0 — XSS estoke (korije, PR #105)**
- `onclick="fn('${non}')"` : non vandè/itilizatè/reviewer te enterpole brital →
  JS abitrè te ka kouri **nan sesyon admin lan**. Korije ak nouvo helper
  `jsAttr()` (echape JS apre sa HTML-atribi ; pwouve anti-breakout, 9/9 payload).
  Aplike sou approveVerif, rejectVerif, openIDModal, openRejectSheet,
  `toast(u.name)`, openVideoPlayer, openConversation, openRatingSheet, addToLook,
  block/unblock.
- `alt="${p.t}"` / `src="${src}"` nan kawousèl pwodwi → `esc()`.
- **Règ**: done nan HTML → `esc()` ; done nan `onclick`/chèn JS atribi → `jsAttr()`.

**P1 — Dirsisman (`migration-2026-harden-p1.sql`)**
- `search_path` fikse (`''`) sou 3 fonksyon trigger ki te rete
  (`generate_order_number`, `update_updated_at`, `update_updated_at_column`).
- `REVOKE EXECUTE ... FROM anon` sou RPC admin (`escrow_overview`,
  `escrow_attention_orders`, `funnel_overview`, `error_overview`) + machin escrow
  (`advance_order_status`, `try_seller_otp`). Supabase auto-grante `anon`, konsa
  `REVOKE FROM PUBLIC` pa t ase. Pa t eksplwatab (gad entèn `is_admin`/`auth.uid()`)
  men prensip mwens privilèj. `log_error` rete anon (kapti erè front anvan login).

**Info / aksepte**
- `referral_rewards` : RLS san policy → ajoute policy SELECT admin
  (`migration-2026-referral-rewards-policy.sql`). Ekriti rete fèmen (trigger sèlman).
- CSP `unsafe-eval` : **aksepte** — nesesè pou CDN Tailwind + Babel onboarding.
  Diminye ak echapman P0. Retire l sèlman si nou pre-konpile.
- `pg_trgm`/`pg_net` nan `public` : aksepte (deplasman riskan sou prod).
- Kle Firebase Web : piblik pa konsepsyon (wè seksyon anwo).

**Aksyon dashboard ki rete** : aktive Leaked Password Protection ; deplwaye
migrasyon yo (`harden-p1`, `referral-rewards-policy`) ; relanse advisors apre.

## Wotasyon sekrè

Lè yon sekrè konpwomèt:
1. Revoke l imedyatman nan dashboard sous la (Supabase / Firebase / Resend)
2. Jenere yon nouvo
3. Mete ajou Vercel env vars + Supabase secrets
4. Re-deplwaye Edge Functions
5. Mete nan `aym_pending_secret_rotation` issue pou trase

Gid konplè: `docs/SECURITY-CHECKLIST.md`.
