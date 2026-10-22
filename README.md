# Study Guide Generator

Turn your course materials into one **interactive study page**, made by AI (Claude Code).

Give it lecture slides, PDFs or an assignment brief, from Canvas or your own files. You get a single `index.html` with a study schedule, interactive diagrams, flashcards, a quiz, a cheat sheet and timers. It's designed to be ADHD-friendly: short tasks, clear goals and built-in breaks.

## What you can make

| Mode | You give it | You get |
|---|---|---|
| `study` | Lecture slides / notes | Hour-by-hour plan, concept cards with diagrams, flashcards, quiz, cheat sheet |
| `assignment` | An assignment brief | A step-by-step guide with code scaffolds, hints and a checklist |
| `solver` | A brief + starter code | A working solution and a guide that teaches you how it works |
| `roadmap` | Just a topic, e.g. "Japanese" | A phase-by-phase learning plan with milestones and a study log |

## Setup (once)

You need **Python 3** and **[Claude Code](https://claude.com/claude-code)**.

```bash
npm install -g @anthropic-ai/claude-code
```
```bash
git clone https://github.com/meganing/study-guide-generator.git
```
```bash
cd study-guide-generator && cp env.example .env
```

If you use Canvas, open `.env` and fill in two lines. Get the token from **Canvas → Account → Settings → New Access Token**.

```
CANVAS_TOKEN=your_token_here
CANVAS_URL=https://your-school.instructure.com
```

No Canvas? Skip this step and use your own files (see below).

## Use it

```bash
./run.sh <course> <hours> --mode <mode>
```

It asks whether your files come from **Canvas** or your **own folder**. When it finishes, it opens the page in your browser.

**Examples**

```bash
./run.sh SEN-304 10 --mode study
```
```bash
./run.sh SEN-304 6 --mode assignment
```
```bash
./run.sh Japanese 5 --mode roadmap
```

- **`<course>`** is a Canvas course code, or any folder name you choose (for example `MY-PROJECT`).
- **`<hours>`** is how much time you have. For `roadmap`, it's hours per week.

### Using your own files

Choose **Local** when asked, then drop your files into the folder it shows: `course-materials/<course>/project/`. PDF, PPTX, TXT, MD and code files all work.

### Only part of a Canvas course

Add a filter to fetch just what you need:

| Flag | Fetches |
|---|---|
| `--module="Week 3"` | Only that module |
| `--search=Lab3` | Only items whose name contains "Lab3" |
| `--only=files,pages` | Only those types (`syllabus`, `modules`, `assignments`, `pages`, `files`) |
| `--since=2026-10-01` | Only items changed since that date |

To see a course's module names:
```bash
python3 canvas_fetcher.py SEN-304 --list
```

### Other options

| Flag | What it does |
|---|---|
| `--skip-fetch` | Reuse files you already have; don't download again |
| `--source=local` | Use your own files without being asked |

## Where to find your page

Open the `index.html` inside `course-materials/<course>/outputs/`:

| Mode | File |
|---|---|
| study | `outputs/index.html` |
| assignment | `outputs/assignments/index.html` |
| solver | `outputs/solver/index.html` (solution code in `outputs/solver/solution/`) |
| roadmap | `outputs/roadmap/index.html` |

It's one file, so double-click it. Your progress (ticked tasks, known flashcards) is saved in your browser. Flashcards are also saved as `05a_flashcards.csv` for Anki.

## Troubleshooting

| Problem | Fix |
|---|---|
| `CANVAS_TOKEN not set` | Create `.env` from `env.example` and add your token |
| `No course found` | The error lists your courses; use the code exactly as shown |
| `claude not found` | Install Claude Code with the `npm` command above |
| `No materials found` | Run once without `--skip-fetch`, or add files to `project/` |

## Updates

- **v1.4 (2026-10):** fetch part of a Canvas course; new design; interactive diagrams
- **v1.3 (2026-09):** roadmap mode for any topic or language
- **v1.2 (2026-09):** better page layout
- **v1.1 (2026-09):** assignment and project guides
- **v1.0 (2026-05):** first release with study, assignment and solver modes

## License

MIT. See [LICENSE](LICENSE).
