# study-pack-generator

An AI workflow that reads your course materials or project descriptions and generates a personalized, ADHD-friendly study pack. Transforms lecture slides, PDFs, and assignment briefs into a single **interactive HTML page** — flip flashcards, a live-feedback quiz, collapsible concept/step cards, Pomodoro + break timers, and progress tracking, all in one file you just double-click open.

## Why ADHD-friendly?

The study output is specifically designed for ADHD learners — this is the most distinctive thing about it:

- **25-minute task blocks** with clear end goals
- **Mandatory 10-minute breaks** every 50 minutes
- **Direct action language** ("Open this file, read it twice")
- **Active learning tasks** (write, say aloud, draw)
- **Visual analogies** for abstract concepts
- **Common mistake warnings** to prevent confusion
- **Multiple learning modalities** (visual, auditory, kinesthetic)

## Interactive HTML output

Every mode produces a single self-contained `index.html` — no server, no build
step, no internet connection needed. Open it in any browser and:

- **Flip flashcards** — click to reveal, mark "I knew it" / "Still learning",
  filter by topic/difficulty, shuffle
- **Live quiz feedback** — multiple choice highlights correct/incorrect
  instantly; short-answer questions reveal a model answer on demand
- **Collapsible concept cards, steps, and code walkthroughs** — search/filter,
  accordion-style, code blocks with a one-click copy button
- **Built-in timers** — a focus timer per task block and an automatic 10-minute
  break timer, with a sound when time's up
- **Progress tracking** — checkboxes, known/learning flashcard state, and a
  completion ring, all saved in your browser (`localStorage`) so closing and
  reopening the file picks up where you left off
- **Dark/light mode** — follows your system theme, with a manual toggle
- **Printable cheat sheet** — a `Print` button gives a clean, nav-free page

Progress is stored per-browser and per-generation — regenerating a pack starts
progress fresh, since the content (and therefore task order) may have changed.

Flashcards are also exported as `05a_flashcards.csv` for Anki import, since
that's a separate workflow worth keeping outside the browser.

## Compatibility

Currently built for Claude Code. Support for other AI agents/runners is planned for a future release.

## Output Modes

Pick one of three presets when you run it:

- **📚 Study mode**: ADHD-friendly study schedules with concept summaries, flashcards, and practice materials
- **📝 Assignment mode**: Step-by-step completion guides for individual assignments
- **🔧 Solver mode**: Complete working solutions with comprehension guides

## Quick Start

### Prerequisites
- Python 3.x
- Claude Code CLI (`npm install -g @anthropic-ai/claude-code`)
- Canvas API access (for automatic material fetching)

### Setup
1. **Clone and configure:**
   ```bash
   git clone <repository-url>
   cd LearningAgent
   ```

2. **Create `.env` file:**
   ```bash
   CANVAS_TOKEN=your_canvas_api_token
   CANVAS_URL=https://your-institution.instructure.com
   ```

3. **Run it:**
   ```bash
   # Auto-detect mode from course materials
   ./run.sh COURSE-CODE 10

   # Specify a preset explicitly
   ./run.sh SYS-102 10 --mode study
   ./run.sh CS-201 8 --mode assignment
   ./run.sh MATH-301 6 --mode solver
   ```

## Usage Examples

### Study mode (exam prep)
```bash
./run.sh SYS-102 10 --mode study
```
**Generates one interactive page (`outputs/index.html`) with:**
- Hour-by-hour ADHD-friendly study schedule — checkable tasks with built-in focus timers
- Concept summary cards with analogies and common mistakes
- 30 flip-to-reveal flashcards (also exported as CSV for Anki import)
- Practice quiz with instant feedback and model answers
- One-page printable cheat sheet for exam day
- "Say it out loud" scripts with a practice timer
- Danger questions targeting examiner traps

### Assignment mode (project guidance)
```bash
./run.sh CS-301 12 --mode assignment
```
**Generates one interactive page (`outputs/assignments/index.html`) with:**
- Sidebar overview of all assignments with time estimates
- Step-by-step completion guide per assignment, with a persisted checklist
- Code scaffolds with a one-click copy button
- Relevant lecture material references
- Common mistakes and testing strategies
- Hints that reveal one at a time so you don't spoil the rest

### Solver mode (working solutions)
```bash
./run.sh PHYS-201 8 --mode solver
```
**Generates a runnable solution plus one interactive page (`outputs/solver/index.html`) with:**
- Complete working solution (ready to submit) in `outputs/solver/solution/`
- Tabbed comprehension guide: Big Picture, Task Analysis, Solution Notes, Code Walkthrough, Q&A Practice
- Code walkthrough with collapsible file/section explanations
- Self-check "questions you must be able to answer" with reveal-answer and a persisted "I can explain this" checklist
- 30-minute crash course for solution comprehension

## Command Options

```bash
./run.sh <course> <hours> [options]

Options:
  --mode <mode>     study | assignment | solver | auto (default: auto)
  --skip-fetch      Use existing materials, don't fetch from Canvas
  --source=local    Drop files manually instead of Canvas fetch

Examples:
  ./run.sh SEN-109 10                           # Auto-detect mode
  ./run.sh SEN-109 10 --mode study              # Study pack for exam
  ./run.sh SEN-109 10 --mode assignment         # Assignment guides
  ./run.sh SEN-109 10 --skip-fetch --mode study # Use existing files
```

## File Organization

### Input structure
```
course-materials/
├── COURSE-CODE/
│   ├── manifest.json           # Course metadata
│   ├── assignments.json        # Assignment details
│   ├── files/
│   │   ├── lecture-1.pdf      # Lecture slides
│   │   ├── lecture-2.pptx     # More lectures
│   │   └── lab-materials/     # Lab files
│   └── project/               # Manual file drop (--source=local)
```

### Output structure
```
course-materials/COURSE-CODE/outputs/
├── index.html                 # ★ START HERE — interactive study pack (study/auto mode)
├── 01_topic_map.json          # Internal working data — all course topics analyzed
├── 02_priority_list.json      # Internal working data — study priority order
├── 05a_flashcards.csv         # Anki import file (same cards as in index.html)
├── assignments/
│   └── index.html             # ★ START HERE — interactive assignment guide (assignment mode)
└── solver/
    ├── index.html              # ★ START HERE — interactive comprehension guide (solver mode)
    └── solution/               # Complete, runnable solution files
```
Each `index.html` is self-contained — open it directly in a browser, no server
or build step required. See [Interactive HTML output](#interactive-html-output)
above for what's in it.

## Canvas Integration

### Automatic fetching
Fetches from Canvas automatically:
- Lecture slides and course files
- Assignment briefs and rubrics
- Course syllabus and schedule
- Any linked external resources

### Manual file drop
For courses without Canvas access:
```bash
./run.sh COURSE-CODE 10 --source=local
# Drop files into: course-materials/COURSE-CODE/project/
# Supports: .pdf .pptx .txt .md .py .js .cpp .zip and more
```

## Supported File Types

- **Lectures:** PDF, PPTX, TXT, MD
- **Code:** PY, JS, TS, CPP, C, RS, JAVA
- **Documents:** PDF, TXT, MD, DOCX
- **Archives:** ZIP, TAR, RAR (auto-extracted)
- **Assignments:** Any text-based format

## Assessment Coverage

### Study mode maps to common assessment types:
- **Exams:** Comprehensive study schedules with practice questions
- **Quizzes:** Targeted concept summaries and flashcards
- **Projects:** Technical concept foundation for implementation
- **Labs:** Hands-on skill development with theoretical backing

### Assignment mode handles:
- **Programming projects** with code scaffolds
- **Research papers** with outline and source guidance
- **Problem sets** with step-by-step solutions
- **Design projects** with methodology and evaluation

## Customization

### Study hours
Adjust total study time based on course difficulty:
- **Light courses:** 4-6 hours
- **Standard courses:** 8-12 hours
- **Heavy courses:** 15-20 hours

### Learning preferences
Claude adapts output to different learning needs:
- Visual learners get diagrams and concept maps
- Auditory learners get speaking scripts and explanations
- Kinesthetic learners get hands-on exercises and building tasks

## Troubleshooting

### Common issues

**"No materials found"**
```bash
# Check if course materials were fetched
ls course-materials/COURSE-CODE/
# If empty, try manual fetch or check Canvas credentials
```

**"Canvas authentication failed"**
```bash
# Verify .env file exists and contains valid tokens
cat .env
# Test Canvas connection manually
```

**"Files not generated"**
- Ensure Claude Code CLI is installed and authenticated
- Check that course materials exist in expected directories
- Try running with `--skip-fetch` if materials already exist

### Getting help
1. Check the course-materials directory structure
2. Verify Canvas API permissions
3. Ensure all prerequisites are installed
4. Run with manual file drop mode for debugging

## Advanced Usage

### Batch processing
```bash
# Process multiple courses
for course in SYS-102 CS-201 MATH-301; do
  ./run.sh $course 10 --mode study
done
```

### Custom study plans
The schedule lives as data inside `outputs/index.html`, in a
`<script id="pack-data" type="application/json">` block. To tweak time blocks,
add personal notes, or adjust break timing, edit that JSON directly — the page
re-renders it on load, no build step needed. For bigger changes (different
topics, different hours), just re-run `./run.sh` — it regenerates the whole
pack, though note this resets saved progress (see
[Interactive HTML output](#interactive-html-output)).

### Integration with Anki
```bash
# Import flashcards
# 1. Open Anki
# 2. File → Import
# 3. Select: course-materials/COURSE-CODE/outputs/05a_flashcards.csv
# 4. Configure field mapping
# 5. Import and start daily review
```

## Contributing

This project is designed to be extensible:

- **New presets:** Add to `INSTRUCTIONS.md`
- **File types:** Extend parsing in `canvas_fetcher.py`
- **Learning styles:** Customize output templates
- **Assessment types:** Add new question formats

## License

[Specify your license here]

## Acknowledgments

Built with Claude Code for content analysis and generation. Designed for neurodivergent learners and evidence-based study techniques.

---

**Need help?** Open an issue or check the troubleshooting section above. Works best with well-organized course materials and clear learning objectives.
