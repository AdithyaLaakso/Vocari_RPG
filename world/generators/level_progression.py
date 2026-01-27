"""
Level Progression System

Creates DETERMINISTIC rules for advancing from one overall level to the next.
The progression system:
- Uses minimum skill thresholds for core skills at each level
- Integrates total skill points (sum of all skill levels)
- Allows flexible paths so users don't get stuck
- Ignores advanced skills for lower-level progression

Each level has:
- Required skill thresholds (must have certain skills at minimum levels)
- Total skill point requirement
- Flexible skill pool (any N of these at threshold Y)
"""

from typing import Dict, Any, List, Set, Tuple
from .base_generator import BaseGenerator
from .trigger_validator import TriggerValidator
from .models import (
    LevelProgressionRequirement,
    LevelProgressionConfig,
    SkillThreshold,
    LanguageLevel,
)


class LevelProgressionGenerator(BaseGenerator):
    """Generates deterministic level progression requirements."""

    # Level order for progression
    LEVEL_ORDER = [
        LanguageLevel.A0,
        LanguageLevel.A0_PLUS,
        LanguageLevel.A1,
        LanguageLevel.A1_PLUS,
        LanguageLevel.A2
    ]

    # Base requirements for each level transition
    # These are multipliers/percentages that get applied to skill counts
    LEVEL_BASE_REQUIREMENTS = {
        # A0 -> A0+: Very basic, just need to show some engagement
        "A0->A0+": {
            "min_total_points": 50,  # Out of 1000
            "core_skill_threshold": 20,  # 20% of max (100)
            "core_skill_count": 3,  # Must have 3 core skills at threshold
            "flexible_threshold": 10,
            "flexible_count": 2,
            "description": "Demonstrate basic familiarity with greetings and simple words"
        },
        # A0+ -> A1: Need more vocabulary and basic grammar
        "A0->A1": {
            "min_total_points": 120,
            "core_skill_threshold": 35,
            "core_skill_count": 5,
            "flexible_threshold": 20,
            "flexible_count": 3,
            "description": "Use basic vocabulary and simple present tense correctly"
        },
        # A1 -> A1+: Expanding vocabulary and grammar
        "A1->A1+": {
            "min_total_points": 250,
            "core_skill_threshold": 50,
            "core_skill_count": 7,
            "flexible_threshold": 30,
            "flexible_count": 4,
            "description": "Construct simple sentences and handle basic conversations"
        },
        # A1+ -> A2: More complex structures
        "A1+->A2": {
            "min_total_points": 450,
            "core_skill_threshold": 65,
            "core_skill_count": 10,
            "flexible_threshold": 40,
            "flexible_count": 5,
            "description": "Use past and future tenses, handle complex conversations"
        }
    }

    def generate(
        self,
        skills: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Generate level progression requirements based on skills."""
        print("  Generating level progression requirements...")

        skill_list = skills.get('skills', [])
        skills_by_level = skills.get('_skills_by_level', {})
        skill_ids = set(skills.get('_skill_ids', []))

        # Create validator
        validator = TriggerValidator(valid_skill_ids=skill_ids)

        # Generate requirements for each level transition
        requirements = []

        for i in range(len(self.LEVEL_ORDER) - 1):
            from_level = self.LEVEL_ORDER[i]
            to_level = self.LEVEL_ORDER[i + 1]

            requirement = self._generate_requirement(
                from_level,
                to_level,
                skill_list,
                skills_by_level
            )

            # Validate requirement
            result = validator.validate_level_progression_requirement(requirement)
            if result.is_valid:
                requirements.append(requirement)
            else:
                print(f"    Warning: Invalid requirement for {from_level.value} -> {to_level.value}")
                for err in result.errors:
                    print(f"      - {err.message}")

        # Create config
        config = LevelProgressionConfig(
            requirements=requirements,
            total_skill_point_cap=1000
        )

        # Convert to serializable format
        progression_data = {
            "requirements": [self._requirement_to_dict(r) for r in requirements],
            "total_skill_point_cap": config.total_skill_point_cap,
            "_level_order": [l.value for l in self.LEVEL_ORDER],
            "_meta": {
                "target_language": self.target_language,
                "native_language": self.native_language,
                "total_transitions": len(requirements)
            }
        }

        print(f"  Generated {len(requirements)} level progression requirements")
        self.save_json(progression_data, "level_progression.json")
        return progression_data

    def _generate_requirement(
        self,
        from_level: LanguageLevel,
        to_level: LanguageLevel,
        skills: List[Dict[str, Any]],
        skills_by_level: Dict[str, List[str]]
    ) -> LevelProgressionRequirement:
        """Generate requirement for a specific level transition."""

        key = f"{from_level.value}->{to_level.value}"
        base_req = self.LEVEL_BASE_REQUIREMENTS.get(key, self.LEVEL_BASE_REQUIREMENTS["A0->A0+"])

        # Get skills up to and including current level
        relevant_levels = []
        for level in self.LEVEL_ORDER:
            relevant_levels.append(level.value)
            if level == from_level:
                break

        # Collect skills from relevant levels
        relevant_skill_ids = []
        for level in relevant_levels:
            relevant_skill_ids.extend(skills_by_level.get(level, []))

        # Categorize skills
        core_skills = []
        flexible_skills = []

        for skill_id in relevant_skill_ids:
            skill = self._find_skill_by_id(skills, skill_id)
            if not skill:
                continue

            # Core skills are vocabulary and grammar at lower levels
            skill_level = skill.get('difficulty', 'A0')
            level_str = skill_level.value if hasattr(skill_level, 'value') else skill_level
            category = skill.get('category', '')

            # Skills at the current level are flexible, lower levels are core
            if level_str == from_level.value:
                flexible_skills.append(skill_id)
            else:
                # Prioritize vocabulary and grammar as core
                if category in ['vocabulary', 'grammar']:
                    core_skills.append(skill_id)
                else:
                    flexible_skills.append(skill_id)

        # Limit core skills to the required count
        core_count = min(len(core_skills), base_req['core_skill_count'])
        selected_core = core_skills[:core_count]

        # Create skill thresholds for core skills
        required_thresholds = [
            SkillThreshold(
                skill_id=skill_id,
                minimum_level=base_req['core_skill_threshold']
            )
            for skill_id in selected_core
        ]

        # Flexible pool from remaining skills
        flexible_pool = flexible_skills[:base_req['flexible_count'] * 2]  # Give double options

        return LevelProgressionRequirement(
            from_level=from_level,
            to_level=to_level,
            minimum_total_skill_points=base_req['min_total_points'],
            required_skill_thresholds=required_thresholds,
            flexible_skill_pool=flexible_pool,
            flexible_skill_count=min(base_req['flexible_count'], len(flexible_pool)),
            flexible_threshold=base_req['flexible_threshold'],
            description=base_req['description']
        )

    def _find_skill_by_id(
        self,
        skills: List[Dict[str, Any]],
        skill_id: str
    ) -> Dict[str, Any]:
        """Find a skill by its ID."""
        for skill in skills:
            if skill.get('id') == skill_id:
                return skill
        return {}

    def _requirement_to_dict(
        self,
        requirement: LevelProgressionRequirement
    ) -> Dict[str, Any]:
        """Convert a requirement to a serializable dict."""
        return {
            "from_level": requirement.from_level.value if hasattr(requirement.from_level, 'value') else requirement.from_level,
            "to_level": requirement.to_level.value if hasattr(requirement.to_level, 'value') else requirement.to_level,
            "minimum_total_skill_points": requirement.minimum_total_skill_points,
            "required_skill_thresholds": [
                {"skill_id": t.skill_id, "minimum_level": t.minimum_level}
                for t in requirement.required_skill_thresholds
            ],
            "flexible_skill_pool": requirement.flexible_skill_pool,
            "flexible_skill_count": requirement.flexible_skill_count,
            "flexible_threshold": requirement.flexible_threshold,
            "description": requirement.description
        }


class LevelProgressionEvaluator:
    """
    Evaluates if a user can advance to the next level.

    This is a runtime component that checks current skill levels against
    progression requirements.
    """

    def __init__(self, config: LevelProgressionConfig):
        self.config = config

    def can_advance(
        self,
        current_level: LanguageLevel,
        skill_levels: Dict[str, int]
    ) -> Tuple[bool, List[str]]:
        """
        Check if user can advance from current level.

        Args:
            current_level: Current language level
            skill_levels: Dict mapping skill_id -> current level (0-100)

        Returns:
            Tuple of (can_advance: bool, reasons: List[str])
        """
        requirement = self.config.get_requirement(current_level)
        if not requirement:
            return False, ["No progression available from this level"]

        reasons = []

        # Check total skill points
        total_points = sum(skill_levels.values())
        if total_points < requirement.minimum_total_skill_points:
            reasons.append(
                f"Need {requirement.minimum_total_skill_points} total skill points, have {total_points}"
            )

        # Check required skill thresholds
        for threshold in requirement.required_skill_thresholds:
            current = skill_levels.get(threshold.skill_id, 0)
            if current < threshold.minimum_level:
                reasons.append(
                    f"Skill '{threshold.skill_id}' needs level {threshold.minimum_level}, have {current}"
                )

        # Check flexible requirements
        if requirement.flexible_skill_count > 0:
            qualifying_count = 0
            for skill_id in requirement.flexible_skill_pool:
                current = skill_levels.get(skill_id, 0)
                if current >= requirement.flexible_threshold:
                    qualifying_count += 1

            if qualifying_count < requirement.flexible_skill_count:
                reasons.append(
                    f"Need {requirement.flexible_skill_count} flexible skills at level {requirement.flexible_threshold}, "
                    f"have {qualifying_count}"
                )

        can_advance = len(reasons) == 0
        return can_advance, reasons

    def get_progress(
        self,
        current_level: LanguageLevel,
        skill_levels: Dict[str, int]
    ) -> Dict[str, Any]:
        """
        Get detailed progress toward next level.

        Returns dict with:
        - total_points_progress: current / required
        - core_skills_progress: list of skill progress
        - flexible_skills_progress: count / required
        - overall_percentage: estimated % to next level
        """
        requirement = self.config.get_requirement(current_level)
        if not requirement:
            return {"error": "No progression available"}

        total_points = sum(skill_levels.values())

        # Core skill progress
        core_progress = []
        core_met = 0
        for threshold in requirement.required_skill_thresholds:
            current = skill_levels.get(threshold.skill_id, 0)
            progress = min(100, int((current / threshold.minimum_level) * 100)) if threshold.minimum_level > 0 else 100
            core_progress.append({
                "skill_id": threshold.skill_id,
                "current": current,
                "required": threshold.minimum_level,
                "progress_percent": progress,
                "met": current >= threshold.minimum_level
            })
            if current >= threshold.minimum_level:
                core_met += 1

        # Flexible skill progress
        flexible_qualifying = 0
        for skill_id in requirement.flexible_skill_pool:
            current = skill_levels.get(skill_id, 0)
            if current >= requirement.flexible_threshold:
                flexible_qualifying += 1

        # Calculate overall percentage
        total_weight = 3  # points, core, flexible
        points_pct = min(100, int((total_points / requirement.minimum_total_skill_points) * 100)) if requirement.minimum_total_skill_points > 0 else 100
        core_pct = int((core_met / len(requirement.required_skill_thresholds)) * 100) if requirement.required_skill_thresholds else 100
        flex_pct = int((flexible_qualifying / requirement.flexible_skill_count) * 100) if requirement.flexible_skill_count > 0 else 100

        overall_pct = int((points_pct + core_pct + flex_pct) / total_weight)

        return {
            "from_level": current_level.value if hasattr(current_level, 'value') else current_level,
            "to_level": requirement.to_level.value if hasattr(requirement.to_level, 'value') else requirement.to_level,
            "total_points": {
                "current": total_points,
                "required": requirement.minimum_total_skill_points,
                "progress_percent": points_pct
            },
            "core_skills": {
                "met": core_met,
                "required": len(requirement.required_skill_thresholds),
                "progress_percent": core_pct,
                "details": core_progress
            },
            "flexible_skills": {
                "qualifying": flexible_qualifying,
                "required": requirement.flexible_skill_count,
                "threshold": requirement.flexible_threshold,
                "progress_percent": flex_pct
            },
            "overall_progress_percent": overall_pct
        }
