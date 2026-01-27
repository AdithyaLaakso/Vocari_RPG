# Migration Guide: RPG World Generator v2

## Overview

This update adds three major systems:
1. **Language Skills** - Trackable skills with difficulty levels
2. **Skill Progression Triggers** - Deterministic triggers that award skill points
3. **Level Progression** - Requirements to advance from A0 → A0+ → A1 → A1+ → A2

All triggers use a **standard format** that can be evaluated deterministically using a grammar checker.

---

## New Output Files

After running the generator, you'll have 3 new JSON files:

| File | Description |
|------|-------------|
| `skills.json` | Language skills with evaluation criteria |
| `triggers.json` | Skill progression triggers |
| `level_progression.json` | Level advancement requirements |

---

## Integration Steps

### 1. Update Your Data Loading

```python
# Before
world_data = orchestrator.generate()
quests = world_data['quests']
npcs = world_data['npcs']

# After - also load new data
skills = world_data['skills']
triggers = world_data['triggers']
level_progression = world_data['level_progression']
```

### 2. Initialize Skill Tracking

Each skill has a level from 0-100. Track per-user:

```python
# Initialize user's skill levels (all start at 0)
user_skills = {skill['id']: 0 for skill in skills['skills']}
```

### 3. Evaluate Triggers After User Input

When the user produces text, use your grammar checker to evaluate triggers:

```python
from generators import TriggerValidator, TriggerCondition, TriggerType

def check_triggers(user_input: str, grammar_check_result: dict, user_state: dict):
    """Check if any triggers should fire after user input."""
    for trigger in triggers['triggers']:
        if evaluate_trigger(trigger['trigger'], user_state, grammar_check_result):
            # Award points
            skill_id = trigger['skill_id']
            points = trigger['points_awarded']
            user_state['skills'][skill_id] = min(100, user_state['skills'][skill_id] + points)
```

### 4. Evaluate Trigger Conditions

Triggers reference counters you maintain:

```python
def evaluate_condition(condition: dict, user_state: dict) -> bool:
    """Evaluate a single trigger condition."""
    trigger_type = condition['trigger_type']
    target_id = condition['target_id']
    operator = condition['operator']
    threshold = condition['threshold']

    # Get current value based on trigger type
    if trigger_type == 'vocab_used_correctly':
        current = user_state['vocab_usage'].get(target_id, 0)
    elif trigger_type == 'grammar_used_correctly':
        current = user_state['grammar_usage'].get(target_id, 0)
    elif trigger_type == 'skill_level_reached':
        current = user_state['skills'].get(target_id, 0)
    elif trigger_type == 'quest_completed':
        current = 1 if target_id in user_state['completed_quests'] else 0
    # ... handle other types

    # Compare
    if operator == '>=': return current >= threshold
    if operator == '>':  return current > threshold
    if operator == '==': return current == threshold
    if operator == '<=': return current <= threshold
    if operator == '<':  return current < threshold
    if operator == '!=': return current != threshold
```

### 5. Handle Compound Triggers

```python
def evaluate_trigger(trigger: dict, user_state: dict, grammar_result: dict) -> bool:
    """Evaluate a trigger (simple or compound)."""
    if 'logic' in trigger:
        # Compound trigger
        if trigger['logic'] == 'AND':
            return all(evaluate_trigger(c, user_state, grammar_result)
                      for c in trigger['conditions'])
        else:  # OR
            return any(evaluate_trigger(c, user_state, grammar_result)
                      for c in trigger['conditions'])
    else:
        # Simple condition
        return evaluate_condition(trigger, user_state)
```

### 6. Check Level Progression

Use the evaluator to check if user can advance:

```python
from generators import LevelProgressionEvaluator, LevelProgressionConfig

# Load config
config = LevelProgressionConfig(**level_progression)
evaluator = LevelProgressionEvaluator(config)

# Check if user can advance
can_advance, reasons = evaluator.can_advance(
    current_level=user_state['level'],  # e.g., LanguageLevel.A0
    skill_levels=user_state['skills']
)

if can_advance:
    user_state['level'] = next_level
```

---

## User State Schema

Your app should track:

```python
user_state = {
    # Current level
    'level': 'A0',  # A0, A0+, A1, A1+, A2

    # Skill levels (0-100 each)
    'skills': {
        'vocab_greetings_basic': 0,
        'grammar_present_ar': 0,
        # ...
    },

    # Counters for triggers (reset periodically or per-session)
    'vocab_usage': {
        'hola': 0,  # times used correctly
        'adios': 0,
        # ...
    },
    'grammar_usage': {
        'present_ar': 0,  # times pattern used correctly
        # ...
    },

    # Game state
    'completed_quests': set(),
    'visited_locations': set(),
    'npc_interactions': {},
}
```

---

## Grammar Checker Integration

Your grammar checker should return which patterns were used correctly:

```python
def check_grammar(user_input: str, target_language: str) -> dict:
    """Returns grammar check result."""
    return {
        'vocab_correct': ['hola', 'buenos_dias'],  # Words used correctly
        'grammar_patterns': ['present_ar'],        # Patterns produced
        'skill_demonstrations': ['greeting'],      # Pragmatic skills shown
    }
```

Then update counters:

```python
result = check_grammar(user_input, 'spanish')

for word in result['vocab_correct']:
    user_state['vocab_usage'][word] = user_state['vocab_usage'].get(word, 0) + 1

for pattern in result['grammar_patterns']:
    user_state['grammar_usage'][pattern] = user_state['grammar_usage'].get(pattern, 0) + 1
```

---

## Trigger Types Reference

| Type | target_id | What to Track |
|------|-----------|---------------|
| `vocab_used_correctly` | Word ID | Count of correct uses |
| `vocab_recognized` | Word ID | Count of correct recognition |
| `grammar_used_correctly` | Pattern ID | Count of correct productions |
| `grammar_pattern_produced` | Pattern ID | Count of pattern uses |
| `skill_demonstrated` | Skill ID | Count of demonstrations |
| `quest_completed` | Quest ID | 1 if completed, 0 otherwise |
| `npc_interaction` | NPC ID | Count of interactions |
| `location_visited` | Location ID | 1 if visited, 0 otherwise |
| `item_acquired` | Item ID | 1 if acquired, 0 otherwise |
| `skill_level_reached` | Skill ID | Current skill level (0-100) |
| `total_skill_points` | "total" | Sum of all skill levels |

---

## Example: Complete Flow

```python
# 1. User says something
user_input = "Hola, buenos días"

# 2. Grammar check
grammar_result = check_grammar(user_input, 'spanish')
# Returns: {'vocab_correct': ['hola', 'buenos_dias'], 'grammar_patterns': ['greeting']}

# 3. Update counters
for word in grammar_result['vocab_correct']:
    user_state['vocab_usage'][word] += 1

# 4. Check triggers
for trigger in triggers['triggers']:
    if evaluate_trigger(trigger['trigger'], user_state, grammar_result):
        if not trigger['repeatable'] and trigger['id'] in user_state['fired_triggers']:
            continue

        # Award points
        user_state['skills'][trigger['skill_id']] += trigger['points_awarded']
        user_state['fired_triggers'].add(trigger['id'])

# 5. Check level progression
can_advance, _ = evaluator.can_advance(user_state['level'], user_state['skills'])
if can_advance:
    advance_user_level(user_state)
```

---

## Breaking Changes

1. **NPC agent_prompts** - Now focus on in-world identity, no teaching language
2. **Quest schema** - Added `target_vocabulary` and `grammar_points` fields
3. **NPC schema** - Added `vocabulary_focus`, `grammar_patterns`, and `relationships`

---

## Validation

Use `TriggerValidator` to validate any custom triggers:

```python
from generators import TriggerValidator

validator = TriggerValidator(
    valid_skill_ids=set(s['id'] for s in skills['skills']),
    valid_quest_ids=set(q['id'] for q in quests['quests'])
)

result = validator.validate_trigger_condition(my_trigger)
if not result.is_valid:
    print(f"Invalid trigger: {result.errors}")
```
