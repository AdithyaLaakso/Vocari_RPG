"""
Base Generator Class

Provides common functionality for all world generators.
"""

import json
import re
from typing import Dict, Any, List, Optional, Type, TypeVar
from pathlib import Path
from openai import OpenAI
from pydantic import BaseModel

T = TypeVar('T', bound=BaseModel)


class BaseGenerator:
    """Base class for all generators with common OpenAI interaction logic."""

    # Language proficiency levels for A0 to A2
    PROFICIENCY_LEVELS = {
        "A0": {
            "name": "Absolute Beginner",
            "description": "No prior knowledge. Single words, basic greetings.",
            "vocabulary_range": "0-50 words",
            "grammar": "None - isolated words only",
            "topics": ["greetings", "numbers 1-10", "colors", "yes/no"]
        },
        "A0+": {
            "name": "False Beginner",
            "description": "Very basic phrases, simple commands.",
            "vocabulary_range": "50-150 words",
            "grammar": "Basic subject-verb, simple present",
            "topics": ["introductions", "numbers 1-100", "days/months", "basic objects"]
        },
        "A1": {
            "name": "Beginner",
            "description": "Simple sentences, basic conversations.",
            "vocabulary_range": "150-500 words",
            "grammar": "Present tense, basic questions, articles",
            "topics": ["family", "food", "weather", "directions", "shopping basics"]
        },
        "A1+": {
            "name": "Elementary",
            "description": "Expanding vocabulary, more complex sentences.",
            "vocabulary_range": "500-1000 words",
            "grammar": "Past tense basics, conjunctions, prepositions",
            "topics": ["daily routines", "hobbies", "descriptions", "past events"]
        },
        "A2": {
            "name": "Pre-Intermediate",
            "description": "Handle routine tasks, describe experiences.",
            "vocabulary_range": "1000-2000 words",
            "grammar": "Future tense, conditionals, comparatives",
            "topics": ["travel", "work", "health", "opinions", "plans"]
        }
    }

    def __init__(
        self,
        embedder,
        target_language: str,
        native_language: str,
        output_path: Path
    ):
        self.embedder = embedder
        self.target_language = target_language
        self.native_language = native_language
        self.output_path = output_path
        self.client = OpenAI()

    def bilingual_text(self, native: str, target: str) -> Dict[str, str]:
        """Create a bilingual text entry."""
        return {
            "native_language": native,
            "target_language": target
        }

    def call_openai(
        self,
        system_prompt: str,
        user_prompt: str,
        model: str = "gpt-4o",
        response_format: Optional[Dict] = None
    ) -> str:
        """Call OpenAI API and return the response content."""
        content, _ = self._call_openai_raw(
            system_prompt=system_prompt,
            user_prompt=user_prompt,
            model=model,
            response_format=response_format
        )
        return content

    def _call_openai_raw(
        self,
        system_prompt: str,
        user_prompt: str,
        model: str = "gpt-4o",
        response_format: Optional[Dict] = None
    ) -> tuple[str, str]:
        """Call OpenAI API and return the response and finish reason."""
        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt}
        ]

        kwargs = {
            "model": model,
            "messages": messages,
        }

        if response_format:
            kwargs["response_format"] = response_format

        response = self.client.chat.completions.create(**kwargs)
        content = response.choices[0].message.content
        finish_reason = response.choices[0].finish_reason
        return content, finish_reason

    def call_openai_structured(
        self,
        system_prompt: str,
        user_prompt: str,
        response_model: Type[T],
        model: str = "gpt-4o",
    ) -> T:
        """Call OpenAI with Pydantic structured output.

        Uses OpenAI's beta.chat.completions.parse() for guaranteed schema compliance.
        This eliminates the need for JSON repair logic.
        """
        response = self.client.beta.chat.completions.parse(
            model=model,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            response_format=response_model,
        )
        return response.choices[0].message.parsed

    def call_openai_json(
        self,
        system_prompt: str,
        user_prompt: str,
        model: str = "gpt-4o",
        max_retries: int = 3
    ) -> Dict[str, Any]:
        """Call OpenAI API and parse JSON response with retry logic.

        DEPRECATED: Prefer call_openai_structured() with Pydantic models.
        """
        last_error = None

        for attempt in range(max_retries):
            try:
                response, finish_reason = self._call_openai_raw(
                    system_prompt=system_prompt,
                    user_prompt=user_prompt,
                    model=model,
                    response_format={"type": "json_object"}
                )

                # Check if response was truncated
                if finish_reason == "length":
                    print(f"    Warning: Response truncated (attempt {attempt + 1}/{max_retries})")
                    # Try to repair truncated JSON
                    repaired = self._repair_truncated_json(response)
                    if repaired is not None:
                        return repaired
                    # If repair failed, retry with shorter request
                    last_error = "Response truncated and could not be repaired"
                    continue

                # Try to parse JSON
                return json.loads(response)

            except json.JSONDecodeError as e:
                print(f"    Warning: JSON parse error (attempt {attempt + 1}/{max_retries}): {str(e)[:100]}")
                last_error = str(e)

                # Try to repair the JSON
                if response:
                    repaired = self._repair_truncated_json(response)
                    if repaired is not None:
                        return repaired

                continue

            except Exception as e:
                print(f"    Warning: API error (attempt {attempt + 1}/{max_retries}): {str(e)[:100]}")
                last_error = str(e)
                continue

        # All retries failed
        raise RuntimeError(f"Failed to get valid JSON after {max_retries} attempts. Last error: {last_error}")

    def _repair_truncated_json(self, response: str) -> Optional[Dict[str, Any]]:
        """Attempt to repair truncated JSON by closing open brackets."""
        if not response:
            return None

        # Try to parse as-is first
        try:
            return json.loads(response)
        except json.JSONDecodeError:
            pass

        # Count open brackets and braces
        open_braces = response.count('{') - response.count('}')
        open_brackets = response.count('[') - response.count(']')

        # Try to close them
        repaired = response.rstrip()

        # Remove trailing comma if present
        if repaired.endswith(','):
            repaired = repaired[:-1]

        # Close brackets and braces
        repaired += ']' * open_brackets
        repaired += '}' * open_braces

        try:
            result = json.loads(repaired)
            print("    Successfully repaired truncated JSON")
            return result
        except json.JSONDecodeError:
            pass

        # Try more aggressive repair: find last complete object
        # Look for the last complete item in arrays
        try:
            # Find position of last complete object/array
            depth = 0
            last_complete = 0
            in_string = False
            escape_next = False

            for i, char in enumerate(response):
                if escape_next:
                    escape_next = False
                    continue
                if char == '\\':
                    escape_next = True
                    continue
                if char == '"' and not escape_next:
                    in_string = not in_string
                    continue
                if in_string:
                    continue

                if char in '{[':
                    depth += 1
                elif char in '}]':
                    depth -= 1
                    if depth == 1:  # Just closed a top-level array item
                        last_complete = i + 1

            if last_complete > 0:
                # Truncate to last complete item and close
                truncated = response[:last_complete]
                # Close remaining brackets
                remaining_braces = truncated.count('{') - truncated.count('}')
                remaining_brackets = truncated.count('[') - truncated.count(']')
                truncated += ']' * remaining_brackets
                truncated += '}' * remaining_braces

                result = json.loads(truncated)
                print(f"    Repaired JSON by truncating to last complete item")
                return result
        except (json.JSONDecodeError, Exception):
            pass

        return None

    def get_relevant_content(self, query: str, top_k: int = 5) -> str:
        """Get relevant content from embeddings."""
        results = self.embedder.query(query, top_k=top_k)
        return "\n\n---\n\n".join([
            f"[Relevance: {r['similarity']:.2f}]\n{r['text']}"
            for r in results
        ])

    def save_json(self, data: Any, filename: str):
        """Save data to a JSON file."""
        filepath = self.output_path / filename
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        print(f"  Saved: {filename}")

    def get_base_system_prompt(self) -> str:
        """Get the base system prompt with language learning constraints."""
        return f"""You are generating content for a language learning RPG that teaches {self.target_language} to speakers of {self.native_language}.

CRITICAL REQUIREMENTS:
1. ALL text that could be displayed to users MUST be in this bilingual format:
   {{"native_language": "text in {self.native_language}", "target_language": "text in {self.target_language}"}}

2. Target proficiency range: A0 (absolute zero) to A2
   - A0: No prior knowledge, single words, basic greetings
   - A0+: Very basic phrases, simple commands
   - A1: Simple sentences, basic conversations
   - A1+: Expanding vocabulary, more complex sentences
   - A2: Routine tasks, describe experiences

3. DO NOT include content beyond A2 level
4. Ensure complete coverage from A0 to A2 - no gaps
5. Light fantasy theme - not excessive, keep it grounded
6. All content must be appropriate for language learning

PROFICIENCY LEVEL DETAILS:
{json.dumps(self.PROFICIENCY_LEVELS, indent=2)}

The learner should be able to progress naturally from knowing zero words to A2 fluency through gameplay."""

    def validate_bilingual_text(self, obj: Any, path: str = "") -> List[str]:
        """Validate that text fields have bilingual format. Returns list of errors."""
        errors = []

        if isinstance(obj, dict):
            # Check if this is a bilingual text object
            if "native_language" in obj and "target_language" in obj:
                if not isinstance(obj["native_language"], str):
                    errors.append(f"{path}.native_language is not a string")
                if not isinstance(obj["target_language"], str):
                    errors.append(f"{path}.target_language is not a string")
            else:
                # Recurse into dict
                for key, value in obj.items():
                    errors.extend(self.validate_bilingual_text(value, f"{path}.{key}"))

        elif isinstance(obj, list):
            for i, item in enumerate(obj):
                errors.extend(self.validate_bilingual_text(item, f"{path}[{i}]"))

        return errors

    def slugify(self, text: str) -> str:
        """Convert text to a URL-safe slug."""
        # Handle bilingual text objects
        if isinstance(text, dict):
            text = text.get("native_language", text.get("target_language", ""))

        if not isinstance(text, str):
            text = str(text)

        # Lowercase and replace spaces/special chars with underscores
        slug = text.lower().strip()
        slug = re.sub(r'[^a-z0-9]+', '_', slug)
        slug = re.sub(r'_+', '_', slug)  # Collapse multiple underscores
        slug = slug.strip('_')
        return slug[:30] if slug else "item"  # Limit length

    def assign_sequential_ids(
        self,
        items: List[Dict[str, Any]],
        prefix: str,
        start_index: int = 1,
        name_field: str = "name"
    ) -> List[Dict[str, Any]]:
        """
        Assign sequential IDs to a list of items, replacing any LLM-generated IDs.

        Args:
            items: List of item dicts
            prefix: ID prefix (e.g., "quest", "item", "npc")
            start_index: Starting index for IDs
            name_field: Field containing the name (for generating readable slugs)

        Returns:
            Items with deterministic IDs assigned
        """
        result = []
        for i, item in enumerate(items):
            idx = start_index + i

            # Get name for slug if available
            name = item.get(name_field, "")
            slug = self.slugify(name) if name else ""

            # Generate deterministic ID: prefix_index_slug (e.g., quest_1_market_herbs)
            if slug:
                item["id"] = f"{prefix}_{idx}_{slug}"
            else:
                item["id"] = f"{prefix}_{idx}"

            result.append(item)

        return result

    def build_id_mapping(
        self,
        old_items: List[Dict[str, Any]],
        new_items: List[Dict[str, Any]]
    ) -> Dict[str, str]:
        """
        Build a mapping from old IDs to new IDs based on list position.

        This allows us to update references after reassigning IDs.
        """
        mapping = {}
        for old_item, new_item in zip(old_items, new_items):
            old_id = old_item.get("id", "")
            new_id = new_item.get("id", "")
            if old_id and new_id:
                mapping[old_id] = new_id
        return mapping

    def update_references(
        self,
        data: Any,
        id_mapping: Dict[str, str],
        reference_fields: List[str]
    ) -> Any:
        """
        Update ID references in data using a mapping.

        Args:
            data: Dict or list containing references
            id_mapping: Mapping from old IDs to new IDs
            reference_fields: Field names that contain ID references

        Returns:
            Data with updated references
        """
        if isinstance(data, dict):
            result = {}
            for key, value in data.items():
                if key in reference_fields and isinstance(value, str):
                    # Update single ID reference
                    result[key] = id_mapping.get(value, value)
                elif key in reference_fields and isinstance(value, list):
                    # Update list of ID references
                    result[key] = [id_mapping.get(v, v) if isinstance(v, str) else v for v in value]
                else:
                    result[key] = self.update_references(value, id_mapping, reference_fields)
            return result
        elif isinstance(data, list):
            return [self.update_references(item, id_mapping, reference_fields) for item in data]
        else:
            return data
