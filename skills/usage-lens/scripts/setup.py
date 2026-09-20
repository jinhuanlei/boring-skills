#!/usr/bin/env python3
"""Idempotent setup: merge usage-lens hooks into settings.json and create default config."""
import json, os, sys

SETTINGS = os.path.expanduser("~/.claude/settings.json")
CONFIG_DIR = os.path.expanduser("~/.config/usage-lens")
CONFIG_FILE = os.path.join(CONFIG_DIR, "config.json")
HOOK_BASE = os.path.expanduser("~/.claude/skills/usage-lens/scripts")

# ponytail: sys.executable, not bare "python" — macOS ships python3 only.
NEW_HOOKS = {
    "UserPromptSubmit": [{
        "hooks": [{"type": "command", "command": f"{sys.executable} {HOOK_BASE}/prompt_hook.py"}]
    }],
    "PostToolUse": [{
        "matcher": "Skill",
        "hooks": [{"type": "command", "command": f"{sys.executable} {HOOK_BASE}/post_tool_hook.py"}]
    }],
}

DEFAULT_CONFIG = {
    "verbosity": "standard",
    "log_path": "~/.claude/usage-lens.jsonl",
    "inactive_threshold_days": 30,
    "trend_window_days": 30,
    "cleanup_keep_days": 90,
}

def strip_usage_lens(hooks):
    """Remove every usage-lens hook from a settings hooks dict, in place."""
    for event in list(hooks):
        for entry in hooks[event]:
            entry["hooks"] = [
                h for h in entry.get("hooks", [])
                if "usage-lens" not in h.get("command", "")
            ]
        hooks[event] = [e for e in hooks[event] if e.get("hooks")]
        if not hooks[event]:
            del hooks[event]
    return hooks

def merge_hooks():
    try:
        with open(SETTINGS) as f:
            settings = json.load(f)
    except FileNotFoundError:
        settings = {}
    else:
        with open(SETTINGS + ".bak", "w") as f:
            json.dump(settings, f, indent=2)

    # ponytail: strip then re-add, so stale entries (bare `python`, moved paths)
    # get migrated instead of duplicated.
    hooks = strip_usage_lens(settings.setdefault("hooks", {}))
    for event, entries in NEW_HOOKS.items():
        hooks.setdefault(event, []).extend(entries)

    with open(SETTINGS, "w") as f:
        json.dump(settings, f, indent=2)
    print(f"  hooks configured: {', '.join(NEW_HOOKS)}")
    print(f"  interpreter: {sys.executable}")

def create_config():
    if os.path.exists(CONFIG_FILE):
        print(f"  config already exists: {CONFIG_FILE}")
        return
    os.makedirs(CONFIG_DIR, exist_ok=True)
    with open(CONFIG_FILE, "w") as f:
        json.dump(DEFAULT_CONFIG, f, indent=2)
    print(f"  config created: {CONFIG_FILE}")

def check_symlink():
    link = os.path.expanduser("~/.claude/skills/usage-lens")
    if os.path.exists(link) or os.path.islink(link):
        print(f"  symlink exists: {link}")
    else:
        print(f"  WARNING: symlink missing — run:")
        print(f"    ln -s /path/to/boring-skills/skills/usage-lens {link}")

if __name__ == "__main__":
    print("usage-lens setup")
    merge_hooks()
    create_config()
    check_symlink()
    print("done.")
