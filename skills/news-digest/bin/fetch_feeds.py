#!/usr/bin/env python3
"""news-digest の収集部（決定的・LLM 不要・stdlib のみ）。

feeds.json の RSS/Atom を並列取得し、既読 (state/news-digest/seen.json) を除いた
新着アイテムを JSON で stdout に出す。判断（スコアリング・選別・要約）は
SKILL.md に従って agent が行う。

usage:
  fetch_feeds.py [--hours 26] [--dry-run] [--max-per-feed 20]

  --dry-run     seen.json を更新しない（テスト用）
  出力は state/news-digest/last_fetch.json にも保存される
  （agent turn が失敗して再実行するときはそちらを読めばよい）
"""
import argparse
import json
import sys
import urllib.request
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timedelta, timezone
from email.utils import parsedate_to_datetime
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parent.parent
STATE_DIR = Path.home() / "openclaw-workspace" / "state" / "news-digest"
UA = "Mozilla/5.0 (compatible; news-digest/1.0; personal use)"
SEEN_KEEP = 3000

ATOM = "{http://www.w3.org/2005/Atom}"


def text(el):
    return (el.text or "").strip() if el is not None else ""


def parse_date(s):
    if not s:
        return None
    for fn in (parsedate_to_datetime,
               lambda v: datetime.fromisoformat(v.replace("Z", "+00:00"))):
        try:
            dt = fn(s)
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)
            return dt
        except (ValueError, TypeError):
            continue
    return None


def parse_feed(raw):
    """RSS2/RDF/Atom を大雑把に吸収して item の list を返す。"""
    # XXE / billion-laughs 対策: DTD を含むフィードは拒否する（正当な RSS/Atom に DTD は不要）
    head = raw[:4096].upper()
    if b"<!DOCTYPE" in head or b"<!ENTITY" in head:
        raise ValueError("feed contains DTD/ENTITY; rejected for safety")
    root = ET.fromstring(raw)
    items = []
    if root.tag == f"{ATOM}feed":  # Atom
        for e in root.findall(f"{ATOM}entry"):
            link = ""
            for l in e.findall(f"{ATOM}link"):
                if l.get("rel") in (None, "alternate"):
                    link = l.get("href", "")
                    break
            items.append({
                "title": text(e.find(f"{ATOM}title")),
                "link": link,
                "published": parse_date(text(e.find(f"{ATOM}published"))
                                        or text(e.find(f"{ATOM}updated"))),
            })
    else:  # RSS 2.0 / RDF 1.0
        for i in root.iter():
            if i.tag.endswith("item"):
                d = {"title": "", "link": "", "published": None}
                for c in i:
                    tag = c.tag.split("}")[-1]
                    if tag == "title":
                        d["title"] = text(c)
                    elif tag == "link":
                        d["link"] = text(c) or c.get("href", "")
                    elif tag in ("pubDate", "date"):
                        d["published"] = parse_date(text(c))
                items.append(d)
    return items


def fetch_one(feed, cutoff, max_per_feed):
    req = urllib.request.Request(feed["url"], headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=20) as r:
        raw = r.read()
    out = []
    for it in parse_feed(raw):
        if not it["link"] or not it["title"]:
            continue
        # published 不明のフィードは新着扱いにする（seen で重複は防げる）
        if it["published"] and it["published"] < cutoff:
            continue
        out.append({
            "title": it["title"],
            "link": it["link"],
            "published": it["published"].isoformat() if it["published"] else None,
            "source": feed["name"],
            "category": feed["category"],
        })
    return out[:max_per_feed]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--hours", type=int, default=26)
    ap.add_argument("--max-per-feed", type=int, default=20)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    feeds_conf = json.loads((SKILL_DIR / "feeds.json").read_text())
    feeds = [{**f, "category": cat}
             for cat, fs in feeds_conf["categories"].items() for f in fs]

    STATE_DIR.mkdir(parents=True, exist_ok=True)
    seen_path = STATE_DIR / "seen.json"
    seen = json.loads(seen_path.read_text()) if seen_path.exists() else []
    seen_set = set(seen)

    cutoff = datetime.now(timezone.utc) - timedelta(hours=args.hours)
    items, failed = [], []
    with ThreadPoolExecutor(max_workers=8) as ex:
        futs = {ex.submit(fetch_one, f, cutoff, args.max_per_feed): f for f in feeds}
        for fut in as_completed(futs):
            f = futs[fut]
            try:
                items.extend(fut.result())
            except Exception as e:  # noqa: BLE001 - フィード単位で握って報告
                failed.append({"name": f["name"], "url": f["url"],
                               "error": f"{type(e).__name__}: {e}"})

    fresh = [it for it in items if it["link"] not in seen_set]
    fresh.sort(key=lambda x: (x["category"], x["published"] or ""), reverse=False)

    if not args.dry_run:
        seen_path.write_text(json.dumps(
            (seen + [it["link"] for it in fresh])[-SEEN_KEEP:], indent=0))

    result = {
        "fetched_at": datetime.now(timezone.utc).isoformat(),
        "window_hours": args.hours,
        "feeds_total": len(feeds),
        "feeds_failed": failed,
        "item_count": len(fresh),
        "items": fresh,
    }
    out = json.dumps(result, ensure_ascii=False, indent=1)
    if not args.dry_run:
        (STATE_DIR / "last_fetch.json").write_text(out)
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
