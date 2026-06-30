<!-- SKILLS_POLICY_START -->
## Skills & tools — use them proactively

Use the installed skills and MCP servers **proactively** whenever they improve the result — **even when the user didn't explicitly ask**. Just tell the user which skill/tool you activated and why (one line). The user has authorized this as a standing rule.

Reach for the right capability by task:

- **Understand / navigate / refactor code** → CodeGraph (`codegraph_explore`) or graphify. For `index.html` (single-file SPA, JS not parseable in HTML), use the extracted code graph: `/home/user/ayitimarket-graph/` — rebuild with its `refresh.sh`; line numbers map back to `index.html` (app block starts ~line 3628, second block ~line 12280).
- **Real backend / schema / data** → the **Supabase MCP** (`mcp__supabase__*`, read-only, scoped to project `htxfwxldzaocuwezzbom`). Prefer it over guessing from `supabase/*.sql`.
- **New UI or visual redesign** → `ui-ux-pro-max`, `frontend-design`, Magic (`mcp__magic__*`).
- **Before building a feature** → `brainstorming` → `writing-plans` → `test-driven-development`.
- **Debugging** → `systematic-debugging`.
- **Test the real app** → gstack `/browse`, `/qa` (the Vercel preview needs the protection-bypass header).
- **Marketplace growth (Kreyòl)** → `cro`, `pricing`, `onboarding`, `copywriting`, `ads`, `seo-audit`.
- **Cross-session memory** → agentmemory (`remember` / `recall` / `handoff`).
- **Before claiming done / shipping** → `verification-before-completion`, then `/ship`.

Honor the project's hard rules (single-file architecture, Kreyòl strings, soft-delete, escrow RPC) — see the `ayitimarket` skill.
<!-- SKILLS_POLICY_END -->

<!-- GSTACK_START -->
## gstack

For **all web browsing**, use the `/browse` skill from gstack. **Never** use `mcp__claude-in-chrome__*` tools.

Available gstack skills:
/office-hours, /plan-ceo-review, /plan-eng-review, /plan-design-review, /design-consultation, /design-shotgun, /design-html, /review, /ship, /land-and-deploy, /canary, /benchmark, /browse, /connect-chrome, /qa, /qa-only, /design-review, /setup-browser-cookies, /setup-deploy, /setup-gbrain, /retro, /investigate, /document-release, /document-generate, /codex, /cso, /autoplan, /plan-devex-review, /devex-review, /careful, /freeze, /guard, /unfreeze, /gstack-upgrade, /learn

> Teammates: install gstack once to enable these skills:
> ```
> git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack && cd ~/.claude/skills/gstack && ./setup
> ```
<!-- GSTACK_END -->
