# INSTRUCTIONS.md
# ─────────────────────────────────────────────────────────────────────────────
# Claude Code instructions — read this file and execute the steps below.
# Note: currently written for Claude Code. Other agent runtimes are not yet supported.
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

Write `outputs/01_topic_map.json`:
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

Write `outputs/02_priority_list.json`:
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
- Hard-coded 10-min breaks every 50 min — never optional
- Final hour: timed mock explanation (no notes) + cheat sheet read

Write `outputs/03_study_schedule.md`:
```
# <course> — <n>-hour survival plan
Goal: [what you can DO by the end]

## Hour 1 — [Punchy title]
Goal: [specific outcome]

### Task 1 · 20 min — [Action verb + topic]
Open sen-109-lec-1.pptx, slides 3–10. [What to look for.] [Why it matters.]
By the end: [what you should understand.]

### Task 2 · 15 min — Say it out loud
Close everything. Say: "[exact sentence]" for 2 minutes. No notes. Twice.

---
⏸ 10-MIN BREAK — stand up, water, no screens
---
## Hour 2 — ...
```

---

## [STUDY] PHASE 4 — CONCEPT SUMMARIES (ADHD-FRIENDLY)

For every non-cut topic write a concept card:
- Plain English first — no formal definition openers
- One vivid everyday analogy
- One common misconception in a warning block
- Max 5 sentences
- End with one key question

Write `outputs/04_concept_summaries.md`:
```
## [Topic name]
[3–5 sentence explanation.]
**Analogy:** [vivid concrete analogy]
> ⚠ Common misconception: [what students get wrong and why]
**Key question:** [examiner-style question]
---
```

---

## [STUDY] PHASE 5 — TEST MATERIALS

### 5A — Flashcards (30 cards)
40% easy / 40% medium / 20% hard. Mix: definition, application, compare, why.
Write `outputs/05a_flashcards.csv`:
```
"Question","Answer","Topic","Difficulty","Tags"
```

### 5B — Practice Quiz (10 questions)
4 MCQ (4 options, mark correct) + 3 short answer + 2 scenario + 1 compare.
Every question: model answer + topic it tests.
Write `outputs/05b_practice_quiz.md`

### 5C — Cheat Sheet
Max 1 A4 page. Key formulas + definitions, foundational → advanced.
Write `outputs/05c_cheat_sheet.md`

### 5D — Say It Out Loud (4–6 scripts)
Natural spoken English. Opening statement, full explanation, "so what",
limitations. Coaching tip after each.
Write `outputs/05d_say_it_out_loud.md`:
```
## [Script title]
"[Exact words to say out loud]"
> Tip: [coaching note]
```

### 5E — Danger Questions (8–10 questions)
Hard examiner traps targeting misconceptions.
Start: "Why...", "What happens if...", "What's the difference...", "How do you know..."
Each: why it's a trap (1 sentence) + model answer (3–5 sentences).
Write `outputs/05e_danger_questions.md`:
```
## Q1 — [Topic]
**Question:** ...
**Why it's a trap:** ...
**Model answer:** ...
---
```

---

## [STUDY] PHASE 6 — HOW TO USE THIS STUDY PACK

Write `outputs/00_HOW_TO_USE.md` — this is the FIRST file the student opens.

It must be warm, direct, ADHD-friendly. Structure:

```
# How to use this study pack — <course> (<n> hours)

## Start here (do this before anything else)
1. Open `03_study_schedule.md` — this is your hour-by-hour plan.
   Follow it exactly. Don't skip ahead.

## The files explained
| File | What it is | When to use it |
|------|-----------|----------------|
| 03_study_schedule.md | Your hour-by-hour plan | Start here |
| 04_concept_summaries.md | One card per topic | When you're stuck on a concept mid-session |
| 05c_cheat_sheet.md | One-page summary | Last 20 min before the exam |
| 05d_say_it_out_loud.md | Scripts to say aloud | End of each study hour |
| 05e_danger_questions.md | Hard examiner traps | After you finish the schedule |
| 05a_flashcards.csv | Import into Anki | Import once, review daily |
| 05b_practice_quiz.md | 10 exam-style questions | After finishing the schedule |

## Recommended flow
Hour 1–<n-1>: Follow 03_study_schedule.md block by block.
              When stuck → open 04_concept_summaries.md for that topic.
Last 30 min:  Read 05c_cheat_sheet.md slowly once.
              Work through 05e_danger_questions.md out loud.
After session: Import 05a_flashcards.csv into Anki. Review tomorrow.

## If you only have 30 minutes
1. Read 05c_cheat_sheet.md (10 min)
2. Say every script in 05d_say_it_out_loud.md out loud (10 min)
3. Read 05e_danger_questions.md answers (10 min)

## Importing flashcards into Anki
1. Open Anki → File → Import
2. Select 05a_flashcards.csv
3. Field separator: Comma
4. Map: Field 1 → Front, Field 2 → Back
5. Click Import
```

---
---

# ══════════════════════════════════════════════════════
# MODE: assignment
# ══════════════════════════════════════════════════════
# Triggered by: --mode assignment  OR  auto-detect (assignment brief found)
# Produces per-assignment completion guides in outputs/assignments/
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

Write `outputs/assignments/00_assignment_overview.md`:
```
# Assignment Overview — <course>

| # | Name | Type | Est. Hours | Due |
|---|------|------|-----------|-----|
| 1 | ... | coding | 4h | ... |

## Time budget across all assignments
Total estimated: Xh
Recommended start: [date math if due dates available]
```

---

## [ASSIGNMENT] PHASE 2 — PER-ASSIGNMENT COMPLETION GUIDE

For EACH assignment, write a separate file:
`outputs/assignments/assignment_<n>_<slug>.md`

Each guide must follow this structure exactly:

```
# Assignment <n>: <name>
**Type:** <coding|written|math|mixed>
**Estimated time:** <n> hours
**Due:** <date or unknown>

---

## 🎯 What you're being asked to do
[2–3 sentence plain-English summary of the goal. Not copied from the brief —
rewritten so it's immediately clear what the deliverable is.]

---

## ✅ Requirements checklist
- [ ] Requirement 1 (from brief, rewritten clearly)
- [ ] Requirement 2
...

---

## 🗺 Step-by-step completion guide

### Step 1 · [Est. time] — [What to do]
**Goal:** [What you will have by the end of this step]
**How:**
[Very detailed instructions. Include:]
- Exact approach to take
- Code snippets with comments where relevant
- Which concepts from the lectures apply here (reference lecture file + slide)
- What to watch out for / common mistakes

**Code scaffold (if applicable):**
```[language]
# Starter code or structure to follow
```

**Done when:** [Specific, checkable completion criterion]

### Step 2 · [Est. time] — ...

---

## 🔗 Relevant lecture material
| Concept needed | Source file | Slides/Pages |
|---------------|------------|-------------|
| ... | sen-109-lec-2.pptx | slides 4–8 |

---

## ⚠ Common mistakes to avoid
- [Mistake 1]: [Why it happens and how to avoid it]
- [Mistake 2]: ...

---

## 🧪 How to test your work
[Specific test cases or verification steps. Include expected outputs.]
```bash
# Example test command or verification
```

---

## 💡 If you're stuck
- [Specific hint for the hardest part]
- Check [exact lecture file + slide] for [concept]
```

---

## [ASSIGNMENT] PHASE 3 — HOW TO USE ASSIGNMENT GUIDES

Write `outputs/assignments/00_HOW_TO_USE.md`:
```
# How to use your assignment guides

## Start here
1. Open `00_assignment_overview.md` for the full picture.
2. Pick the assignment you're working on.
3. Open its guide file.
4. Work through Step by Step — check off requirements as you go.

## Workflow per assignment
1. Read "What you're being asked to do" (2 min)
2. Check off the requirements list so you know the scope
3. Follow steps in order — don't skip ahead
4. When stuck on a concept → open the linked lecture file at the listed slide
5. Use the test section to verify before submitting

## Time management
[Paste the time budget from 00_assignment_overview.md]
```

---
---

# ══════════════════════════════════════════════════════
# MODE: solver
# ══════════════════════════════════════════════════════
# Triggered by: --mode solver
# Produces: working solution + comprehension guide
# ─────────────────────────────────────────────────────

## [SOLVER] PHASE 1 — UNDERSTAND THE TASK

Read ALL project/assignment files:
- Assignment brief (pdf, txt, md)
- Starter code files
- Any provided tests
- README if present
- assignments.json

Build a complete understanding record:
- What the program/project must do
- Input/output specification
- Constraints and edge cases
- Grading rubric (if present in brief)
- Language and framework required

Write `outputs/solver/00_task_analysis.md`:
```
# Task Analysis: <assignment name>

## What needs to be built
[Plain-English description of what the finished program does]

## Input / Output
- Input: ...
- Output: ...
- Edge cases to handle: ...

## Constraints
- Language: ...
- Libraries allowed: ...
- Performance requirements: ...

## Grading breakdown (if available)
| Criterion | Points | Notes |
|-----------|--------|-------|
```

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
Write the complete file to `outputs/solver/solution/<filename>`:
- Full working implementation
- Student-style comments throughout
- Edge cases handled

### Write `outputs/solver/01_solution_notes.md`:
```
# Solution notes
## Approach chosen and why
[Why this approach, written in first-person student voice]
## Key decisions
- [Decision 1]: [Why]
## Known limitations
- [Any edge cases not handled, if any]
```

---

## [SOLVER] PHASE 3 — COMPREHENSION GUIDE

This is critical. The student must UNDERSTAND what was built, not just
submit it. Write a guide that teaches them their own solution.

Write `outputs/solver/02_comprehension_guide.md`:

```
# Comprehension guide: <assignment name>
## How to understand this solution in <hours> hours

---

## The big picture (read this first — 10 min)
[3–5 sentences: what the program does, the core idea behind the approach,
and why it works. Written so the student can explain it to someone else.]

---

## Walk through the code — file by file

### File: <filename>

#### Section: <function or block name> (lines X–Y)
**What this does:**
[Plain English explanation]

**Why it's written this way:**
[The reasoning — what alternatives exist and why this approach was chosen]

**The key line(s):**
```[language]
// The most important line(s) with explanation inline
```

**What to say if asked about this:**
"[Exact spoken explanation the student can use in an oral or viva]"

---

## Concepts this solution uses
| Concept | Where in code | Lecture reference |
|---------|--------------|------------------|
| [concept] | [function name] | [lecture file + slide] |

---

## Questions you must be able to answer

### Q1: [Question about the solution]
**Answer:** [Full answer]
**Say it as:** "[Natural spoken version]"

### Q2: ...

---

## What makes this solution good
[3–5 bullet points — specific things done well that the student can mention]

## What could be improved (if you had more time)
[Honest limitations — shows critical thinking]

---

## 30-minute crash course to understand this before submission
1. (5 min) Read "The big picture" above out loud
2. (10 min) Open solution/<filename>, read with the walk-through open side by side
3. (5 min) Cover the code and explain each section in your own words
4. (10 min) Answer all questions in "Questions you must be able to answer" out loud
```

---

## [SOLVER] PHASE 4 — HOW TO USE

Write `outputs/solver/00_HOW_TO_USE.md`:
```
# How to use your solver pack

## Files
| File | What it is |
|------|-----------|
| solution/ | Complete working solution — ready to submit |
| 00_task_analysis.md | What the assignment requires |
| 01_solution_notes.md | Approach and key decisions |
| 02_comprehension_guide.md | Understand your solution before submitting |

## Before submitting — do this
1. Read 02_comprehension_guide.md fully (30 min)
2. Open the solution files and follow along with the guide
3. Cover the guide and explain each part out loud in your own words
4. Answer every question in the "Questions you must be able to answer" section
5. Only submit once you can explain every part without notes

## If your course uses a specific submission format
Adjust file names / structure in solution/ as needed before submitting.
```

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
- Markdown renders cleanly
- CSV is correctly quoted

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

START HERE → <path to 00_HOW_TO_USE.md>
════════════════════════════════════════════════════════
```
