# Shared agent skills

Edit skills only in `.claude/skills/`. These are the canonical, tracked files for
Claude Code, Codex, and Cursor. The three workflow skills are `create-pr`,
`create-pr-for-issue`, and `merge-pr`.

Each `.agents/skills/<name>` is a tracked relative symbolic link to
`../../.claude/skills/<name>`. Codex discovers that directory; Cursor can discover
both `.agents/skills/` and `.claude/skills/`. Both paths resolve to the same files,
so there is no copying or synchronization step. Preserve symlinks when cloning
or exporting this repository. The old `.claude/commands/merge-pr.md` was replaced
by the canonical merge skill; do not recreate it as a second definition.

Claude reads the canonical skills directly. Codex reads the linked entry points.
Cursor's duplicate-entry display across both supported roots depends on its
version; check its skill picker after reload. There are no independent duplicate
skill bodies in this repository. An on-disk link check does not prove a running
client has refreshed its picker. Restart/reload a client if discovery is stale.

Use the active tool's shell/session and file-editing APIs. For a fresh-context
review, Claude can use `general-purpose`; Codex and Cursor use their available
subagent tools. Do not carry one tool's argument names into another tool's calls.
The workflow requirements (review, gate, issue linkage, squash merge, cleanup)
are shared. Global project instructions remain in `AGENTS.md`.

## Hooks and local configuration

Skills are instructions; hooks are executable tool configuration. They are not
interchangeable. Keep `.claude/settings.json` separate from any Codex or Cursor
hook configuration. Personal settings and runtime state should stay local.

The existing local, untracked `.codex/hooks.json` calls the same tracked
`scripts/hooks/guard_bash_hygiene.sh` used by Claude. Current Codex documentation
supports the `PreToolUse`/`Bash` matcher and `tool_input.command` payload used by
that script. Its relative command path works from the repo root but does not
resolve from nested working directories. This skill-sharing change does not
modify or track that local hook file or enable hooks in any client. Hook loading
also requires the client's feature/trust configuration; script tests alone do
not establish that a running client enforces the hook.

## References

- [Codex skill discovery](https://learn.chatgpt.com/docs/build-skills)
- [Claude skill discovery](https://code.claude.com/docs/en/skills)
- [Cursor skill discovery](https://prod.cursor.com/help/customization/skills)
- [Codex hooks and working-directory behavior](https://learn.chatgpt.com/docs/hooks)
