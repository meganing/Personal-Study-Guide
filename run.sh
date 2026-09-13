#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# run.sh — Personal Study Guide launcher
# See README.md for full usage guide
# ─────────────────────────────────────────────────────────────────────────────

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

banner()  { echo -e "\n${CYAN}${BOLD}▶ $1${RESET}"; }
ok()      { echo -e "${GREEN}✓ $1${RESET}"; }
warn()    { echo -e "${YELLOW}⚠ $1${RESET}"; }
die()     { echo -e "${RED}✗ $1${RESET}"; exit 1; }
info()    { echo -e "${DIM}  $1${RESET}"; }
divider() { echo -e "${DIM}────────────────────────────────────────${RESET}"; }

# ── Parse args ────────────────────────────────────────────────────────────────
# For every mode except roadmap: COURSE is a course-materials folder label,
# HOURS is study/work hours. For roadmap mode: COURSE is the TOPIC (e.g.
# "Japanese"), HOURS is WEEKLY_HOURS (hours/week available).
COURSE="${1:-}"
HOURS="${2:-5}"
MODE="auto"
SKIP_FETCH=false
SOURCE=""   # canvas | local — only asked for assignment/solver modes
RM_TYPE=""       # roadmap: subject | language
RM_CURRENT=""    # roadmap: current level
RM_TARGET=""     # roadmap: target level
RM_DURATION=""   # roadmap: e.g. "2 months", "1 year"

for i in $(seq 1 $#); do
  case "${!i}" in
    --mode)
      next=$((i+1)); MODE="${!next}" ;;
    --mode=*)
      MODE="${!i#--mode=}" ;;
    --skip-fetch)
      SKIP_FETCH=true ;;
    --source=*)
      SOURCE="${!i#--source=}" ;;
    --type=*)
      RM_TYPE="${!i#--type=}" ;;
    --current=*)
      RM_CURRENT="${!i#--current=}" ;;
    --target=*)
      RM_TARGET="${!i#--target=}" ;;
    --duration=*)
      RM_DURATION="${!i#--duration=}" ;;
  esac
done

# ── Help / usage ──────────────────────────────────────────────────────────────
if [[ -z "$COURSE" || "$COURSE" == "--help" || "$COURSE" == "-h" ]]; then
  echo ""
  echo -e "${BOLD}Personal Study Guide${RESET} — Claude-powered study & assignment tool"
  echo ""
  echo -e "${BOLD}Usage:${RESET}"
  echo -e "  ./run.sh <course> <hours> [--mode <mode>] [--skip-fetch]"
  echo -e "  ./run.sh <topic> <weekly-hours> --mode roadmap [--type=...] [--current=...] [--target=...] [--duration=...]"
  echo ""
  echo -e "${BOLD}Modes:${RESET}"
  echo -e "  study       ADHD-friendly study pack from lecture materials"
  echo -e "  assignment  Step-by-step completion guide per assignment"
  echo -e "  solver      Working solution + comprehension guide"
  echo -e "  roadmap     Learning roadmap for a topic/language you name yourself — no course files needed"
  echo -e "  (omit)      Auto-detect from files present (study/assignment/solver only)"
  echo ""
  echo -e "${BOLD}Examples:${RESET}"
  echo -e "  ./run.sh SEN-109 10 --mode study"
  echo -e "  ./run.sh SEN-109 10 --mode assignment"
  echo -e "  ./run.sh SEN-109 10 --mode solver"
  echo -e "  ./run.sh SEN-109 10 --skip-fetch --mode study"
  echo -e "  ./run.sh Japanese 5 --mode roadmap"
  echo -e "  ./run.sh \"Machine Learning\" 6 --mode roadmap --type=subject --current=\"knows Python\" --target=\"ship a small ML project\" --duration=\"3 months\""
  echo ""
  echo -e "  See ${BOLD}README.md${RESET} for the full guide."
  echo ""
  exit 0
fi

# Validate mode
if [[ "$MODE" != "auto" && "$MODE" != "study" && "$MODE" != "assignment" && \
      "$MODE" != "solver" && "$MODE" != "roadmap" ]]; then
  die "Invalid mode '$MODE'. Use: study | assignment | solver | roadmap"
fi

SAFE_COURSE="${COURSE// /_}"
MATERIALS_DIR="course-materials/${SAFE_COURSE}"
OUTPUTS_DIR="${MATERIALS_DIR}/outputs"

# ── Load .env ─────────────────────────────────────────────────────────────────
if [[ -f ".env" ]]; then
  set -a; source .env; set +a
  ok "Loaded .env"
else
  warn ".env not found — relying on shell environment variables"
fi

# ── Pre-flight checks ─────────────────────────────────────────────────────────
banner "Pre-flight checks"
command -v python3 &>/dev/null || die "python3 not found. Install Python 3."
command -v claude  &>/dev/null || die "claude not found. Run: npm install -g @anthropic-ai/claude-code"
ok "All checks passed"

if [[ "$MODE" == "roadmap" ]]; then
  # ── Step 1: Roadmap details (no course files involved at all) ────────────────
  banner "Step 1/2 — Roadmap details"

  if [[ -z "$RM_TYPE" ]]; then
    echo ""
    divider
    echo -e "${BOLD}  Is \"${COURSE}\" a subject or a language?${RESET}"
    divider
    echo -e "  ${CYAN}1)${RESET} Subject  — e.g. Machine Learning, Guitar, Calculus"
    echo -e "  ${CYAN}2)${RESET} Language — e.g. Japanese, Spanish"
    divider
    echo ""
    read -rp "  Enter 1 or 2: " type_choice
    case "$type_choice" in
      1) RM_TYPE="subject"  ;;
      2) RM_TYPE="language" ;;
      *) die "Invalid choice. Enter 1 or 2." ;;
    esac
    echo ""
  fi
  if [[ "$RM_TYPE" != "subject" && "$RM_TYPE" != "language" ]]; then
    die "Invalid --type '$RM_TYPE'. Use: subject | language"
  fi

  if [[ "$RM_TYPE" == "language" ]]; then
    CURRENT_PROMPT="  Current level (e.g. \"complete beginner\", \"know basic greetings\", \"can hold simple conversations\"): "
    TARGET_PROMPT="  Target level / goal (e.g. \"conversational for travel\", \"JLPT N3\", \"fluent enough to work in it\"): "
  else
    CURRENT_PROMPT="  Current level (e.g. \"complete beginner\", \"know the basics\", \"comfortable with fundamentals\"): "
    TARGET_PROMPT="  Target level / goal (e.g. \"can build a small project\", \"job-ready\", \"pass the certification exam\"): "
  fi

  [[ -z "$RM_CURRENT" ]]  && read -rp "$CURRENT_PROMPT" RM_CURRENT
  [[ -z "$RM_TARGET" ]]   && read -rp "$TARGET_PROMPT" RM_TARGET
  [[ -z "$RM_DURATION" ]] && read -rp "  Duration (e.g. \"2 months\", \"1 year\"): " RM_DURATION
  echo ""

  [[ -z "$RM_CURRENT"  ]] && die "Current level is required for roadmap mode."
  [[ -z "$RM_TARGET"   ]] && die "Target level is required for roadmap mode."
  [[ -z "$RM_DURATION" ]] && die "Duration is required for roadmap mode."

  ok "Topic: ${COURSE} (${RM_TYPE}) · ${RM_CURRENT} → ${RM_TARGET} · ${RM_DURATION} · ${HOURS}h/week"

else
  # ── Ask file source (all other modes, unless --skip-fetch or --source set) ───
  if [[ "$SKIP_FETCH" == false ]] && [[ -z "$SOURCE" ]]; then

    echo ""
    divider
    echo -e "${BOLD}  Where are your course files?${RESET}"
    divider
    echo -e "  ${CYAN}1)${RESET} Canvas  — fetch automatically from Canvas"
    echo -e "  ${CYAN}2)${RESET} Local   — I will drop the files in myself"
    divider
    echo ""
    read -rp "  Enter 1 or 2: " source_choice

    case "$source_choice" in
      1) SOURCE="canvas" ;;
      2) SOURCE="local"  ;;
      *) die "Invalid choice. Enter 1 or 2." ;;
    esac
    echo ""
  fi

  # ── Step 1A: Canvas fetch ────────────────────────────────────────────────────
  if [[ "$SKIP_FETCH" == false && "$SOURCE" == "canvas" ]]; then
    banner "Step 1/2 — Fetching materials from Canvas"

    [[ -z "${CANVAS_TOKEN:-}" ]] && die "CANVAS_TOKEN not set. Add it to .env"
    [[ -z "${CANVAS_URL:-}"   ]] && die "CANVAS_URL not set. Add it to .env"
    python3 -c "import requests" 2>/dev/null || { warn "Installing requests..."; pip install requests -q; }

    # Pass --include-assignment-files for assignment/solver modes
    if [[ "$MODE" == "assignment" || "$MODE" == "solver" ]]; then
      python3 canvas_fetcher.py "$COURSE" --hours "$HOURS" --include-assignment-files
    else
      python3 canvas_fetcher.py "$COURSE" --hours "$HOURS"
    fi

    ok "Canvas materials saved to ${MATERIALS_DIR}/"

  # ── Step 1B: Local drop ──────────────────────────────────────────────────────
  elif [[ "$SOURCE" == "local" ]]; then
    banner "Step 1/2 — Local file setup"

    DROP_DIR="${MATERIALS_DIR}/project"
    mkdir -p "$DROP_DIR"

    echo ""
    echo -e "  ${BOLD}Drop your project/assignment files into this folder:${RESET}"
    echo ""
    echo -e "  ${CYAN}${BOLD}  $(pwd)/${DROP_DIR}/${RESET}"
    echo ""
    info "Include: assignment brief, starter code, any provided files"
    info "Supported: .py .rs .c .cpp .js .ts .pdf .txt .md .zip and more"
    echo ""
    divider
    read -rp "  Press Enter when your files are in the folder..." _
    divider
    echo ""

    # Check something was actually dropped
    file_count=$(find "$DROP_DIR" -type f | wc -l | tr -d ' ')
    if [[ "$file_count" -eq 0 ]]; then
      die "No files found in ${DROP_DIR}/. Add your files and try again."
    fi
    ok "Found ${file_count} file(s) in ${DROP_DIR}/"

  elif [[ "$SKIP_FETCH" == true ]]; then
    banner "Step 1/2 — Skipping fetch (--skip-fetch)"
    [[ -d "$MATERIALS_DIR" ]] || die "No materials found at ${MATERIALS_DIR}/"
    ok "Using existing materials in ${MATERIALS_DIR}/"
  fi
fi

# ── Step 2: Run agent ─────────────────────────────────────────────────────────
if [[ "$MODE" == "roadmap" ]]; then
  banner "Step 2/2 — Generating roadmap"
  mkdir -p "${OUTPUTS_DIR}/roadmap"
  AGENT_PROMPT="Read INSTRUCTIONS.md and execute every instruction in the MODE: roadmap section exactly as written. Do not explain, do not summarise, do not ask questions — just execute all phases now. INPUTS: MODE: roadmap TOPIC: ${COURSE} TOPIC_TYPE: ${RM_TYPE} CURRENT_LEVEL: ${RM_CURRENT} TARGET_LEVEL: ${RM_TARGET} DURATION: ${RM_DURATION} WEEKLY_HOURS: ${HOURS} Write the output file to: ${OUTPUTS_DIR}/roadmap/index.html Begin with [ROADMAP] PHASE 0 immediately."
else
  if [[ "$MODE" == "auto" ]]; then
    banner "Step 2/2 — Generating study pack (auto-detecting mode)"
    MODE_LINE="Auto-detect the mode from the files present in the course folder."
  else
    banner "Step 2/2 — Generating study pack (mode: ${MODE})"
    MODE_LINE="The mode is: ${MODE}. Do not auto-detect — use this mode exactly."
  fi

  mkdir -p "$OUTPUTS_DIR"
  mkdir -p "${OUTPUTS_DIR}/assignments"

  AGENT_PROMPT="Read INSTRUCTIONS.md and execute every instruction in it exactly as written. Do not explain, do not summarise, do not ask questions — just execute all phases now. INPUTS: Course materials folder: ${MATERIALS_DIR}/ Study/work hours: ${HOURS} ${MODE_LINE} Write all output files to: ${OUTPUTS_DIR}/ Write assignment files to: ${OUTPUTS_DIR}/assignments/ Write solver files to: ${OUTPUTS_DIR}/solver/ If source is local, project files are in: ${MATERIALS_DIR}/project/ Begin with Step 0 immediately."
fi

# Uses your Claude Code default model (whatever you've set via `/model`) unless
# CLAUDE_MODEL is set in .env or the shell environment to pin a specific one.
CLAUDE_ARGS=(--permission-mode acceptEdits)
if [[ -n "${CLAUDE_MODEL:-}" ]]; then
  CLAUDE_ARGS+=(--model "$CLAUDE_MODEL")
fi

# --permission-mode acceptEdits: this runs non-interactively (prompt piped via
# stdin, no TTY), so Claude can't ask for per-file write approval. acceptEdits
# lets it write files without prompting while still gating other tool use —
# scoped to this script's job of generating files under ${OUTPUTS_DIR}/.
echo "$AGENT_PROMPT" | claude "${CLAUDE_ARGS[@]}"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}════════════════════════════════════════${RESET}"
echo -e "${GREEN}${BOLD}  🎉 Done! Open this file first:${RESET}"
echo -e "${GREEN}${BOLD}════════════════════════════════════════${RESET}"
echo ""

START_FILE=""

if [[ "$MODE" == "study" || "$MODE" == "auto" ]]; then
  START_FILE="${OUTPUTS_DIR}/index.html"
  echo -e "  ${BOLD}→ START HERE:${RESET}  ${START_FILE}"
  echo ""
  echo -e "  ${DIM}Open it directly in any browser — no server needed."
  echo -e "  Flashcards also exported for Anki: ${OUTPUTS_DIR}/05a_flashcards.csv${RESET}"
fi

if [[ "$MODE" == "assignment" ]]; then
  START_FILE="${OUTPUTS_DIR}/assignments/index.html"
  echo -e "  ${BOLD}→ START HERE:${RESET}  ${START_FILE}"
  echo ""
  echo -e "  ${DIM}Open it directly in any browser — no server needed.${RESET}"
fi

if [[ "$MODE" == "solver" ]]; then
  START_FILE="${OUTPUTS_DIR}/solver/index.html"
  echo -e "  ${BOLD}→ START HERE:${RESET}  ${START_FILE}"
  echo ""
  echo -e "  ${DIM}Solution:      ${OUTPUTS_DIR}/solver/solution/"
  echo -e "  Open the guide directly in any browser — no server needed.${RESET}"
fi

if [[ "$MODE" == "roadmap" ]]; then
  START_FILE="${OUTPUTS_DIR}/roadmap/index.html"
  echo -e "  ${BOLD}→ START HERE:${RESET}  ${START_FILE}"
  echo ""
  echo -e "  ${DIM}Open it directly in any browser — no server needed."
  echo -e "  Log your study sessions on the 🔥 Study log tab as you go.${RESET}"
fi

echo ""

# ── Open it ───────────────────────────────────────────────────────────────────
if [[ -f "$START_FILE" ]]; then
  if command -v open &>/dev/null; then
    open "$START_FILE"
  elif command -v xdg-open &>/dev/null; then
    xdg-open "$START_FILE" &>/dev/null &
  fi
fi