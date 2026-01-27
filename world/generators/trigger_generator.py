"""
Trigger Generator

Generates skill progression triggers that advance user skill levels.
All triggers are designed to be evaluatable deterministically using
only a grammar checker as an external tool.

Trigger types include:
- Vocabulary usage (correct use of specific words X times)
- Grammar usage (correct use of grammar patterns X times)
- Skill demonstrations (using pragmatic skills appropriately)
- In-game events (quest completion, NPC interaction, etc.)
"""

from typing import Dict, Any, List
from .base_generator import BaseGenerator
from .trigger_validator import TriggerValidator
from .models import (
    SkillProgressionTrigger,
    TriggerCondition,
    CompoundTrigger,
    TriggerType,
    TriggerOperator,
)


class TriggerGenerator(BaseGenerator):
    """Generates skill progression triggers."""

    # Default trigger thresholds by level
    LEVEL_THRESHOLDS = {
        "A0": {"vocab": 2, "grammar": 1, "pragmatic": 1},
        "A0+": {"vocab": 3, "grammar": 2, "pragmatic": 2},
        "A1": {"vocab": 4, "grammar": 3, "pragmatic": 3},
        "A1+": {"vocab": 5, "grammar": 4, "pragmatic": 4},
        "A2": {"vocab": 6, "grammar": 5, "pragmatic": 5},
    }

    def generate(
        self,
        skills: Dict[str, Any],
        quests: Dict[str, Any],
        npcs: Dict[str, Any],
    ) -> Dict[str, Any]:
        """Generate skill progression triggers."""
        print("  Generating skill progression triggers...")

        skill_list = skills.get('skills', [])
        skill_ids = set(skills.get('_skill_ids', []))

        quest_list = quests.get('quests', [])
        quest_ids = {q.get('id') for q in quest_list if q.get('id')}

        npc_list = npcs.get('npcs', [])
        npc_ids = {n.get('id') for n in npc_list if n.get('id')}

        # Create validator for trigger validation
        validator = TriggerValidator(
            valid_skill_ids=skill_ids,
            valid_quest_ids=quest_ids,
            valid_npc_ids=npc_ids,
        )

        all_triggers = []

        # Generate triggers for each skill
        for skill in skill_list:
            skill_triggers = self._generate_triggers_for_skill(skill)

            # Validate generated triggers
            valid_triggers = []
            for trigger in skill_triggers:
                result = validator.validate_skill_progression_trigger(trigger)
                if result.is_valid:
                    valid_triggers.append(trigger)
                else:
                    print(f"    Warning: Invalid trigger for skill '{skill.get('id', 'unknown')}': {result.errors[0].message if result.errors else 'unknown error'}")

            all_triggers.extend(valid_triggers)

        # Generate quest-based triggers
        print("    Generating quest-based triggers...")
        quest_triggers = self._generate_quest_triggers(quest_list, skill_list)
        for trigger in quest_triggers:
            result = validator.validate_skill_progression_trigger(trigger)
            if result.is_valid:
                all_triggers.append(trigger)

        # Convert to serializable format
        triggers_data = {
            "triggers": [self._trigger_to_dict(t) for t in all_triggers],
            "_trigger_count": len(all_triggers),
            "_triggers_by_skill": self._group_triggers_by_skill(all_triggers),
            "_meta": {
                "target_language": self.target_language,
                "native_language": self.native_language,
                "total_triggers": len(all_triggers)
            }
        }

        print(f"  Generated {len(all_triggers)} valid triggers")
        self.save_json(triggers_data, "triggers.json")
        return triggers_data

    def _generate_triggers_for_skill(
        self,
        skill: Dict[str, Any],
    ) -> List[SkillProgressionTrigger]:
        """Generate triggers for a specific skill."""
        triggers = []
        skill_category = skill.get('category', 'vocabulary')
        skill_level = skill.get('difficulty', 'A0')

        # Get threshold for this level
        level_str = skill_level.value if hasattr(skill_level, 'value') else skill_level
        thresholds = self.LEVEL_THRESHOLDS.get(level_str, self.LEVEL_THRESHOLDS["A0"])

        if skill_category == 'vocabulary':
            triggers.extend(self._generate_vocab_triggers(skill, thresholds))
        elif skill_category == 'grammar':
            triggers.extend(self._generate_grammar_triggers(skill, thresholds))
        elif skill_category == 'pragmatic':
            triggers.extend(self._generate_pragmatic_triggers(skill, thresholds))

        return triggers

    def _generate_vocab_triggers(
        self,
        skill: Dict[str, Any],
        thresholds: Dict[str, int]
    ) -> List[SkillProgressionTrigger]:
        """Generate vocabulary usage triggers."""
        triggers = []
        skill_id = skill.get('id', '')
        vocab_threshold = thresholds.get('vocab', 3)

        # Basic trigger: use any word from this skill correctly X times
        triggers.append(SkillProgressionTrigger(
            skill_id=skill_id,
            points_awarded=10,
            trigger=TriggerCondition(
                trigger_type=TriggerType.VOCAB_USED_CORRECTLY,
                target_id=skill_id,
                operator=TriggerOperator.GREATER_EQUAL,
                threshold=vocab_threshold
            ),
            repeatable=True,
            cooldown_interactions=5,
            description=f"Use vocabulary from '{skill_id}' correctly {vocab_threshold} times"
        ))

        # Mastery trigger: use vocabulary 10+ times
        triggers.append(SkillProgressionTrigger(
            skill_id=skill_id,
            points_awarded=25,
            trigger=TriggerCondition(
                trigger_type=TriggerType.VOCAB_USED_CORRECTLY,
                target_id=skill_id,
                operator=TriggerOperator.GREATER_EQUAL,
                threshold=vocab_threshold * 3
            ),
            repeatable=False,
            cooldown_interactions=0,
            description=f"Master vocabulary from '{skill_id}' (use {vocab_threshold * 3}+ times)"
        ))

        return triggers

    def _generate_grammar_triggers(
        self,
        skill: Dict[str, Any],
        thresholds: Dict[str, int]
    ) -> List[SkillProgressionTrigger]:
        """Generate grammar usage triggers."""
        triggers = []
        skill_id = skill.get('id', '')
        grammar_threshold = thresholds.get('grammar', 2)

        # Basic trigger: produce correct grammar pattern X times
        triggers.append(SkillProgressionTrigger(
            skill_id=skill_id,
            points_awarded=15,
            trigger=TriggerCondition(
                trigger_type=TriggerType.GRAMMAR_USED_CORRECTLY,
                target_id=skill_id,
                operator=TriggerOperator.GREATER_EQUAL,
                threshold=grammar_threshold
            ),
            repeatable=True,
            cooldown_interactions=3,
            description=f"Use grammar pattern '{skill_id}' correctly {grammar_threshold} times"
        ))

        # Pattern production trigger
        triggers.append(SkillProgressionTrigger(
            skill_id=skill_id,
            points_awarded=20,
            trigger=TriggerCondition(
                trigger_type=TriggerType.GRAMMAR_PATTERN_PRODUCED,
                target_id=skill_id,
                operator=TriggerOperator.GREATER_EQUAL,
                threshold=grammar_threshold * 2
            ),
            repeatable=False,
            cooldown_interactions=0,
            description=f"Produce grammar pattern '{skill_id}' {grammar_threshold * 2}+ times"
        ))

        return triggers

    def _generate_pragmatic_triggers(
        self,
        skill: Dict[str, Any],
        thresholds: Dict[str, int]
    ) -> List[SkillProgressionTrigger]:
        """Generate pragmatic skill triggers."""
        triggers = []
        skill_id = skill.get('id', '')
        pragmatic_threshold = thresholds.get('pragmatic', 2)

        # Skill demonstration trigger
        triggers.append(SkillProgressionTrigger(
            skill_id=skill_id,
            points_awarded=15,
            trigger=TriggerCondition(
                trigger_type=TriggerType.SKILL_DEMONSTRATED,
                target_id=skill_id,
                operator=TriggerOperator.GREATER_EQUAL,
                threshold=pragmatic_threshold
            ),
            repeatable=True,
            cooldown_interactions=5,
            description=f"Demonstrate skill '{skill_id}' appropriately {pragmatic_threshold} times"
        ))

        return triggers

    def _generate_quest_triggers(
        self,
        quests: List[Dict[str, Any]],
        skills: List[Dict[str, Any]]
    ) -> List[SkillProgressionTrigger]:
        """Generate triggers based on quest completion."""
        triggers = []

        # Build skill lookup by level
        skills_by_level = {}
        for skill in skills:
            level = skill.get('difficulty', 'A0')
            level_str = level.value if hasattr(level, 'value') else level
            if level_str not in skills_by_level:
                skills_by_level[level_str] = []
            skills_by_level[level_str].append(skill)

        for quest in quests:
            quest_id = quest.get('id', '')
            quest_level = quest.get('language_level', 'A0')
            level_str = quest_level.value if hasattr(quest_level, 'value') else quest_level

            if not quest_id:
                continue

            # Get skills at this level
            level_skills = skills_by_level.get(level_str, [])
            if not level_skills:
                continue

            # Create trigger that awards points to a relevant skill
            # Choose the first skill at this level
            target_skill = level_skills[0]

            triggers.append(SkillProgressionTrigger(
                skill_id=target_skill.get('id', ''),
                points_awarded=20,
                trigger=TriggerCondition(
                    trigger_type=TriggerType.QUEST_COMPLETED,
                    target_id=quest_id,
                    operator=TriggerOperator.EQUAL,
                    threshold=1
                ),
                repeatable=False,
                cooldown_interactions=0,
                description=f"Complete quest '{quest_id}'"
            ))

        return triggers

    def _trigger_to_dict(self, trigger: SkillProgressionTrigger) -> Dict[str, Any]:
        """Convert a trigger to a serializable dict."""
        trigger_dict = {
            "skill_id": trigger.skill_id,
            "points_awarded": trigger.points_awarded,
            "repeatable": trigger.repeatable,
            "cooldown_interactions": trigger.cooldown_interactions,
            "description": trigger.description
        }

        # Convert the trigger condition
        if isinstance(trigger.trigger, CompoundTrigger):
            trigger_dict["trigger"] = self._compound_trigger_to_dict(trigger.trigger)
        else:
            trigger_dict["trigger"] = self._condition_to_dict(trigger.trigger)

        return trigger_dict

    def _condition_to_dict(self, condition: TriggerCondition) -> Dict[str, Any]:
        """Convert a trigger condition to a serializable dict."""
        return {
            "trigger_type": condition.trigger_type.value,
            "target_id": condition.target_id,
            "operator": condition.operator.value,
            "threshold": condition.threshold
        }

    def _compound_trigger_to_dict(self, compound: CompoundTrigger) -> Dict[str, Any]:
        """Convert a compound trigger to a serializable dict."""
        conditions = []
        for cond in compound.conditions:
            if isinstance(cond, CompoundTrigger):
                conditions.append(self._compound_trigger_to_dict(cond))
            else:
                conditions.append(self._condition_to_dict(cond))

        return {
            "logic": compound.logic.value,
            "conditions": conditions
        }

    def _group_triggers_by_skill(
        self,
        triggers: List[SkillProgressionTrigger]
    ) -> Dict[str, int]:
        """Group trigger count by skill."""
        by_skill = {}
        for trigger in triggers:
            skill_id = trigger.skill_id
            if skill_id not in by_skill:
                by_skill[skill_id] = 0
            by_skill[skill_id] += 1
        return by_skill
