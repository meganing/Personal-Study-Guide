# Learning Agent — AI-Powered Study & Assignment Tool

An intelligent learning agent that automatically generates comprehensive, ADHD-friendly study materials from course content. Transforms lecture slides, PDFs, and assignment briefs into structured learning packs with schedules, flashcards, practice quizzes, and more.

## 🎯 What It Does

The Learning Agent analyzes your course materials and creates personalized study packs in three modes:

- **📚 Study Mode**: ADHD-friendly study schedules with concept summaries, flashcards, and practice materials
- **📝 Assignment Mode**: Step-by-step completion guides for individual assignments  
- **🔧 Solver Mode**: Complete working solutions with comprehension guides

## 🚀 Quick Start

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

3. **Run the agent:**
   ```bash
   # Auto-detect mode from course materials
   ./run.sh COURSE-CODE 10

   # Specify mode explicitly  
   ./run.sh SYS-102 10 --mode study
   ./run.sh CS-201 8 --mode assignment
   ./run.sh MATH-301 6 --mode solver
   ```

## 📖 Usage Examples

### Study Mode (Exam Prep)
```bash
./run.sh SYS-102 10 --mode study
```
**Creates:**
- Hour-by-hour ADHD-friendly study schedule
- Concept summaries with analogies and common mistakes
- 30 flashcards (CSV for Anki import)
- Practice quiz with model answers
- One-page cheat sheet for exam day
- "Say it out loud" scripts for active learning
- Danger questions targeting examiner traps

### Assignment Mode (Project Guidance)
```bash
./run.sh CS-301 12 --mode assignment
```
**Creates:**
- Overview of all assignments with time estimates
- Step-by-step completion guides for each assignment
- Code scaffolds and implementation approaches
- Relevant lecture material references
- Common mistakes and testing strategies

### Solver Mode (Working Solutions)
```bash
./run.sh PHYS-201 8 --mode solver
```
**Creates:**
- Complete working solution (ready to submit)
- Comprehensive understanding guide
- Code walkthrough with explanations
- Questions you must be able to answer
- 30-minute crash course for solution comprehension

## 🎮 Command Options

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

## 📁 File Organization

### Input Structure
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

### Output Structure
```
course-materials/COURSE-CODE/outputs/
├── 00_HOW_TO_USE.md           # Start here - usage guide
├── 01_topic_map.json          # All course topics analyzed
├── 02_priority_list.json      # Study priority order
├── 03_study_schedule.md       # Hour-by-hour plan
├── 04_concept_summaries.md    # Topic explanations
├── 05a_flashcards.csv         # Anki import file
├── 05b_practice_quiz.md       # Exam-style questions
├── 05c_cheat_sheet.md         # One-page reference
├── 05d_say_it_out_loud.md     # Speaking practice
├── 05e_danger_questions.md    # Hard examiner traps
├── assignments/               # Assignment-specific guides
└── solver/                    # Complete solutions
```

## 🧠 ADHD-Friendly Features

The study mode is specifically designed for ADHD learners:

- **25-minute task blocks** with clear end goals
- **Mandatory 10-minute breaks** every 50 minutes  
- **Direct action language** ("Open this file, read it twice")
- **Active learning tasks** (write, say aloud, draw)
- **Visual analogies** for abstract concepts
- **Common mistake warnings** to prevent confusion
- **Multiple learning modalities** (visual, auditory, kinesthetic)

## 🔧 Canvas Integration

### Automatic Fetching
The agent automatically fetches:
- Lecture slides and course files
- Assignment briefs and rubrics
- Course syllabus and schedule
- Any linked external resources

### Manual File Drop
For courses without Canvas access:
```bash
./run.sh COURSE-CODE 10 --source=local
# Drop files into: course-materials/COURSE-CODE/project/
# Supports: .pdf .pptx .txt .md .py .js .cpp .zip and more
```

## 📚 Supported File Types

- **Lectures:** PDF, PPTX, TXT, MD
- **Code:** PY, JS, TS, CPP, C, RS, JAVA
- **Documents:** PDF, TXT, MD, DOCX
- **Archives:** ZIP, TAR, RAR (auto-extracted)
- **Assignments:** Any text-based format

## 🎯 Assessment Coverage

### Study Mode Maps to Common Assessment Types:
- **Exams:** Comprehensive study schedules with practice questions
- **Quizzes:** Targeted concept summaries and flashcards  
- **Projects:** Technical concept foundation for implementation
- **Labs:** Hands-on skill development with theoretical backing

### Assignment Mode Handles:
- **Programming projects** with code scaffolds
- **Research papers** with outline and source guidance
- **Problem sets** with step-by-step solutions
- **Design projects** with methodology and evaluation

## ⚙️ Customization

### Study Hours
Adjust total study time based on course difficulty:
- **Light courses:** 4-6 hours
- **Standard courses:** 8-12 hours  
- **Heavy courses:** 15-20 hours

### Learning Preferences
The agent adapts to different learning needs:
- Visual learners get diagrams and concept maps
- Auditory learners get speaking scripts and explanations
- Kinesthetic learners get hands-on exercises and building tasks

## 🐛 Troubleshooting

### Common Issues

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

### Getting Help
1. Check the course-materials directory structure
2. Verify Canvas API permissions
3. Ensure all prerequisites are installed
4. Run with manual file drop mode for debugging

## 🔮 Advanced Usage

### Batch Processing
```bash
# Process multiple courses
for course in SYS-102 CS-201 MATH-301; do
  ./run.sh $course 10 --mode study
done
```

### Custom Study Plans
Edit the generated study schedule to fit your calendar:
```bash
# Generated schedule is in:
course-materials/COURSE-CODE/outputs/03_study_schedule.md
# Modify time blocks, add personal notes, adjust break timing
```

### Integration with Anki
```bash
# Import flashcards
# 1. Open Anki
# 2. File → Import
# 3. Select: course-materials/COURSE-CODE/outputs/05a_flashcards.csv
# 4. Configure field mapping
# 5. Import and start daily review
```

## 🤝 Contributing

This learning agent is designed to be extensible:

- **New modes:** Add to `LEARNING_AGENT.md` instruction set
- **File types:** Extend parsing in `canvas_fetcher.py`
- **Learning styles:** Customize output templates
- **Assessment types:** Add new question formats

## 📄 License

[Specify your license here]

## 🙏 Acknowledgments

Built with Claude Code for intelligent content analysis and generation. Designed for neurodivergent learners and evidence-based study techniques.

---

**Need help?** Open an issue or check the troubleshooting section above. The learning agent works best with well-organized course materials and clear learning objectives.