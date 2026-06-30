---
name: altitude
description: Scope and right-size a new feature BEFORE building it. Scrapes the repo for grounding, sets left/right guardrails with one sharp AskUserQuestion batch, uncovers the true job, then pins the feature to its correct depth — neither over- nor under-engineered — and emits a reviewable Scope Decision Record that says what to build, exactly how deep, which files to touch, and what NOT to build. Use when about to add a feature and unsure of the best approach or how deep to go, or any time scope/altitude is ambiguous.
argument-hint: <the feature you want to add>
author: jncoppeta
metadata:
  hermes:
    tags: [scoping, planning, feature, right-sizing, intent]
    category: engineering
---

# Altitude

Altitude decides the *altitude* of a feature — how deep to build it — before any code is written. It grounds itself in the real repo, draws the left/right guardrails with the fewest sharp questions, excavates the true job behind the request, and pins the feature to its correct depth using checkable heuristics anchored in the repo's own history. Output is a **Scope Decision Record**: what to build, exactly how deep, which files (cited), and what NOT to build — then it hands the chosen depth to `plan`.

The problem it solves: "I want to add a feature but don't know the best way, and can't tell what is too in-depth and what is not." Altitude turns that judgment call into a defensible, grounded decision.

## Request

$ARGUMENTS

If non-empty, that is the feature to scope. If empty, infer the feature from the conversation. Either way, run the pipeline below.

## When to use / when NOT

Use when adding a feature where the right approach or depth is unclear, scope is ambiguous, or a "small" change might secretly be large.

Do NOT run the full pipeline on trivial work — Phase 0 fast-paths it. Bias to the full pipeline only on genuine ambiguity.

## Core principles (do not violate)

- **Ground before asking.** Every question option must cite a real file/pattern found in the scrape — never a generic vibe.
- **Code-first.** Resolve every open decision from the codebase before asking the user; only ask what the code genuinely cannot settle.
- **Depth is decided, not felt.** Depth is a grounded ladder pick or a costed-bracket choice, always re-checked by the heuristics (and conditionally by adversarial graders) — never an agent's gut call.
- **Hard caps.** ≤4 questions per batch, ≤2 question batches total, ≤20 files in the scrape, ≤2 re-grades. Stop on the explicit stop condition, not on "feeling confident."
- **Floor-bias under ambiguity.** When scope stays unstated, recommend the shallowest rung that clears the under-engineering line — never default to the ceiling.
- **Nothing silent.** Every cut element lands on a visible Deferred list; every unaddressed blast-radius node lands on a Deepen list.

---

## Phase 0 — Triage & fast-path gate

Capture the raw request verbatim. Classify it:

- **trivial / clear-and-local / single-file-unambiguous** → skip the pipeline. State a one-line plan and hand straight to `plan` (or implement). Zero questions.
- **non-trivial / ambiguous / multi-file / any cross-cutting or new-data-source signal** → enter the full pipeline.

Bias HARD to "full" on any ambiguity — a deceptively-large request fast-pathing out is the exact failure this skill exists to prevent. Set `is_solution_shaped = true` if the request prescribes a *solution* ("add a Redis cache") rather than a *job* ("make the dashboard load faster") — it pre-arms the Phase 4 intent probe.

## Phase 1 — Ground scrape + tier-precedent mining

Spawn a **read-only** subagent (Agent tool, `subagent_type: Explore`) so heavy reads stay out of this context. Instruct it to be a compass, not an encyclopedia — **hard 20-file cap, depth-1 imports**. It must return:

1. **Repo map + closest sibling** — the existing feature most like the request (e.g. for "add a network view," the nearest existing view).
2. **Extension/insertion points** cited as `file:line` — where the sibling registers, dispatches, documents itself.
3. **Conventions** — naming, env-var prefix, error/fallback idiom, doc-pairing (e.g. README + help text updated together).
4. **Tier precedents mined from git.** Run `git log --stat` on the 2-3 most feature-like commits and derive the repo's *own* blast-radius tiers from their diffstats — e.g. Tier A (pure re-render: ~1 function + dispatch), Tier B (cross-cutting: new source across modules + adapters), Tier C (refined source: collector + fallback). These are the depth budget, anchored in this repo, not generic S/M/L.
5. **Convention-fit checklist** — the concrete nodes any feature of this kind must touch.

Rules: **ground claims in code, not docs** (a manifest may lie about platform support). If git history is too thin to calibrate tiers, set `tiers_uncalibrated = true`, fall back to generic Floor/Standard/Ceiling, and say so to the user.

Output → `RealityModel`.

## Phase 2 — Candidates + decision-slot ledger

Reason in **solution space before question space**.

1. Draft **2-4 concrete candidate builds** at different altitudes (Floor / Standard / Ceiling), each grounded in the scrape's real touchpoints, each with a predicted blast-radius set and a tier.
2. For every **decision slot** (each parameter where builds could differ), resolve from the codebase first via a targeted just-in-time read. Tag each slot:
   - `SPECIFIED` (a fact) — settled.
   - `INFERABLE` (code settles it) → becomes a **stated assumption**, surfaced in the read-back, **not** a question.
   - `UNKNOWN-finite` / `UNKNOWN-open` — candidate questions.
   - Mark each slot `load-bearing` if it splits the candidate set.
3. Only `UNKNOWN + load-bearing + build-SPLITTING` slots survive as **question-eligible**. A slot whose every answer leaves the same candidate set standing is **never asked**.

Output → `ScopeLadder` (Floor→Ceiling candidates, each a cited deliverable + touch-set + tier) and `SlotLedger` (tagged slots, stated assumptions, the short eligible-question list ranked by expected information gain).

## Phase 3 — Guardrail questions (one AskUserQuestion batch)

**ONE** batch via AskUserQuestion, **≤4 questions**, MECE options each grounded in a real file/pattern, each with an "Other / let me explain" escape hatch, ranked by expected value of information.

Ask-vs-infer (both gates must pass, else infer a default and **state it**):
- Gate 1: ≥2 genuinely viable builds for this axis.
- Gate 2: forward-simulate each branch — the outputs materially differ.

Question order:
- **Q1 — Scope-ladder pick.** Floor / Standard / Ceiling as concrete, cited deliverables. One pick sets BOTH left/right guardrails and captures the depth decision cheaply.
- **Q2 — Tier-confirm.** "Reads as a Tier-A re-render vs a Tier-B new data source — which?" Catches the "new view secretly needs a new metric" trap at question time, not at a late gate.
- **Q3 — Non-goals.** Explicit out-of-scope.
- **Q4 — Highest remaining EVPI load-bearing slot** (data model / surface / edge cases), if one survives.

**Hybrid depth:** the Q1 ladder pick is the default depth surface. Render a side-by-side **costed bracket** (Phase 6) only when the feature is **Tier-B/C or intent confidence is low** — those are the cases where the user genuinely cannot judge scope.

Output → `GuardrailSpec` {chosen rung, confirmed tier, Must/Should buckets, explicit non_goals[], reuse-vs-new-abstraction, stated_assumptions[]}.

## Phase 4 — Intent refinement + Socratic read-back

Fire **one** Jobs-to-be-Done what/how probe **only** when `is_solution_shaped` OR the ladder pick conflicts with the code-implied tier. **Never ask "why"** (it invites rationalized, misleading answers). Recover the job as **verb + objective** ("confirm a deploy succeeded without reading logs").

Before settling, **generate the counter-interpretation** (confirmation-bias guard): if the ask looks oversized, ladder one rung down; if a slot is still underspecified, one rung up. Cap ~3 rungs.

Close with a **Socratic read-back** — a compact spec that mirrors back every inferred-not-asked assumption:

> "I'll build **X** at rung **Y**, touching **Z** (`file:line`), assuming **A / B / C**, non-goals **N**. Right?"

The user confirms or corrects in one turn. A correction triggers at most **one** final batch (hard cap **≤2 batches total**). Intent counts as uncovered only when the read-back is accepted AND the chosen candidate survives Phase 5 against the stated job.

Output → `IntentSpec` {job_statement, resolved_slots, counter_interpretation_checked, non_goals, read_back_confirmed}.

## Phase 5 — Scope-fit gate

Build a per-element **Scope-Fit Ledger** for the chosen candidate, scoring each element against the heuristics below.

Then, **conditionally**, run the adversarial panel:
- **Tier-A two-way-door** features (re-renders, internal helpers): certified by heuristics + read-back alone. **Skip the graders.**
- **Tier-B/C or any one-way-door element** (schema, wire contract, platform branch, new source, auth): spawn **3 fresh** subagents (Agent tool, `subagent_type: general-purpose`) in parallel, each with a **distinct lens**:
  1. Prosecute **OVER-engineered for the confirmed tier/job**.
  2. Prosecute **UNDER-engineered** (missing convention nodes, fallbacks, doc-pairing).
  3. Neutral **gold-plating / trace** judge (anything tracing to nothing).

Quorum: a verdict survives only with a valid quorum AND over-votes < 2 AND under-votes < 2. **Abstain/null NEVER counts as pass** — all-abstain means "needs more grounding" → loop back to Phase 1. On OVER → drop one rung & re-grade. On UNDER → raise one rung. Hard cap **≤2 re-grades**.

Auto-generate:
- **Deferred list** — every element with `traces_to = NONE`.
- **Deepen list** — every predicted blast-radius node left unaddressed (e.g. a new source missing OS-switch+fallback, an un-updated README/help text).

Output → `ScopeFitLedger` (one card per element {element, traces_to, tier, door, over_signals[], under_signals[], verdict: right|cut|deepen}) + surviving rung + Deferred list + Deepen list.

### Grader prompt (per lens)

> You are grading a proposed feature build for SCOPE FIT, through ONE lens only: **{OVER | UNDER | GOLD-PLATING}**.
> The confirmed job: `{job_statement}`. The confirmed tier: `{tier}`. The chosen build + cited touch-set: `{candidate}`. The repo's tier precedents + convention checklist: `{RealityModel}`.
> Prosecute your lens hard. For OVER: name every element that exceeds what the confirmed tier/job needs. For UNDER: name every convention node or blast-radius node inside the tier's envelope that the build fails to touch. For GOLD-PLATING: name every element that traces to no Must/Should/job.
> If you cannot ground a complaint in a cited file or the checklist, ABSTAIN on it — do not invent. Return {verdict: over|under|fit|abstain, flagged_elements[], rationale}.

## Phase 6 — Scope Decision Record → plan

Render the **Scope Decision Record**:

```
JOB:            <verb + objective>
DEPTH:          <chosen rung> — <why this rung>
TOUCHPOINTS:    <file:line each> — follow pattern <sibling>
NON-GOALS:      <explicit out-of-scope>
DEFERRED/COULD: <over-scope elements cut>
DEEPEN:         <under-scope nodes that must be covered>
VERDICTS:       <grader results, if run>
ACCEPTANCE:     <checklist proving the job is done>
PLAN MODE:      exact | exploration
```

**Costed bracket (only on Tier-B/C or low intent confidence):** additionally render, via the `lavish` skill, a side-by-side Floor/Std/Ceiling comparison — deliverable, files-touched/blast-radius, and a Build/Delay/Carry/Repair cost ledger — with the recommended **Floor** marked and "extra depth is a paid choice" framing, so the user picks depth with eyes open. (If lavish is unavailable or its poll stalls, fall back to native AskUserQuestion.)

**Handoff:** on approval, hand the chosen rung straight to built-in `plan` (Exact if settled, Exploration if not). Keep `run`/`verify` as explicit opt-in — do not auto-run.

---

## Scope heuristics — the calibration engine ("how deep is too deep")

1. **Tier-mismatch (headline detector).** `confirmed_tier == code_implied_tier?` A mismatch is the #1 over/under flag and forces the intent probe (e.g. user picks Floor "add a view" but the data needs a new collector → silently under-scoped).
2. **Blast-radius containment.** Every element must sit inside the chosen tier's predicted touch-set. Outside the envelope → OVER. A convention node inside the envelope left unaddressed → UNDER (→ Deepen list).
3. **Convention-fit.** Any new data source / platform branch MUST carry the fallback idiom every sibling has → missing = UNDER. New persistent/stateful machinery is earned only by a metric that needs it → adding it for a static value = OVER.
4. **Rule-of-three (countable YAGNI).** Extract an abstraction only at ≥3 *current* instances, counted in the scrape — not imagined. <3 = OVER.
5. **Zero-consumer / no-bottleneck.** Any config/flag/param with zero current consumers = OVER. Any optimization without a measured bottleneck = OVER (Knuth).
6. **Gold-plating trace test.** Every shipped element must trace to a Must/Should bucket or the job. `traces_to = NONE` → auto-Deferred, never silently built.
7. **Reversibility door.** One-way (schema, wire/public contract, platform branch, auth) → earns deeper design + an ADR-warrant + tests. Two-way (internal helper, re-render, copy) → simplest thing that works. When stuck on a one-way door, prefer cheaply converting it to two-way (flag/version) BEFORE paying for depth.
8. **YAGNI exemptions.** Refactoring, tests, and malleability/readability are EXEMPT — never cut for depth. Stakes-bearing / one-way-door code keeps its tests and error-handling even at the Floor.
9. **Floor-bias under ambiguity.** When scope stays unstated after the question cap, recommend the shallowest rung clearing the UNDER line — never the Ceiling. If still ambiguous, salvage-return naming the unresolved slots rather than guessing high.

## Anti-patterns

- Don't ask any question before grounding in the codebase.
- Don't resolve depth by feeling; it's a grounded pick re-checked by heuristics (+ conditional graders).
- Don't loop until "confident" — stop on the slot-resolution + EVPI + ≤2-batch cap.
- Don't run the full pipeline on trivial changes.
- Don't let abstain/null count as pass; all-abstain → loop back to the scrape.
- Don't self-certify; graders are fresh subagents with distinct lenses.
- Don't default to the Ceiling under ambiguity.
- Don't cut refactoring/tests/malleability under YAGNI; don't keep zero-consumer config.
- Don't trust docs over code.
- Don't ask "why" in the intent probe.
- Don't silently drop deferred scope or unaddressed blast-radius nodes.
- Don't run the 3-grader gate on a Tier-A two-way-door re-render.
