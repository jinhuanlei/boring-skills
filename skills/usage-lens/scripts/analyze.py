#!/usr/bin/env python3
"""Analyze usage-lens.jsonl and emit JSON. Consumed by the SKILL.md."""
import argparse, json, os, sys, time
from collections import defaultdict
from datetime import datetime, timezone

DEFAULTS = {
    "log_path": "~/.claude/usage-lens.jsonl",
    "inactive_threshold_days": 30,
    "trend_window_days": 30,
}

def load_config():
    try:
        with open(os.path.expanduser("~/.config/usage-lens/config.json")) as f:
            return {**DEFAULTS, **json.load(f)}
    except Exception:
        return dict(DEFAULTS)

def installed_skills():
    skills = {}
    try:
        with open(os.path.expanduser("~/.agents/.skill-lock.json")) as f:
            for name, meta in json.load(f).get("skills", {}).items():
                skills[name] = meta.get("installedAt")
    except Exception:
        pass
    try:
        d = os.path.expanduser("~/.claude/skills")
        for name in os.listdir(d):
            if name not in skills and os.path.isdir(os.path.join(d, name)):
                skills[name] = None
    except Exception:
        pass
    return skills

def load_events(log_path, since_ms=None, event_type=None):
    events = []
    try:
        with open(os.path.expanduser(log_path)) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    e = json.loads(line)
                    if event_type and e.get("type") != event_type:
                        continue
                    if since_ms and e.get("ts", 0) < since_ms:
                        continue
                    events.append(e)
                except Exception:
                    pass
    except FileNotFoundError:
        pass
    return events

def iso_to_ms(iso):
    if not iso:
        return None
    try:
        dt = datetime.fromisoformat(iso.replace("Z", "+00:00"))
        return dt.timestamp() * 1000
    except Exception:
        return None

def capped_days_since(now_ms, installed_ms, tracking_since_ms):
    """Days since install, capped by how far back the log actually observed."""
    return int(min(now_ms - installed_ms, now_ms - tracking_since_ms) / 86400000)

def compute_trend(name, all_events, window_ms):
    now_ms = time.time() * 1000
    recent = sum(1 for e in all_events if e.get("name") == name and e.get("ts", 0) >= now_ms - window_ms)
    prior = sum(1 for e in all_events if e.get("name") == name and now_ms - 2 * window_ms <= e.get("ts", 0) < now_ms - window_ms)
    if recent < 3 and prior < 3:
        return "flat"
    if prior == 0:
        return "up" if recent > 0 else "flat"
    pct = (recent - prior) / prior
    return "up" if pct > 0.2 else "down" if pct < -0.2 else "flat"

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--json", action="store_true")
    p.add_argument("--type", default=None)
    p.add_argument("--days", type=int, default=30)
    p.add_argument("--all", dest="all_time", action="store_true")
    args = p.parse_args()

    cfg = load_config()
    log_path = cfg["log_path"]
    inactive_days = cfg["inactive_threshold_days"]
    trend_window_days = cfg["trend_window_days"]

    now_ms = time.time() * 1000
    period_ms = args.days * 86400 * 1000
    since_ms = None if args.all_time else now_ms - period_ms
    trend_window_ms = trend_window_days * 86400 * 1000

    period_events = load_events(log_path, since_ms=since_ms, event_type=args.type)
    all_events = load_events(log_path, since_ms=now_ms - 2 * trend_window_ms)

    installed = installed_skills()

    counts = defaultdict(int)
    last_ts: dict = {}
    for e in period_events:
        name = e.get("name", "")
        if not name:
            continue
        counts[name] += 1
        ts = e.get("ts", 0)
        if name not in last_ts or ts > last_ts[name]:
            last_ts[name] = ts

    all_names = sorted(set(counts) | set(installed))
    skills_out = []
    for name in all_names:
        skills_out.append({
            "name": name,
            "count": counts.get(name, 0),
            "last_ts": last_ts.get(name),
            "installed_at": installed.get(name),
            "trend": compute_trend(name, all_events, trend_window_ms),
        })

    all_log_ts = [e.get("ts", 0) for e in load_events(log_path)]
    tracking_since_ms = min(all_log_ts) if all_log_ts else now_ms

    recs = []
    threshold_ms = inactive_days * 86400 * 1000
    for s in skills_out:
        installed_ms = iso_to_ms(s["installed_at"])
        if s["count"] == 0 and installed_ms and (now_ms - installed_ms) > threshold_ms:
            days_since = capped_days_since(now_ms, installed_ms, tracking_since_ms)
            recs.append({"name": s["name"], "reason": "inactive", "detail": f"not used in {days_since}d"})
        elif s["trend"] == "down":
            recent = sum(1 for e in all_events if e.get("name") == s["name"] and e.get("ts", 0) >= now_ms - trend_window_ms)
            prior = sum(1 for e in all_events if e.get("name") == s["name"] and now_ms - 2 * trend_window_ms <= e.get("ts", 0) < now_ms - trend_window_ms)
            recs.append({"name": s["name"], "reason": "declining", "detail": f"was {prior}/mo, now {recent}/mo"})

    print(json.dumps({
        "period_days": None if args.all_time else args.days,
        "total_events": len(period_events),
        "skills": skills_out,
        "recommendations": recs,
    }, indent=2))

if __name__ == "__main__":
    main()
