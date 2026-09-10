# Course Materials Directory

This directory contains example course structures and generated study materials.

## Structure

```
course-materials/
├── COURSE-CODE/
│   ├── manifest.json          # Course metadata
│   ├── assignments.json       # Assignment details  
│   ├── syllabus.txt          # Course syllabus
│   ├── modules.json          # Course structure
│   ├── files/                # Course content goes here (PDFs, slides, etc.)
│   └── outputs/              # Generated study materials
│       ├── 00_HOW_TO_USE.md
│       ├── 01_topic_map.json
│       ├── 03_study_schedule.md
│       ├── 04_concept_summaries.md
│       ├── 05a_flashcards.csv
│       └── ...
```

## Examples Included

- **SYS-102**: Computer Architecture course with full study pack
- **SEN-109**: Rust Systems Programming course structure

## Usage

1. Run `./run.sh COURSE-CODE HOURS` to generate materials
2. Course content files are automatically fetched from Canvas
3. Generated study materials appear in `outputs/` directory
4. All files in `files/` and `outputs/` are gitignored for privacy

## Privacy Note

Actual course materials (PDFs, slides, videos) are not included in this repository to protect copyright and student privacy.