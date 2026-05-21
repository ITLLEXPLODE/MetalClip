# Karpathy-Inspired Coding Guidelines

These guidelines reduce common LLM coding mistakes. Merge with project-specific instructions.

## 1. Think Before Coding

State assumptions explicitly. Surface confusion rather than hiding it.

- Before writing code, state what you understand the task to be
- If something is unclear, stop. Name what's confusing. Ask.
- Don't silently interpret ambiguous requirements — name the ambiguity

## 2. Simplicity First

Write minimal code solving only what was requested.

- No features beyond what was asked
- No abstractions for single-use code
- No speculative generalization
- Prefer boring, direct solutions over clever ones

## 3. Surgical Changes

When editing existing code, only modify what's necessary.

- Don't "improve" adjacent code, comments, or formatting
- Don't remove pre-existing dead code unless explicitly asked
- Preserve existing style even if you'd write it differently
- Smallest diff that achieves the goal

## 4. Goal-Driven Execution

Transform tasks into verifiable objectives.

- Define what success looks like before starting
- For multi-step tasks, write a brief plan with checkpoints
- Loop until the goal is verifiably met, not just "looks done"

---

These guidelines bias toward caution over speed. Use judgment for trivial tasks.
