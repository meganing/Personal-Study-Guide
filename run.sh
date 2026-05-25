#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# run.sh — study-pack-generator launcher
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
COURSE="${1:-}"
HOURS="${2:-5}"
MODE="auto"
SKIP_FETCH=false
SOURCE=""   # canvas | local

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
  esac
done

# ── Help / usage ──────────────────────────────────────────────────────────────
if [[ -z "$COURSE" || "$COURSE" == "--help" || "$COURSE" == "-h" ]]; then
  echo ""
  echo -e "${BOLD}study-pack-generator${RESET} — Claude-powered study & assignment tool"
  echo ""
  echo -e "${BOLD}Usage:${RESET}"
  echo -e "  ./run.sh <course> <hours> [--mode <mode>] [--skip-fetch]"
  echo ""
  echo -e "${BOLD}Modes:${RESET}"
  echo -e "  study       ADHD-friendly study pack from lecture materials"
  echo -e "  assignment  Step-by-step completion guide per assignment"
  echo -e "  solver      Working solution + comprehension guide"
  echo -e "  (omit)      Auto-detect from files present"
  echo ""
  echo -e "${BOLD}Examples:${RESET}"
  echo -e "  ./run.sh SEN-109 10 --mode study"
  echo -e "  ./run.sh SEN-109 10 --mode assignment"
  echo -e "  ./run.sh SEN-109 10 --mode solver"
  echo -e "  ./run.sh SEN-109 10 --skip-fetch --mode study"
  echo ""
  echo -e "  See ${BOLD}README.md${RESET} for the full guide."
  echo ""
  exit 0
fi

# Validate mode
if [[ "$MODE" != "auto" && "$MODE" != "study" && \
      "$MODE" != "assignment" && "$MODE" != "solver" ]]; then
  die "Invalid mode '$MODE'. Use: study | assignment | solver"
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

# ── Ask file source (all modes unless --skip-fetch or --source already set) ───
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

# ── Step 1A: Canvas fetch ─────────────────────────────────────────────────────
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

# ── Step 1B: Local drop ───────────────────────────────────────────────────────
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

# ── Step 2: Run agent ─────────────────────────────────────────────────────────
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

echo "$AGENT_PROMPT" | claude --model claude-sonnet-4-20250514

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}════════════════════════════════════════${RESET}"
echo -e "${GREEN}${BOLD}  🎉 Done! Open this file first:${RESET}"
echo -e "${GREEN}${BOLD}════════════════════════════════════════${RESET}"
echo ""

if [[ "$MODE" == "study" || "$MODE" == "auto" ]]; then
  echo -e "  ${BOLD}→ START HERE:${RESET}  ${OUTPUTS_DIR}/00_HOW_TO_USE.md"
  echo ""
  echo -e "  ${DIM}Schedule:      ${OUTPUTS_DIR}/03_study_schedule.md"
  echo -e "  Concepts:      ${OUTPUTS_DIR}/04_concept_summaries.md"
  echo -e "  Flashcards:    ${OUTPUTS_DIR}/05a_flashcards.csv"
  echo -e "  Cheat sheet:   ${OUTPUTS_DIR}/05c_cheat_sheet.md"
  echo -e "  Danger Qs:     ${OUTPUTS_DIR}/05e_danger_questions.md${RESET}"
fi

if [[ "$MODE" == "assignment" ]]; then
  echo -e "  ${BOLD}→ START HERE:${RESET}  ${OUTPUTS_DIR}/assignments/00_HOW_TO_USE.md"
  echo ""
  echo -e "  ${DIM}Overview:      ${OUTPUTS_DIR}/assignments/00_assignment_overview.md"
  echo -e "  Guides:        ${OUTPUTS_DIR}/assignments/assignment_*.md${RESET}"
fi

if [[ "$MODE" == "solver" ]]; then
  echo -e "  ${BOLD}→ START HERE:${RESET}  ${OUTPUTS_DIR}/solver/00_HOW_TO_USE.md"
  echo ""
  echo -e "  ${DIM}Solution:      ${OUTPUTS_DIR}/solver/solution/"
  echo -e "  Understand it: ${OUTPUTS_DIR}/solver/02_comprehension_guide.md${RESET}"
fi

echo ""