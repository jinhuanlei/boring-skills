#!/usr/bin/env python3
"""Self-check for the tracking-window cap (see analyze.capped_days_since)."""
from analyze import capped_days_since

DAY = 86400_000

def test_caps_at_tracking_window_when_installed_long_before_logging():
    now = 200 * DAY
    installed = 0          # installed 200d ago
    tracking_since = 190 * DAY  # but logging only started 10d ago
    assert capped_days_since(now, installed, tracking_since) == 10

def test_uses_install_age_when_tracking_predates_install():
    now = 200 * DAY
    installed = 150 * DAY  # installed 50d ago
    tracking_since = 0     # logging existed the whole time
    assert capped_days_since(now, installed, tracking_since) == 50

if __name__ == "__main__":
    test_caps_at_tracking_window_when_installed_long_before_logging()
    test_uses_install_age_when_tracking_predates_install()
    print("ok")


def test_strip_usage_lens():
    from setup import strip_usage_lens
    hooks = {
        "UserPromptSubmit": [{"hooks": [
            {"command": "python /x/usage-lens/scripts/prompt_hook.py"},
        ]}],
        "PostToolUse": [
            {"matcher": "Bash", "hooks": [{"command": "atuin hook claude-code"}]},
            {"matcher": "Skill", "hooks": [{"command": "python /x/usage-lens/scripts/post_tool_hook.py"}]},
        ],
    }
    strip_usage_lens(hooks)
    assert "UserPromptSubmit" not in hooks, "empty event must be removed"
    assert len(hooks["PostToolUse"]) == 1, "unrelated hooks must survive"
    assert hooks["PostToolUse"][0]["matcher"] == "Bash"
    strip_usage_lens(hooks)  # idempotent
    assert len(hooks["PostToolUse"]) == 1
