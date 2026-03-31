# Skills

Collection of agent skills for Claude Code, Codex, etc. See [AGENTS.md](AGENTS.md) for rules.

## Available Skills

| Skill | Description |
|-------|-------------|
| [oracle](oracle/) | Second-opinion analysis via GPT-5.3-codex — planning, debugging, code review |

## Installation

### Via the Skills CLI

The easiest way to install is with the [Skills CLI](https://github.com/vercel-labs/skills):

```bash
npx skills add cookavich/skills -a claude-code -g
```

Use `--list` to browse available skills first, or `--skill oracle` to install a specific one.

### Manual

Clone the repo, then symlink individual skills into your Claude Code personal skills directory:

```bash
git clone https://github.com/cookavich/skills.git && cd skills
ln -s "$(pwd)/oracle" ~/.claude/skills/oracle
```

Claude Code automatically discovers skills in `~/.claude/skills/`. Once linked, the skill is available as a slash command (e.g. `/oracle`) in every session across all projects. Changes to the source are picked up immediately.
