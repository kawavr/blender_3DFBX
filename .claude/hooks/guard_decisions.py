#!/usr/bin/env python3
"""PreToolUse guard (WORKFLOW.md §14): AI must not mark a decision as Accepted.

Blocks Edit/Write/MultiEdit on docs/decisions/* when
  - the new content sets `status: Accepted`, or
  - the file on disk is already Accepted (accepted decisions are changed by humans only).
Exit 2 = block (stderr is shown to the model). Bash can bypass this; CODEOWNERS is the real enforcement.
"""
import json
import os
import re
import sys

ACCEPTED = re.compile(r"^status:\s*Accepted\b", re.MULTILINE)


def main() -> int:
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0
    ti = data.get("tool_input") or {}
    path = ti.get("file_path") or ""
    if not path:
        return 0
    project = os.environ.get("CLAUDE_PROJECT_DIR") or data.get("cwd") or os.getcwd()
    rel = os.path.relpath(os.path.abspath(path), os.path.abspath(project))
    if not rel.replace(os.sep, "/").startswith("docs/decisions/"):
        return 0

    try:
        with open(path, encoding="utf-8") as f:
            current = f.read()
    except FileNotFoundError:
        current = ""

    if ACCEPTED.search(current):
        print("BLOCKED: this decision is Accepted; changes require a human (gate G8). "
              "Write a new Proposed ADR that supersedes it instead.", file=sys.stderr)
        return 2

    # Simulate the resulting file so partial edits (e.g. "Proposed" -> "Accepted") are caught.
    if "content" in ti:
        new_text = str(ti.get("content") or "")
    else:
        new_text = current
        edits = ti.get("edits") or [{"old_string": ti.get("old_string", ""),
                                     "new_string": ti.get("new_string", ""),
                                     "replace_all": ti.get("replace_all", False)}]
        for e in edits:
            if not isinstance(e, dict):
                continue
            o, n = str(e.get("old_string") or ""), str(e.get("new_string") or "")
            if o and o in new_text:
                new_text = new_text.replace(o, n) if e.get("replace_all") else new_text.replace(o, n, 1)
            else:
                new_text += "\n" + n  # cannot simulate; check the inserted text conservatively
    if ACCEPTED.search(new_text):
        print("BLOCKED: only a human may set `status: Accepted` on a decision (WORKFLOW.md §14). "
              "Leave it as Proposed and request approval.", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
