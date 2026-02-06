"""
Game Generator

Generates mini-games for quests with educational content.
Uses a separate agent (GPT-5) to generate Lua code for each game.

Games are:
1. Thematically related to quests
2. Educational (teach vocabulary/grammar from the quest)
3. Fun and unique - dynamically generated, not from fixed templates

The game generator creates prompts describing each game, then the game agent
generates the actual Lua code using the game engine API (loaded from prompt.txt).
"""

from typing import Dict, Any, List
from pathlib import Path
from .base_generator import BaseGenerator


class GameGenerator(BaseGenerator):
    """Generates mini-games for quests."""

    # Game concept examples to inspire unique games (not a fixed list)
    GAME_CONCEPT_EXAMPLES = [
        "vocabulary_match: Match words to their translations by clicking pairs",
        "word_order: Drag words to arrange them into a correct sentence",
        "fill_blank: Type the missing word in a sentence",
        "spelling_bee: Spell words letter by letter as they appear",
        "category_sort: Drag items into the correct category buckets",
        "memory_match: Flip cards to match word pairs",
        "word_search: Find hidden words in a letter grid",
        "typing_race: Type words before they reach the bottom of the screen",
        "picture_label: Click on parts of a scene and type their names",
        "whack_a_word: Click the correct translation before it disappears",
        "word_snake: Guide a snake to eat letters spelling a word",
        "bubble_pop: Pop bubbles containing correct answers",
        "jigsaw_sentence: Assemble sentence fragments like puzzle pieces",
        "rhythm_vocab: Tap words in rhythm with a beat",
        "gravity_drop: Catch falling words in the correct bucket",
    ]

    def __init__(
        self,
        embedder,
        target_language: str,
        native_language: str,
        output_path: Path
    ):
        super().__init__(embedder, target_language, native_language, output_path)
        self.game_engine_api = self._load_game_engine_api()

    def _load_game_engine_api(self) -> str:
        """Load the game engine API documentation from prompt.txt."""
        # Look for prompt.txt in parent directories
        prompt_path = Path(__file__).parent.parent.parent / "prompt.txt"
        if prompt_path.exists():
            with open(prompt_path, 'r', encoding='utf-8') as f:
                return f.read()
        else:
            raise FileNotFoundError(f"Game engine API not found at {prompt_path}")

    def generate(
        self,
        world_map: Dict[str, Any],
        npcs: Dict[str, Any],
        items: Dict[str, Any],
        quests: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Generate mini-games for quests."""
        print("  Generating mini-games...")

        # Build lookup tables
        self.locations = world_map.get('locations', [])
        self.npcs_list = npcs.get('npcs', [])
        self.items_list = items.get('items', [])
        self.quests_list = quests.get('quests', [])

        # Generate game specifications
        game_specs = self._generate_game_specs()

        if not game_specs:
            print("    No games generated")
            return {"games": []}

        # Generate Lua code for each game using the game agent
        games_with_code = []
        for i, spec in enumerate(game_specs):
            print(f"    Generating Lua for game {i + 1}/{len(game_specs)}: {spec.get('name', {}).get('native_language', 'Unknown')}...")
            lua_code = self._generate_lua_code(spec)
            spec['lua_code'] = lua_code
            games_with_code.append(spec)

        # Assign IDs and convert indices to IDs
        final_games = self._finalize_games(games_with_code)

        result = {
            "games": final_games,
            "_games_by_location": self._group_by_location(final_games),
            "_games_by_npc": self._group_by_npc(final_games),
            "_games_by_quest": self._group_by_quest(final_games),
        }

        self.save_json(result, "games.json")
        print(f"  Generated {len(final_games)} mini-games")
        return result

    def _generate_game_specs(self) -> List[Dict[str, Any]]:
        """Generate game specifications based on quests."""
        # CRITICAL: Every quest MUST have at least one game
        # Generate one game per quest to ensure full coverage
        target_game_count = len(self.quests_list)

        system_prompt = f"""{self.get_base_system_prompt()}

You are designing UNIQUE and FUN mini-games for a language learning RPG.

CRITICAL REQUIREMENT:
- You MUST generate exactly ONE game for EACH quest
- Every quest needs its own minigame - no quest should be left without one
- Each game MUST have a related_quest_index pointing to its quest

Each game should:
1. Be THEMATICALLY connected to a quest (setting, characters, items)
2. Be EDUCATIONALLY valuable (reinforce quest vocabulary/grammar)
3. Be CREATIVE and ENGAGING - not generic exercises
4. Be APPROPRIATE for the language level

GAME CONCEPT INSPIRATION (create variations or entirely new concepts):
{chr(10).join('- ' + ex for ex in self.GAME_CONCEPT_EXAMPLES)}

The games will be implemented as Lua code running in a simple 2D game engine.
Keep mechanics achievable with: drawing shapes, text, mouse input, simple animation.

DO NOT create complex 3D games or games requiring assets/images.
Focus on creative uses of shapes, colors, text, and interaction."""

        # Format quest info for the prompt
        quests_info = self._format_quests_for_prompt()
        locations_info = self._format_locations_indexed()
        npcs_info = self._format_npcs_indexed()

        user_prompt = f"""Design exactly {target_game_count} unique mini-games - ONE for EACH quest listed below.

CRITICAL: Every quest MUST have exactly one game. The number of games must equal the number of quests.

=== QUESTS (with vocabulary and grammar) ===
{quests_info}

=== LOCATIONS (use index for trigger) ===
{locations_info}

=== NPCs (use index for trigger) ===
{npcs_info}

For each game, provide:
1. name: Bilingual name
2. description: Bilingual description of what player does
3. language_level: A0, A0+, A1, A1+, or A2
4. trigger: How the game is accessed
   - trigger_type: "location" or "npc"
   - target_index: Index of the location or NPC
5. target_vocabulary: Words the game teaches (from the quest)
6. grammar_focus: Grammar points practiced (if any)
7. related_quest_index: Index of the related quest (REQUIRED - every game must link to a quest)
8. game_prompt: DETAILED description for generating Lua code, including:
   - Game mechanics (how it works)
   - Visual design (colors, layout, shapes)
   - Educational content (exact words/phrases to use)
   - Win/lose conditions
   - Any animations or effects
9. skill_points: Points awarded (10-30 based on difficulty)

REQUIREMENTS:
- Generate exactly {target_game_count} games (one per quest)
- Each game MUST have a valid related_quest_index (0 to {target_game_count - 1})
- Every quest index must be covered by exactly one game
- Make each game UNIQUE - avoid repetitive mechanics!

Target: {self.target_language}, Native: {self.native_language}

Return as JSON: {{"games": [...]}}"""

        try:
            result = self.call_openai_json(
                system_prompt=system_prompt,
                user_prompt=user_prompt,
                model="gpt-5",
            )
            return result.get('games', [])
        except Exception as e:
            print(f"    Warning: Failed to generate game specs: {e}")
            return []

    def _generate_lua_code(self, game_spec: Dict[str, Any]) -> str:
        """Generate Lua code for a game using the game agent (GPT-5)."""
        game_prompt = game_spec.get('game_prompt', '')
        name = game_spec.get('name', {}).get('native_language', 'Game')
        vocabulary: str = game_spec.get('target_vocabulary', [])
        grammar = game_spec.get('grammar_focus', [])
        level = game_spec.get('language_level', 'A0')

        # Format vocabulary for the prompt
        vocab_str = str(vocabulary)

        grammar_str = str(grammar)

        system_prompt = f"""You are a Lua game developer. You ONLY output valid Lua code, nothing else.
No explanations, no markdown, no comments outside the code. Just pure Lua.

{self.game_engine_api}

CRITICAL RULES:
1. Output ONLY Lua code - no markdown, no explanations
2. Use ONLY the API functions listed above
3. Keep the game simple but polished
4. Include clear visual feedback for correct/wrong answers
5. The game must be completable and have a clear end state
6. Use halt() when the game is won or lost
7. Display text in {self.target_language} with {self.native_language} hints where helpful
8. Make it visually appealing with colors and smooth animations"""

        user_prompt = f"""Create a Lua game: {name}

GAME DESCRIPTION:
{game_prompt}

VOCABULARY TO USE:
{vocab_str}

GRAMMAR FOCUS: {grammar_str}

LANGUAGE LEVEL: {level}

Requirements:
- Screen size: use getScreenWidth() and getScreenHeight()
- Must have init(), update(dt), and draw() functions
- Track score and display it
- Show success/failure state clearly
- Call halt() when game ends
- Use pleasant colors and clear text

Output ONLY the Lua code, nothing else."""

        try:
            # Use GPT-5 for better code generation
            response = self.call_openai(
                system_prompt=system_prompt,
                user_prompt=user_prompt,
                model="gpt-5",
            )

            # Clean up the response - remove any markdown if present
            code = response.strip()
            if code.startswith("```lua"):
                code = code[6:]
            if code.startswith("```"):
                code = code[3:]
            if code.endswith("```"):
                code = code[:-3]

            return code.strip()

        except Exception as e:
            print(f"      Warning: Failed to generate Lua code: {e}")
            # Return a minimal fallback game
            raise e

    def _get_fallback_game(self, name: str,) -> str:
        """Return a minimal fallback game if generation fails."""
        return f'''-- Fallback game: {name}
local score = 0
local gameOver = false
local message = ""

function init()
    message = "Click to start"
end

function update(dt)
    if isMouseJustPressed() and not gameOver then
        score = score + 10
        if score >= 30 then
            gameOver = true
            message = "You win!"
        end
    end
end

function draw()
    clear("#1a1a2e")
    drawText("Score: " .. score, 10, 10, "#ffffff", 20)
    drawText(message, getScreenWidth()/2 - 50, getScreenHeight()/2, "#00ff00", 24)
    if gameOver then
        drawText("Game Complete!", getScreenWidth()/2 - 70, getScreenHeight()/2 + 40, "#ffff00", 20)
    end
end
'''

    def _finalize_games(self, games: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Assign IDs and convert indices to actual IDs."""
        finalized = []
        for i, game in enumerate(games):
            idx = i + 1
            name = game.get('name', {})
            slug = self.slugify(name)
            game['id'] = f"game_{idx}_{slug}" if slug else f"game_{idx}"

            # Convert trigger indices to IDs
            trigger = game.get('trigger', {})
            trigger_type = trigger.get('trigger_type', 'location')
            target_index = trigger.get('target_index', 0)

            if trigger_type == 'location' and target_index < len(self.locations):
                game['trigger_id'] = self.locations[target_index].get('id', f'loc_{target_index}')
                game['trigger_type'] = 'location'
            elif trigger_type == 'npc' and target_index < len(self.npcs_list):
                game['trigger_id'] = self.npcs_list[target_index].get('id', f'npc_{target_index}')
                game['trigger_type'] = 'npc'
            else:
                # Default to first location
                game['trigger_id'] = self.locations[0].get('id', 'loc_1') if self.locations else 'loc_1'
                game['trigger_type'] = 'location'

            # Convert quest index to ID
            quest_index = game.get('related_quest_index')
            if quest_index is not None and quest_index < len(self.quests_list):
                game['related_quest_id'] = self.quests_list[quest_index].get('id')
            else:
                game['related_quest_id'] = None

            # Remove index-based fields
            game.pop('trigger', None)
            game.pop('related_quest_index', None)

            finalized.append(game)

        return finalized

    def _group_by_location(self, games: List[Dict[str, Any]]) -> Dict[str, List[str]]:
        """Group game IDs by trigger location."""
        by_location = {}
        for game in games:
            if game.get('trigger_type') == 'location':
                loc_id = game.get('trigger_id', '')
                if loc_id not in by_location:
                    by_location[loc_id] = []
                by_location[loc_id].append(game['id'])
        return by_location

    def _group_by_npc(self, games: List[Dict[str, Any]]) -> Dict[str, List[str]]:
        """Group game IDs by trigger NPC."""
        by_npc = {}
        for game in games:
            if game.get('trigger_type') == 'npc':
                npc_id = game.get('trigger_id', '')
                if npc_id not in by_npc:
                    by_npc[npc_id] = []
                by_npc[npc_id].append(game['id'])
        return by_npc

    def _group_by_quest(self, games: List[Dict[str, Any]]) -> Dict[str, List[str]]:
        """Group game IDs by related quest."""
        by_quest = {}
        for game in games:
            quest_id = game.get('related_quest_id')
            if quest_id:
                if quest_id not in by_quest:
                    by_quest[quest_id] = []
                by_quest[quest_id].append(game['id'])
        return by_quest

    def _format_quests_for_prompt(self) -> str:
        """Format quests with their vocabulary and grammar for the prompt."""
        lines = []
        for i, quest in enumerate(self.quests_list):
            name = quest.get('name', {}).get('native_language', quest.get('id', f'Quest {i}'))
            level = quest.get('language_level', 'A0')
            vocab = quest.get('target_vocabulary', [])
            grammar = quest.get('grammar_points', [])

            vocab_str = ", ".join([
                f"{v.get('target_language', '')}({v.get('native_language', '')})"
                for v in vocab[:5]
            ]) if vocab else "none"

            grammar_str = ", ".join(grammar[:3]) if grammar else "none"

            lines.append(f"[{i}] {name} (level: {level})")
            lines.append(f"    Vocabulary: {vocab_str}")
            lines.append(f"    Grammar: {grammar_str}")
        return "\n".join(lines)

    def _format_locations_indexed(self) -> str:
        """Format locations with indices."""
        lines = []
        for i, loc in enumerate(self.locations):
            name = loc.get('name', {}).get('native_language', loc.get('id', f'Location {i}'))
            level = loc.get('minimum_language_level', 'A0')
            lines.append(f"[{i}] {name} (level: {level})")
        return "\n".join(lines)

    def _format_npcs_indexed(self) -> str:
        """Format NPCs with indices."""
        lines = []
        for i, npc in enumerate(self.npcs_list):
            name = npc.get('name', {}).get('native_language', npc.get('id', f'NPC {i}'))
            loc_id = npc.get('location_id', 'unknown')
            lines.append(f"[{i}] {name} @ {loc_id}")
        return "\n".join(lines)
