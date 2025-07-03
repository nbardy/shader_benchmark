import os
import base64
import re
import aiohttp
import json
from typing import List
from pathlib import Path
from dotenv import load_dotenv

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
    
    async def evaluate(self, judge_prompt: str, result_image_path: Path) -> List[int]:
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
        
        # Prepare the full prompt
        full_prompt = f"""
{judge_prompt}

Please evaluate the shader output image and provide your scores.

Your response MUST end with exactly 5 integers (1-10) in this format:
SCORES: [X, X, X, X, X]

Where each X is a score from 1-10.
"""
        
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
                    
                    # Parse scores from response
                    scores = self._parse_scores(response_text)
                    print(f"Parsed scores: {scores}")
                    return scores
            
        except Exception as e:
            print(f"Error calling GPT-4o judge: {e}")
            # Return default scores on error
            return [1, 1, 1, 1, 1]
    
    def _encode_image(self, image_path: Path) -> str:
        """Encode image to base64 for OpenAI API"""
        with open(image_path, "rb") as image_file:
            return base64.b64encode(image_file.read()).decode('utf-8')
    
    def _parse_scores(self, response_text: str) -> List[int]:
        """Parse scores from the judge response"""
        
        # Look for SCORES: [X, X, X, X, X] pattern
        scores_pattern = r'SCORES:\s*\[(\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+)\]'
        match = re.search(scores_pattern, response_text)
        
        if match:
            scores = [int(match.group(i)) for i in range(1, 6)]
            # Validate scores are in range 1-10
            scores = [max(1, min(10, score)) for score in scores]
            return scores
        
        # Fallback: look for any 5 numbers in the response
        numbers = re.findall(r'\b([1-9]|10)\b', response_text)
        if len(numbers) >= 5:
            scores = [int(num) for num in numbers[:5]]
            return scores
        
        # Final fallback: look for any numbers and pad/truncate to 5
        all_numbers = re.findall(r'\b\d+\b', response_text)
        if all_numbers:
            scores = []
            for num_str in all_numbers:
                num = int(num_str)
                if 1 <= num <= 10:
                    scores.append(num)
                if len(scores) >= 5:
                    break
            
            # Pad with 5s if we don't have enough scores
            while len(scores) < 5:
                scores.append(5)
            
            return scores[:5]
        
        print("Could not parse scores from judge response, using default scores")
        return [5, 5, 5, 5, 5]  # Default neutral scores