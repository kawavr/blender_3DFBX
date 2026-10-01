# CLAUDE.md

This file is loaded by every Claude Code session in this repository. Full workflow: `docs/ai-workflow/WORKFLOW.md` (the authoritative source; this file is a summary).

## Project

Blender add-on / tooling for 3D FBX. <!-- TODO(human): describe architecture, entry points, supported Blender versions, how to run tests -->

Checks used as evidence: `scripts/ai/checks.txt` (run via `scripts/ai/run-checks.sh <task_id>`).

## Roles (one role per session)

| Model | Role | Stages | Prompt |
|---|---|---|---|
| Claude Opus 5.5 | Architect | SPEC, ESCALATION, ARBITRATION, INVESTIGATION, FINAL_REVIEW | `docs/ai-workflow/prompts/opus-architect.md` (`/ai-spec`, `/ai-escalation`) |
| Claude Sonnet 5.5 (default) | Implementer | IMPL, LOCAL_VERIFY, FIX, experiments | `docs/ai-workflow/prompts/sonnet-implementer.md` (`/ai-impl`) |
| GPT-6 Astra (Codex) | Independent auditor | REVIEW, INVESTIGATION, external spec research | `docs/ai-workflow/prompts/astra-review.md` (not run from Claude Code) |
| Human | Orchestrator & approver | TRIAGE, SPEC_GATE, MERGE_GATE, all gates G1–G9 | — |

If you are not sure which role/stage you are in: read `tasks/<id>/task.yaml` (`current_stage`, `owner`). If it is not your stage, say `NOT_MY_STAGE` and stop.

Normal path: **simple tasks → Sonnet alone; hard decisions → Opus; finished code → Astra audit.**

## Rules that always apply

1. **Work only on a task.** Every change belongs to `tasks/<task_id>/` with a `task.yaml`. Stay inside `allowed_scope`; respect `forbidden_scope`.
2. **One task = one branch (`ai/<task_id>`) = one worktree (`../wt/<task_id>`) = one owner at a time.** Never edit another task's worktree. Never edit the same worktree as another agent.
3. **No delegation.** Do not start subagents or call other models. Finish your stage, print the stage report, stop. The human decides the next stage.
4. **No spec changes.** You may not change acceptance criteria, scope, limits or approvals. Propose via `tasks/<id>/escalations.md`.
5. **Accepted Decisions are human-only.** ADRs you write in `docs/decisions/` are `status: Proposed`. Never set `Accepted` (a hook blocks it).
6. **Rationale goes to `tasks/<id>/log.md`**, not to code comments or commit messages (the reviewer must judge the code without your reasoning).
7. **Never delete, skip, xfail or weaken a failing test** to get green.
8. **Dependencies**: no add/upgrade/remove outside `dependencies.packages_allowed_to_add` (gate G6).
9. **Git**: no force-push, `reset --hard`, rebase or amend after the first review round. Small commits: `spec|test|feat|fix|refactor|evidence(<task_id>): ...`.

## Escalate to Opus (stop and record ESC-n) when

E1 requirement contradicts code structure · E2 architecture change needed · E3 public API change · E4 file format / persistence / schema change · E5 dependency change · E6 security-critical decision · E7 same failure not fixed after 3 attempts · E8 scope grows beyond `allowed_scope` or ~2× estimate · E9 acceptance criteria insufficient or contradictory.
Do **not** escalate local implementation details; decide them and note in log.md.

## Loop prevention

- Same failure: max 3 fix attempts → E7. Task: max 12 check runs. Review: max 2 Astra rounds.
- Every change must trace to an AC id, a review finding id, or a failing check in an evidence log. No "just in case" work.
- Do not re-test a REFUTED hypothesis without citing new evidence. Do not re-read unchanged files in the same session.
- When exit criteria are met: report and stop. Out-of-scope observations → one line in `follow_ups`, not acted on.
- "There is more I could check" is not a reason to continue.

## Evidence and completion

Statuses: `VERIFIED` · `PARTIALLY_VERIFIED` · `IMPLEMENTED_UNVERIFIED` · `BLOCKED` · `HYPOTHESIS` (`REFUTED` for hypotheses).

- "Tests pass" requires an evidence log from `scripts/ai/run-checks.sh` whose commit matches the current code. Cite its path.
- "Fixed" means: the check that failed before (evidence A) passes after (evidence B). Cite both.
- Anything not executed is `IMPLEMENTED_UNVERIFIED`. Say so explicitly.
- End every stage with the stage report (WORKFLOW.md §12.4): AC table with status + evidence, `unverified:` line, scope statement, `follow_ups`.

## Human gates (AI proposes, human decides)

G1 architecture · G2 breaking public/external API (incl. operator names, properties, output file compatibility) · G3 persistence format / migration · G4 credentials / auth · G5 destructive operations · G6 dependency add/major/remove · G7 CI / release / infra · G8 spec / ADR / this workflow · G9 raising loop limits or skipping Astra review.
