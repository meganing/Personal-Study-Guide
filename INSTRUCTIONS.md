# INSTRUCTIONS.md
# ─────────────────────────────────────────────────────────────────────────────
# Claude Code instructions — read this file and execute the steps below.
# Note: currently written for Claude Code. Other agent runtimes are not yet supported.
#
# OUTPUT FORMAT: the student-facing deliverable in every mode is a single,
# self-contained, interactive HTML file (flip flashcards, live quiz feedback,
# collapsible concept/step cards, Pomodoro + break timers, progress tracking
# saved via localStorage, dark/light mode). You do NOT hand-write this HTML.
# You build a JSON data object from the course material, then splice it into
# a pre-built template from templates/ (relative to the repo root — this is
# the cwd run.sh invokes `claude` from). See each mode's "ASSEMBLE" phase and
# the JSON DATA SCHEMA box for exact field names — the template's JavaScript
# reads those field names directly, so they must match exactly.
# ─────────────────────────────────────────────────────────────────────────────

## STEP 0 — READ INPUTS & DETECT MODE

### 0A — Read arguments
The run.sh script will pass these as context in the prompt:
- COURSE_DIR: path to course materials folder
- HOURS: study/work hours available
- MODE: one of `study` | `assignment` | `solver`

If MODE is not specified, auto-detect using rule 0C below.

### 0B — Read manifest
Read `<COURSE_DIR>/manifest.json` for course_name and study_hours.
If missing, infer from folder name and use HOURS argument.

### 0C — Auto-detect mode (only if --mode not passed)
Scan the course folder:
- If folder contains ONLY lecture files (pptx, pdf, txt) → MODE = study
- If folder contains assignment briefs OR a `assignments/` subfolder → MODE = assignment
- If folder contains project source files (.py, .rs, .c, .cpp, .js, .ts, Makefile,
  Cargo.toml, requirements.txt, etc.) alongside an assignment brief → MODE = solver

Print detected mode to console: `🔍 Detected mode: <mode>`

### 0D — Create output folders
```
<COURSE_DIR>/outputs/
<COURSE_DIR>/outputs/assignments/   (always create)
```

### 0E — Print mission start
```
════════════════════════════════════════════════════════
🚀 LEARNING AGENT STARTED
Course : <course_name>
Hours  : <hours>
Mode   : <MODE>
════════════════════════════════════════════════════════
```

Then immediately begin the phase set for the detected/specified mode.

---
---

# ══════════════════════════════════════════════════════
# MODE: study
# ══════════════════════════════════════════════════════
# Triggered by: --mode study  OR  auto-detect (lecture files only)
# Produces: outputs/index.html — a single interactive study pack
# ─────────────────────────────────────────────────────

## [STUDY] PHASE 1 — INGEST & MAP

Read ALL files in the course folder recursively:
- `.pptx`: extract text from every slide (slide number + text)
- `.pdf`: extract text from every page
- `.txt` / `.md`: read fully
- `.json`: parse

Build a complete topic list — every distinct concept in the course.
For each topic record:
- Source file + slide/page number
- Complexity 1–5
- Prerequisites (other topic IDs)
- Whether it appears in assignments.json → exam_relevant = true
- Estimated study minutes

Quality check: sum of estimated_minutes must be within ±20% of (hours × 60).

Write `outputs/01_topic_map.json` (internal working data, not shown to the student):
```json
{
  "course": "...", "study_hours": 10, "total_topics": 0,
  "topics": [{
    "id": "T01", "name": "...",
    "source": "sen-109-lec-1.pptx slide 4",
    "complexity": 3, "prerequisites": [],
    "exam_relevant": true, "estimated_minutes": 20
  }]
}
```

---

## [STUDY] PHASE 2 — PRIORITISE

Read `outputs/01_topic_map.json`. Order by:
1. Prerequisites always before dependents
2. Exam-relevant before background theory
3. Higher complexity gets more time

Cut lowest-priority non-prerequisite topics if total exceeds hours.

Write `outputs/02_priority_list.json` (internal working data, not shown to the student):
```json
{
  "study_hours": 10, "coverage_percent": 90,
  "ordered_topics": [{"rank": 1, "topic_id": "T01", "reason": "..."}],
  "topics_cut": [{"topic_id": "T12", "reason": "..."}]
}
```

---

## [STUDY] PHASE 3 — STUDY SCHEDULE (ADHD-FRIENDLY)

ADHD rules — all mandatory:
- Each hour block has ONE outcome goal ("you can explain X without notes")
- Every task names the EXACT file + slide/page to open
- Direct second-person tone ("Open this. Read it twice.")
- No task longer than 25 minutes
- Every task ends with an active action: write, say aloud, or run
- Breaks every 50 min are handled automatically by the template (it inserts a
  10-min break banner with its own timer after every `breaks_after_every_minutes`
  of cumulative task time) — do not write break tasks yourself
- Final hour: timed mock explanation (no notes) + cheat sheet read

Build the `schedule` array (do NOT write a markdown file — this becomes the
`schedule` field in the study pack JSON assembled in Phase 6):
```json
[
  {
    "hour": 1,
    "title": "Punchy title",
    "goal": "Specific outcome for this hour",
    "tasks": [
      {
        "type": "study", "minutes": 20,
        "title": "Action verb + topic",
        "body": "Open sen-109-lec-1.pptx, slides 3-10. What to look for. Why it matters.",
        "outcome": "What you should understand by the end."
      },
      {
        "type": "speak", "minutes": 15,
        "title": "Say it out loud",
        "script": "Close everything. Say '[exact sentence]' for 2 minutes. No notes. Twice.",
        "outcome": "You said it twice without looking."
      }
    ]
  }
]
```
Also record an overall pack `goal` (one sentence: what the student can DO by the
end of all hours) — this becomes the top-level `goal` field in Phase 6.

---

## [STUDY] PHASE 4 — CONCEPT SUMMARIES (ADHD-FRIENDLY)

For every non-cut topic build a concept entry:
- Plain English first — no formal definition openers
- One vivid everyday analogy
- One common misconception
- Max 5 sentences for the explanation
- End with one key question

Build the `concepts` array (becomes the `concepts` field in Phase 6):
```json
[
  {
    "name": "Topic name",
    "explanation": "3-5 sentence explanation.",
    "analogy": "Vivid concrete analogy.",
    "misconception": "What students get wrong and why.",
    "key_question": "Examiner-style question."
  }
]
```

---

## [STUDY] PHASE 5 — TEST MATERIALS

### 5A — Flashcards (30 cards)
40% easy / 40% medium / 20% hard. Mix: definition, application, compare, why.

Build the `flashcards` array (becomes the `flashcards` field in Phase 6):
```json
[{"q": "...", "a": "...", "topic": "...", "difficulty": "easy"}]
```
ALSO write `outputs/05a_flashcards.csv` from this exact same data, for Anki import:
```
"Question","Answer","Topic","Difficulty","Tags"
```

### 5B — Practice Quiz (10 questions)
4 MCQ (4 options each) + 3 short answer + 2 scenario + 1 compare.
Every question needs a model answer/explanation.

Build the `quiz` object (becomes the `quiz` field in Phase 6):
```json
{
  "mcq": [{"q": "...", "options": ["...","...","...","..."], "correct": 0, "explanation": "..."}],
  "short_answer": [{"q": "...", "model_answer": "..."}],
  "scenario": [{"q": "...", "model_answer": "..."}],
  "compare": [{"q": "...", "model_answer": "..."}]
}
```
`correct` is the zero-based index into `options`.

### 5C — Cheat Sheet
Max 1 A4-page worth of content. Key formulas + definitions, foundational → advanced.

Build the `cheat_sheet` object (becomes the `cheat_sheet` field in Phase 6):
```json
{"sections": [{"heading": "...", "items": ["...", "..."]}]}
```

### 5D — Say It Out Loud (4–6 scripts)
Natural spoken English. Opening statement, full explanation, "so what", limitations.
Coaching tip after each.

Build the `say_it_out_loud` array (becomes the field of the same name in Phase 6):
```json
[{"title": "...", "script": "Exact words to say out loud.", "tip": "Coaching note."}]
```

### 5E — Danger Questions (8–10 questions)
Hard examiner traps targeting misconceptions.
Start: "Why...", "What happens if...", "What's the difference...", "How do you know..."

Build the `danger_questions` array (becomes the field of the same name in Phase 6):
```json
[{"topic": "...", "question": "...", "why_trap": "One sentence.", "model_answer": "3-5 sentences."}]
```

---

## [STUDY] PHASE 6 — ASSEMBLE THE INTERACTIVE STUDY PACK

This is the final, student-facing deliverable — it replaces the separate
markdown files from earlier versions of this tool.

1. Assemble one JSON object from Phases 1–5:
   ```json
   {
     "course": "<course name>",
     "hours": <hours>,
     "generated_at": "<ISO 8601 timestamp of now>",
     "goal": "<overall pack goal from Phase 3>",
     "breaks_after_every_minutes": 50,
     "schedule": [ ... from Phase 3 ... ],
     "concepts": [ ... from Phase 4 ... ],
     "flashcards": [ ... from Phase 5A ... ],
     "quiz": { ... from Phase 5B ... },
     "cheat_sheet": { ... from Phase 5C ... },
     "say_it_out_loud": [ ... from Phase 5D ... ],
     "danger_questions": [ ... from Phase 5E ... ]
   }
   ```
2. Read the template at `templates/study_pack.html` (repo root, do not modify
   the template file itself).
3. Replace every occurrence of `__COURSE_TITLE__` with the plain-text course
   name (HTML-escape `&`, `<`, `>` if the name contains them).
4. Replace the single occurrence of `__STUDY_DATA_JSON__` with the JSON object
   from step 1. The JSON must be syntactically valid (double-quoted keys and
   strings, no trailing commas). If any string value contains the literal
   substring `</script`, write it as `<\/script` so it can't terminate the
   surrounding `<script>` tag early.
5. Write the result to `outputs/index.html`. This is the ONLY file the student
   needs to open — the page itself has section navigation (Schedule, Concepts,
   Flashcards, Quiz, Cheat Sheet, Say It Aloud, Danger Zone), so no separate
   "how to use" file is needed.

---
---

# ══════════════════════════════════════════════════════
# MODE: assignment
# ══════════════════════════════════════════════════════
# Triggered by: --mode assignment  OR  auto-detect (assignment brief found)
# Produces: outputs/assignments/index.html — one interactive guide covering
# every assignment, with a sidebar to switch between them
# ─────────────────────────────────────────────────────

## [ASSIGNMENT] PHASE 1 — PARSE ASSIGNMENTS

Read `assignments.json` in the course folder.
Also scan for any assignment brief files (pdf, txt, md) in the folder.

For each assignment build a record:
- Name, due date, points
- Full description / requirements extracted from brief
- Detected type: coding | written | math | mixed
- Detected language/framework (if coding): scan for keywords, imports, file extensions
- Estimated hours to complete (based on complexity)
- A short, unique, URL-safe `id` slug (e.g. `assignment-1-lab-report`)

Build the `overview` object (total time budget across all assignments, and a
recommended start date/order if due dates are available) — this becomes the
`overview` field in Phase 3:
```json
{
  "total_hours": 12,
  "recommended_start": "This week — Assignment 1 is due soonest",
  "assignments": [
    {"id": "...", "name": "...", "type": "coding", "est_hours": 4, "due": "..."}
  ]
}
```

---

## [ASSIGNMENT] PHASE 2 — PER-ASSIGNMENT COMPLETION GUIDE

For EACH assignment, build one record for the `assignments` array (becomes
the `assignments` field in Phase 3). Keep the same depth and quality bar as a
full written guide — this is rendered directly, not summarized further:

```json
{
  "id": "assignment-1-lab-report",
  "name": "Assignment 1: Lab Report",
  "type": "coding",
  "est_hours": 4,
  "due": "2026-09-20",
  "summary": "2-3 sentence plain-English rewrite of the goal — not copied from the brief, rewritten so the deliverable is immediately clear.",
  "requirements": ["Requirement 1 rewritten clearly", "Requirement 2", "..."],
  "steps": [
    {
      "title": "What to do in this step",
      "est_minutes": 30,
      "goal": "What you will have by the end of this step",
      "how": "Very detailed instructions: exact approach, which lecture concepts apply (reference file + slide), what to watch out for.",
      "code_scaffold": {"lang": "python", "code": "# Starter code or structure to follow"},
      "done_when": "Specific, checkable completion criterion"
    }
  ],
  "lecture_refs": [{"concept": "...", "source": "sen-109-lec-2.pptx", "slides": "4-8"}],
  "common_mistakes": [{"mistake": "...", "why": "Why it happens and how to avoid it"}],
  "testing": {"description": "Specific test cases or verification steps, with expected outputs.", "commands": ["pytest test_x.py"]},
  "hints": ["Specific hint for the hardest part (revealed one at a time in the UI)", "..."]
}
```
`code_scaffold` is optional — omit it entirely for non-coding steps rather than
leaving it null. `commands` may be an empty array for non-code testing steps.

---

## [ASSIGNMENT] PHASE 3 — ASSEMBLE THE INTERACTIVE ASSIGNMENT GUIDE

1. Assemble one JSON object:
   ```json
   {
     "course": "<course name>",
     "generated_at": "<ISO 8601 timestamp of now>",
     "overview": { ... from Phase 1 ... },
     "assignments": [ ... from Phase 2 ... ]
   }
   ```
2. Read the template at `templates/assignment_pack.html` (repo root).
3. Replace every `__COURSE_TITLE__` with the plain-text course name (HTML-escape
   `&`, `<`, `>`).
4. Replace the single `__ASSIGNMENT_DATA_JSON__` with the JSON object from
   step 1, applying the same validity and `</script` escaping rules as the
   study mode assembly step.
5. Write the result to `outputs/assignments/index.html`. This is the only file
   the student needs — the Overview tab covers the full-picture summary a
   separate "how to use" file used to provide.

---
---

# ══════════════════════════════════════════════════════
# MODE: solver
# ══════════════════════════════════════════════════════
# Triggered by: --mode solver
# Produces: outputs/solver/solution/  (real, runnable source files)
#       and outputs/solver/index.html (interactive comprehension guide)
# ─────────────────────────────────────────────────────

## [SOLVER] PHASE 1 — UNDERSTAND THE TASK

Read ALL project/assignment files:
- Assignment brief (pdf, txt, md)
- Starter code files
- Any provided tests
- README if present
- assignments.json

Build the `task_analysis` object (becomes the `task_analysis` field in Phase 4):
```json
{
  "what": "Plain-English description of what the finished program does",
  "io": {"input": "...", "output": "...", "edge_cases": "..."},
  "constraints": {"language": "...", "libraries": "...", "performance": "..."},
  "grading": [{"criterion": "...", "points": 10, "notes": "..."}]
}
```
`grading` may be an empty array if no rubric is available.

---

## [SOLVER] PHASE 2 — BUILD THE SOLUTION

Write a complete, working solution. Rules:

### Code quality rules (minimum AI traces):
- Write code in a natural student style for the detected language
- Use simple, readable variable names (not overly descriptive AI names)
- Include comments that explain WHY, not just WHAT — written as a student
  thinking out loud, not as documentation
- Do NOT use every advanced language feature available — use what a
  competent student in this course would know
- Match the complexity level of the lecture material — if lectures use
  basic loops, don't use advanced iterators unless required
- Avoid overly perfect structure — real student code has some personality

### For each source file needed:
Write the complete file to `outputs/solver/solution/<filename>` (a real,
runnable source file — this is the only part of solver mode that is NOT
HTML):
- Full working implementation
- Student-style comments throughout
- Edge cases handled

Build the `solution_notes` object (becomes the `solution_notes` field in
Phase 4) and a `solution_files` array listing every path written above
(e.g. `["solution/main.py", "solution/utils.py"]`):
```json
{
  "approach": "Why this approach, written in first-person student voice",
  "decisions": [{"decision": "...", "why": "..."}],
  "limitations": ["Any edge cases not handled, if any"]
}
```

---

## [SOLVER] PHASE 3 — COMPREHENSION GUIDE DATA

This is critical. The student must UNDERSTAND what was built, not just
submit it. Build data for a guide that teaches them their own solution.

Build the `comprehension` object (becomes the `comprehension` field in Phase 4):
```json
{
  "big_picture": "3-5 sentences: what the program does, the core idea, and why it works — written so the student can explain it to someone else.",
  "files": [
    {
      "filename": "main.py",
      "sections": [
        {
          "name": "function or block name",
          "lines": "12-30",
          "what": "Plain English explanation of what this does.",
          "why": "The reasoning — what alternatives exist and why this approach was chosen.",
          "key_lines": {"lang": "python", "code": "the most important line(s), with an inline comment"},
          "say": "Exact spoken explanation the student can use in an oral or viva."
        }
      ]
    }
  ],
  "concepts": [{"concept": "...", "where": "function name", "lecture_ref": "lecture file + slide"}],
  "questions": [{"q": "Question about the solution", "answer": "Full answer", "say": "Natural spoken version"}],
  "good_points": ["Specific things done well that the student can mention"],
  "improvements": ["Honest limitations — shows critical thinking"]
}
```
Include enough `questions` entries to cover every non-trivial design decision
(aim for 5-8) — these become a self-check practice deck in the UI.

---

## [SOLVER] PHASE 4 — ASSEMBLE THE INTERACTIVE COMPREHENSION GUIDE

1. Assemble one JSON object:
   ```json
   {
     "course": "<course name>",
     "assignment_name": "<assignment name>",
     "generated_at": "<ISO 8601 timestamp of now>",
     "task_analysis": { ... from Phase 1 ... },
     "solution_notes": { ... from Phase 2 ... },
     "comprehension": { ... from Phase 3 ... },
     "solution_files": [ ... from Phase 2 ... ]
   }
   ```
2. Read the template at `templates/solver_pack.html` (repo root).
3. Replace every `__COURSE_TITLE__` with the plain-text course name (HTML-escape
   `&`, `<`, `>`).
4. Replace the single `__SOLVER_DATA_JSON__` with the JSON object from step 1,
   applying the same validity and `</script` escaping rules as study mode.
5. Write the result to `outputs/solver/index.html`.

---
---

# ══════════════════════════════════════════════════════
# QUALITY STANDARDS (ALL MODES)
# ══════════════════════════════════════════════════════

Before writing any file:
- No hallucinated facts — if unsure, mark [VERIFY]
- All file references must be real files that exist in the course folder
- All code must be complete and runnable — no placeholder `# TODO` unless
  explicitly noted as student exercise
- CSV is correctly quoted
- Every JSON object you assemble for a template must be valid JSON (double-quoted
  keys/strings, no trailing commas, no comments) and must match the field names
  in that mode's DATA SCHEMA exactly — the template's JavaScript reads those
  keys verbatim and will silently render nothing for a misspelled or missing key
- Escape any literal `</script` inside a JSON string value as `<\/script`
- Never edit the template files in `templates/` themselves — only read them

---

# ══════════════════════════════════════════════════════
# FINAL STEP (ALL MODES)
# ══════════════════════════════════════════════════════

After ALL files are written, print:

```
════════════════════════════════════════════════════════
✅ PACK COMPLETE
════════════════════════════════════════════════════════
Course : <course_name>
Hours  : <hours>
Mode   : <mode>

Output files:
<list every file written with its path>

START HERE → <outputs/index.html                    for study mode>
             <outputs/assignments/index.html         for assignment mode>
             <outputs/solver/index.html               for solver mode>

Open that file directly in any browser — no server needed.
════════════════════════════════════════════════════════
```
