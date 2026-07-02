#!/bin/bash
# SessionStart hook — restores the ephemeral tools/MCP/skills that don't live in
# the repo, so a fresh Claude Code web container comes back fully equipped.
# Skills committed under .claude/skills/ are already cloned with the repo; this
# only rebuilds what is container-level: CLIs, MCP servers, the code graph, and
# the globally-installed reference skills.
#
# Secrets are read from environment variables (set them in your Claude Code web
# environment → Settings → Environment Variables). Nothing secret is committed.
#   SUPABASE_ACCESS_TOKEN  → Supabase MCP (read-only)
#   GEMINI_API_KEY         → agentmemory semantic embeddings + knowledge graph
#   MAGIC_API_KEY          → 21st.dev Magic MCP
set -uo pipefail
LOG(){ echo "[ayitimarket-setup] $*"; }

# Web/remote only — never clobber a developer's own local setup.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then exit 0; fi
PROJ="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# ── 1. CLIs (idempotent) ──────────────────────────────────────────────
command -v codegraph   >/dev/null 2>&1 || { LOG "install codegraph";   npm install -g --silent @colbymchenry/codegraph   || LOG "codegraph install failed"; }
command -v agentmemory >/dev/null 2>&1 || { LOG "install agentmemory"; npm install -g --silent @agentmemory/agentmemory || LOG "agentmemory install failed"; }
command -v graphify    >/dev/null 2>&1 || { LOG "install graphify";    pip install --quiet graphifyy                     || LOG "graphify install failed"; }
command -v yt-dlp      >/dev/null 2>&1 || { LOG "install yt-dlp";      pip install --quiet yt-dlp                        || LOG "yt-dlp install failed"; }
command -v ffmpeg      >/dev/null 2>&1 || { LOG "install ffmpeg";      apt-get install -y --no-install-recommends ffmpeg >/dev/null 2>&1 || { apt-get update -qq >/dev/null 2>&1; apt-get install -y --no-install-recommends ffmpeg >/dev/null 2>&1; } || LOG "ffmpeg install failed"; }

# ── 2. MCP servers (add only if absent) ───────────────────────────────
have_mcp(){ python3 - "$1" <<'PY'
import json,sys,os
try: d=json.load(open(os.path.expanduser("~/.claude.json")))
except Exception: sys.exit(1)
sys.exit(0 if sys.argv[1] in d.get("mcpServers",{}) else 1)
PY
}

if [ -n "${MAGIC_API_KEY:-}" ]; then
  have_mcp magic || { LOG "wire magic"; claude mcp add magic --scope user --env API_KEY="$MAGIC_API_KEY" -- npx -y @21st-dev/magic@latest || LOG "magic wiring failed"; }
else LOG "skip magic (MAGIC_API_KEY unset)"; fi

have_mcp codegraph || { LOG "wire codegraph"; codegraph install --target claude --location global --yes >/dev/null 2>&1 || LOG "codegraph wiring failed"; }

if [ -n "${GEMINI_API_KEY:-}" ]; then
  mkdir -p "$HOME/.agentmemory"
  if ! grep -q '^GEMINI_API_KEY=' "$HOME/.agentmemory/.env" 2>/dev/null; then
    agentmemory init >/dev/null 2>&1 || true
    printf '\nGEMINI_API_KEY=%s\nEMBEDDING_PROVIDER=gemini\nGRAPH_EXTRACTION_ENABLED=true\nGEMINI_MODEL=gemini-2.5-flash\n' "$GEMINI_API_KEY" >> "$HOME/.agentmemory/.env"
  fi
else LOG "agentmemory will run keyword-only (GEMINI_API_KEY unset)"; fi
have_mcp agentmemory || { LOG "wire agentmemory"; agentmemory connect claude-code >/dev/null 2>&1 || LOG "agentmemory wiring failed"; }

if [ -n "${SUPABASE_ACCESS_TOKEN:-}" ]; then
  have_mcp supabase || { LOG "wire supabase"; claude mcp add supabase --scope user --env SUPABASE_ACCESS_TOKEN="$SUPABASE_ACCESS_TOKEN" -- npx -y @supabase/mcp-server-supabase@latest --read-only --project-ref=htxfwxldzaocuwezzbom || LOG "supabase wiring failed"; }
else LOG "skip supabase (SUPABASE_ACCESS_TOKEN unset)"; fi

# ── 3. graphify code graph of index.html (no repo changes) ────────────
if command -v graphify >/dev/null 2>&1 && [ -f "$PROJ/index.html" ]; then
  GDIR="$HOME/ayitimarket-graph"; mkdir -p "$GDIR"
  python3 - "$PROJ/index.html" "$GDIR/app.js" <<'PY'
import re,sys
html=open(sys.argv[1]).read()
big=[(html[:m.start(1)].count('\n')+1,m.group(1)) for m in re.finditer(r'<script(?:\s[^>]*)?>([\s\S]*?)</script>',html) if m.group(1).strip() and m.group(1).count('\n')>500]
open(sys.argv[2],'w').write(''.join(f"\n// ===== from index.html line {ln} =====\n{b}\n" for ln,b in big))
PY
  graphify update "$GDIR" >/dev/null 2>&1 && LOG "code graph rebuilt ($GDIR)" || LOG "code graph build skipped"
fi

# ── 4. ephemeral global skills ────────────────────────────────────────
# agentmemory skills (recall/remember/handoff/...)
[ -d "$HOME/.claude/skills/recall" ] || { LOG "restore agentmemory skills"; npx -y skills add rohitg00/agentmemory --agent claude-code -g -y >/dev/null 2>&1 || LOG "agentmemory skills skipped"; }

# watch skill (video analysis via yt-dlp/ffmpeg/Whisper)
[ -d "$HOME/.claude/skills/watch" ] || { LOG "restore watch skill"; npx -y skills add bradautomates/claude-video --agent claude-code -g -y >/dev/null 2>&1 || LOG "watch skill skipped"; }

# system-prompts-leaks reference skill
if [ ! -d "$HOME/.claude/skills/system-prompts-leaks" ]; then
  LOG "restore system-prompts-leaks skill"
  D="$HOME/.claude/skills/system-prompts-leaks"; mkdir -p "$D/reference"
  if curl -fsSL "https://codeload.github.com/asgeirtj/system_prompts_leaks/tar.gz/refs/heads/main" -o /tmp/spl.tgz 2>/dev/null; then
    tar -xzf /tmp/spl.tgz -C /tmp 2>/dev/null && cp -r /tmp/system_prompts_leaks-main/. "$D/reference/" 2>/dev/null
    rm -rf "$D/reference/.git" "$D/reference/.github"
  fi
  cat > "$D/SKILL.md" <<'MD'
---
name: system-prompts-leaks
description: Reference archive of publicly documented/leaked system prompts for AI assistants (Claude, ChatGPT, Gemini, Grok, Perplexity, Copilot, Meta AI, Mistral, Cursor, Qwen, Notion). Use to compare how assistants are instructed, study prompt-engineering patterns, or model your own system/agent prompts. Markdown under reference/.
---
# System Prompt Leaks — reference archive
Read-only study material (not a tool). Browse `reference/` by editor; `grep -ri "<topic>" reference/` to compare phrasings. Community-extracted — may be outdated; never present as a product's official current prompt.
MD
fi

# gstack suite (browser-driven skills) — heavier, best-effort
if [ ! -d "$HOME/.claude/skills/gstack" ]; then
  LOG "restore gstack"
  if GIT_CONFIG_GLOBAL=/dev/null git -c http.proxy="${HTTPS_PROXY:-}" -c http.sslCAInfo=/root/.ccr/ca-bundle.crt \
       clone --single-branch --depth 1 https://github.com/garrytan/gstack.git "$HOME/.claude/skills/gstack" >/dev/null 2>&1; then
    ( cd "$HOME/.claude/skills/gstack" && ./setup >/dev/null 2>&1 || true )
    # Bridge the pre-installed Chromium to the build gstack's Playwright expects.
    PWJSON="$HOME/.claude/skills/gstack/node_modules/playwright-core/browsers.json"
    if [ -f "$PWJSON" ]; then
      WANT=$(python3 -c "import json;print(next((b['revision'] for b in json.load(open('$PWJSON'))['browsers'] if b['name']=='chromium'),''))" 2>/dev/null)
      HAVE=$(ls -d /opt/pw-browsers/chromium-* 2>/dev/null | grep -oE '[0-9]+$' | sort -rn | head -1)
      if [ -n "$WANT" ] && [ -n "$HAVE" ] && [ "$WANT" != "$HAVE" ]; then
        ln -sfn "/opt/pw-browsers/chromium-$HAVE" "/opt/pw-browsers/chromium-$WANT"
        mkdir -p "/opt/pw-browsers/chromium_headless_shell-$WANT/chrome-headless-shell-linux64"
        ln -sfn "/opt/pw-browsers/chromium_headless_shell-$HAVE/chrome-linux/headless_shell" \
                "/opt/pw-browsers/chromium_headless_shell-$WANT/chrome-headless-shell-linux64/chrome-headless-shell" 2>/dev/null
        touch "/opt/pw-browsers/chromium_headless_shell-$WANT/INSTALLATION_COMPLETE" 2>/dev/null
      fi
    fi
  else LOG "gstack clone skipped"; fi
fi

LOG "done"
exit 0
