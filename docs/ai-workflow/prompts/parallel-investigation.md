# Difficult bug: independent root-cause investigation

This same prompt is given separately to Claude Opus 5.5 and GPT-6 Astra. Neither sees the other's output.

---

You are one of two independent investigators. Another investigator receives the same material. You will not see their answer, and they will not see yours. Do not try to be comprehensive by listing every conceivable cause; produce a small number of falsifiable hypotheses with evidence.

## Inputs

- `problem.md` — observed facts only: symptoms, reproduction steps, logs, environment, frequency, recent changes
- `src/` — source snapshot at the commit where the problem is observed
- `evidence/` — any existing logs / failing test output (may be empty)

You must not modify `src/`. You may create a scratch copy to run experiments. Do not invoke other agents.

## Budget

- At most 5 hypotheses.
- Stop when you have produced the output below. Do not keep exploring because "more could be checked".
- If you cannot reproduce and cannot narrow the cause, say so; that is a valid result.

## Output (Markdown, exactly this structure)

```markdown
# Investigation: <task_id> — investigator: <opus|astra>
snapshot: <sha>

## Observations I verified myself
- <fact> — how verified (command + output excerpt, or file:line)

## Hypotheses
### H-<investigator>-1
- statement: <one sentence root cause>
- mechanism: <causal chain from trigger to symptom, with file:line>
- supporting evidence: <facts above that support it>
- contradicting evidence: <facts that do not fit, or "none found">
- reproduction conditions: <when it occurs / does not occur>
- falsification: <experiment whose result would refute this hypothesis>
- minimal reproducer: <smallest script/test; code block; state whether executed>
- fix direction: <approach, not a full patch>; risk of the fix
- confidence: high | medium | low
- status: HYPOTHESIS | CONFIRMED (only if you executed a reproducer that isolates the cause)

## Ranking and why
## What I could not determine, and what data would settle it
```

Rules:
- `CONFIRMED` requires an executed reproducer whose output you include. Otherwise `HYPOTHESIS`.
- Do not include a full patch. Implementation is done by a separate implementer after hypotheses are tested.
- Prefer hypotheses that can be distinguished from each other by a single experiment.
