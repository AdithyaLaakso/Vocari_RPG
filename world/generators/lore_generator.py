"""
Lore Generator

Generates the world lore, backstory, and setting for the RPG.
"""

from typing import Dict, Any
from .base_generator import BaseGenerator


class LoreGenerator(BaseGenerator):
    """Generates world lore aligned with language learning content."""

    def generate(self) -> Dict[str, Any]:
        """Generate the world lore."""
        print("  Generating world lore...")

        # Get content summary for context
        content_summary = self.embedder.get_content_summary(max_chunks=15)

        # Query for thematic content
        thematic_content = self.get_relevant_content(
            "themes topics vocabulary grammar lessons",
            top_k=10
        )

        system_prompt = f"""{self.get_base_system_prompt()}

You are generating the WORLD LORE for this language learning RPG.

Create a cohesive fantasy world that:
1. Has a light fantasy theme (small village/town setting, minor magical elements)
2. Provides natural contexts for language learning (marketplace, inn, school, etc.)
3. Has a reason for the player to interact with many NPCs
4. Creates motivation for the player to learn the language
5. Is welcoming and not threatening - suitable for beginners

The world should feel like a place where someone would naturally need to learn the local language to get by."""

        user_prompt = f"""Based on the language learning content below, create the world lore.

LANGUAGE LEARNING CONTENT SUMMARY:
{content_summary}

THEMATIC CONTENT:
{thematic_content}

Generate a JSON object with this structure:
{{
    "world_name": {{"native_language": "...", "target_language": "..."}},
    "world_description": {{"native_language": "...", "target_language": "..."}},
    "backstory": {{
        "summary": {{"native_language": "...", "target_language": "..."}},
        "player_origin": {{"native_language": "...", "target_language": "..."}},
        "motivation": {{"native_language": "...", "target_language": "..."}}
    }},
    "setting": {{
        "era": {{"native_language": "...", "target_language": "..."}},
        "atmosphere": {{"native_language": "...", "target_language": "..."}},
        "culture": {{"native_language": "...", "target_language": "..."}}
    }},
    "magical_elements": [
        {{
            "name": {{"native_language": "...", "target_language": "..."}},
            "description": {{"native_language": "...", "target_language": "..."}}
        }}
    ],
    "factions": [
        {{
            "name": {{"native_language": "...", "target_language": "..."}},
            "description": {{"native_language": "...", "target_language": "..."}},
            "role_in_world": {{"native_language": "...", "target_language": "..."}}
        }}
    ],
    "key_themes": [
        {{"native_language": "...", "target_language": "..."}}
    ],
    "language_integration": {{
        "why_player_learns": {{"native_language": "...", "target_language": "..."}},
        "how_language_fits": {{"native_language": "...", "target_language": "..."}}
    }}
}}

The target language is {self.target_language} and native language is {self.native_language}.
Make the world feel authentic to {self.target_language}-speaking cultures while keeping it fantasy.
Ensure all text fields use the bilingual format shown above."""

        lore = self.call_openai_json(
            system_prompt=system_prompt,
            user_prompt=user_prompt,
        )

        # Validate
        errors = self.validate_bilingual_text(lore)
        if errors:
            print(f"  Warning: Bilingual format issues found: {errors[:3]}...")

        self.save_json(lore, "lore.json")
        return lore
