# Codex Context Guide

Use this folder as optional context. Do not load every file for every task.

Recommended pattern:

1. Always rely on the small root `AGENTS.md` for global rules.
2. Load `repo_map.md` when you need orientation.
3. Load a focused subsystem file only when the task touches that subsystem.
4. Open full source files only when they are directly edited or directly explain the bug.

Suggested task prompt shape:

```text
Use AGENTS.md and docs/context/repo_map.md only for orientation.
For this task, inspect only the directly relevant files first.
Do not run tools/tests; static review only.
Do not provide generic test cases at the end.
```
