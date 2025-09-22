import os
import base64
import re
import aiohttp
import json
import xml.etree.ElementTree as ET
from typing import List
from pathlib import Path
from dotenv import load_dotenv
from critic_template import CriticTemplate

class Judge:
    def __init__(self):
        self.api_key = os.getenv('OPENROUTER_API_KEY')
        if not self.api_key:
            raise ValueError("OPENROUTER_API_KEY environment variable not set")
        
        self.base_url = "https://openrouter.ai/api/v1"
        self.headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
        self.critic_template = CriticTemplate()
    
    async def evaluate_with_template(self, critic_path: Path, request_path: Path, result_image_path: Path, save_dir: Path = None) -> List[int]:
        """Evaluate using structured critic template system"""
        
        # Generate the full prompt using template
        judge_prompt = self.critic_template.format_critic_prompt(critic_path, request_path)
        return await self.evaluate(judge_prompt, result_image_path, save_dir)
    
    async def evaluate(self, judge_prompt: str, result_image_path: Path, save_dir: Path = None) -> List[int]:
        """Evaluate the shader result using GPT-4o via OpenRouter as a judge"""
        
        if not result_image_path or not result_image_path.exists():
            print(f"Error: Result image not found at {result_image_path}")
            return [1, 1, 1, 1, 1]
        
        # Encode image to base64
        try:
            image_base64 = self._encode_image(result_image_path)
        except Exception as e:
            print(f"Error encoding image: {e}")
            return [1, 1, 1, 1, 1]
        
        # The judge_prompt from template already contains instructions
        full_prompt = judge_prompt
        
        try:
            payload = {
                "model": "openai/gpt-4o",
                "messages": [
                    {
                        "role": "user",
                        "content": [
                            {
                                "type": "text",
                                "text": full_prompt
                            },
                            {
                                "type": "image_url",
                                "image_url": {
                                    "url": f"data:image/png;base64,{image_base64}"
                                }
                            }
                        ]
                    }
                ]
            }
            
            print("Calling GPT-4o judge for evaluation...")
            
            async with aiohttp.ClientSession() as session:
                async with session.post(
                    f"{self.base_url}/chat/completions",
                    headers=self.headers,
                    json=payload
                ) as response:
                    
                    if response.status != 200:
                        error_text = await response.text()
                        raise Exception(f"OpenRouter API error: {response.status} - {error_text}")
                    
                    result = await response.json()
                    response_text = result['choices'][0]['message']['content']
                    print(f"Judge response: {response_text}")
                    
                    # Save raw judge response if save directory provided
                    if save_dir and save_dir.exists():
                        judge_log_file = save_dir / "judge_response.txt"
                        with open(judge_log_file, 'w', encoding='utf-8') as f:
                            f.write("=== JUDGE EVALUATION LOG ===\n\n")
                            f.write("PROMPT:\n")
                            f.write(full_prompt)
                            f.write("\n\n" + "="*50 + "\n\n")
                            f.write("RAW RESPONSE:\n")
                            f.write(response_text)
                            f.write("\n\n" + "="*50 + "\n\n")
                        print(f"Judge response saved to: {judge_log_file}")
                    
                    # Parse scores from response
                    scores = self._parse_scores(response_text)
                    
                    # Add parsed scores to log file if it exists
                    if save_dir and save_dir.exists():
                        judge_log_file = save_dir / "judge_response.txt"
                        with open(judge_log_file, 'a', encoding='utf-8') as f:
                            f.write(f"PARSED SCORES:\n{scores}\n\n")
                            if scores == [1, 1, 1, 1, 1]:
                                f.write("⚠️ WARNING: Default fallback scores - parsing may have failed!\n")
                    
                    print(f"Parsed scores: {scores}")
                    return scores
            
        except Exception as e:
            print(f"Error calling GPT-4o judge: {e}")
            
            # Save error log if save directory provided
            if save_dir and save_dir.exists():
                error_log_file = save_dir / "judge_error.txt"
                with open(error_log_file, 'w', encoding='utf-8') as f:
                    f.write("=== JUDGE ERROR LOG ===\n\n")
                    f.write(f"ERROR: {str(e)}\n\n")
                    f.write("PROMPT USED:\n")
                    f.write(full_prompt)
                    f.write("\n\n")
                    f.write("RETURNING DEFAULT SCORES: [1, 1, 1, 1, 1]\n")
                print(f"Judge error logged to: {error_log_file}")
            
            # Return default scores on error
            return [1, 1, 1, 1, 1]
    
    def _encode_image(self, image_path: Path) -> str:
        """Encode image to base64 for OpenAI API"""
        with open(image_path, "rb") as image_file:
            return base64.b64encode(image_file.read()).decode('utf-8')
    
    def _parse_scores(self, response_text: str) -> List[int]:
        """Parse scores from the judge response - supports both XML and legacy formats"""
        
        # First try new XML format: <scores><S1>85</S1><S2>72</S2>...</scores>
        scores_xml_pattern = r'<scores>(.*?)</scores>'
        xml_match = re.search(scores_xml_pattern, response_text, re.DOTALL)
        
        if xml_match:
            xml_content = xml_match.group(1)
            try:
                scores = []
                for i in range(1, 6):
                    score_pattern = rf'<S{i}>(\d+)</S{i}>'
                    score_match = re.search(score_pattern, xml_content)
                    if score_match:
                        score = int(score_match.group(1))
                        # Validate score is in range 1-100
                        score = max(1, min(100, score))
                        scores.append(score)
                    else:
                        print(f"Warning: Missing S{i} in XML scores")
                        scores.append(50)  # Default middle score
                
                if len(scores) == 5:
                    print(f"Successfully parsed XML scores: {scores}")
                    return scores
                    
            except Exception as e:
                print(f"Error parsing XML scores: {e}")
        
        # Fallback to legacy SCORES: [X, X, X, X, X] pattern (1-10 scale)
        scores_pattern = r'SCORES:\s*\[(\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+)\]'
        match = re.search(scores_pattern, response_text)
        
        if match:
            scores = [int(match.group(i)) for i in range(1, 6)]
            # Convert 1-10 scale to 1-100 scale for backward compatibility
            scores = [max(1, min(10, score)) * 10 for score in scores]
            print(f"Parsed legacy scores (converted to 100-scale): {scores}")
            return scores
        
        # Try to find any sequence of 5 numbers that could be scores
        all_numbers = re.findall(r'\b\d+\b', response_text)
        if len(all_numbers) >= 5:
            scores = []
            for num_str in all_numbers[:5]:
                num = int(num_str)
                if 1 <= num <= 10:
                    # Assume 1-10 scale, convert to 1-100
                    scores.append(num * 10)
                elif 1 <= num <= 100:
                    # Assume 1-100 scale
                    scores.append(num)
                else:
                    # Invalid score, use default
                    scores.append(50)
            
            if len(scores) == 5:
                print(f"Parsed fallback scores: {scores}")
                return scores
        
        print("Could not parse scores from judge response, using default scores")
        return [0, 0, 0, 0, 0]  # Default scores for missing/errored evaluations (1-100 scale)