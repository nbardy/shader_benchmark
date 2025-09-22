# Shader Benchmark Technical Documentation

This directory contains comprehensive technical documentation for the Shader Benchmark project, focusing on the recent scoring system overhaul and implementation details.

## Documentation Overview

### 📋 [Progress and Goals](progress_and_goals.md)
**Project overview, accomplishments, and future roadmap**
- Complete scoring system overhaul summary
- Architecture overview and technical achievements  
- Current goals and success metrics
- Key learnings and next phase planning

### 🔧 [Scoring System Technical](scoring_system_technical.md) 
**Detailed technical implementation of the 5-score evaluation system**
- Template system architecture (`critic_template.py`)
- XML parsing implementation (`judge.py`)
- Critic file format specifications
- Performance characteristics and error handling

### 🧪 [Testing Guide](testing_guide.md)
**Comprehensive testing procedures and troubleshooting**
- Environment setup (venv, uv, pyenv)
- Component testing procedures
- End-to-end pipeline validation
- Performance benchmarking and debugging

## Quick Navigation

### For Developers
- **Getting Started**: See [Testing Guide - Quick Start Testing](testing_guide.md#quick-start-testing)
- **Implementation Details**: See [Scoring System Technical](scoring_system_technical.md#system-architecture)
- **Project Status**: See [Progress and Goals](progress_and_goals.md#recent-major-accomplishments)

### For Researchers  
- **System Overview**: See [Progress and Goals - Architecture](progress_and_goals.md#architecture-overview)
- **Evaluation Framework**: See [Scoring System Technical - Template Structure](scoring_system_technical.md#template-structure)
- **Performance Metrics**: See [Progress and Goals - Metrics](progress_and_goals.md#metrics-and-success-criteria)

### For Operations
- **Environment Setup**: See [Testing Guide - Environment Setup](testing_guide.md#environment-setup)
- **Troubleshooting**: See [Testing Guide - Troubleshooting](testing_guide.md#troubleshooting)
- **Continuous Integration**: See [Testing Guide - Continuous Integration](testing_guide.md#continuous-integration-testing)

## Key Achievements Summary

### ✅ Scoring System Overhaul (July 2025)
- **10x Granularity**: Migrated from 1-10 to 1-100 scale
- **100 File Conversion**: All critic files converted to structured format
- **XML Integration**: `<scores><S1>X</S1>...</scores>` parsing implemented
- **Template System**: Structured evaluation with preserved mathematical complexity

### ✅ Technical Implementation  
- **Template Engine**: `critic_template.py` with robust parsing
- **Judge Integration**: Enhanced `judge.py` with XML score extraction
- **Report System**: Updated `generate_report.py` for 1-100 scale display
- **Pipeline Integration**: Complete `main.py` template system integration

### ✅ Quality Assurance
- **Information Preservation**: All mathematical formulas and tolerances maintained
- **Backward Compatibility**: Legacy format support during transition
- **Comprehensive Testing**: Component, integration, and end-to-end validation
- **Documentation Coverage**: Complete technical specifications and guides

## System Architecture

```
Scoring System Flow:
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ Critic Template │ -> │ Judge Evaluation │ -> │ Report Generation│
│ (Structured)    │    │ (XML Parsing)    │    │ (1-100 Scale)   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
    ┌────────────┐         ┌────────────┐         ┌──────────────┐
    │ parse_     │         │ _parse_    │         │ _format_     │
    │ questions()│         │ scores()   │         │ scores_table()│
    └────────────┘         └────────────┘         └──────────────┘
```

## Change Log

### July 31, 2025
- Created comprehensive technical documentation
- Documented scoring system overhaul implementation
- Added testing procedures and troubleshooting guides
- Updated main CLAUDE.md with documentation references

### July 30, 2025  
- Completed scoring system overhaul
- Implemented template-based evaluation system
- Converted all 100 critic files to structured format
- Integrated XML parsing with 1-100 scale

---

*Documentation Version: 1.0*  
*Last Updated: July 31, 2025*