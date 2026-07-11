---
name: ayitimarket
description: Use when working in the AyitiMarket repository — product now branded Ekomat (Haitian multi-vendor marketplace). Provides architecture orientation, state shape, helper inventory, Supabase schema, role flows, conventions (Kreyòl strings, soft-delete, escrow state machine, role-aware notifications), and the canonical patterns for adding features without breaking existing flows. Trigger on any task touching index.html, supabase/*.sql, the boutique/seller/admin panels, cart, chat, notifications, orders, or escrow.
---

# Ekomat (ex-AyitiMarket) — project skill

> Rebrand 2026-07-11 : la marque produit est **Ekomat**. Le repo GitHub, les chemins, les IDs Firebase (`ayitimarket-19c78`), les clés localStorage (`aym_*`) et le slug de ce skill gardent l'ancien nom.

## What this is (and what it is NOT)

**Ekomat** is a Haitian multi-vendor e-commerce marketplace serving three roles: **buyer**, **seller**, and **admin**. UI strings are written in **Haitian Creole (Kreyòl)** — never replace them with French/English unless the user asks.

**The architecture is NOT what older briefs say.** Some prior conversations describe it as "React/Next.js + Zustand/Redux". That is wrong. The reality:

- **Single-file vanilla JS SPA**: `index.html` (~11k lines) holds the entire frontend — UI, state, Supabase calls, all of it. No bundler, no framework, no JSX.
- **State** is a single global object `A` (e.g. `A.user`, `A.cart`, `A.chatId`). No Zustand. No Redux. No React Context.
- **Rendering** is string templates assigned to `innerHTML`. Components don't exist.
- **Backend** is **Supabase** (Postgres + Auth + Storage + Realtime). The client uses `db = supabase.createClient(...)`.
- **PWA** with `sw.js` and `manifest.json`.
- **Hosted on Vercel**. `vercel.json` controls the deploy.

When in doubt: read `index.html`. There's no other JS bundle.

## Repo layout

```
index.html              ← entire SPA (UI + state + Supabase) — 11k+ lines
onboarding.html         ← first-visit onboarding flow
sw.js                   ← service worker (PWA)
manifest.json           ← PWA manifest
vercel.json             ← deploy config
.env.example            ← SUPABASE_URL / SUPABASE_ANON_KEY
supabase/
  schema.sql            ← initial tables (profiles, products, orders, etc.)
  rls-policies.sql      ← row-level security
  seed.sql              ← demo data
  migration-2026-04..07.sql  ← additive migrations
```

## Database schema (Supabase) — essential tables

All tables use UUID PKs and live in `public`. Read `supabase/schema.sql` + the `migration-2026-*.sql` files for the full picture. Most-used columns:

- **profiles** — `id` (FK auth.users), `role` ∈ {`buyer`,`seller`,`admin`}, `display_name`, `avatar_url`, `verified_seller`, `rating_avg`, `sales_count`, `phone`, `moncash_number`, `location`, `bio`, `status` ∈ {`active`,`pending`,`banned`}, `banned_until`, `ban_reason`.
- **products** — `seller_id`, `title`, `price`, `old_price`, `category`, `location`, `stock`, `images TEXT[]`, `sizes TEXT[]`, `status` ∈ {`active`,`draft`,`sold`,`archived`}. **Soft-delete uses `status='archived'`** to preserve the `orders.product_id` FK.
- **orders** — `buyer_id`, `seller_id`, `product_id`, `quantity`, `unit_price`, `total_amount`, `fee_amount`, `net_amount`, `status` (escrow state machine, see below), `payment_method`, `moncash_ref`, `pickup_location`, `otp_code`, `escrow_released`.
- **cart_items** — `(user_id, product_id, qty)` with `UNIQUE(user_id, product_id)`. Upserts via `onConflict: 'user_id,product_id'`.
- **messages** — `sender_id`, `receiver_id`, `product_id` (one thread per contact across products), `content`, `read`. Special prefixes: `[LOC]<json>` for location, `[VOICE]<json>` for voice notes (base64 dataURL inline — no Storage bucket).
- **notifications** — `user_id`, `type` ∈ {`order`,`system`,`chat`,`promo`}, `icon`, `title`, `body`, `color`, `read`. Realtime subscribed on `user_id=eq.<me>`.
- **flash_deals** — `product_id`, `price`, `old_price`, `discount_pct`, `stock`, `active`, `ends_at`.
- **favorites**, **followers**, **verification_requests**, **reviews**.
- **app_settings** — platform config (`admin_moncash_number`, `fee_percent`, `escrow_auto_release_hours`).

Custom RPCs: `advance_order_status(p_order_id, p_to_status, p_moncash_ref, p_admin_note)`, `try_seller_otp(p_order_id, p_otp)`, `increment_views(product_uuid)`, `update_seller_rating()` (trigger).

## Order escrow state machine

`ORDER_STATUS_MAP` lives in `index.html` near line 4785. Canonical pipeline:

```
awaiting_payment        Buyer just placed order, must MonCash the admin
  → payment_submitted   Buyer pasted MonCash ref, admin must verify
  → payment_verified    Admin confirmed — escrow active, seller prepares
  → ready_for_pickup    Seller marked product ready
  → picked_up           Buyer collected
  → otp_confirmed       Seller validated buyer's 6-digit OTP at pickup
  → released            Admin transferred funds to seller's MonCash
  → completed           Buyer rated, lifecycle closed
```
Off-path: `cancelled`, `disputed`, `refunded`. **All transitions go through the `advance_order_status` RPC** — never `db.from('orders').update({status:...})` directly.

## Global frontend state (`A`)

Single global object, initialized near line 3433 in `index.html`. Key fields:

| Field | Purpose |
|---|---|
| `A.user` | `{ uid, name, role, verifiedSeller, … }` after login |
| `A.isAuth` | boolean auth gate |
| `A.tab` | current bottom-nav tab; `A.stack` is the back-navigation stack |
| `A.curProd` | product currently viewed/ordered |
| `A.cart` | `[{ id, qty }]` mirrored into `cart_items` |
| `A.chatId` | product_id of the open chat |
| `A.chatSellerId` / `A.chatOtherId` | chat peer (both end up equal after `openChatFor` override) |
| `A.msgs` | `{ [productId]: [{ s, t/url/coords, tm, type? }] }` |
| `A.favs` | `Set` of product ids |
| `A.selPickup`, `A.selPay` | order sheet selections |
| `A._escrowCurrent`, `A._escrowGroupIds` | active escrow payment sheet context |
| `A._adminConfPayOrder` | active admin "Confirm Payment" sheet context |

In-memory caches: `PRODUCTS` (array), `SELLERS` (dict), `NOTIFS` (array), `FLASH_DEALS`, `PICKUPS`, `APP_SETTINGS`, `ADMIN_USERS`, `VERIF_REQUESTS`, `CURRENCY` (HTG↔USD toggle).

## Helpers you must use (and not reinvent)

All defined near the top of the script in `index.html`. Search them by name:

- `fp(n)` — number → `"1,234"` (locale `fr`).
- `fpc(htg)` — number → `"1,234 HTG"` or `"$9.49"` depending on `CURRENCY.current`.
- `discountPct(p)` — returns the integer % discount when `p.oldP > p.p`, else `0`. Used to render the `-X%` badge consistently.
- `prodPlaceholder(p, height)` — SVG placeholder with category-themed icon (uses `p.e`, `p.ec`). Fallback for missing images.
- `cartProductImageHTML(p, sizePx)` — returns `<img>` with `onerror` fallback to `prodPlaceholder`. Use this in any new cart-like list.
- `cartGroupBySeller()` — groups `A.cart` into `[{ sellerId, sellerName, sellerVerified, items, total }]`.
- `notify(userId, { type, icon, title, body, color })` — inserts one row into `notifications`. Always use this instead of `db.from('notifications').insert(...)` inline.
- `notifyAdmins({ … })` — fan-out to every admin profile (excludes self). Use for new orders, payments to verify, disputes.
- `toast(msg)` — bottom toast.
- `playNotifSound()`, `navigator.vibrate(...)` (gated by `VIBRATE_ON`).
- `openSheet('sheetId')` / `closeSheets()` — bottom-sheet UI.

## Realtime channels

Defined near the bottom of `index.html`. Subscribed at boot when relevant role is logged in:

- `subscribeToNotifications()` — INSERT on `notifications` filtered by `user_id=eq.<me>`. Every role.
- `subscribeToChat(productId, otherId)` — INSERT on `messages` between two users. Re-subscribed on entering a chat.
- `subscribeToAdminOrders()` — INSERT/UPDATE on `orders`, **admin only**. Refreshes the admin panel + toasts on new orders and `payment_submitted` transitions.

When adding role-wide events, prefer **inserting a `notifications` row** for each affected user (caught automatically by their realtime channel) rather than spinning up a new dedicated channel.

## Role flows

### Buyer
- Sees feed (`navTo('feed')`), product detail, cart, orders history, notifications, chat.
- Adds to cart → `addToCart(pid)` (upsert `cart_items`).
- Checkouts **per seller** from cart via `placeSellerOrder(sellerId)` — creates one order row per cart line, decrements stock, clears cart for that seller, opens consolidated escrow sheet.
- Pays MonCash externally, pastes ref into `escrowPaySheet`, submits → `submitPaymentRef()`. If multiple orders in the group (`_escrowGroupIds`), all advance with the same ref.

### Seller (verified)
- Sees feed + their own **Boutik mwen** (`renderBoutiqueContent`).
- Publishes products via `pub` tab. Soft-deletes via `submitDeleteProduct()` (sets `status='archived'`).
- The boutique query **must** filter `.neq('status', 'archived')` so archived rows disappear from the seller's view.
- Marks orders ready (`sellerMarkReady`), confirms buyer OTP at pickup (`confirmSellerOTP`).
- Receives payouts on their `profiles.moncash_number` when admin releases escrow.

### Admin
- Sees the admin panel (`#screen-admin`) with 4 tabs: `verif` (verifications), `orders` (escrow management), `users`, `convos`.
- **Bug 4.2 flow** for payment confirmation: `openAdminConfirmPayment(orderId)` opens `#adminConfirmPaymentSheet` showing buyer/seller/amount/MonCash ref + optional note. `submitAdminConfirmPayment()` advances to `payment_verified` and notifies both parties via `notify()`.
- Releases escrow: `adminReleaseEscrow` (calls `moncashSendPayout` adapter — currently a stub).
- Resolves disputes: `adminResolveDispute(id, 'release'|'refund')`.

## Conventions (HARD rules — apply automatically)

1. **Kreyòl only** in UI strings. Don't translate to French/English.
2. **No schema migrations** unless the user explicitly asks. The current schema covers all the recent features (`old_price`, `avatar_url`, `cart_items`, `notifications`, `flash_deals`, etc.).
3. **Soft-delete products** via `status='archived'`. Never `db.from('products').delete()` — it breaks `orders.product_id` FK.
4. **Always filter `status`** when querying products for any user-facing surface (feed, boutique, similar, search). Archived/draft rows must be invisible to consumers.
5. **All `notifications` writes go through `notify()` / `notifyAdmins()`** — no inline `db.from('notifications').insert(...)` anymore.
6. **All order status transitions go through the `advance_order_status` RPC.** Never update `orders.status` directly.
7. **One global object** (`A`). Don't introduce `useState`, classes, or new state systems. New state lives on `A.<your_field>`.
8. **No new files unless necessary.** Edit `index.html`. The single-file architecture is intentional.
9. **Don't add comments** explaining what code does. Only add a 1-line comment when *why* is non-obvious (e.g. "Bug X: archived rows reappeared without this filter").
10. **Cart of any seller checks out as N orders sharing one MonCash ref.** `A._escrowGroupIds` carries the row ids; `submitPaymentRef` advances them all.
11. **Voice messages** are stored inline as base64 `[VOICE]<json>` in `messages.content` — no Supabase Storage bucket. Don't refactor to Storage without a clear reason.
12. **`A.chatSellerId` is misleading legacy naming.** In the override (`_origOpenChatFor`) it's reassigned to the true peer regardless of role. New code should fall back via `A.chatSellerId || A.chatOtherId` (both exclude self).

## Working pattern

For any feature/bug:

1. **Locate** the existing functions: `grep -n "renderX\|submitY\|openZ" index.html`. The codebase is one file — `grep` first, read second.
2. **Match the surrounding style.** No semicolons-only changes, no whitespace churn.
3. **Use existing helpers** (`notify`, `discountPct`, `cartProductImageHTML`, `openSheet`, …).
4. **Verify syntax** after editing:
   ```
   node -e "const fs=require('fs');const html=fs.readFileSync('index.html','utf8');const re=/<script(?:\\s[^>]*)?>([\\s\\S]*?)<\\/script>/g;const vm=require('vm');let m,idx=0,errs=0;while((m=re.exec(html))){const s=m[1];if(!s.trim()){idx++;continue;}try{new vm.Script(s,{filename:'inline-'+idx+'.js'});}catch(e){errs++;console.log('Script',idx,':',e.message);}idx++;}console.log(errs?('ERRORS: '+errs):'OK');"
   ```
5. **Commit + push** to the working branch (see Git below).
6. **Open a draft PR** unless told otherwise. The Vercel preview auto-deploys.

## Git / PR flow

- Long-lived feature branch is typically `claude/<topic>-<id>`. Stay on it; **never push directly to `main`**.
- Sync with main before starting: `git fetch origin main && git pull origin main --no-edit`.
- Commits go on the feature branch with a descriptive message (no `--no-verify`, no `--amend`).
- Push: `git push -u origin <branch>` with up to 4 retries on network failures (2 s / 4 s / 8 s / 16 s backoff).
- Open the PR as **draft** using `mcp__github__create_pull_request` (or `gh pr create --draft`), `base=main`. Body: `## Summary` + bullet list + `## Test plan` checklist.

## What's already shipped (recent backlog — for context)

PRs merged into `main`:

- **#36** — multi-seller cart refactor: images in cart, real per-item delete (DB + UI), seller-grouped checkout, badge auto-clear, persist via `cart_items` upsert.
- **#37** — discount rendering: `discountPct(p)` helper + strikethrough/`-X%` badge in feed/similar/detail/order-sheet/chat-card/boutique; seller avatar (`avatar_url`) wired into seller profile screen and product-detail seller card.
- **#38** — global notifications: `notify()` / `notifyAdmins()` helpers; missing inserts plugged on `cancelOrder` / `adminRefund` / `confirmSellerOTP` / `placeSellerOrder` / `confirmOrder`. Voice messages unblocked for buyers/admins via `peerId` fallback; `openChatFor` resets `#msgIn` so `voiceBtn` stays visible.
- **#39** — admin realtime: `subscribeToAdminOrders` (INSERT/UPDATE) at boot for admins; `adminConfirmPaymentSheet` (`openAdminConfirmPayment` / `submitAdminConfirmPayment`) replaces native `prompt()` with a clear "Wi, peman resevwa — Konfime" CTA.
- **#40** — boutique view fix: `renderBoutiqueContent` now filters `.neq('status', 'archived')` so soft-deleted products disappear immediately.

Don't repeat these. Build on them.

## Bug-investigation checklist

When a flow looks broken:

1. **Status filter missing?** (#40 root cause) — check that the query excludes `archived` / `draft` / `cancelled` etc.
2. **Stale local state?** Remember `A.cart` and `PRODUCTS` are in-memory mirrors. After mutations, refresh both then re-render.
3. **Wrong peer in chat?** `A.chatSellerId` is reassigned by the override — fall back via `chatSellerId || chatOtherId`.
4. **Order transition didn't propagate?** Use `advance_order_status` RPC; never raw UPDATE.
5. **Notification not received?** Either (a) no insert was made for that user, or (b) realtime channel not subscribed at boot. The channel filter is `user_id=eq.<me>` so the insert must use `user_id = recipient`.
6. **Image not showing?** Use `cartProductImageHTML` pattern (`<img onerror=…prodPlaceholder…/>`).

## What this skill does NOT cover

- The two prior `claude.ai/code/session_*` conversations referenced by the user are not readable by Claude. Anything from those sessions must be re-provided in-context if needed.
- React/Next.js patterns. This is a vanilla JS SPA; do not introduce framework idioms.
