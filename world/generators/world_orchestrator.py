"""
World Orchestrator

Coordinates all generators to create a complete RPG world.
"""

import json
from pathlib import Path
from typing import Dict, Any, Optional

from .lore_generator import LoreGenerator
from .npc_generator import NPCGenerator
from .map_generator import MapGenerator
from .item_generator import ItemGenerator
from .quest_generator import QuestGenerator
from .tutor_generator import TutorGenerator
from .skill_generator import SkillGenerator
from .trigger_generator import TriggerGenerator
from .level_progression import LevelProgressionGenerator


class WorldOrchestrator:
    """Orchestrates the generation of a complete RPG world."""

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

    def _load_cached(self, filename: str) -> Optional[Dict[str, Any]]:
        """Load cached JSON file if it exists."""
        filepath = self.output_path / filename
        if filepath.exists():
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except (json.JSONDecodeError, IOError):
                return None
        return None

    def generate(self) -> Dict[str, Any]:
        """Generate the complete RPG world, using cached files when available."""
        world_data = {}

        # Step 1: Generate or load world lore
        print("  [1/9] World lore...")
        cached_lore = self._load_cached("lore.json")
        if cached_lore:
            print("    Using cached lore.json")
            world_data['lore'] = cached_lore
        else:
            print("    Generating world lore...")
            lore_gen = LoreGenerator(
                embedder=self.embedder,
                target_language=self.target_language,
                native_language=self.native_language,
                output_path=self.output_path
            )
            world_data['lore'] = lore_gen.generate()

        # Step 2: Generate or load map/locations
        print("  [2/9] Map and locations...")
        cached_map = self._load_cached("map.json")
        if cached_map:
            print("    Using cached map.json")
            world_data['map'] = cached_map
        else:
            print("    Generating map and locations...")
            map_gen = MapGenerator(
                embedder=self.embedder,
                target_language=self.target_language,
                native_language=self.native_language,
                output_path=self.output_path
            )
            world_data['map'] = map_gen.generate(world_data['lore'])

        # Step 3: Generate or load NPCs
        print("  [3/9] NPCs...")
        cached_npcs = self._load_cached("npcs.json")
        if cached_npcs:
            print("    Using cached npcs.json")
            world_data['npcs'] = cached_npcs
        else:
            print("    Generating NPCs...")
            npc_gen = NPCGenerator(
                embedder=self.embedder,
                target_language=self.target_language,
                native_language=self.native_language,
                output_path=self.output_path
            )
            world_data['npcs'] = npc_gen.generate(world_data['lore'], world_data['map'])

        # Step 4: Generate or load items
        print("  [4/9] Items...")
        cached_items = self._load_cached("items.json")
        if cached_items:
            print("    Using cached items.json")
            world_data['items'] = cached_items
        else:
            print("    Generating items...")
            item_gen = ItemGenerator(
                embedder=self.embedder,
                target_language=self.target_language,
                native_language=self.native_language,
                output_path=self.output_path
            )
            world_data['items'] = item_gen.generate(world_data['lore'], world_data['map'])

        # Step 5: Generate or load quests
        print("  [5/9] Quests...")
        cached_quests = self._load_cached("quests.json")
        if cached_quests:
            print("    Using cached quests.json")
            world_data['quests'] = cached_quests
        else:
            print("    Generating quests...")
            quest_gen = QuestGenerator(
                embedder=self.embedder,
                target_language=self.target_language,
                native_language=self.native_language,
                output_path=self.output_path
            )
            world_data['quests'] = quest_gen.generate(
                world_data['lore'],
                world_data['map'],
                world_data['npcs'],
                world_data['items']
            )

        # Step 6: Generate or load tutor data
        print("  [6/9] Tutor data...")
        cached_tutor = self._load_cached("tutor.json")
        if cached_tutor:
            print("    Using cached tutor.json")
            world_data['tutor'] = cached_tutor
        else:
            print("    Generating tutor data...")
            tutor_gen = TutorGenerator(
                embedder=self.embedder,
                target_language=self.target_language,
                native_language=self.native_language,
                output_path=self.output_path
            )
            world_data['tutor'] = tutor_gen.generate(
                world_data['quests'],
                world_data['items'],
                world_data['npcs']
            )

        # Step 7: Generate or load language skills
        print("  [7/9] Language skills...")
        cached_skills = self._load_cached("skills.json")
        if cached_skills:
            print("    Using cached skills.json")
            world_data['skills'] = cached_skills
        else:
            print("    Generating language skills...")
            # Get grammar curriculum from tutor data
            grammar_curriculum = world_data['tutor'].get('grammar_by_level', {})
            skill_gen = SkillGenerator(
                embedder=self.embedder,
                target_language=self.target_language,
                native_language=self.native_language,
                output_path=self.output_path
            )
            world_data['skills'] = skill_gen.generate(
                world_data['lore'],
                grammar_curriculum
            )

        # Step 8: Generate or load skill progression triggers
        print("  [8/9] Skill progression triggers...")
        cached_triggers = self._load_cached("triggers.json")
        if cached_triggers:
            print("    Using cached triggers.json")
            world_data['triggers'] = cached_triggers
        else:
            print("    Generating skill progression triggers...")
            trigger_gen = TriggerGenerator(
                embedder=self.embedder,
                target_language=self.target_language,
                native_language=self.native_language,
                output_path=self.output_path
            )
            world_data['triggers'] = trigger_gen.generate(
                world_data['skills'],
                world_data['quests'],
                world_data['npcs'],
            )

        # Step 9: Generate or load level progression requirements
        print("  [9/9] Level progression requirements...")
        cached_progression = self._load_cached("level_progression.json")
        if cached_progression:
            print("    Using cached level_progression.json")
            world_data['level_progression'] = cached_progression
        else:
            print("    Generating level progression requirements...")
            progression_gen = LevelProgressionGenerator(
                embedder=self.embedder,
                target_language=self.target_language,
                native_language=self.native_language,
                output_path=self.output_path
            )
            world_data['level_progression'] = progression_gen.generate(
                world_data['skills']
            )

        print("  World generation complete!")
        return world_data
