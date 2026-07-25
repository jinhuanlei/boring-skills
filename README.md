# boring-skills

A personal collection of agent skills I use across my own coding sessions. Each skill lives under `skills/<name>/` and is symlinked into `~/.claude/skills/` so any agent that discovers skills there picks it up.

Works with Claude Code, opencode, Rovo Dev, Cursor, and any agent that reads `AGENTS.md` or `CLAUDE.md`.

---

## Catalog

| Skill | Description | Docs |
|-------|-------------|------|
| [auto-learnings](./skills/auto-learnings) | Cross-session memory: captures corrections, preferences, project facts, and debug insights so future sessions remember without re-explaining. | [Guide](./docs/skills/auto-learnings.md) |
| [usage-lens](./skills/usage-lens) | Tracks which skills you actually invoke via hooks, then surfaces usage patterns and inactive-skill recommendations. | [Guide](./docs/skills/usage-lens.md) |
| [skill-cleaner](./skills/skill-cleaner) | Audits installed skills for health problems and duplicates, then removes named skills only after checking what depends on them. | — |

---

## Install

Each skill is a directory with a `SKILL.md` and optional `scripts/`. Symlink it into `~/.claude/skills/`:

```sh
# clone the repo
git clone https://github.com/jinhuanlei/boring-skills.git ~/boring-skills

# symlink whichever skills you want
ln -s ~/boring-skills/skills/auto-learnings ~/.claude/skills/auto-learnings
ln -s ~/boring-skills/skills/usage-lens     ~/.claude/skills/usage-lens
```

Some skills need one-time setup after symlinking — check the individual guide.

---

## Docs

- [`docs/skills/`](./docs/skills/) — per-skill guides (commands, config, storage)
- [`docs/specs/`](./docs/specs/) — design specs for skills in development
