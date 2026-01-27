"""
Map Generator

Generates the world map with locations appropriate for language learning progression.
"""

from typing import Dict, Any, List
from .base_generator import BaseGenerator


class MapGenerator(BaseGenerator):
    """Generates the world map with interconnected locations."""

    def generate(self, lore: Dict[str, Any]) -> Dict[str, Any]:
        """Generate the world map based on lore."""
        print("  Generating world map...")

        # Get vocabulary/topic content for location inspiration
        location_content = self.get_relevant_content(
            "places locations buildings vocabulary",
            top_k=8
        )

        system_prompt = f"""{self.get_base_system_prompt()}

You are generating the WORLD MAP for this language learning RPG.

CRITICAL RULES:
1. DO NOT generate "id" fields - IDs will be assigned automatically
2. Focus on creating meaningful location names and content

Create locations that:
1. Provide natural contexts for different vocabulary domains (market=shopping, inn=food, etc.)
2. Are interconnected in a logical way
3. Have varying accessibility based on player progression
4. Support the A0 to A2 learning journey
5. Include indoor and outdoor locations

Each location should clearly map to specific language learning topics."""

        user_prompt = f"""Based on the world lore and language content, create the world map.

WORLD LORE:
World Name: {lore.get('world_name', {})}
Setting: {lore.get('setting', {})}

LANGUAGE CONTENT FOR LOCATIONS:
{location_content}

Generate a JSON object with this structure (DO NOT include "id" fields - they will be assigned automatically):
{{
    "map_metadata": {{
        "name": {{"native_language": "...", "target_language": "..."}},
        "description": {{"native_language": "...", "target_language": "..."}},
        "scale": "village|town|region"
    }},
    "regions": [
        {{
            "name": {{"native_language": "...", "target_language": "..."}},
            "description": {{"native_language": "...", "target_language": "..."}},
            "unlocked_at_level": "A0|A0+|A1|A1+|A2"
        }}
    ],
    "locations": [
        {{
            "region_index": 0,
            "name": {{"native_language": "...", "target_language": "..."}},
            "description": {{"native_language": "...", "target_language": "..."}},
            "type": "building|outdoor|dungeon|home|shop|etc",
            "language_topics": ["greetings", "shopping", "etc"],
            "vocabulary_domain": {{"native_language": "...", "target_language": "..."}},
            "minimum_language_level": "A0|A0+|A1|A1+|A2",
            "unlock_requirements": {{
                "language_level": "A0",
                "quest_prerequisites": [],
                "story_flags": []
            }},
            "connection_indices": [1, 2, 3],
            "atmosphere": {{"native_language": "...", "target_language": "..."}},
            "coordinates": {{"x": 0, "y": 0}}
        }}
    ]
}}

REQUIREMENTS:
1. Create 15-25 locations total
2. Group them into 3-5 regions
3. Regions should unlock progressively (A0 region first, then A0+, etc.)
4. Each language level (A0, A0+, A1, A1+, A2) should have at least 3 locations
5. Include: town square, market, inn/tavern, homes, school/library, outdoor areas
6. Make coordinates logical for a 2D map layout
7. Ensure A0 locations are immediately accessible
8. Use region_index (0-based) to indicate which region a location belongs to
9. Use connection_indices (0-based location index) to indicate connected locations

Target language: {self.target_language}
Native language: {self.native_language}"""

        world_map = self.call_openai_json(
            system_prompt=system_prompt,
            user_prompt=user_prompt,
            max_tokens=8192
        )

        # Assign deterministic IDs to regions
        regions = world_map.get('regions', [])
        regions = self.assign_sequential_ids(regions, prefix="region", start_index=1, name_field="name")
        world_map['regions'] = regions

        # Build region ID lookup
        region_ids = [r['id'] for r in regions]

        # Assign deterministic IDs to locations
        locations = world_map.get('locations', [])
        locations = self.assign_sequential_ids(locations, prefix="loc", start_index=1, name_field="name")

        # Convert region_index to region_id and connection_indices to connection IDs
        location_ids = [loc['id'] for loc in locations]
        for loc in locations:
            # Convert region_index to region_id
            region_idx = loc.pop('region_index', 0)
            if 0 <= region_idx < len(region_ids):
                loc['region_id'] = region_ids[region_idx]
            else:
                loc['region_id'] = region_ids[0] if region_ids else "region_1"

            # Convert connection_indices to connection IDs
            conn_indices = loc.pop('connection_indices', [])
            loc['connections'] = []
            for idx in conn_indices:
                if isinstance(idx, int) and 0 <= idx < len(location_ids):
                    loc['connections'].append(location_ids[idx])

            # Initialize empty lists for NPCs and items (to be filled later)
            loc['npcs'] = []
            loc['available_items'] = []

        world_map['locations'] = locations

        # Build connections list from location connections
        connections = []
        seen_pairs = set()
        for loc in locations:
            for conn_id in loc.get('connections', []):
                pair = tuple(sorted([loc['id'], conn_id]))
                if pair not in seen_pairs:
                    seen_pairs.add(pair)
                    connections.append({
                        "from_location": loc['id'],
                        "to_location": conn_id,
                        "bidirectional": True
                    })
        world_map['connections'] = connections

        # Set starting location to first A0 location
        starting_loc = None
        for loc in locations:
            if loc.get('minimum_language_level') == 'A0':
                starting_loc = loc['id']
                break
        world_map['starting_location'] = starting_loc or (location_ids[0] if location_ids else None)

        print(f"  Generated {len(locations)} locations in {len(regions)} regions")

        # Validate
        errors = self.validate_bilingual_text(world_map)
        if errors:
            print(f"  Warning: Bilingual format issues found in map: {errors[:3]}...")

        self.save_json(world_map, "map.json")
        return world_map
