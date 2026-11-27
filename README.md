# boring-skills

A personal collection of agent skills I use across my own coding sessions. Each skill lives under `skills/<name>/` and installs via the `skills` CLI into any agent that discovers skills there.

Works with Claude Code, opencode, Cursor, and any agent that reads `AGENTS.md` or `CLAUDE.md`.

---

## Catalog

| Skill | Description | Docs |
|-------|-------------|------|
| [auto-learnings](./skills/auto-learnings) | Cross-session memory: captures corrections, preferences, project facts, and debug insights so future sessions remember without re-explaining. | [Guide](./docs/skills/auto-learnings.md) |
| [usage-lens](./skills/usage-lens) | Tracks which skills you actually invoke via hooks, then surfaces usage patterns and inactive-skill recommendations. | [Guide](./docs/skills/usage-lens.md) |
| [skill-healthcheck](./skills/skill-healthcheck) | Audits installed skills for health problems and duplicates, then removes named skills only after checking what depends on them. | — |

---

## Install

Install with [`skills`](https://www.npmjs.com/package/skills) — no clone, no manual symlinking:

```sh
# install specific skills globally
npx skills add jinhuanlei/boring-skills -g -s auto-learnings,usage-lens

# install everything globally
npx skills add jinhuanlei/boring-skills -g --all
```

Drop `-g` to install into the current project instead. Use `npx skills add jinhuanlei/boring-skills -l` to list available skills without installing.

Some skills need one-time setup after installing — check the individual guide.

---

## Docs

- [`docs/skills/`](./docs/skills/) — per-skill guides (commands, config, storage)
- [`docs/specs/`](./docs/specs/) — design specs for skills in development
