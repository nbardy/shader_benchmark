# Scoring System Technical Documentation

## Overview

The Shader Benchmark scoring system underwent a complete overhaul to provide granular, structured evaluation of mathematical visualizations. This document details the technical implementation of the 5-score system with 1-100 scale granularity.

## System Architecture

### Core Components

```python
shader_benchmark/llm_harness/
├── critic_template.py          # Template parsing and formatting
├── judge.py                    # Score extraction and API integration  
├── main.py                     # Pipeline integration
└── generate_report.py          # Report formatting with new scale
```

## Template System (`critic_template.py`)

### Class Structure

```python
class CriticTemplate:
    def __init__(self):
        self.template_string = """..."""  # Full evaluation template
        
    def parse_questions(self, critic_content: str) -> Dict[str, str]
    def format_critic_prompt(self, critic_path: Path, request_path: Path) -> str
    def validate_critic_format(self, critic_content: str) -> bool
```

### Parsing Algorithm

The `parse_questions()` method uses a sophisticated regex-based approach:

```python
def parse_questions(self, critic_content: str) -> Dict[str, str]:
    questions = {}
    
    # Primary format: __SECTION_NAME__
    section_patterns = [
        r'__MATHEMATICAL_ACCURACY__(.*?)(?=__[A-Z_]+__|$)',
        r'__VISUAL_IMPLEMENTATION__(.*?)(?=__[A-Z_]+__|$)', 
        r'__COMPLETENESS_AND_SPECIFICATIONS__(.*?)(?=__[A-Z_]+__|$)'
    ]
    
    # Fallback formats for legacy compatibility
    legacy_patterns = [
        r'QUESTION\s*1[:\s]*(.*?)(?=QUESTION\s*[23]|$)',
        r'QUESTION\s*2[:\s]*(.*?)(?=QUESTION\s*[3]|$)',
        r'QUESTION\s*3[:\s]*(.*?)$'
    ]
```

### Template Structure

The evaluation template follows a structured format:

```
You are evaluating a mathematical visualization shader...

**SECTION 1: MATHEMATICAL ACCURACY**
{question_1}

**SECTION 2: VISUAL IMPLEMENTATION** 
{question_2}

**SECTION 3: COMPLETENESS & SPECIFICATIONS**
{question_3}

Provide scores (1-100) for each category:
S1: Problem Accuracy (Generic)
S2: Visual Quality (Generic)  
S3: Mathematical Accuracy Section
S4: Visual Implementation Section
S5: Completeness & Specifications Section

Format: <scores><S1>X</S1><S2>X</S2><S3>X</S3><S4>X</S4><S5>X</S5></scores>
```

## Score Parsing (`judge.py`)

### XML Parsing Implementation

```python
def _parse_scores(self, response_text: str) -> List[int]:
    """Parse scores from judge response - supports both XML and legacy formats"""
    
    # Primary: XML format
    scores_xml_pattern = r'<scores>(.*?)</scores>'
    xml_match = re.search(scores_xml_pattern, response_text, re.DOTALL)
    
    if xml_match:
        xml_content = xml_match.group(1)
        scores = []
        
        for i in range(1, 6):
            score_pattern = rf'<S{i}>(\d+)</S{i}>'
            score_match = re.search(score_pattern, xml_content)
            if score_match:
                score = int(score_match.group(1))
                # Clamp to 1-100 range
                score = max(1, min(100, score))
                scores.append(score)
    
    # Fallback: Legacy format
    legacy_pattern = r'SCORES:\s*\[([^\]]+)\]'
    legacy_match = re.search(legacy_pattern, response_text)
    if legacy_match and not scores:
        score_values = [int(x.strip()) for x in legacy_match.group(1).split(',')]
        # Convert 1-10 scale to 1-100 scale  
        scores = [max(1, min(100, score * 10)) for score in score_values]
```

### API Integration

```python
async def evaluate_with_template(self, critic_path: Path, request_path: Path, 
                                result_image_path: Path) -> List[int]:
    """Evaluate using structured critic template system"""
    
    # Generate the full prompt using template
    judge_prompt = self.critic_template.format_critic_prompt(critic_path, request_path)
    return await self.evaluate(judge_prompt, result_image_path)
```

## Critic File Format

### Structured Format

Each critic file follows the three-section structure:

```
__MATHEMATICAL_ACCURACY__
Topological Structure Analysis:
- Exactly three separate, mutually linked tori visible representing pre-images...
- Mathematical relationship between S³ and S² correctly visualized?
- Proper vertex connections with exactly 3 edges meeting at each vertex?

Spectral Analysis Requirements:
- Power spectrum containing spikes at spatial frequencies f_n = b^n Hz...
- FFT spectral-spike test identifying first 10 theoretical peak frequencies...

__VISUAL_IMPLEMENTATION__
Curve Rendering Standards:
- Orange stroke with hue ≈ 30° and saturation > 0.9 for proper color identification
- Stroke width median = 3 ± 0.3 pixels maintaining visual consistency
- Continuously rough appearance without any smooth sections visible

Graph Layout and Presentation:
- Proper scale and centering with y-range occupying 80 ± 10% of canvas height
- Axes lines rendered in grey (RGB ≈ 144) with 1 ± 0.2 pixel thickness

__COMPLETENESS_AND_SPECIFICATIONS__
Required Function Elements:
- Complete Weierstrass "Monster" Function visualization demonstrating all properties
- Mathematical accuracy verified through Hölder exponent and spectral analysis
- Visual quality meeting all specified styling and presentation requirements

Technical Specification Compliance:
- All mathematical ground-truth requirements satisfied within tolerance
- Image processing capability for PNG to linear-RGB conversion
- Canny-edge detection compatibility for orange stroke isolation
```

### Information Density Preservation

The conversion process preserved:
- **Mathematical Formulas**: Complex equations like `α_theory = -ln(a)/ln(b) = -ln(0.5)/ln(3) ≈ 0.630930`
- **Technical Tolerances**: Precise measurements like `± 0.3 pixels`, `80 ± 10%`
- **Color Specifications**: Exact requirements like `hue ≈ 30°`, `RGB ≈ 144`
- **Mathematical Relationships**: Topological constraints and geometric properties

## Report Generation (`generate_report.py`)

### Scale Display Updates

```python
def _format_scores_table(self, scores: List[int]) -> str:
    """Format scores as a markdown table."""
    table = "| Category | Score |\n|----------|-------|\n"
    for category, score in zip(self.SCORE_CATEGORIES, scores):
        table += f"| {category} | {score}/100 |\n"  # Updated from /10
    
    total = sum(scores)
    avg = total / len(scores)
    table += f"| **Total** | **{total}/500** |\n"        # Updated from /50
    table += f"| **Average** | **{avg:.1f}/100** |\n"     # Updated from /10
```

### Summary Statistics

```python
# Average scores display
for category, avg_score in zip(self.SCORE_CATEGORIES, stats['avg_scores']):
    section += f"| {category} | {avg_score:.1f}/100 |\n"  # Updated scale

# Performance highlights  
section += f"(Total: {sum(stats['best_test'].scores)}/500)  \n"  # Updated total
```

## Testing and Validation

### End-to-End Testing

```python
# Test new scoring system
async def test_judge():
    judge = Judge()
    scores = await judge.evaluate_with_template(critic_path, request_path, image_path)
    # Expects: [1, 1, 1, 1, 1] on 1-100 scale
```

### Validation Results

- **XML Parsing**: Successfully extracts `<S1>85</S1><S2>72</S2>...` format
- **Scale Validation**: Enforces 1-100 range with clamping
- **Backward Compatibility**: Handles legacy `SCORES: [X,X,X,X,X]` format
- **Template Integration**: Processes structured critic sections correctly

## Performance Characteristics

### Parsing Performance
- **Section Extraction**: O(n) regex matching across file content
- **XML Processing**: Lightweight parsing for 5 score values
- **Template Generation**: String substitution with 3 sections

### Memory Usage
- **Template Storage**: Single template string (~2KB)
- **Critic Content**: Individual files range 1-5KB
- **Score Processing**: Minimal overhead for 5-integer arrays

### Scalability
- **Batch Processing**: Supports parallel evaluation across problems
- **File I/O**: Efficient path-based critic loading
- **API Rate Limiting**: Async implementation prevents throttling

## Error Handling

### Parsing Failures
```python
def parse_questions(self, critic_content: str) -> Dict[str, str]:
    try:
        # Primary parsing attempt
        return structured_sections
    except Exception:
        # Fallback to legacy format
        return legacy_sections
```

### Score Validation
```python
def _parse_scores(self, response_text: str) -> List[int]:
    # Clamp scores to valid range
    score = max(1, min(100, score))
    
    # Ensure exactly 5 scores
    if len(scores) != 5:
        return [1, 1, 1, 1, 1]  # Safe fallback
```

### Template Validation
```python
def validate_critic_format(self, critic_content: str) -> bool:
    required_sections = ['__MATHEMATICAL_ACCURACY__', 
                        '__VISUAL_IMPLEMENTATION__',
                        '__COMPLETENESS_AND_SPECIFICATIONS__']
    return all(section in critic_content for section in required_sections)
```

## Migration Strategy

### Conversion Process
1. **Format Detection**: Identify legacy vs. structured format
2. **Content Extraction**: Parse existing evaluation criteria
3. **Section Mapping**: Organize into thematic categories
4. **Detail Preservation**: Maintain all mathematical formulas and tolerances
5. **Validation**: Ensure template compliance

### Backward Compatibility
- **Dual Parser Support**: Handles both XML and legacy score formats
- **Gradual Migration**: System operates during transition period
- **Fallback Mechanisms**: Robust error handling for mixed formats

---

*Technical Documentation Version: 1.0*
*Last Updated: July 31, 2025*