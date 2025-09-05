# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

This repository is designed for analyzing scientific podcasts about cancer and diet research. The primary goal is to fact-check claims made in podcast episodes against peer-reviewed literature and build a knowledge base of verified scientific information.

## Repository Structure

- `episodes/` - Organized by topic areas (e.g., `cancer-and-keto/`, `nutrition-myths/`)
  - Each topic directory contains episode analysis files and all related assets
- `research/` - Supporting research papers, citations, and scientific references  
- `docs/` - Documentation, methodology, and analysis frameworks

## Source Review Guidelines

### Using the LLM Source Review System

When conducting source reviews for claim research documents, **always reference and follow the standardized instructions in `llm-review-sources-instructions.md`**.

#### Key Requirements:
- Use neutral, evidence-based evaluation (no bias toward medical consensus)
- Focus on methodology quality over authority/prestige
- Assess only peer-reviewed literature
- Follow the standardized table format for consistency

#### Automation Available:
- Use `review_sources.sh` script for basic DOI resolution and table generation
- Manual review required for detailed quality/relevance assessments
- Ensure all references include DOI links where available

#### Source Review Table Format:
```markdown
## Sources Review

| Reference | Study Type | Sample/Population | Quality | Relevance | Key Finding | Limitations | Support |
|-----------|------------|-------------------|---------|-----------|-------------|-------------|---------|
```

#### Quality Assessment Criteria:
- **High**: Large samples, appropriate controls, low bias, reputable journals
- **Moderate**: Adequate methodology with some limitations
- **Low**: Small samples, significant methodological flaws, high bias

#### Support Classification:
- **Supports**: Clear evidence supporting the claim
- **Mixed**: Both supporting and contradictory findings
- **Contradicts**: Clear evidence against the claim
- **Inconclusive**: Insufficient evidence

### File Organization Guidelines

**Claim Research Files:**
- Name format: `claim-##-short-description.md`
- Must include: References section with DOI links, Sources Review table
- Append Sources Review after References section

**Reference Standards:**
- Format: `Author et al. (Year). "Title." *Journal* Volume:Pages. https://doi.org/...`
- Include DOI links for all sources
- Use consistent citation formatting

## Git Workflow

This is a content-focused repository where changes typically involve:
- Adding new episode analyses
- Updating research findings with source reviews
- Expanding documentation

The project uses standard git practices with descriptive commit messages for tracking research progress.
