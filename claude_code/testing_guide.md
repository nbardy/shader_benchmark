# Testing Guide - Shader Benchmark

## Quick Start Testing

### Environment Setup

Choose one of the following Python environment setups:

#### Option 1: Virtual Environment (Recommended for Testing)
```bash
cd shader_benchmark/llm_harness
python3 -m venv venv
source venv/bin/activate          # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

#### Option 2: UV (Fast Package Manager)
```bash
cd llm_harness
uv sync                          # Creates venv and installs dependencies
uv run python main.py --model MODEL --prompt-folder FOLDER
```

#### Option 3: pyenv (Version Management)
```bash
pyenv install 3.11
pyenv local 3.11
pip install -r requirements.txt
```

### API Configuration

Ensure your `.env` file is configured:
```bash
# llm_harness/.env
OPENROUTER_API_KEY=your_api_key_here
```

## Test Categories

### 1. Individual Component Testing

#### Template System Test
```bash
source venv/bin/activate
python3 -c "
from critic_template import CriticTemplate
from pathlib import Path

template = CriticTemplate()
critic_path = Path('../problems/base_set/geometric_cube/critic.txt')
request_path = Path('../problems/base_set/geometric_cube/request.txt')

prompt = template.format_critic_prompt(critic_path, request_path)
print('Template generation successful!')
print(f'Prompt length: {len(prompt)} characters')
"
```

#### Judge Scoring Test
```bash
source venv/bin/activate
python3 -c "
import asyncio
from dotenv import load_dotenv
from judge import Judge
from pathlib import Path

load_dotenv()

async def test_judge():
    judge = Judge()
    # Test with existing result
    image_path = Path('test_08af6858-66f7-48ba-8e96-51f656abd732_results/result.png')
    critic_path = Path('../problems/base_set/hopf_fibration_base_loops/critic.txt')
    request_path = Path('../problems/base_set/hopf_fibration_base_loops/request.txt')
    
    scores = await judge.evaluate_with_template(critic_path, request_path, image_path)
    print(f'Scores (1-100 scale): {scores}')
    print(f'Total: {sum(scores)}/500')
    
asyncio.run(test_judge())
"
```

#### Report Generation Test
```bash
source venv/bin/activate
python3 generate_report.py --model "test-model" --output test_report.md
echo "Report generated: test_report.md"
```

### 2. End-to-End Pipeline Testing

#### Simple Problem Test
```bash
cd shader_benchmark
source llm_harness/venv/bin/activate

# Test with a simple geometric problem
python3 llm_harness/main.py \
  --model "anthropic/claude-3-5-sonnet-20241022" \
  --prompt-folder "problems/base_set/geometric_cube"
```

#### Multiple Problem Batch Test
```bash
# Test multiple problems in sequence
for problem in geometric_cube regular_tetrahedron rounded_box; do
  echo "Testing: $problem"
  python3 llm_harness/main.py \
    --model "anthropic/claude-3-5-sonnet-20241022" \
    --prompt-folder "problems/base_set/$problem"
  echo "Completed: $problem"
done
```

### 3. Scoring System Validation

#### XML Format Validation
```bash
source venv/bin/activate
python3 -c "
import re

# Test XML parsing regex
test_responses = [
    '<scores><S1>85</S1><S2>72</S2><S3>91</S3><S4>78</S4><S5>82</S5></scores>',
    'Some text before <scores><S1>90</S1><S2>85</S2><S3>88</S3><S4>92</S4><S5>87</S5></scores> some after',
    'SCORES: [8,7,9,6,8]'  # Legacy format
]

for response in test_responses:
    # XML format test
    scores_xml_pattern = r'<scores>(.*?)</scores>'
    xml_match = re.search(scores_xml_pattern, response, re.DOTALL)
    
    if xml_match:
        print(f'XML Match: {xml_match.group(1)}')
        scores = []
        for i in range(1, 6):
            score_pattern = rf'<S{i}>(\d+)</S{i}>'
            score_match = re.search(score_pattern, xml_match.group(1))
            if score_match:
                scores.append(int(score_match.group(1)))
        print(f'Extracted scores: {scores}')
    else:
        print('No XML match found')
    print('---')
"
```

#### Scale Conversion Test
```bash
source venv/bin/activate
python3 -c "
# Test 1-10 to 1-100 scale conversion
legacy_scores = [8, 7, 9, 6, 8]
converted_scores = [max(1, min(100, score * 10)) for score in legacy_scores]

print(f'Legacy (1-10): {legacy_scores} -> Total: {sum(legacy_scores)}/50')
print(f'New (1-100): {converted_scores} -> Total: {sum(converted_scores)}/500')
print(f'Average: {sum(converted_scores)/len(converted_scores):.1f}/100')
"
```

### 4. Critic Format Validation

#### Format Compliance Check
```bash
source venv/bin/activate
python3 -c "
from pathlib import Path
from critic_template import CriticTemplate

template = CriticTemplate()
problems_dir = Path('../problems/base_set')

compliant_count = 0
total_count = 0

for problem_dir in problems_dir.iterdir():
    if problem_dir.is_dir():
        critic_file = problem_dir / 'critic.txt'
        if critic_file.exists():
            total_count += 1
            with open(critic_file, 'r') as f:
                content = f.read()
            
            if template.validate_critic_format(content):
                compliant_count += 1
            else:
                print(f'Non-compliant: {problem_dir.name}')

print(f'Compliance: {compliant_count}/{total_count} files')
print(f'Success rate: {compliant_count/total_count*100:.1f}%')
"
```

#### Section Content Analysis
```bash
source venv/bin/activate
python3 -c "
from pathlib import Path
from critic_template import CriticTemplate

template = CriticTemplate()
problem_dir = Path('../problems/base_set/weierstrass_function')
critic_file = problem_dir / 'critic.txt'

with open(critic_file, 'r') as f:
    content = f.read()

sections = template.parse_questions(content)
for section_name, section_content in sections.items():
    print(f'=== {section_name} ===')
    print(f'Length: {len(section_content)} characters')
    print(f'Lines: {len(section_content.splitlines())} lines')
    print('---')
"
```

### 5. Performance Testing

#### Template Generation Benchmark
```bash
source venv/bin/activate
python3 -c "
import time
from pathlib import Path
from critic_template import CriticTemplate

template = CriticTemplate()
problems_dir = Path('../problems/base_set')

start_time = time.time()
processed = 0

for problem_dir in problems_dir.iterdir():
    if problem_dir.is_dir():
        critic_file = problem_dir / 'critic.txt'
        request_file = problem_dir / 'request.txt'
        
        if critic_file.exists() and request_file.exists():
            prompt = template.format_critic_prompt(critic_file, request_file)
            processed += 1

end_time = time.time()
print(f'Processed {processed} problems in {end_time - start_time:.2f} seconds')
print(f'Average: {(end_time - start_time)/processed*1000:.1f}ms per problem')
"
```

### 6. Integration Testing

#### Full Workflow Test (No Shader Execution)
```bash
source venv/bin/activate
python3 -c "
import asyncio
from pathlib import Path
from dotenv import load_dotenv
from critic_template import CriticTemplate
from judge import Judge

load_dotenv()

async def test_workflow():
    # Test template generation
    template = CriticTemplate()
    critic_path = Path('../problems/base_set/geometric_cube/critic.txt')
    request_path = Path('../problems/base_set/geometric_cube/request.txt')
    
    prompt = template.format_critic_prompt(critic_path, request_path)
    print(f'✓ Template generated ({len(prompt)} chars)')
    
    # Test with dummy image (for API test)
    if Path('test_result.png').exists():
        judge = Judge()
        scores = await judge.evaluate_with_template(critic_path, request_path, Path('test_result.png'))
        print(f'✓ Scoring completed: {scores}')
        print(f'✓ Scale validation: All scores 1-100: {all(1 <= s <= 100 for s in scores)}')
    else:
        print('! No test image available for judge testing')

asyncio.run(test_workflow())
"
```

## Troubleshooting

### Common Issues

#### 1. Import Errors
```bash
# Issue: ModuleNotFoundError: No module named 'critic_template'
# Solution: Run from llm_harness directory
cd llm_harness
source venv/bin/activate
python3 your_test.py
```

#### 2. API Key Issues
```bash
# Issue: OPENROUTER_API_KEY environment variable not set
# Solution: Check .env file exists and is properly formatted
ls -la .env
cat .env  # Should show: OPENROUTER_API_KEY=sk-or-v1-...
```

#### 3. Missing Dependencies
```bash
# Issue: ImportError: No module named 'aiohttp'
# Solution: Reinstall requirements
pip install -r requirements.txt
```

#### 4. Path Issues
```bash
# Issue: FileNotFoundError: critic.txt not found
# Solution: Use absolute paths or verify working directory
pwd  # Should be in shader_benchmark/llm_harness
ls ../problems/base_set/geometric_cube/  # Should show critic.txt and request.txt
```

### Debug Commands

#### Check Environment
```bash
echo "Working directory: $(pwd)"
echo "Python version: $(python3 --version)"
echo "Virtual env: $VIRTUAL_ENV"
echo "API key set: $([ -n "$OPENROUTER_API_KEY" ] && echo 'Yes' || echo 'No')"
```

#### Verify File Structure
```bash
ls -la ../problems/base_set/ | head -10
find ../problems/base_set -name "critic.txt" | wc -l  # Should show 100
find ../problems/base_set -name "request.txt" | wc -l  # Should show 100
```

#### Test Dependencies
```bash
python3 -c "
import aiohttp, requests, dotenv, pathlib, json, re, xml.etree.ElementTree
print('✓ All dependencies available')
"
```

## Continuous Integration Testing

### Test Suite Script
```bash
#!/bin/bash
# test_suite.sh

echo "=== Shader Benchmark Test Suite ==="

# Setup
cd llm_harness
source venv/bin/activate || { echo "Failed to activate venv"; exit 1; }

# Component tests
echo "Testing template system..."
python3 -c "from critic_template import CriticTemplate; print('✓ Template import successful')"

echo "Testing judge system..."
python3 -c "from judge import Judge; print('✓ Judge import successful')"

echo "Testing report generator..."
python3 -c "from generate_report import ReportGenerator; print('✓ Report generator import successful')"

# Format validation
echo "Validating critic formats..."
python3 -c "
from pathlib import Path
from critic_template import CriticTemplate

template = CriticTemplate()
problems = list(Path('../problems/base_set').iterdir())
valid = sum(1 for p in problems if (p/'critic.txt').exists() and template.validate_critic_format((p/'critic.txt').read_text()))
print(f'✓ {valid}/{len(problems)} critic files valid')
"

echo "=== Test Suite Complete ==="
```

Make it executable and run:
```bash
chmod +x test_suite.sh
./test_suite.sh
```

---

*Testing Guide Version: 1.0*
*Last Updated: July 31, 2025*