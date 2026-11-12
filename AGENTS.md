# Local preferences

- On Windows, prefer Git Bash for shell commands. Use
  `C:/Program Files/Git/bin/bash.exe` with `login: false` when available.
- Use PowerShell only when a Windows-specific task requires it, and explain why.
- Before requesting command approval, explain the command's purpose in plain
  Russian and describe any persistent prefix permission being requested.

# Discuss, approve, then implement

- For new tasks, first reason about the request and propose a concrete solution
  in Russian. Explain the intended result, the main changes, and how correctness
  will be checked. Ask for the user's comments or agreement, then stop before
  implementation. Read-only investigation needed to ground the proposal is OK.
- Treat feedback as input for a revised proposal, not as approval to implement.
  Repeat discussion until the user explicitly agrees to the proposed solution.
- Once the user agrees, implement the agreed scope autonomously, including
  necessary verification and routine fixes. Do not repeatedly ask to proceed.
- Ask again only when a material change of direction, scope, or consequences
  needs the user's decision, or when a required permission cannot be avoided.
- Minimize command approval prompts by using available tools, existing narrow
  permissions, and commands within the workspace. Never bypass required
  approvals or request broad persistent permissions just to reduce prompts.
- Finish with what changed, how it was verified, and any remaining limitations.
- If the user explicitly asks to execute immediately without discussion, follow
  that instruction for the task.
