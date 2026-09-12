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
- MODE: one of `study` | `assignment` | `solver` | `roadmap`

If MODE is not specified, auto-detect using rule 0C below (this only applies
to `study` | `assignment` | `solver` — `roadmap` is never auto-detected and
is only ever passed explicitly, since it has no course folder to scan).

**If MODE is `roadmap`, stop reading here and skip straight to the
`[ROADMAP]` section below** — it defines its own inputs (no COURSE_DIR/HOURS),
its own startup print, and its own phases. The rest of Step 0 (0B-0E) and
everything in STUDY/ASSIGNMENT/SOLVER below does not apply to it.

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
the `assignments` field in Phase 3).

### Writing rules — ADHD-friendly, beginner-friendly, mandatory:
- Assume the student is a beginner in this specific topic. The first time a
  non-everyday term appears (mutex, recursion, big-O, whatever the domain
  needs), define it in one short clause inline — don't assume it's known.
- `how` is an array of 2-5 short bullets, NOT a paragraph. Each bullet is one
  concrete, scannable action or fact — one idea per bullet, plain words.
- No step longer than 30 minutes. If a step needs more, split it into two
  steps instead of writing a longer one.
- Direct, active, second-person tone ("Open X. Do Y.") — no filler, no
  throat-clearing, no restating the obvious.
- `summary` and `common_mistakes[].why` follow the same rule: short sentences,
  no walls of text.
- Every step still ends with `done_when`: one concrete, self-checkable sign.

```json
{
  "id": "assignment-1-lab-report",
  "name": "Assignment 1: Lab Report",
  "type": "coding",
  "est_hours": 4,
  "due": "2026-09-20",
  "summary": "1-2 short sentences, plain English: what the deliverable is, not copied from the brief.",
  "glossary": [{"term": "Mutex", "meaning": "A lock only one thread can hold at a time."}],
  "requirements": ["Requirement 1 rewritten clearly", "Requirement 2", "..."],
  "time_plan": [
    {"session": 1, "hours": 2, "covers": "Steps 1-2", "goal": "One-sentence outcome for this work session."}
  ],
  "steps": [
    {
      "title": "What to do in this step",
      "est_minutes": 25,
      "goal": "What you will have by the end of this step",
      "how": ["Short concrete action 1.", "Short concrete action 2 — name the exact file/command/concept.", "What to watch out for, in one line."],
      "code_scaffold": {"lang": "python", "code": "# Starter code or structure to follow"},
      "done_when": "Specific, checkable completion criterion"
    }
  ],
  "lecture_refs": [{"concept": "...", "source": "sen-109-lec-2.pptx", "slides": "4-8"}],
  "common_mistakes": [{"mistake": "...", "why": "Short reason, one sentence."}],
  "testing": {"description": "Specific test cases or verification steps, with expected outputs.", "commands": ["pytest test_x.py"]},
  "hints": ["Specific hint for the hardest part (revealed one at a time in the UI)", "..."],
  "resources": [{"name": "Real, well-known reference (man page, official docs, video tutorial, classic paper)", "note": "One line: why a beginner needs this.", "type": "doc", "url": "https://... (optional)"}]
}
```
`code_scaffold` is optional — omit it entirely for non-coding steps rather than
leaving it null. `commands` may be an empty array for non-code testing steps.
`glossary` covers only terms actually used in this assignment's guide (aim for
4-8). `time_plan` splits the assignment's `est_hours` into work sessions sized
for a beginner's actual attention span (60-120 min each) so the student knows
how to spend the HOURS they have — this is the "help with time" piece,
equivalent to study mode's hour blocks.

`resources` (aim for 4-6, mix of types): each has a `type` (e.g. `video`,
`doc`, `article`, `paper`) and an optional `url`. If a tool that can browse
the web is available, look the resource up for real and only include `url`
when you have confirmed, from that lookup, that the page/video actually
exists — a search result you did not verify is not enough. If no browsing
tool is available, or you can't confirm a link, omit `url` entirely and give
just `name`/`note` so the student can search for it themselves. Never type a
URL from memory or guess a plausible-looking one — a wrong or dead link is
worse than no link.

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
# MODE: roadmap
# ══════════════════════════════════════════════════════
# Triggered by: --mode roadmap ONLY — never auto-detected. There is no
# course folder here; the learner describes a goal directly instead.
# Produces: outputs/roadmap/index.html — an interactive learning roadmap
# with a phase-by-phase plan, real study resources, and a study-log/streak
# tracker the learner uses over time as they actually study.
# ─────────────────────────────────────────────────────

## [ROADMAP] PHASE 0 — READ INPUTS & START

run.sh passes these instead of COURSE_DIR/HOURS:
- TOPIC: free text, e.g. "Japanese" or "Machine Learning"
- TOPIC_TYPE: `subject` | `language`
- CURRENT_LEVEL: free text — where the learner is starting from
- TARGET_LEVEL: free text — what they want to be able to do/know
- DURATION: free text, e.g. "2 months", "1 year"
- WEEKLY_HOURS: number — hours/week they can realistically commit

Create `<OUTPUTS_DIR>/roadmap/` (run.sh also creates this, but ensure it
exists). Then print:
```
════════════════════════════════════════════════════════
🚀 LEARNING AGENT STARTED
Topic     : <TOPIC> (<TOPIC_TYPE>)
Level     : <CURRENT_LEVEL> → <TARGET_LEVEL>
Duration  : <DURATION> · <WEEKLY_HOURS>h/week
Mode      : roadmap
════════════════════════════════════════════════════════
```

---

## [ROADMAP] PHASE 1 — RESEARCH THE PATH

- Draw on real, well-established knowledge of how this topic is normally
  learned in sequence: for a `language`, that means a CEFR-style progression
  (or the equivalent for non-European languages) across listening, speaking,
  reading, writing, vocab, and grammar; for a `subject`, that means the
  standard prerequisite chain and canonical curriculum a competent teacher
  would use.
- If a tool that can browse the web is available, look up real, current,
  well-regarded resources for this specific TOPIC (courses, books, apps,
  communities) rather than relying only on memory — apply the same
  verification rule as assignment mode's `resources` field below.
- Sanity-check DURATION against CURRENT_LEVEL → TARGET_LEVEL. If it's
  unrealistic as literally stated (e.g. "true beginner to fluent in 2
  weeks"), do not refuse and do not silently ignore it — build the most
  honest plan that fits the time given, and say so plainly in `overview`
  (e.g. "this gets you a solid survival-conversation foundation, not
  fluency, in 2 weeks — fluency realistically takes years of immersion").

---

## [ROADMAP] PHASE 2 — BUILD THE PHASES (ADHD-FRIENDLY)

Split DURATION into 3-8 phases with realistic timeframes (fewer, longer
phases for a short DURATION; more for a year or longer). Writing rules:

- Every `milestone` must be concretely checkable/observable by the learner
  themselves — "hold a 5-minute self-introduction from memory" is good,
  "get better at speaking" is not.
- `focus_areas` and `milestones` are short bullets (1-2 sentences each), not
  paragraphs — same rule as assignment mode.
- Each phase ends with one concrete `checkpoint`: a specific self-test that
  tells the learner they're ready for the next phase.
- Pace milestones to WEEKLY_HOURS — don't write a plan that assumes more
  time than the learner said they have.

```json
{
  "id": "phase-1",
  "title": "Foundations: hiragana, katakana, and core sentence patterns",
  "timeframe": "Weeks 1-4",
  "goal": "One sentence: what you'll be able to do by the end of this phase.",
  "focus_areas": ["Hiragana reading & writing", "Katakana reading & writing", "Basic sentence structure (X wa Y desu)"],
  "milestones": ["Read any hiragana word without sounding out each letter", "Introduce yourself in 3-4 full sentences"],
  "resources": [{"name": "Real, well-known resource for THIS phase", "type": "app", "note": "Why this fits this phase specifically.", "url": "https://... (optional, verified)"}],
  "checkpoint": "A concrete self-test to know you're ready for phase 2."
}
```

---

## [ROADMAP] PHASE 3 — OVERALL MATERIALS & CONSISTENCY TIPS

Build:
- `materials`: 4-8 general resources not tied to one specific phase (e.g. a
  community/subreddit/Discord, a reference grammar, an overall course) —
  same real-resources-only, verify-before-linking rule as assignment mode.
- `tips`: 3-5 short, ADHD-friendly consistency habits for THIS topic/duration
  (e.g. "10 minutes every day beats 2 hours once a week — streaks are the
  whole game here"). One sentence each.

---

## [ROADMAP] PHASE 4 — ASSEMBLE THE INTERACTIVE ROADMAP

1. Assemble one JSON object:
   ```json
   {
     "topic": "<TOPIC>",
     "topic_type": "<TOPIC_TYPE>",
     "current_level": "<CURRENT_LEVEL>",
     "target_level": "<TARGET_LEVEL>",
     "duration": "<DURATION>",
     "weekly_hours": <WEEKLY_HOURS>,
     "generated_at": "<ISO 8601 timestamp of now>",
     "overview": "2-4 sentences: the plan and why it's paced this way — see the realism note in Phase 1.",
     "weekly_commitment": "Plain-English restatement of how to spread WEEKLY_HOURS across a week (e.g. '~30-45 min most days beats one long weekend session').",
     "tips": [ ... from Phase 3 ... ],
     "phases": [ ... from Phase 2 ... ],
     "materials": [ ... from Phase 3 ... ]
   }
   ```
2. Read the template at `templates/roadmap_pack.html` (repo root, do not
   modify the template file itself).
3. Replace every `__TOPIC_TITLE__` with the plain-text TOPIC (HTML-escape
   `&`, `<`, `>`).
4. Replace the single `__ROADMAP_DATA_JSON__` with the JSON object from step
   1, applying the same validity and `</script` escaping rules as every
   other mode.
5. Write the result to `outputs/roadmap/index.html`. This is the only file
   the learner needs — it also holds their study-log/streak tracker, which
   lives entirely in the page's own `localStorage` and needs no data from
   this generation step.

---
---

# ══════════════════════════════════════════════════════
# QUALITY STANDARDS (ALL MODES)
# ══════════════════════════════════════════════════════

Before writing any file:
- No hallucinated facts — if unsure, mark [VERIFY]
- All file references must be real files that exist in the course folder
  (not applicable to roadmap mode, which has no course folder — it follows
  its own resource-verification rule in `[ROADMAP] PHASE 1` instead)
- All code must be complete and runnable — no placeholder `# TODO` unless
  explicitly noted as student exercise
- CSV is correctly quoted
- Every JSON object you assemble for a template must be valid JSON (double-quoted
  keys/strings, no trailing commas, no comments) and must match the field names
  in that mode's DATA SCHEMA exactly — the template's JavaScript reads those
  keys verbatim and will silently render nothing for a misspelled or missing key
- Escape any literal `</script` inside a JSON string value as `<\/script`
- Never edit the template files in `templates/` themselves — only read them
- Never invent a URL for a `resources`/`materials` entry — only include one
  you actually verified exists (via a browsing tool), otherwise omit `url`
  and give just `name`/`note`

---

# ══════════════════════════════════════════════════════
# FINAL STEP (ALL MODES)
# ══════════════════════════════════════════════════════

After ALL files are written, print:

```
════════════════════════════════════════════════════════
✅ PACK COMPLETE
════════════════════════════════════════════════════════
Course : <course_name>              (roadmap mode: Topic  : <TOPIC>)
Hours  : <hours>                    (roadmap mode: Duration: <DURATION>)
Mode   : <mode>

Output files:
<list every file written with its path>

START HERE → <outputs/index.html                    for study mode>
             <outputs/assignments/index.html         for assignment mode>
             <outputs/solver/index.html               for solver mode>
             <outputs/roadmap/index.html              for roadmap mode>

Open that file directly in any browser — no server needed.
════════════════════════════════════════════════════════
```
