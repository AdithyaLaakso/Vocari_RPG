"""
NPC Generator

Generates NPCs with detailed personality prompts for future agent interactions.
Each NPC includes comprehensive behavior guidelines and example responses.

IMMERSION RULES:
- NPC agent_prompts focus on IN-WORLD identity and behavior
- NO teaching instructions or meta-commentary
- NO references to "the player", "the game", "language learning"
- Focus on vocabulary/grammar the character naturally uses
"""

from typing import Dict, Any, List
from .base_generator import BaseGenerator
from .models import NPCList, NPCRelationshipList, LanguageLevel


class NPCGenerator(BaseGenerator):
    """Generates NPCs with detailed agent prompts."""

    # Configuration
    MIN_NPCS_PER_LEVEL = 10
    LANGUAGE_LEVELS = ["A0", "A0+", "A1", "A1+", "A2"]

    # NPC archetypes with IN-WORLD behavior templates
    # Note: "teacher" archetype is an in-world village teacher, NOT a language tutor
    NPC_ARCHETYPES = {
        "merchant": {
            "typical_behaviors": [
                "Willing to negotiate prices within reason (10-20% discount max)",
                "Enthusiastic about their products",
                "May offer deals for bulk purchases",
                "Will not give items for free",
                "Will not accept obviously unfair trades"
            ],
            "unlikely_behaviors": [
                "Giving 50%+ discounts",
                "Giving away merchandise",
                "Buying items at above market value",
                "Accepting IOUs from strangers"
            ]
        },
        "guard": {
            "typical_behaviors": [
                "Helpful with directions and safety information",
                "Suspicious of suspicious behavior",
                "Enforces rules firmly but fairly",
                "Willing to assist with legitimate problems"
            ],
            "unlikely_behaviors": [
                "Participating in illegal activities",
                "Ignoring obvious crimes",
                "Accepting bribes",
                "Abandoning their post without reason"
            ]
        },
        "innkeeper": {
            "typical_behaviors": [
                "Friendly and welcoming to travelers",
                "Knowledgeable about local gossip",
                "Offers food, drink, and lodging for payment",
                "May share information about the town"
            ],
            "unlikely_behaviors": [
                "Giving free room and board",
                "Revealing private information about guests",
                "Serving illegal substances"
            ]
        },
        "child": {
            "typical_behaviors": [
                "Curious and asking questions",
                "Playing games",
                "Simple vocabulary and topics",
                "May know hiding spots or shortcuts",
                "Easily distracted"
            ],
            "unlikely_behaviors": [
                "Understanding complex adult topics",
                "Having specialized knowledge",
                "Making important decisions",
                "Keeping complex secrets"
            ]
        },
        "elder": {
            "typical_behaviors": [
                "Sharing stories and wisdom",
                "Speaking in measured, thoughtful ways",
                "Knowing local history",
                "Offering advice (not always taken)"
            ],
            "unlikely_behaviors": [
                "Being impulsive or rash",
                "Running errands",
                "Physical activities"
            ]
        },
        "teacher": {
            "typical_behaviors": [
                "Patient with village children",
                "Knowledgeable about local history",
                "Runs the village school",
                "Speaks clearly and slowly",
                "Corrects mistakes gently"
            ],
            "unlikely_behaviors": [
                "Discussing topics beyond basic education",
                "Leaving the school during class hours",
                "Being mean or discouraging"
            ]
        },
        "villager": {
            "typical_behaviors": [
                "Friendly but busy with daily tasks",
                "Knows neighbors and local gossip",
                "Helpful when not occupied",
                "Has opinions about village events"
            ],
            "unlikely_behaviors": [
                "Dropping everything to help strangers",
                "Sharing private family matters",
                "Taking long journeys"
            ]
        },
        "craftsman": {
            "typical_behaviors": [
                "Proud of their work",
                "Willing to discuss their craft",
                "May teach basics of their trade",
                "Trades goods for materials or money"
            ],
            "unlikely_behaviors": [
                "Giving away their tools",
                "Working for free",
                "Sharing trade secrets easily"
            ]
        },
        "farmer": {
            "typical_behaviors": [
                "Early riser, works hard",
                "Knowledgeable about weather and crops",
                "Sells produce at market",
                "Friendly but practical"
            ],
            "unlikely_behaviors": [
                "Leaving crops unattended",
                "Giving away harvest",
                "Working at night"
            ]
        }
    }

    def generate(self, lore: Dict[str, Any], world_map: Dict[str, Any]) -> Dict[str, Any]:
        """Generate NPCs for the world, ensuring minimum per language level."""
        print("  Generating NPCs...")

        # Get vocabulary content
        vocab_content = self.get_relevant_content(
            "vocabulary words phrases conversations dialogue",
            top_k=10
        )

        # Collect location info grouped by level
        locations = world_map.get('locations', [])
        locations_by_level = {}
        for loc in locations:
            level = loc.get('minimum_language_level', 'A0')
            if level not in locations_by_level:
                locations_by_level[level] = []
            locations_by_level[level].append(loc)

        valid_location_ids = {loc['id'] for loc in locations}

        # Generate NPCs for each language level
        all_npcs = []
        npc_counter = 1

        for level in self.LANGUAGE_LEVELS:
            level_locations = locations_by_level.get(level, [])
            if not level_locations:
                # Use locations from adjacent levels if none at this level
                for adj_level in self.LANGUAGE_LEVELS:
                    if locations_by_level.get(adj_level):
                        level_locations = locations_by_level[adj_level][:2]
                        break

            if not level_locations:
                continue

            print(f"    Generating NPCs for level {level}...")

            locations_summary = "\n".join([
                f"- {loc['id']}: {loc.get('name', {})} (Topics: {loc.get('language_topics', [])})"
                for loc in level_locations
            ])

            # Generate batch for this level
            level_npcs = self._generate_npcs_for_level(
                lore, level, locations_summary, vocab_content, level_locations
            )

            # Assign IDs and validate locations
            for npc in level_npcs:
                npc['id'] = f"npc_{npc_counter}_{self.slugify(npc.get('name', {}))}"
                npc_counter += 1

                # Fix location_id if invalid
                if npc.get('location_id') not in valid_location_ids:
                    if level_locations:
                        npc['location_id'] = level_locations[0]['id']

            all_npcs.extend(level_npcs)
            print(f"      Generated {len(level_npcs)} NPCs for level {level}")

        # Build NPC data structure
        npcs_data = {"npcs": all_npcs}

        # Build location->npcs index
        npcs_by_location = {}
        for npc in all_npcs:
            loc_id = npc.get('location_id')
            if loc_id not in npcs_by_location:
                npcs_by_location[loc_id] = []
            npcs_by_location[loc_id].append(npc['id'])

        npcs_data['_npcs_by_location'] = npcs_by_location

        # Build level->npcs index
        npcs_by_level = {}
        for npc in all_npcs:
            level = npc.get('language_level', 'A0')
            if level not in npcs_by_level:
                npcs_by_level[level] = []
            npcs_by_level[level].append(npc['id'])

        npcs_data['_npcs_by_level'] = npcs_by_level

        print(f"  Generated {len(all_npcs)} total NPCs across {len(npcs_by_location)} locations")
        for level in self.LANGUAGE_LEVELS:
            count = len(npcs_by_level.get(level, []))
            print(f"    {level}: {count} NPCs")

        # Generate relationships between NPCs
        print("  Generating NPC relationships...")
        relationships = self._generate_relationships(npcs_data, lore)
        npcs_data['relationships'] = relationships
        print(f"  Generated {len(relationships)} relationships")

        # Validate bilingual text
        errors = self.validate_bilingual_text(npcs_data)
        if errors:
            print(f"  Warning: Bilingual format issues found in NPCs: {errors[:3]}...")

        self.save_json(npcs_data, "npcs.json")
        return npcs_data

    def _generate_npcs_for_level(
        self,
        lore: Dict[str, Any],
        level: str,
        locations_summary: str,
        vocab_content: str,
        level_locations: List[Dict[str, Any]]
    ) -> List[Dict[str, Any]]:
        """Generate NPCs for a specific language level."""
        system_prompt = self._build_system_prompt_for_level(level)
        user_prompt = self._build_user_prompt_for_level(
            lore, level, locations_summary, vocab_content, level_locations
        )

        try:
            npcs_result = self.call_openai_structured(
                system_prompt=system_prompt,
                user_prompt=user_prompt,
                response_model=NPCList
            )
            return [npc.model_dump() for npc in npcs_result.npcs]
        except Exception as e:
            print(f"      Warning: Failed to generate NPCs for level {level}: {e}")
            # Try with smaller batch
            return self._generate_npcs_fallback(lore, level, level_locations)

    def _generate_npcs_fallback(
        self,
        lore: Dict[str, Any],
        level: str,
        level_locations: List[Dict[str, Any]]
    ) -> List[Dict[str, Any]]:
        """Fallback generation with simpler prompts."""
        npcs = []
        archetypes = ["merchant", "villager", "guard", "elder", "child"]

        for i, archetype in enumerate(archetypes[:self.MIN_NPCS_PER_LEVEL]):
            loc = level_locations[i % len(level_locations)] if level_locations else {"id": "village_center"}
            npcs.append({
                "name": {"native_language": f"{archetype.title()} {i+1}", "target_language": f"{archetype.title()} {i+1}"},
                "title": {"native_language": f"Village {archetype.title()}", "target_language": f"Village {archetype.title()}"},
                "archetype": archetype,
                "location_id": loc.get('id', 'village_center'),
                "language_level": level,
                "description": {"native_language": f"A {archetype} in the village", "target_language": f"Un {archetype} en el pueblo"},
                "appearance": {"native_language": "Average appearance", "target_language": "Apariencia promedio"},
                "personality": {
                    "traits": [{"native_language": "Friendly", "target_language": "Amigable"}],
                    "speaking_style": {"native_language": "Simple and direct", "target_language": "Simple y directo"},
                    "quirks": []
                },
                "knowledge": {
                    "knows_about": [{"native_language": "Local area", "target_language": "Área local"}],
                    "does_not_know": [{"native_language": "Distant lands", "target_language": "Tierras lejanas"}]
                },
                "greeting": {"native_language": "Hello!", "target_language": "¡Hola!"},
                "farewell": {"native_language": "Goodbye!", "target_language": "¡Adiós!"},
                "agent_prompt": f"You are a {archetype} who speaks simply at {level} level.",
                "vocabulary_focus": ["hola", "adios", "gracias"],
                "grammar_patterns": ["simple present"],
                "example_interactions": [{
                    "player_action": "Greet",
                    "npc_response": {"native_language": "Hello there!", "target_language": "¡Hola!"},
                    "reasoning": "Friendly greeting"
                }],
                "behavioral_boundaries": {
                    "will_do": ["Chat", "Give directions"],
                    "will_not_do": ["Give away items for free"],
                    "conditions": []
                }
            })

        return npcs

    def _build_system_prompt_for_level(self, level: str) -> str:
        """Build the system prompt for NPC generation at a specific level."""
        level_descriptions = {
            "A0": "absolute beginners - single words, basic greetings only",
            "A0+": "basic phrases - simple two-word sentences",
            "A1": "simple sentences - basic present tense",
            "A1+": "expanding sentences - past tense introduction",
            "A2": "complex sentences - multiple tenses, conditionals"
        }
        level_desc = level_descriptions.get(level, "basic")

        return f"""{self.get_base_system_prompt()}

You are generating NPCs for language level {level} ({level_desc}).

Each NPC needs:
1. A unique personality and role
2. A detailed AGENT PROMPT for AI role-play
3. Example dialogue at {level} level
4. Clear behavioral boundaries

CRITICAL IMMERSION RULES FOR agent_prompt:
- Focus on IN-WORLD identity: who they are, their personality
- Specify VOCABULARY they naturally use (appropriate for {level})
- Specify GRAMMAR PATTERNS they model
- DO NOT include: "help players learn", "teach vocabulary", "the player", "the game"
- The NPC should just BE their character

EXAMPLE agent_prompt for {level}:
"You are Miguel, a fruit seller. You speak simply using basic nouns and numbers.
You greet customers warmly. Vocabulary: fruits, numbers 1-10. Grammar: simple statements."

CRITICAL RULES:
1. DO NOT generate "id" fields - IDs assigned automatically
2. location_id MUST match EXACTLY from the LOCATIONS list
3. agent_prompt: 100-200 words, IN-CHARACTER only
4. ALL NPCs must have language_level set to "{level}"
5. Generate EXACTLY {self.MIN_NPCS_PER_LEVEL}-12 NPCs"""

    def _build_user_prompt_for_level(
        self,
        lore: Dict[str, Any],
        level: str,
        locations_summary: str,
        vocab_content: str,
        level_locations: List[Dict[str, Any]]
    ) -> str:
        """Build the user prompt for NPC generation at a specific level."""
        location_ids = [loc['id'] for loc in level_locations]

        return f"""Generate {self.MIN_NPCS_PER_LEVEL}-12 NPCs for language level {level}.

WORLD: {lore.get('world_name', {}).get('native_language', 'Fantasy Village')}

=== VALID LOCATIONS FOR THESE NPCs ===
{locations_summary}

VOCABULARY CONTENT:
{vocab_content[:1000]}

Generate NPCs following the NPCList schema:
- EXACTLY {self.MIN_NPCS_PER_LEVEL}-12 NPCs (no fewer!)
- ALL must have language_level: "{level}"
- Distribute across locations: {', '.join(location_ids)}
- Include variety: merchants, guards, children, elders, villagers, craftsmen, farmers
- agent_prompt: 100-200 words, IN-CHARACTER
- vocabulary_focus: 3-5 words
- grammar_patterns: 2-3 patterns
- 1-2 example_interactions per NPC

ARCHETYPES TO USE:
- merchant: sells goods, negotiates prices
- guard: protects, gives directions
- villager: daily tasks, local gossip
- elder: wisdom, stories
- child: curious, simple speech
- craftsman: proud of work
- farmer: practical, weather-aware

REQUIREMENTS:
1. location_id must be one of: {', '.join(location_ids)}
2. language_level MUST be "{level}" for ALL NPCs
3. Generate at least {self.MIN_NPCS_PER_LEVEL} NPCs!

Target: {self.target_language}, Native: {self.native_language}"""

    def _build_system_prompt(self) -> str:
        """Build the system prompt for NPC generation (legacy, for relationships)."""
        return f"""{self.get_base_system_prompt()}

You are generating NPCs for this language learning RPG."""

    def _build_user_prompt(self, lore: Dict[str, Any], locations_summary: str, vocab_content: str) -> str:
        """Build the user prompt for NPC generation (legacy)."""
        return f"""Generate NPCs for this world.

WORLD LORE:
{lore.get('world_name', {})}

=== VALID LOCATIONS ===
{locations_summary}

Target language: {self.target_language}
Native language: {self.native_language}"""

    def _generate_relationships(self, npcs_data: Dict[str, Any], lore: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Generate relationships between NPCs."""
        npcs = npcs_data.get('npcs', [])
        if len(npcs) < 2:
            return []

        # For large NPC counts, limit the summary to avoid token issues
        max_npcs_in_prompt = min(len(npcs), 60)

        # Create a summary of NPCs for the prompt
        npc_summary = "\n".join([
            f"[{i}] {npc.get('name', {}).get('native_language', 'Unknown')} - {npc.get('archetype', 'villager')} at {npc.get('location_id', 'unknown')}"
            for i, npc in enumerate(npcs[:max_npcs_in_prompt])
        ])

        # Scale relationship count based on NPC count
        relationship_count = min(30, max(15, len(npcs) // 2))

        system_prompt = f"""{self.get_base_system_prompt()}

You are generating RELATIONSHIPS between NPCs in a village.
Create realistic relationships that add depth to the world.

Relationship types:
- family: Parent, child, sibling, spouse, cousin
- friend: Close friends, childhood friends
- rival: Professional or personal rivalry
- professional: Business partners, mentor/apprentice
- neighbor: Live near each other
- acquaintance: Know each other casually"""

        user_prompt = f"""Generate {relationship_count} relationships between these NPCs.

=== NPCs (use indices 0 to {max_npcs_in_prompt - 1}) ===
{npc_summary}

Guidelines:
1. Create logical relationships (merchants might be business partners, children might be siblings)
2. Connect NPCs across different locations (creates reasons to travel)
3. Mix relationship types
4. Some NPCs can have multiple relationships
5. Use npc_a_index and npc_b_index to reference NPCs by their position in the list
6. Indices must be between 0 and {max_npcs_in_prompt - 1}

Target language: {self.target_language}
Native language: {self.native_language}"""

        try:
            relationships_result = self.call_openai_structured(
                system_prompt=system_prompt,
                user_prompt=user_prompt,
                response_model=NPCRelationshipList
            )

            # Convert indices to IDs
            result = []
            for rel in relationships_result.relationships:
                rel_dict = rel.model_dump()
                npc_a_idx = rel_dict.pop('npc_a_index', 0)
                npc_b_idx = rel_dict.pop('npc_b_index', 0)

                if 0 <= npc_a_idx < len(npcs) and 0 <= npc_b_idx < len(npcs):
                    rel_dict['npc_a_id'] = npcs[npc_a_idx]['id']
                    rel_dict['npc_b_id'] = npcs[npc_b_idx]['id']
                    result.append(rel_dict)

            return result
        except Exception as e:
            print(f"    Warning: Failed to generate relationships: {e}")
            return []

    def _format_archetypes(self) -> str:
        """Format archetype guidelines for the prompt."""
        lines = []
        for archetype, behaviors in self.NPC_ARCHETYPES.items():
            lines.append(f"\n{archetype.upper()}:")
            lines.append("  Typical behaviors:")
            for b in behaviors['typical_behaviors']:
                lines.append(f"    - {b}")
            lines.append("  Unlikely/refused behaviors:")
            for b in behaviors['unlikely_behaviors']:
                lines.append(f"    - {b}")
        return "\n".join(lines)

    def generate_npc_agent_prompt(self, npc: Dict[str, Any]) -> str:
        """Generate a comprehensive agent prompt for a specific NPC.
        This can be called separately to expand NPC prompts if needed."""

        system_prompt = f"""You are creating a detailed AI agent prompt for an NPC in an RPG.
The agent using this prompt will role-play as this NPC and must:
1. Stay in character at all times
2. Use {self.target_language} at the specified proficiency level
3. Have realistic limitations based on their role

CRITICAL: The prompt must be IN-CHARACTER only.
- NO teaching instructions
- NO references to "the player" or "the game"
- Focus on who the character IS and how they behave

Create a prompt that covers ALL possible interaction scenarios the agent might face."""

        user_prompt = f"""Create a comprehensive agent prompt for this NPC:

NPC Data:
{npc}

The prompt should cover:
1. Core identity and personality (who they are, how they speak)
2. Knowledge boundaries (what they know, what they don't)
3. Behavioral limits (what they will/won't do and why)
4. Vocabulary they naturally use (related to their role)
5. Grammar patterns they model
6. Common scenarios and how to handle them
7. Quest-related interactions if applicable
8. How to handle unexpected or inappropriate requests
9. Cultural elements to incorporate

Make it 400-600 words, highly specific, and actionable for an AI agent.
Remember: IN-CHARACTER ONLY. No meta-language about teaching."""

        return self.call_openai(
            system_prompt=system_prompt,
            user_prompt=user_prompt,
        )
