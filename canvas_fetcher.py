#!/usr/bin/env python3
"""
canvas_fetcher.py
-----------------
Fetches course materials from Canvas LMS.
Usage: python canvas_fetcher.py "SEN-109" --hours 10
       python canvas_fetcher.py "SEN-109" --hours 10 --include-assignment-files
"""

import os
import sys
import json
import argparse
import requests
from pathlib import Path

OUTPUT_DIR = Path("course-materials")

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
    course = matches[0]
    print(f"\n📚 Course: {course['name']} (ID: {course['id']})")
    return course

def fetch_files(course_id, dest_dir: Path):
    print("\n📂 Fetching course files...")
    files = get(f"/courses/{course_id}/files", params={"per_page": 100})
    for f in files:
        name = f.get("display_name", f.get("filename", "file"))
        url  = f.get("url")
        if url:
            download_file(url, dest_dir / "files" / name)

def fetch_pages(course_id, dest_dir: Path):
    print("\n📄 Fetching pages...")
    pages = get(f"/courses/{course_id}/pages", params={"per_page": 100})
    for p in pages:
        slug   = p.get("url", "page")
        detail = get(f"/courses/{course_id}/pages/{slug}")
        body   = detail.get("body", "")
        title  = detail.get("title", slug)
        out    = dest_dir / "pages" / f"{slug}.txt"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(f"# {title}\n\n{body}", encoding="utf-8")
        print(f"  [✓] {title}")

def fetch_syllabus(course_id, dest_dir: Path):
    print("\n📋 Fetching syllabus...")
    detail   = get(f"/courses/{course_id}", params={"include[]": "syllabus_body"})
    syllabus = detail.get("syllabus_body", "")
    if syllabus:
        out = dest_dir / "syllabus.txt"
        out.write_text(f"# Syllabus\n\n{syllabus}", encoding="utf-8")
        print("  [✓] syllabus.txt")
    else:
        print("  [!] No syllabus found")

def fetch_assignments(course_id, dest_dir: Path):
    print("\n📝 Fetching assignments...")
    assignments = get(f"/courses/{course_id}/assignments", params={"per_page": 100})
    summary = []
    for a in assignments:
        summary.append({
            "id":          a.get("id"),
            "name":        a.get("name"),
            "due_at":      a.get("due_at"),
            "points":      a.get("points_possible"),
            "description": a.get("description", "")[:2000],
            "submission_types": a.get("submission_types", []),
            "has_attachments": bool(a.get("attachments", [])),
        })
    out = dest_dir / "assignments.json"
    out.write_text(json.dumps(summary, indent=2), encoding="utf-8")
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
    structure = [{"module": m.get("name"),
                  "items": [{"title": i.get("title"), "type": i.get("type")}
                             for i in m.get("items", [])]}
                 for m in modules]
    out = dest_dir / "modules.json"
    out.write_text(json.dumps(structure, indent=2), encoding="utf-8")
    print(f"  [✓] {len(modules)} modules saved")

def write_manifest(dest_dir: Path, course, hours, include_assignment_files):
    manifest = {
        "course_name":             course.get("name"),
        "course_code":             course.get("course_code"),
        "study_hours":             hours,
        "fetched_assignment_files": include_assignment_files,
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
    args = parser.parse_args()

    get_config()  # validate token early

    dest_dir = OUTPUT_DIR / args.course.replace(" ", "_")
    dest_dir.mkdir(parents=True, exist_ok=True)
    print(f"📁 Saving to: {dest_dir}/")

    course = find_course(args.course)
    cid    = course["id"]

    fetch_syllabus(cid, dest_dir)
    fetch_modules(cid,  dest_dir)
    assignments = fetch_assignments(cid, dest_dir)  # returns raw list
    fetch_pages(cid,    dest_dir)
    fetch_files(cid,    dest_dir)

    if args.include_assignment_files:
        fetch_assignment_files(cid, assignments, dest_dir)

    write_manifest(dest_dir, course, args.hours, args.include_assignment_files)
    print(f"\n🎉 All materials saved to → {dest_dir}/")

if __name__ == "__main__":
    main()