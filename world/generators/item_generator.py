"""
Item Generator

Generates items that exist in specific locations in the game world.
Items are the foundation for fetch/gather quests and must be placed
in accessible locations for quests to be completable.
"""

from typing import Dict, Any, List
from .base_generator import BaseGenerator


class ItemGenerator(BaseGenerator):
    """Generates items placed in specific locations."""

    # Item categories with typical examples
    ITEM_CATEGORIES = {
        "consumable": {
            "description": "Food, drinks, potions that can be used",
            "examples": ["bread", "water", "healing herb", "apple"],
            "typical_locations": ["market", "inn", "farm", "forest"]
        },
        "material": {
            "description": "Crafting or quest materials",
            "examples": ["wood", "stone", "cloth", "herb"],
            "typical_locations": ["forest", "mine", "field", "shop"]
        },
        "tool": {
            "description": "Usable tools and equipment",
            "examples": ["key", "map", "lantern", "rope"],
            "typical_locations": ["shop", "home", "guild"]
        },
        "document": {
            "description": "Letters, books, notes",
            "examples": ["letter", "book", "note", "map"],
            "typical_locations": ["library", "home", "school", "shop"]
        },
        "valuable": {
            "description": "Currency and valuables",
            "examples": ["coin", "gem", "ring", "necklace"],
            "typical_locations": ["market", "treasure", "shop"]
        },
        "gift": {
            "description": "Items meant to be given to NPCs",
            "examples": ["flower", "pastry", "handmade item"],
            "typical_locations": ["garden", "market", "shop"]
        }
    }

    def generate(self, lore: Dict[str, Any], world_map: Dict[str, Any]) -> Dict[str, Any]:
        """Generate items placed in specific locations."""
        print("  Generating items...")

        # Get vocabulary content for item names
        item_content = self.get_relevant_content(
            "objects things items vocabulary nouns",
            top_k=10
        )

        # Extract location info for the prompt
        locations_info = []
        for loc in world_map.get('locations', []):
            locations_info.append({
                "id": loc['id'],
                "name": loc.get('name', {}),
                "type": loc.get('type', ''),
                "language_level": loc.get('minimum_language_level', 'A0'),
                "vocabulary_domain": loc.get('vocabulary_domain', {})
            })

        system_prompt = f"""{self.get_base_system_prompt()}

You are generating ITEMS for this language learning RPG.

CRITICAL REQUIREMENTS:
1. Every item MUST be placed in a specific location using ONLY location_ids from the LOCATIONS list below
2. Items must be appropriate for their location (herbs in forest, bread in market, etc.)
3. Item language level must match or be below its location's level
4. Items are the foundation for quests - they MUST be gatherable/purchasable
5. DO NOT generate "id" fields - IDs will be assigned automatically by the system

ITEM ACQUISITION TYPES:
- "gather": Can be picked up freely (herbs in forest, stones on ground)
- "purchase": Must be bought from NPC at location (food at market)
- "receive": Given by NPC during quest/dialogue
- "find": Hidden/discoverable at location

ITEM CATEGORIES:
{self._format_item_categories()}

Each location should have 2-5 items appropriate to it."""

        user_prompt = f"""Generate items for this world.

WORLD CONTEXT:
{lore.get('world_name', {})}

=== VALID LOCATIONS (use ONLY these location_ids) ===
{self._format_locations_for_prompt(locations_info)}

VOCABULARY CONTENT:
{item_content}

Generate a JSON object with this structure (DO NOT include "id" fields - they will be assigned automatically):
{{
    "items": [
        {{
            "name": {{"native_language": "...", "target_language": "..."}},
            "description": {{"native_language": "...", "target_language": "..."}},
            "category": "consumable|material|tool|document|valuable|gift",
            "location_id": "MUST be from VALID LOCATIONS list above",
            "acquisition_type": "gather|purchase|receive|find",
            "language_level": "A0|A0+|A1|A1+|A2",
            "quantity_available": -1,
            "respawns": true,
            "price": 0,
            "vocabulary_word": {{"native_language": "...", "target_language": "..."}},
            "usage_hint": {{"native_language": "...", "target_language": "..."}}
        }}
    ]
}}

REQUIREMENTS:
1. Create 40-60 items total
2. Distribution by level:
   - A0: 8-12 very simple items (basic nouns like apple, water, bread)
   - A0+: 10-15 items (slightly more variety)
   - A1: 10-15 items (food, tools, materials)
   - A1+: 8-12 items (more specialized items)
   - A2: 6-10 items (complex or valuable items)
3. Every location must have at least 2 items
4. Items must match their location logically
5. CRITICAL: location_id MUST be copied exactly from the VALID LOCATIONS list
6. quantity_available: -1 means unlimited, positive number means limited
7. price: 0 for gatherable items, positive for purchasable

Target language: {self.target_language}
Native language: {self.native_language}"""

        items_data = self.call_openai_json(
            system_prompt=system_prompt,
            user_prompt=user_prompt,
        )

        # Assign deterministic IDs to all items
        items = items_data.get('items', [])
        items = self.assign_sequential_ids(items, prefix="item", start_index=1, name_field="name")
        items_data['items'] = items

        # Validate and fix location_ids
        valid_location_ids = {loc['id'] for loc in world_map.get('locations', [])}
        valid_items = []
        removed_count = 0

        for item in items:
            if item.get('location_id') in valid_location_ids:
                valid_items.append(item)
            else:
                # Try to find a matching location by partial match
                found = False
                loc_id = item.get('location_id', '')
                for valid_id in valid_location_ids:
                    if loc_id in valid_id or valid_id in loc_id:
                        item['location_id'] = valid_id
                        valid_items.append(item)
                        found = True
                        break

                if not found:
                    # Assign to first location as fallback
                    if valid_location_ids:
                        item['location_id'] = list(valid_location_ids)[0]
                        valid_items.append(item)
                        print(f"    Warning: Fixed invalid location for item '{item.get('id')}'")
                    else:
                        removed_count += 1

        items_data['items'] = valid_items

        if removed_count > 0:
            print(f"  Warning: Removed {removed_count} items with unfixable location_ids")

        # Build location->items index for easy lookup
        items_by_location = {}
        for item in valid_items:
            loc_id = item.get('location_id')
            if loc_id not in items_by_location:
                items_by_location[loc_id] = []
            items_by_location[loc_id].append(item['id'])

        items_data['_items_by_location'] = items_by_location

        print(f"  Generated {len(valid_items)} items across {len(items_by_location)} locations")

        # Validate bilingual text
        errors = self.validate_bilingual_text(items_data)
        if errors:
            print(f"  Warning: Bilingual format issues found in items: {errors[:3]}...")

        self.save_json(items_data, "items.json")
        return items_data

    def _format_item_categories(self) -> str:
        """Format item categories for the prompt."""
        lines = []
        for category, info in self.ITEM_CATEGORIES.items():
            lines.append(f"\n{category.upper()}: {info['description']}")
            lines.append(f"  Examples: {', '.join(info['examples'])}")
            lines.append(f"  Typical locations: {', '.join(info['typical_locations'])}")
        return "\n".join(lines)

    def _format_locations_for_prompt(self, locations: List[Dict]) -> str:
        """Format locations list for the prompt."""
        lines = []
        for loc in locations:
            name = loc.get('name', {})
            name_str = name.get('target_language', name.get('native_language', loc['id']))
            lines.append(
                f"- {loc['id']}: {name_str} (type: {loc.get('type', 'unknown')}, "
                f"level: {loc.get('language_level', 'A0')})"
            )
        return "\n".join(lines)
