// supabase/functions/send-email/index.ts
//
// Edge Function ki voye yon imèl tranzaksyonèl chak fwa yon ranje
// kreye nan tab `public.notifications`. Imèl yo soti via Resend
// (https://resend.com) — yon plan gratis ki vini ak 100 imèl/jou.
//
// FLOW:
//   1. Database Webhook (Supabase Studio → Database → Webhooks) tape
//      sou URL fonksyon sa a chak ranje INSERT sou `notifications`,
//      ak header `x-webhook-secret` = WEBHOOK_SECRET.
//   2. Fonksyon an chèche imèl resipyan an nan `auth.users`.
//   3. Bati yon HTML imèl ki bati selon `record.type` (komand, sistèm,
//      chat, promo). Sijè a + kò yo nan Kreyòl.
//   4. POST sou https://api.resend.com/emails ak Bearer token la.
//
// SECRETS POU KONFIGIRE (`supabase secrets set …` oswa Studio):
//   RESEND_API_KEY   →  re_xxx — soti nan resend.com → API Keys
//   EMAIL_FROM       →  egz. "AyitiMarket <noreply@ayitimarket.com>"
//                       (domèn dwe verifye sou Resend)
//   WEBHOOK_SECRET   →  menm sekrè ki itilize ak send-push
//
// DEPLWAYE:
//   supabase functions deploy send-email --no-verify-jwt
//
// Si RESEND_API_KEY pa konfigire, fonksyon an retounen 200 ak
// "skipped: not configured" — pa kraze flow notifikasyon an.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const RESEND_URL = "https://api.resend.com/emails";

function unauthorized(): Response {
    return new Response("unauthorized", { status: 401 });
}
function json(body: unknown, status = 200): Response {
    return new Response(JSON.stringify(body), {
        status,
        headers: { "content-type": "application/json" },
    });
}

// Bati sijè + kò HTML imèl la dapre tip notifikasyon an.
function buildEmail(record: Record<string, unknown>): { subject: string; html: string } {
    const title = String(record.title || "AyitiMarket");
    const body = String(record.body || "");
    const type = String(record.type || "system");
    const color = String(record.color || "#00666f");

    // Sijè preset selon tip
    const subjects: Record<string, string> = {
        order: "[AyitiMarket] " + title,
        chat:  "[AyitiMarket — Chat] " + title,
        system: "[AyitiMarket] " + title,
        promo: "[AyitiMarket] " + title,
    };
    const subject = subjects[type] || subjects.system;

    const html = `<!DOCTYPE html>
<html lang="ht"><body style="margin:0;padding:0;background:#fcf9f4;font-family:'Helvetica Neue',Arial,sans-serif;color:#1c1c19">
  <div style="max-width:560px;margin:24px auto;background:#fff;border-radius:16px;overflow:hidden;border:1px solid #e5e2dd">
    <div style="padding:24px;background:${color}14;border-bottom:3px solid ${color}">
      <p style="margin:0;font-size:11px;font-weight:700;letter-spacing:.12em;text-transform:uppercase;color:${color}">AyitiMarket</p>
      <h1 style="margin:8px 0 0;font-size:20px;font-weight:800;color:#1c1c19">${title}</h1>
    </div>
    <div style="padding:24px">
      <p style="margin:0;font-size:15px;line-height:1.55;color:#3d4949">${body || "Ou gen yon nouvèl notifikasyon nan AyitiMarket."}</p>
      <a href="https://ayiti-market.vercel.app/" style="display:inline-block;margin-top:20px;padding:12px 20px;border-radius:10px;background:${color};color:#fff;text-decoration:none;font-weight:700;font-size:14px">
        Louvri AyitiMarket
      </a>
    </div>
    <div style="padding:14px 24px;background:#f6f3ee;border-top:1px solid #e5e2dd">
      <p style="margin:0;font-size:11px;color:#6d7979;line-height:1.5">
        Ou resevwa imèl sa a paske ou enskri sou AyitiMarket.
        Pou koupe imèl yo, ale nan Paramèt → Notifikasyon.
      </p>
    </div>
  </div>
</body></html>`;
    return { subject, html };
}

Deno.serve(async (req: Request) => {
    if (req.method !== "POST") return new Response("method not allowed", { status: 405 });

    const expected = Deno.env.get("WEBHOOK_SECRET");
    if (expected) {
        const got = req.headers.get("x-webhook-secret")
            ?? req.headers.get("authorization")?.replace(/^Bearer\s+/i, "")
            ?? "";
        if (got !== expected) return unauthorized();
    }

    let payload: any;
    try { payload = await req.json(); }
    catch { return json({ ok: false, error: "invalid json" }, 400); }
    const record = payload?.record ?? payload;
    if (!record || !record.user_id) {
        return json({ ok: true, skipped: "no user_id in payload" });
    }

    const apiKey = Deno.env.get("RESEND_API_KEY");
    const from = Deno.env.get("EMAIL_FROM");
    if (!apiKey || !from) {
        return json({ ok: true, skipped: "RESEND_API_KEY or EMAIL_FROM not configured" });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceKey) {
        return json({ ok: false, error: "missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY" }, 500);
    }
    const supabase = createClient(supabaseUrl, serviceKey, {
        auth: { persistSession: false, autoRefreshToken: false },
    });

    // Chèche imèl resipyan an nan auth.users via service role (admin API).
    let email: string | null = null;
    try {
        const { data, error } = await supabase.auth.admin.getUserById(record.user_id);
        if (error) {
            console.warn("[send-email] getUserById:", error.message);
        } else {
            email = data?.user?.email ?? null;
        }
    } catch (e) {
        console.warn("[send-email] getUserById threw:", (e as Error).message);
    }
    if (!email) {
        return json({ ok: true, skipped: "recipient has no email" });
    }

    const { subject, html } = buildEmail(record);

    try {
        const res = await fetch(RESEND_URL, {
            method: "POST",
            headers: {
                Authorization: `Bearer ${apiKey}`,
                "Content-Type": "application/json",
            },
            body: JSON.stringify({ from, to: [email], subject, html }),
        });
        const status = res.status;
        const body = await res.text();
        if (!res.ok) return json({ ok: false, status, body }, 500);
        return json({ ok: true, status, body: body ? JSON.parse(body) : null });
    } catch (e) {
        return json({ ok: false, error: (e as Error).message }, 500);
    }
});
