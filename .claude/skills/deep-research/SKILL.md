---
name: deep-research
description: >
  Run iterative, multi-source deep research on a topic using the built-in WebSearch and
  WebFetch tools (no API keys, no paid services). Generates targeted queries, reads real
  sources, distills cited learnings, then recurses on the open questions before writing a
  structured Markdown report with a Sources section. Use this whenever the user wants to
  genuinely investigate something rather than get a quick answer: "deep research", "recherche
  approfondie", "research this thoroughly", "investigate", "market research", "competitive
  landscape", "explore X from multiple angles", "find everything about", "état de l'art",
  "veille sur", or any question where one web search is clearly not enough and the stakes
  justify reading several sources. For AyitiMarket this is the tool for market sizing,
  competitor scans, MonCash/payment options, diaspora e-commerce trends, and growth-channel
  research. Do NOT use it for a single factual lookup, a definition, coding help, or reading
  one known URL — answer those directly. It replaces paid deep-research apps (Firecrawl/OpenAI
  based ones) at zero cost by using the agent's own tools.
---

# Deep Research

Reproduce the "deep research" pattern (iterative query → read → learn → recurse → report)
using only the built-in `WebSearch` and `WebFetch` tools. No external service, no API key,
no cost. The point is depth: instead of answering from a single search, you widen (breadth)
and deepen (depth) until the picture is solid, always grounding claims in sources you
actually fetched.

## When this is worth it

Deep research spends real tool calls (each WebFetch reads a page). Use it when the answer
matters enough to read 5–20 sources: a market decision, a competitor scan, a "should we"
question with money attached. For a quick fact, just search once and answer — don't convene
the whole machine.

## Parameters

Two knobs control cost and thoroughness. Infer sensible defaults from the request; only ask
the user if the scope is genuinely unclear.

- **breadth** — how many distinct search queries per level (how wide you cast the net).
- **depth** — how many times you recurse into follow-up questions (how deep you dig).

Modes (a shorthand the user can invoke, e.g. "deep-research X, quick"):

| Mode      | breadth | depth | Rough source count | Use for |
|-----------|---------|-------|--------------------|---------|
| quick     | 2       | 1     | ~4–6               | a fast scan, one sitting |
| standard  | 3–4     | 2     | ~10–15             | the default |
| deep      | 4–5     | 3     | ~20–30             | a big decision, a full landscape |

Breadth typically **halves at each deeper level** (e.g. 4 → 2 → 1): the first level maps the
territory, deeper levels chase only the most important open threads.

## Procedure

### Step 0 — Frame the question

Restate the topic in one sharp sentence and pin down what a *useful* answer looks like. If
the request is vague or high-stakes and you can't tell the angle (audience, geography, time
frame, decision at hand), ask **one** focused round of questions via AskUserQuestion, then
proceed. For AyitiMarket, default the lens to **Haiti + the Haitian diaspora** and surface
the Kreyòl/local angle where it matters, unless told otherwise.

Keep a running research state as you go:
- **learnings** — a growing list of concise, factual takeaways, each tagged with its source URL(s).
- **visited** — URLs already fetched (never fetch the same URL twice).
- **questions** — open follow-up questions surfaced by what you've read.

### Step 1 — Generate queries (breadth)

From the topic (plus any learnings/questions carried in from a previous level), write
`breadth` **distinct, targeted** search queries. Make them specific and non-overlapping —
each should attack a different facet (size, players, pricing, regulation, trends, risks…).
Vague queries waste fetches. When the subject is local, include location and, where useful,
Kreyòl or French terms alongside English, since sources may be in any of the three.

### Step 2 — Search and select

For each query, run `WebSearch`. From the results, pick the **2–3 most credible and
on-topic** links. Prefer primary sources, recognized institutions, official docs, and recent
dates over content farms and SEO spam. Skip anything already in `visited`.

### Step 3 — Read and distill

`WebFetch` each selected URL with a prompt that pulls out exactly what this research needs
(pass the framed question into the fetch prompt so the extraction is targeted, not generic).
From each page, add:
- 1–5 **learnings**: specific, information-dense, quantified where possible (numbers, dates,
  names), each carrying its source URL. Prefer surprising or decision-relevant facts.
- any new **follow-up questions** the page opens up.

Add every fetched URL to `visited`. If a fetch returns a cross-host redirect, follow it once
with a second WebFetch to the redirect URL.

### Step 4 — Recurse (depth)

If `depth > 0` and meaningful questions remain: pick the strongest follow-up questions, set
`breadth = max(1, breadth / 2)`, `depth = depth - 1`, and go back to Step 1 using those
questions as the new seeds. Stop early when new fetches stop yielding fresh learnings — depth
is a budget, not a quota. Diminishing returns are the signal to write the report.

### Step 5 — Synthesize the report

Deduplicate and organize the learnings into a coherent narrative, not a link dump. Every
non-obvious claim must trace to a source in the list. Call out disagreements between sources
and note where evidence is thin rather than papering over gaps. Match the user's language
(Kreyòl/French/English) in the prose.

Save the report to `research/<slug>-<YYYY-MM-DD>.md` (create `research/` if missing) and tell
the user the path. For a small "answer" request, an inline answer plus sources is fine — skip
the file.

## Report structure

Use this template (trim sections that don't apply):

```markdown
# Deep Research: [Topic]
_Date: YYYY-MM-DD · Mode: [quick/standard/deep] · Sources: N_

## TL;DR
3–6 bullet points with the decision-relevant conclusions.

## Key findings
Organized by theme. Each claim cites its source inline like [1], [2].

## Open questions / gaps
What remains uncertain or unverified, and what would resolve it.

## Recommendation (if a decision was implied)
The "so what" for the user's actual situation.

## Sources
[1] Title — URL
[2] Title — URL
```

## Notes and limits

- **Cost is fetches.** Each fetched page is a WebFetch call. Respect the mode's budget; if you
  blow past it, say so.
- **No paywalled/authenticated pages** — WebFetch fails on those. Route around them with
  other sources rather than guessing their contents.
- **Recency matters.** Prefer recent sources for fast-moving topics and note publication dates.
- **Don't fabricate.** If the web didn't say it, it doesn't go in the report. An honest "sources
  are thin here" beats a confident guess.
- This is research, not translation or analysis-for-its-own-sake. Hand the report to the next
  step (e.g. a `claude-council` pressure-test, or a Kreyòl rewrite for AyitiMarket content).
