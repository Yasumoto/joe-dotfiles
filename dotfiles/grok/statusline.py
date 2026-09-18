#!/usr/bin/env python3
"""Grok Build status line.

stdin: one StatusLineContext JSON object (see xai-grok-status-line testdata).
stdout: 1-2 lines. Empty stdout hides the row, so this always prints a line.

`trigger=state` reads caches and the transcript tail. It does not call glab.
`trigger=refresh_interval` may call glab and the local auth scripts.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

RESET = "\x1b[0m"
GREY = "90"
RED = "31"
YELLOW = "33"
GREEN = "32"
CYAN = "36"
MAGENTA = "35"
BLUE = "34"
ORANGE = "38;5;208"

GITLAB_HOST = "git.int.n7k.io"
MAX_CHIPS = 12
AUTH_TTL_S = 60
GLAB_TIMEOUT_S = 3
AUTH_TIMEOUT_S = 2

URL_RE = re.compile(r"https://[^\s<>\"'\\]+")
MR_RE = re.compile(
    r"^https://git\.int\.n7k\.io/.+/-/merge_requests/(\d+)", re.IGNORECASE
)
SLACK_RE = re.compile(
    r"^https://(?:[A-Za-z0-9.-]+\.slack\.com|app\.slack\.com)/", re.IGNORECASE
)
GLASS_RE = re.compile(r"^https://glass\.int\.n7k\.io/d/([^/?#]+)", re.IGNORECASE)
JIRA_RE = re.compile(
    r"^https://[^/]+\.atlassian\.net/browse/([A-Z][A-Z0-9]+-\d+)", re.IGNORECASE
)
OSC_RE = re.compile(r"\x1b\]8;[^\x07]*\x07")
SGR_RE = re.compile(r"\x1b\[[0-9;]*m")

EFFORT = {
    "xhigh": "xH",
    "x-high": "xH",
    "extra-high": "xH",
    "high": "H",
    "medium": "M",
    "low": "L",
    "max": "max",
}


def paint(code: str, text: str) -> str:
    return f"\x1b[{code}m{text}{RESET}"


def link(url: str, label: str, code: str) -> str:
    if not url.startswith(("https://", "http://", "mailto:")):
        return paint(code, label)
    safe = url.replace("\x1b", "").replace("\x07", "")
    return f"\x1b]8;;{safe}\x07{paint(code, label)}\x1b]8;;\x07"


def visible_len(text: str) -> int:
    return len(SGR_RE.sub("", OSC_RE.sub("", text)))


def columns() -> int:
    try:
        width = int(os.environ.get("COLUMNS") or "80")
    except ValueError:
        width = 80
    return max(16, min(width, 500))


def cache_root() -> Path:
    override = os.environ.get("GROK_STATUSLINE_CACHE")
    path = Path(override) if override else Path.home() / ".cache" / "grok-statusline"
    path.mkdir(parents=True, exist_ok=True)
    return path


def read_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text())
    except (OSError, json.JSONDecodeError):
        return None


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(payload))
    os.replace(tmp, path)


def model_short(name: str) -> str:
    match = re.search(r"\d+\.\d+", name)
    if match:
        return match.group(0)
    return name[:12]


def truncate(text: str, limit: int) -> str:
    if len(text) <= limit:
        return text
    return text[: limit - 1] + "…"


def clean_url(url: str) -> str:
    return url.rstrip(".,);:\"'")


def chunk_text(update: dict[str, Any]) -> str:
    content = update.get("content")
    if isinstance(content, dict):
        meta = content.get("_meta") if isinstance(content.get("_meta"), dict) else {}
        display = meta.get("displayText")
        if isinstance(display, str) and display:
            return display
        text = content.get("text")
        return text if isinstance(text, str) else ""
    if isinstance(content, list):
        parts = []
        for block in content:
            if isinstance(block, dict) and isinstance(block.get("text"), str):
                parts.append(block["text"])
        return "\n".join(parts)
    return ""


def classify(url: str, slack_n: int) -> tuple[dict[str, Any] | None, int]:
    url = clean_url(url)
    mr = MR_RE.match(url)
    if mr:
        iid = mr.group(1)
        canonical = mr.group(0).rstrip("/")
        return {
            "kind": "mr",
            "key": f"mr:{iid}",
            "iid": iid,
            "label": f"!{iid}",
            "url": canonical,
            "color": CYAN,
        }, slack_n
    if SLACK_RE.match(url) and "/team/" not in url:
        slack_n += 1
        return {
            "kind": "slack",
            "key": f"slack:{url.split('?')[0]}",
            "label": f"s{slack_n}",
            "url": url,
            "color": MAGENTA,
        }, slack_n
    glass = GLASS_RE.match(url)
    if glass:
        uid = glass.group(1)
        return {
            "kind": "glass",
            "key": f"glass:{uid}",
            "label": "g/" + truncate(uid, 16),
            "url": url,
            "color": ORANGE,
        }, slack_n
    jira = JIRA_RE.match(url)
    if jira:
        key = jira.group(1)
        return {
            "kind": "jira",
            "key": f"jira:{key}",
            "label": key,
            "url": url,
            "color": BLUE,
        }, slack_n
    return None, slack_n


def harvest(path: str | None) -> list[dict[str, Any]]:
    if not path:
        return []
    transcript = Path(path)
    try:
        stat = transcript.stat()
    except OSError:
        return []
    digest = hashlib.sha256(str(transcript).encode()).hexdigest()[:16]
    store = cache_root() / "transcript" / f"{digest}.json"
    saved = read_json(store)
    if not isinstance(saved, dict):
        saved = None
    stamp = [stat.st_mtime_ns, stat.st_size]
    if saved and saved.get("stamp") == stamp and isinstance(saved.get("links"), list):
        return saved["links"]

    offset = 0
    links: list[dict[str, Any]] = []
    slack_n = 0
    if (
        saved
        and isinstance(saved.get("offset"), int)
        and isinstance(saved.get("size"), int)
        and saved["size"] <= stat.st_size
        and isinstance(saved.get("links"), list)
    ):
        offset = saved["offset"]
        links = list(saved["links"])
        slack_n = int(saved.get("slack_n") or 0)
    seen = {item.get("key") for item in links}

    try:
        with transcript.open("rb") as handle:
            handle.seek(offset)
            blob = handle.read()
    except OSError:
        return links
    if not blob.endswith(b"\n"):
        cut = blob.rfind(b"\n")
        if cut < 0:
            return links
        blob = blob[: cut + 1]
    new_offset = offset + len(blob)

    for raw in blob.splitlines():
        if b"user_message_chunk" not in raw and b"agent_message_chunk" not in raw:
            continue
        try:
            obj = json.loads(raw)
        except json.JSONDecodeError:
            continue
        update = (obj.get("params") or {}).get("update") if isinstance(obj, dict) else None
        if not isinstance(update, dict):
            continue
        if update.get("sessionUpdate") not in ("user_message_chunk", "agent_message_chunk"):
            continue
        meta = update.get("_meta") if isinstance(update.get("_meta"), dict) else {}
        if meta.get("hideFromScrollback"):
            continue
        text = chunk_text(update)
        if not text or text.startswith("<system-reminder"):
            continue
        for match in URL_RE.findall(text):
            chip, slack_n = classify(match, slack_n)
            if not chip or chip["key"] in seen:
                continue
            seen.add(chip["key"])
            links.append(chip)

    write_json(
        store,
        {
            "stamp": stamp,
            "size": stat.st_size,
            "offset": new_offset,
            "slack_n": slack_n,
            "links": links[-40:],
        },
    )
    return links[-40:]


def gitlab_key(data: dict[str, Any]) -> str:
    workspace = data.get("workspace") or {}
    repo = workspace.get("repo") or {}
    branch = workspace.get("branch") or ""
    host = repo.get("host") or ""
    owner = repo.get("owner") or ""
    name = repo.get("name") or ""
    root = workspace.get("repo_root") or data.get("cwd") or ""
    ident = f"{host}/{owner}/{name}" if host and name else root
    return f"{ident}@{branch}"


def repo_cwd(data: dict[str, Any]) -> str | None:
    workspace = data.get("workspace") or {}
    for candidate in (workspace.get("repo_root"), workspace.get("current_dir"), data.get("cwd")):
        if isinstance(candidate, str) and candidate and os.path.isdir(candidate):
            return candidate
    return None


def parse_mrs(text: str) -> list[Any]:
    payload = json.loads(text)
    if isinstance(payload, list):
        return payload
    if isinstance(payload, dict):
        for key in ("items", "merge_requests", "data"):
            value = payload.get(key)
            if isinstance(value, list):
                return value
    return []


def fetch_mr(branch: str, cwd: str | None) -> dict[str, Any] | None:
    """Return {mr: ...}|{mr: None} on a real answer, or None if glab failed."""
    try:
        proc = subprocess.run(
            ["glab", "mr", "list", "--source-branch", branch, "-F", "json"],
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=GLAB_TIMEOUT_S,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if proc.returncode != 0:
        return None
    try:
        mrs = parse_mrs(proc.stdout)
    except json.JSONDecodeError:
        return None
    if not mrs or not isinstance(mrs[0], dict):
        return {"mr": None}
    first = mrs[0]
    url = first.get("web_url") or first.get("webUrl")
    iid = first.get("iid")
    if not isinstance(url, str) or not url.startswith("https://") or iid is None:
        return {"mr": None}
    mr: dict[str, Any] = {"iid": iid, "url": url}
    pipe = first.get("head_pipeline") or first.get("headPipeline") or first.get("pipeline")
    if isinstance(pipe, dict):
        status = pipe.get("status")
        if isinstance(status, str):
            mr["pipeline_status"] = status
        purl = pipe.get("web_url") or pipe.get("webUrl")
        if isinstance(purl, str) and purl.startswith("https://"):
            mr["pipeline_url"] = purl
    return {"mr": mr}


def load_gitlab(data: dict[str, Any], trigger: str) -> dict[str, Any] | None:
    workspace = data.get("workspace") or {}
    repo = workspace.get("repo") or {}
    if repo.get("host") != GITLAB_HOST:
        return None
    branch = workspace.get("branch")
    if not isinstance(branch, str) or not branch:
        return None
    key = gitlab_key(data)
    path = cache_root() / "gitlab.json"
    saved = read_json(path)
    cached = saved if isinstance(saved, dict) and saved.get("key") == key else None
    # A busy turn re-runs this on every state change. Hit glab only when this
    # branch has no cache yet, or when the refresh timer fired.
    if trigger != "refresh_interval" and cached is not None:
        mr = cached.get("mr")
        return mr if isinstance(mr, dict) else None
    fresh = fetch_mr(branch, repo_cwd(data))
    if fresh is None:
        if cached is None:
            write_json(path, {"key": key, "mr": None})
        mr = (cached or {}).get("mr")
        return mr if isinstance(mr, dict) else None
    write_json(path, {"key": key, "mr": fresh.get("mr")})
    mr = fresh.get("mr")
    return mr if isinstance(mr, dict) else None


def run_auth(script: str) -> dict[str, Any] | None:
    path = Path.home() / ".claude" / script
    if not os.access(path, os.X_OK):
        return None
    try:
        proc = subprocess.run(
            [str(path), "--json"],
            capture_output=True,
            text=True,
            timeout=AUTH_TIMEOUT_S,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    line = (proc.stdout or "").strip().splitlines()
    if not line:
        return None
    try:
        payload = json.loads(line[-1])
    except json.JSONDecodeError:
        return None
    return payload if isinstance(payload, dict) else None


def load_auth(trigger: str) -> dict[str, Any]:
    path = cache_root() / "auth.json"
    saved = read_json(path)
    cached = saved if isinstance(saved, dict) else {}
    if trigger != "refresh_interval" and cached:
        return cached
    try:
        age = os.path.getmtime(path)
    except OSError:
        age = 0
    if cached and (time_now() - age) < AUTH_TTL_S:
        return cached
    fresh = {
        "at": time_now(),
        "aws": run_auth("aws-sso-status.sh") or cached.get("aws"),
        "k8s": run_auth("k8s-token-status.sh") or cached.get("k8s"),
    }
    write_json(path, fresh)
    return fresh


def time_now() -> float:
    return time.time()


def session_parts(data: dict[str, Any]) -> list[str]:
    parts: list[str] = []
    model = (data.get("model") or {}).get("display_name")
    if isinstance(model, str) and model:
        parts.append(model_short(model))
    level = ((data.get("effort") or {}).get("level") or "").lower()
    short = EFFORT.get(level)
    if short:
        parts.append(paint(GREY, short))
    window = data.get("context_window") or {}
    pct = window.get("used_percentage")
    if isinstance(pct, (int, float)):
        threshold = window.get("auto_compact_threshold_percent")
        if not isinstance(threshold, (int, float)) or threshold <= 0:
            threshold = 80
        code = YELLOW if pct >= threshold else None
        text = f"ctx:{int(pct)}%"
        parts.append(paint(code, text) if code else text)
    cost = (data.get("cost") or {}).get("total_cost_usd")
    if isinstance(cost, (int, float)) and cost >= 0.01:
        text = f"${cost:.2f}"
        parts.append(paint(ORANGE, text) if cost >= 0.50 else text)
    return parts


def repo_parts(data: dict[str, Any], mr: dict[str, Any] | None) -> list[str]:
    parts: list[str] = []
    workspace = data.get("workspace") or {}
    branch = workspace.get("branch")
    if isinstance(branch, str) and branch:
        parts.append(branch)
    name = (data.get("worktree") or {}).get("name")
    if isinstance(name, str) and name and name != branch:
        parts.append(paint(GREY, "wt:" + name))
    if mr and isinstance(mr.get("url"), str) and mr["url"].startswith("https://"):
        iid = mr.get("iid")
        if iid is not None:
            parts.append(link(mr["url"], f"!{iid}", CYAN))
        status = (mr.get("pipeline_status") or "").lower()
        glyph = {
            "success": "pass",
            "failed": "fail",
            "running": "run",
            "pending": "wait",
            "created": "wait",
            "canceled": "stop",
            "cancelled": "stop",
            "skipped": "stop",
        }.get(status)
        if glyph:
            code = {"success": GREEN, "failed": RED, "running": YELLOW}.get(status, GREY)
            purl = mr.get("pipeline_url")
            parts.append(link(purl, glyph, code) if isinstance(purl, str) else paint(code, glyph))
    return parts


def auth_parts(auth: dict[str, Any]) -> list[str]:
    parts: list[str] = []
    aws = auth.get("aws") if isinstance(auth.get("aws"), dict) else None
    if aws:
        status = aws.get("status")
        minutes = aws.get("expires_in_minutes")
        short = aws.get("short") or ""
        if status == "expired":
            parts.append(paint(RED, "aws:expired"))
        elif status == "ok" and isinstance(minutes, (int, float)) and minutes <= 30:
            label = f"aws:{short}" if short else f"aws:{int(minutes)}m"
            parts.append(paint(RED if minutes <= 10 else YELLOW, label))
    k8s = auth.get("k8s") if isinstance(auth.get("k8s"), dict) else None
    if k8s:
        status = k8s.get("status")
        # k8s-token-status.sh stores remaining seconds in expires_in_minutes.
        seconds = k8s.get("expires_in_minutes")
        short = str(k8s.get("short") or "")
        if status in ("auth-needed",) or short.upper() == "AUTH":
            parts.append(paint(RED, "k8s:AUTH"))
        elif status == "expired" or short == "expired":
            parts.append(paint(RED, "k8s:expired"))
        elif status == "ok" and isinstance(seconds, (int, float)) and 0 < seconds <= 3600:
            label = f"k8s:{short}" if short else f"k8s:{int(seconds // 60)}m"
            parts.append(paint(RED if seconds <= 900 else YELLOW, label))
    return parts


def chip_parts(links: list[dict[str, Any]], mr: dict[str, Any] | None) -> list[str]:
    current = str(mr.get("iid")) if mr and mr.get("iid") is not None else None
    chosen = []
    for item in links:
        if item.get("kind") == "mr" and current and str(item.get("iid")) == current:
            continue
        url = item.get("url")
        label = item.get("label")
        if not isinstance(url, str) or not isinstance(label, str):
            continue
        chosen.append(link(url, label, str(item.get("color") or CYAN)))
    extra = max(0, len(chosen) - MAX_CHIPS)
    shown = chosen[:MAX_CHIPS]
    if extra:
        shown.append(paint(GREY, f"+{extra}"))
    return shown


def fit_branch(parts: list[str], branch: str | None, width: int) -> list[str]:
    """Shrink the branch only when the whole row would overflow. A 32-char cap
    was cutting `…glass-aud` down to `…glass-` on a wide terminal."""
    if not isinstance(branch, str) or branch not in parts:
        return parts

    def total(items: list[str]) -> int:
        if not items:
            return 0
        return sum(visible_len(item) for item in items) + len(items) - 1

    if total(parts) <= width:
        return parts
    others = total(parts) - len(branch)
    room = width - others
    if room < 8:
        return parts
    short = truncate(branch, room)
    return [short if item == branch else item for item in parts]


def pack(parts: list[str], width: int) -> list[str]:
    lines: list[str] = []
    current: list[str] = []
    used = 0
    for part in parts:
        gap = 1 if current else 0
        need = visible_len(part) + gap
        if current and used + need > width:
            lines.append(" ".join(current))
            if len(lines) >= 5:
                return lines
            current = [part]
            used = visible_len(part)
            continue
        current.append(part)
        used += need
    if current and len(lines) < 5:
        lines.append(" ".join(current))
    return lines or ["grok"]


def build(data: dict[str, Any]) -> list[str]:
    trigger = data.get("trigger") or "state"
    mr = load_gitlab(data, str(trigger))
    auth = load_auth(str(trigger))
    groups = [
        session_parts(data),
        repo_parts(data, mr),
        auth_parts(auth),
    ]
    parts: list[str] = []
    for group in groups:
        if not group:
            continue
        if parts:
            parts.append(paint(GREY, "│"))
        parts.extend(group)
    parts.extend(chip_parts(harvest(data.get("transcript_path")), mr))
    branch = (data.get("workspace") or {}).get("branch")
    width = columns()
    return pack(fit_branch(parts, branch if isinstance(branch, str) else None, width), width)


def main() -> int:
    raw = sys.stdin.read()
    try:
        data = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError:
        return 0
    if not isinstance(data, dict):
        return 0
    try:
        lines = build(data)
    except Exception:
        lines = ["statusline"]
    sys.stdout.write("\n".join(lines) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
