"""
Critic Template System for Shader Benchmark

This module provides functionality to parse structured critic files with __QUESTION_X__ headers
and format them into standardized evaluation prompts with 5 scoring criteria.
"""

import re
from pathlib import Path
from typing import Dict, Optional

class CriticTemplate:
    """Handles parsing and formatting of structured critic prompts."""
    
    def __init__(self):
        self.template = """Evaluate this shader-generated image based on the mathematical visualization requirements.

You are an expert mathematical visualization judge. Examine the provided image carefully and score it on 5 criteria using a scale of 1-100 (where 1 is completely incorrect/poor and 100 is perfect).

**SCORING CRITERIA (1-100 scale each):**

**S1: Problem Accuracy (Generic)**
How accurately does the result match the mathematical and technical requirements specified in the problem? Consider correctness of mathematical concepts, adherence to specifications, and proper implementation of the core mathematical visualization.

**S2: Visual Quality (Generic)** 
How aesthetic, polished, and technically sound is the visual result? Consider image resolution, anti-aliasing, freedom from visual glitches, appropriate lighting/shading, color choices, and overall visual appeal.

**S3: Problem-Specific Criterion 1**
{question_1}

**S4: Problem-Specific Criterion 2**
{question_2}

**S5: Problem-Specific Criterion 3**
{question_3}

**EVALUATION INSTRUCTIONS:**
1. Examine the image thoroughly against each criterion
2. Provide detailed reasoning for each score
3. Consider the mathematical accuracy as the highest priority
4. End your response with the exact format: <scores><S1>XX</S1><S2>XX</S2><S3>XX</S3><S4>XX</S4><S5>XX</S5></scores>

**PROBLEM CONTEXT:**
{problem_description}

Now evaluate the provided image and give your detailed assessment followed by the numerical scores in the specified XML format.

**CRITICAL OUTPUT REQUIREMENT — read carefully:**
The very last line of your response MUST be a single XML scores block with ALL FIVE scores
present, in this exact form (each NN is an integer 1–100):

<scores><S1>NN</S1><S2>NN</S2><S3>NN</S3><S4>NN</S4><S5>NN</S5></scores>

Do NOT omit S3, S4, or S5 — partial blocks are treated as a parse failure and your scoring
contribution is discarded. Do NOT wrap the block in markdown code fences. Do NOT add text
after the closing </scores> tag."""

    def parse_questions(self, critic_content: str) -> Dict[str, str]:
        """Parse structured sections from critic file content."""
        questions = {}
        
        # The mathematical set and reconstruction set use different semantic
        # section names, but both define three ordered problem-specific
        # criteria. Parse either vocabulary into S3/S4/S5.
        section_patterns = [
            r'__(?:MATHEMATICAL_ACCURACY|VISUAL_MATCH)__(.*?)(?=__[A-Z_]+__|$)',
            r'__(?:VISUAL_IMPLEMENTATION|PROCEDURAL_INTEGRITY)__(.*?)(?=__[A-Z_]+__|$)',
            r'__(?:COMPLETENESS_AND_SPECIFICATIONS|COMPLETENESS)__(.*?)(?=__[A-Z_]+__|$)'
        ]
        
        section_matches = []
        for i, pattern in enumerate(section_patterns, 1):
            match = re.search(pattern, critic_content, re.DOTALL)
            if match:
                section_content = match.group(1).strip()
                questions[i] = section_content
                section_matches.append(i)
        
        # If new format found, return it
        if section_matches:
            return questions
            
        # Fallback to __QUESTION_X__ format for backward compatibility
        sections = re.split(r'__QUESTION_(\d+)__', critic_content)
        
        # sections[0] is content before first question (ignore)
        # sections[1] = "1", sections[2] = question 1 content
        # sections[3] = "2", sections[4] = question 2 content, etc.
        
        for i in range(1, len(sections), 2):
            if i + 1 < len(sections):
                question_num = sections[i]
                question_content = sections[i + 1].strip()
                questions[int(question_num)] = question_content
        
        return questions
    
    def load_request_content(self, request_path: Path) -> str:
        """Load the problem description from request.txt file."""
        try:
            with open(request_path, 'r', encoding='utf-8') as f:
                return f.read().strip()
        except Exception as e:
            return f"Error loading problem description: {e}"
    
    def format_critic_prompt(self, critic_path: Path, request_path: Path) -> str:
        """
        Format a structured critic file into a complete evaluation prompt.
        
        Args:
            critic_path: Path to critic.txt file with __QUESTION_X__ format  
            request_path: Path to request.txt file with problem description
            
        Returns:
            Formatted evaluation prompt ready for LLM judge
        """
        try:
            # Load critic content
            with open(critic_path, 'r', encoding='utf-8') as f:
                critic_content = f.read()
            
            # Parse questions
            questions = self.parse_questions(critic_content)
            
            # Load problem description
            problem_description = self.load_request_content(request_path)
            
            # Validate we have all 3 questions
            missing_questions = []
            for q_num in [1, 2, 3]:
                if q_num not in questions:
                    missing_questions.append(q_num)
            
            if missing_questions:
                # Provide default questions for missing ones
                defaults = {
                    1: "Mathematical Precision Assessment:\n- Are the core mathematical concepts rendered accurately?\n- Do all mathematical relationships and formulas match specifications?\n- Is the algorithmic implementation mathematically correct?",
                    2: "Technical Implementation Quality:\n- Are rendering requirements (resolution, anti-aliasing, materials) met?\n- Is lighting and shading appropriate for the visualization?\n- Are colors, gradients, and visual effects properly implemented?", 
                    3: "Specification Completeness:\n- Are all required visual elements present and positioned correctly?\n- Do reference objects, legends, and annotations appear as specified?\n- Is the overall composition and presentation professional?"
                }
                
                for q_num in missing_questions:
                    questions[q_num] = defaults[q_num]
                    print(f"Warning: Missing __QUESTION_{q_num}__ in {critic_path}, using default")
            
            # Format template
            formatted_prompt = self.template.format(
                question_1=questions[1],
                question_2=questions[2], 
                question_3=questions[3],
                problem_description=problem_description
            )
            
            return formatted_prompt
            
        except Exception as e:
            # Return error prompt that will still work
            return f"""Error processing critic template: {e}

Please evaluate this shader result on a scale of 1-100 for each criterion and respond with:
<scores><S1>50</S1><S2>50</S2><S3>50</S3><S4>50</S4><S5>50</S5></scores>"""

    def validate_critic_format(self, critic_path: Path) -> Dict[str, any]:
        """
        Validate that a critic file has proper __QUESTION_X__ format.
        
        Returns:
            Dict with 'valid' (bool), 'questions_found' (list), 'issues' (list)
        """
        result = {
            'valid': True,
            'questions_found': [],
            'issues': []
        }
        
        try:
            with open(critic_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            questions = self.parse_questions(content)
            result['questions_found'] = list(questions.keys())
            
            # Check for required questions
            for q_num in [1, 2, 3]:
                if q_num not in questions:
                    result['valid'] = False
                    result['issues'].append(f"Missing __QUESTION_{q_num}__")
                elif not questions[q_num].strip():
                    result['valid'] = False  
                    result['issues'].append(f"Empty content for __QUESTION_{q_num}__")
            
            # Check for extra questions
            extra_questions = [q for q in questions.keys() if q not in [1, 2, 3]]
            if extra_questions:
                result['issues'].append(f"Unexpected questions found: {extra_questions}")
                
        except Exception as e:
            result['valid'] = False
            result['issues'].append(f"Error reading file: {e}")
        
        return result

# Convenience function for easy importing
def format_critic_prompt(critic_path: Path, request_path: Path) -> str:
    """Convenience function to format a critic prompt."""
    template = CriticTemplate()
    return template.format_critic_prompt(critic_path, request_path)
