#!/usr/bin/env python3
"""
canvas_fetcher.py
-----------------
Fetches course materials from Canvas LMS.
Usage: python canvas_fetcher.py "SEN-109" --hours 10
       python canvas_fetcher.py "SEN-109" --hours 10 --include-assignment-files

Fetch only part of a course (filters can be combined):
       python canvas_fetcher.py "SEN-109" --list                     # show module names
       python canvas_fetcher.py "SEN-109" --module "Week 3"          # one module
       python canvas_fetcher.py "SEN-109" --search "Lab3"            # names containing text
       python canvas_fetcher.py "SEN-109" --only files,pages         # some content types
       python canvas_fetcher.py "SEN-109" --since 2026-10-01         # changed since a date
"""

import os
import sys
import json
import argparse
import requests
from pathlib import Path
from datetime import datetime, timezone

OUTPUT_DIR = Path("course-materials")
CONTENT_TYPES = ["syllabus", "modules", "assignments", "pages", "files"]

# Set from the command line in main(). An empty filter lets everything through.
FILTERS = {"modules": [], "search": "", "since": None, "only": set(CONTENT_TYPES)}
# When --module is used, only content linked from the matching modules is kept.
ALLOWED = None   # {"files": set(ids), "pages": set(urls), "assignments": set(ids)}
# Every file this run saved (or found already saved), relative to the course folder
FETCHED = []
DEST_DIR = None

def record(path: Path):
    FETCHED.append(str(path.relative_to(DEST_DIR)))

def get_config():
    token = os.getenv("CANVAS_TOKEN", "").strip()
    url   = os.getenv("CANVAS_URL", "https://canvas.instructure.com").rstrip("/")
    if not token:
        print("❌ CANVAS_TOKEN is empty or not set.")
        print("   Check your .env file contains: CANVAS_TOKEN=your_token_here")
        sys.exit(1)
    return token, url

def get(endpoint, params=None):
    token, canvas_url = get_config()
    headers = {"Authorization": f"Bearer {token}"}
    url = f"{canvas_url}/api/v1{endpoint}"
    results = []
    while url:
        r = requests.get(url, headers=headers, params=params)
        r.raise_for_status()
        data = r.json()
        if isinstance(data, list):
            results.extend(data)
        else:
            return data
        url = None
        if "next" in r.links:
            url = r.links["next"]["url"]
            params = None
    return results

def download_file(url, dest: Path):
    record(dest)
    if dest.exists():
        print(f"  [skip] {dest.name}")
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    token, _ = get_config()
    headers  = {"Authorization": f"Bearer {token}"}
    r = requests.get(url, headers=headers, stream=True)
    r.raise_for_status()
    with open(dest, "wb") as f:
        for chunk in r.iter_content(chunk_size=8192):
            f.write(chunk)
    print(f"  [✓] {dest.name}")

def parse_date(value):
    """Canvas dates look like 2026-10-01T08:00:00Z. Returns None if missing."""
    if not value:
        return None
    return datetime.fromisoformat(value.replace("Z", "+00:00"))

def wanted(name, updated_at=None, kind=None, key=None):
    """True if an item passes the --search, --since and --module filters."""
    if FILTERS["search"] and FILTERS["search"] not in (name or "").lower():
        return False
    if FILTERS["since"]:
        when = parse_date(updated_at)
        if when and when < FILTERS["since"]:
            return False
    if ALLOWED is not None and kind and key not in ALLOWED[kind]:
        return False
    return True

def find_course(keyword: str):
    courses = get("/courses", params={"enrollment_state": "active", "per_page": 50})
    kw = keyword.lower()
    matches = [c for c in courses
               if kw in c.get("name","").lower()
               or kw in c.get("course_code","").lower()]
    if not matches:
        print(f"No course found matching '{keyword}'. Available:")
        for c in courses:
            print(f"  - {c.get('course_code','')} | {c.get('name','')}")
        sys.exit(1)
    # Prefer an exact course-code match, and say so if the keyword was ambiguous
    exact = [c for c in matches if c.get("course_code","").lower() == kw]
    if len(matches) > 1:
        print(f"⚠  '{keyword}' matches {len(matches)} courses:")
        for c in matches:
            print(f"  - {c.get('course_code','')} | {c.get('name','')}")
        print("   Using the first one. Pass the full course code to pick another.")
    course = (exact or matches)[0]
    print(f"\n📚 Course: {course['name']} (ID: {course['id']})")
    return course

def fetch_files(course_id, dest_dir: Path):
    print("\n📂 Fetching course files...")
    params = {"per_page": 100}
    if len(FILTERS["search"]) >= 2:
        params["search_term"] = FILTERS["search"]   # let Canvas narrow it down first
    files = get(f"/courses/{course_id}/files", params=params)
    kept = 0
    for f in files:
        name = f.get("display_name", f.get("filename", "file"))
        url  = f.get("url")
        if url and wanted(name, f.get("updated_at"), "files", f.get("id")):
            download_file(url, dest_dir / "files" / name)
            kept += 1
    print(f"  {kept} of {len(files)} file(s) matched")

def fetch_pages(course_id, dest_dir: Path):
    print("\n📄 Fetching pages...")
    params = {"per_page": 100}
    if len(FILTERS["search"]) >= 2:
        params["search_term"] = FILTERS["search"]
    pages = get(f"/courses/{course_id}/pages", params=params)
    for p in pages:
        slug   = p.get("url", "page")
        if not wanted(p.get("title", slug), p.get("updated_at"), "pages", slug):
            continue
        detail = get(f"/courses/{course_id}/pages/{slug}")
        body   = detail.get("body", "")
        title  = detail.get("title", slug)
        out    = dest_dir / "pages" / f"{slug}.txt"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(f"# {title}\n\n{body}", encoding="utf-8")
        record(out)
        print(f"  [✓] {title}")

def fetch_syllabus(course_id, dest_dir: Path):
    print("\n📋 Fetching syllabus...")
    detail   = get(f"/courses/{course_id}", params={"include[]": "syllabus_body"})
    syllabus = detail.get("syllabus_body", "")
    if syllabus:
        out = dest_dir / "syllabus.txt"
        out.write_text(f"# Syllabus\n\n{syllabus}", encoding="utf-8")
        record(out)
        print("  [✓] syllabus.txt")
    else:
        print("  [!] No syllabus found")

def fetch_assignments(course_id, dest_dir: Path):
    print("\n📝 Fetching assignments...")
    assignments = get(f"/courses/{course_id}/assignments", params={"per_page": 100})
    assignments = [a for a in assignments
                   if wanted(a.get("name"), a.get("updated_at"), "assignments", a.get("id"))]
    summary = []
    for a in assignments:
        summary.append({
            "id":          a.get("id"),
            "name":        a.get("name"),
            "due_at":      a.get("due_at"),
            "points":      a.get("points_possible"),
            "description": (a.get("description") or "")[:2000],
            "submission_types": a.get("submission_types", []),
            "has_attachments": bool(a.get("attachments", [])),
        })
    out = dest_dir / "assignments.json"
    out.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    record(out)
    print(f"  [✓] {len(summary)} assignments saved")
    return assignments

def fetch_assignment_files(course_id, assignments, dest_dir: Path):
    """
    Fetch files attached directly to assignment pages —
    separate from the general Files section.
    """
    print("\n📎 Fetching assignment attachments...")
    project_dir = dest_dir / "project"
    project_dir.mkdir(parents=True, exist_ok=True)
    fetched = 0

    for a in assignments:
        aid   = a.get("id")
        aname = a.get("name", f"assignment_{aid}")
        # Sanitise name for folder
        safe  = "".join(c if c.isalnum() or c in " -_" else "_" for c in aname)

        # 1. Attachments directly on the assignment object
        for att in a.get("attachments", []):
            url  = att.get("url")
            name = att.get("display_name", att.get("filename", "file"))
            if url:
                download_file(url, project_dir / safe / name)
                fetched += 1

        # 2. Try fetching the assignment detail for any linked files
        try:
            detail = get(f"/courses/{course_id}/assignments/{aid}")
            for att in detail.get("attachments", []):
                url  = att.get("url")
                name = att.get("display_name", att.get("filename", "file"))
                if url:
                    download_file(url, project_dir / safe / name)
                    fetched += 1
        except Exception:
            pass

    if fetched == 0:
        print("  [!] No assignment attachments found on Canvas.")
        print("      If your professor uploaded starter files to the Files")
        print("      section instead, they are already in files/ above.")
        print("      Otherwise use --mode local to drop files manually.")
    else:
        print(f"  [✓] {fetched} attachment(s) saved to project/")

def fetch_modules(course_id, dest_dir: Path):
    print("\n🗂  Fetching modules...")
    modules   = get(f"/courses/{course_id}/modules",
                    params={"include[]": "items", "per_page": 100})
    if FILTERS["modules"]:
        modules = matching_modules(modules)
    structure = [{"module": m.get("name"),
                  "items": [{"title": i.get("title"), "type": i.get("type")}
                             for i in m.get("items", [])]}
                 for m in modules]
    out = dest_dir / "modules.json"
    out.write_text(json.dumps(structure, indent=2), encoding="utf-8")
    record(out)
    print(f"  [✓] {len(modules)} modules saved")

def matching_modules(modules):
    """Modules whose name contains any of the --module keywords."""
    keys = [m.lower() for m in FILTERS["modules"]]
    return [m for m in modules if any(k in m.get("name","").lower() for k in keys)]

def list_modules(course_id):
    print("\n🗂  Modules in this course:")
    for m in get(f"/courses/{course_id}/modules", params={"per_page": 100}):
        print(f"  - {m.get('name')}  ({m.get('items_count', '?')} items)")
    print('\nFetch one with:  --module "<part of the name>"')

def collect_module_content(course_id):
    """Work out which files, pages and assignments the chosen modules link to."""
    modules = get(f"/courses/{course_id}/modules",
                  params={"include[]": "items", "per_page": 100})
    chosen = matching_modules(modules)
    if not chosen:
        print(f"No module matches {FILTERS['modules']}. Available:")
        for m in modules:
            print(f"  - {m.get('name')}")
        sys.exit(1)
    allowed = {"files": set(), "pages": set(), "assignments": set()}
    for m in chosen:
        print(f"  ✓ Module: {m.get('name')}")
        # Big modules don't inline their items, so fetch them separately
        items = m.get("items")
        if items is None:
            items = get(f"/courses/{course_id}/modules/{m['id']}/items",
                        params={"per_page": 100})
        for i in items:
            if i.get("type") == "File":
                allowed["files"].add(i.get("content_id"))
            elif i.get("type") == "Page":
                allowed["pages"].add(i.get("page_url"))
            elif i.get("type") == "Assignment":
                allowed["assignments"].add(i.get("content_id"))
    print(f"  → {len(allowed['files'])} file(s), {len(allowed['pages'])} page(s), "
          f"{len(allowed['assignments'])} assignment(s)")
    return allowed

def write_manifest(dest_dir: Path, course, hours, include_assignment_files):
    manifest = {
        "course_name":             course.get("name"),
        "course_code":             course.get("course_code"),
        "study_hours":             hours,
        "fetched_assignment_files": include_assignment_files,
        # Tells the agent when only part of the course was fetched
        "filters": {
            "modules": FILTERS["modules"],
            "search":  FILTERS["search"],
            "since":   FILTERS["since"].date().isoformat() if FILTERS["since"] else None,
            "only":    [c for c in CONTENT_TYPES if c in FILTERS["only"]],
        },
        # Exactly what this run fetched. The folder may also hold older downloads.
        "fetched": FETCHED,
    }
    out = dest_dir / "manifest.json"
    out.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"\n✅ Manifest written → {out}")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("course", help="Course keyword e.g. 'SEN-109'")
    parser.add_argument("--hours", type=int, default=5)
    parser.add_argument("--include-assignment-files", action="store_true",
                        help="Also fetch files attached to assignment pages")
    parser.add_argument("--list", action="store_true",
                        help="List the course's modules and exit")
    parser.add_argument("--module", action="append", default=[],
                        help="Only fetch content from modules whose name contains this "
                             "(repeat or comma-separate for several)")
    parser.add_argument("--search", default="",
                        help="Only fetch files/pages/assignments whose name contains this")
    parser.add_argument("--only", default="",
                        help="Comma list of: " + ",".join(CONTENT_TYPES))
    parser.add_argument("--since", default="",
                        help="Only fetch items updated on or after this date (YYYY-MM-DD)")
    args = parser.parse_args()

    get_config()  # validate token early

    global ALLOWED, DEST_DIR
    FILTERS["modules"] = [m.strip() for arg in args.module for m in arg.split(",") if m.strip()]
    FILTERS["search"]  = args.search.strip().lower()
    if args.only:
        only = {c.strip().lower() for c in args.only.split(",") if c.strip()}
        unknown = only - set(CONTENT_TYPES)
        if unknown:
            print(f"❌ Unknown --only value(s): {', '.join(sorted(unknown))}")
            print(f"   Use any of: {', '.join(CONTENT_TYPES)}")
            sys.exit(1)
        FILTERS["only"] = only
    if args.since:
        try:
            FILTERS["since"] = datetime.strptime(args.since, "%Y-%m-%d").replace(tzinfo=timezone.utc)
        except ValueError:
            print(f"❌ --since must look like 2026-10-01, got '{args.since}'")
            sys.exit(1)

    dest_dir = OUTPUT_DIR / args.course.replace(" ", "_")
    dest_dir.mkdir(parents=True, exist_ok=True)
    DEST_DIR = dest_dir
    print(f"📁 Saving to: {dest_dir}/")

    course = find_course(args.course)
    cid    = course["id"]

    if args.list:
        list_modules(cid)
        return

    if FILTERS["modules"]:
        print("\n🔎 Finding module content...")
        ALLOWED = collect_module_content(cid)

    only = FILTERS["only"]
    # The syllabus covers the whole course, so skip it when narrowing down
    narrowed = FILTERS["modules"] or FILTERS["search"] or FILTERS["since"]
    if "syllabus" in only and not (narrowed and args.only == ""):
        fetch_syllabus(cid, dest_dir)
    if "modules" in only:
        fetch_modules(cid, dest_dir)
    assignments = []
    if "assignments" in only:
        assignments = fetch_assignments(cid, dest_dir)  # returns filtered raw list
    if "pages" in only:
        fetch_pages(cid, dest_dir)
    if "files" in only:
        fetch_files(cid, dest_dir)

    if args.include_assignment_files:
        fetch_assignment_files(cid, assignments, dest_dir)

    write_manifest(dest_dir, course, args.hours, args.include_assignment_files)
    print(f"\n🎉 All materials saved to → {dest_dir}/")

if __name__ == "__main__":
    main()