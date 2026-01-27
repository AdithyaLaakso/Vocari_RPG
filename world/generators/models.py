"""
Pydantic Models for RPG World Generator

Defines all data structures used by generators for OpenAI structured output.
"""

from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Literal
from enum import Enum


class LanguageLevel(str, Enum):
    A0 = "A0"
    A0_PLUS = "A0+"
    A1 = "A1"
    A1_PLUS = "A1+"
    A2 = "A2"


class BilingualText(BaseModel):
    """Bilingual text in both native and target language."""
    native_language: str
    target_language: str


# ============================================================================
# NPC Models
# ============================================================================

class NPCPersonality(BaseModel):
    traits: List[BilingualText]
    speaking_style: BilingualText
    quirks: List[BilingualText] = []


class NPCKnowledge(BaseModel):
    knows_about: List[BilingualText]
    does_not_know: List[BilingualText]


class NPCExampleInteraction(BaseModel):
    player_action: str
    npc_response: BilingualText
    reasoning: str


class NPCBehavioralBoundaries(BaseModel):
    will_do: List[str]
    will_not_do: List[str]
    conditions: List[str] = []


class NPC(BaseModel):
    name: BilingualText
    title: BilingualText
    archetype: Literal["merchant", "guard", "innkeeper", "child", "elder", "teacher", "villager", "craftsman", "farmer"]
    location_id: str
    language_level: LanguageLevel
    description: BilingualText
    appearance: BilingualText
    personality: NPCPersonality
    knowledge: NPCKnowledge
    inventory: List[str] = []
    quest_roles: List[str] = []
    greeting: BilingualText
    farewell: BilingualText
    agent_prompt: str = Field(
        description="In-world character prompt. Focus on vocabulary/grammar they use. NO teaching instructions or meta-commentary."
    )
    vocabulary_focus: List[str] = Field(
        default=[],
        description="Simple words this NPC uses frequently"
    )
    grammar_patterns: List[str] = Field(
        default=[],
        description="Simple grammatical structures this NPC models"
    )
    example_interactions: List[NPCExampleInteraction]
    behavioral_boundaries: NPCBehavioralBoundaries


class NPCList(BaseModel):
    npcs: List[NPC]


class NPCRelationship(BaseModel):
    """Relationship between two NPCs."""
    npc_a_index: int = Field(description="Index of first NPC in the npcs array")
    npc_b_index: int = Field(description="Index of second NPC in the npcs array")
    relationship_type: Literal["family", "friend", "rival", "professional", "neighbor", "acquaintance"]
    description: BilingualText


class NPCRelationshipList(BaseModel):
    relationships: List[NPCRelationship]


# ============================================================================
# Quest Models
# ============================================================================

class TaskCompletionCriteria(BaseModel):
    """Criteria for task completion - uses indices that get converted to IDs later."""
    location_index: Optional[int] = Field(default=None, description="Index of target location (for at_location)")
    npc_index: Optional[int] = Field(default=None, description="Index of target NPC (for talked_to, gave_item, received_item)")
    item_index: Optional[int] = Field(default=None, description="Index of target item (for has_item, gave_item, received_item)")


class QuestTask(BaseModel):
    order: int
    description: BilingualText
    completion_type: Literal["at_location", "talked_to", "has_item", "gave_item", "received_item"]
    completion_criteria: TaskCompletionCriteria


class QuestDialogue(BaseModel):
    quest_offer: BilingualText
    quest_complete: BilingualText


class Quest(BaseModel):
    type: Literal["main", "side", "repeatable"]
    pattern: Literal["fetch", "delivery", "information", "persuasion", "exploration", "social"]
    name: BilingualText
    description: BilingualText
    giver_npc_index: int = Field(description="Index of the NPC who gives this quest")
    language_level: LanguageLevel
    target_vocabulary: List[BilingualText] = Field(
        default=[],
        description="Key vocabulary words for this quest"
    )
    grammar_points: List[str] = Field(
        default=[],
        description="Grammar structures practiced in this quest"
    )
    tasks: List[QuestTask]
    dialogue: QuestDialogue


class QuestList(BaseModel):
    quests: List[Quest]


# ============================================================================
# Item Models
# ============================================================================

class Item(BaseModel):
    name: BilingualText
    description: BilingualText
    category: Literal["consumable", "material", "tool", "document", "valuable", "gift"]
    location_id: str
    acquisition_type: Literal["gather", "purchase", "receive", "find"]
    language_level: LanguageLevel
    quantity_available: int = Field(default=-1, description="-1 means unlimited")
    respawns: bool = True
    price: int = Field(default=0, description="0 for free items")
    vocabulary_word: BilingualText
    usage_hint: BilingualText


class ItemList(BaseModel):
    items: List[Item]


# ============================================================================
# Location Models
# ============================================================================

class LocationConnection(BaseModel):
    to_location_id: str
    direction: BilingualText
    description: BilingualText
    required_level: Optional[LanguageLevel] = None


class Location(BaseModel):
    name: BilingualText
    type: str
    description: BilingualText
    minimum_language_level: LanguageLevel
    language_topics: List[str]
    vocabulary_domain: BilingualText
    atmosphere: BilingualText
    connections: List[LocationConnection] = []


class LocationList(BaseModel):
    locations: List[Location]


# ============================================================================
# Lore Models
# ============================================================================

class WorldTheme(BaseModel):
    name: BilingualText
    description: BilingualText


class WorldLore(BaseModel):
    world_name: BilingualText
    setting: BilingualText
    theme: WorldTheme
    history: List[BilingualText]
    culture: List[BilingualText]
    language_context: str = Field(description="Why the target language is spoken here")


# ============================================================================
# Tutor Prompt Models
# ============================================================================

class TutorPromptData(BaseModel):
    """Instructions/prompts for a tutor agent to be implemented later."""
    tutor_system_prompt: str = Field(description="System prompt for the tutor agent")
    teaching_style: BilingualText
    intervention_triggers: List[str]
    vocabulary_by_quest: Dict[str, List[str]] = Field(
        default={},
        description="Quest ID -> vocabulary words"
    )
    grammar_by_level: Dict[str, List[str]] = Field(
        default={},
        description="Level -> grammar points"
    )


class GrammarCurriculum(BaseModel):
    """Grammar curriculum organized by proficiency level."""
    level: LanguageLevel
    grammar_points: List[str] = Field(description="Grammar structures for this level")
    example_sentences: List[BilingualText] = Field(
        default=[],
        description="Example sentences demonstrating the grammar"
    )


# ============================================================================
# Trigger System Models - Standard Format for Deterministic Triggers
# ============================================================================

class TriggerType(str, Enum):
    """Types of triggers that can advance skills or progression."""
    # Vocabulary triggers
    VOCAB_USED_CORRECTLY = "vocab_used_correctly"
    VOCAB_RECOGNIZED = "vocab_recognized"

    # Grammar triggers
    GRAMMAR_USED_CORRECTLY = "grammar_used_correctly"
    GRAMMAR_PATTERN_PRODUCED = "grammar_pattern_produced"

    # Skill triggers (pragmatic, cultural, etc.)
    SKILL_DEMONSTRATED = "skill_demonstrated"

    # In-game triggers
    QUEST_COMPLETED = "quest_completed"
    NPC_INTERACTION = "npc_interaction"
    LOCATION_VISITED = "location_visited"
    ITEM_ACQUIRED = "item_acquired"

    # Compound triggers
    SKILL_LEVEL_REACHED = "skill_level_reached"
    TOTAL_SKILL_POINTS = "total_skill_points"


class TriggerOperator(str, Enum):
    """Comparison operators for trigger conditions."""
    GREATER_THAN = ">"
    GREATER_EQUAL = ">="
    EQUAL = "=="
    LESS_EQUAL = "<="
    LESS_THAN = "<"
    NOT_EQUAL = "!="


class TriggerCondition(BaseModel):
    """
    A single trigger condition that can be evaluated deterministically.

    Examples:
    - vocab_used_correctly: "hola" >= 3  (used "hola" correctly 3+ times)
    - grammar_used_correctly: "present_tense_ar" >= 5
    - skill_level_reached: "greetings" >= 50
    - quest_completed: "quest_1_market" == 1
    """
    trigger_type: TriggerType
    target_id: str = Field(description="ID of the target: vocab word, grammar pattern, skill_id, quest_id, etc.")
    operator: TriggerOperator
    threshold: int = Field(ge=0, description="Threshold value for comparison")

    def to_string(self) -> str:
        """Convert to human-readable string representation."""
        return f"{self.trigger_type.value}:{self.target_id} {self.operator.value} {self.threshold}"

    @classmethod
    def from_string(cls, s: str) -> "TriggerCondition":
        """Parse from string representation."""
        import re
        pattern = r"^(\w+):(.+?)\s*(>=|<=|==|!=|>|<)\s*(\d+)$"
        match = re.match(pattern, s.strip())
        if not match:
            raise ValueError(f"Invalid trigger condition format: {s}")

        trigger_type_str, target_id, operator_str, threshold_str = match.groups()
        return cls(
            trigger_type=TriggerType(trigger_type_str),
            target_id=target_id,
            operator=TriggerOperator(operator_str),
            threshold=int(threshold_str)
        )


class CompoundLogic(str, Enum):
    """Logic operators for combining trigger conditions."""
    AND = "AND"
    OR = "OR"


class CompoundTrigger(BaseModel):
    """
    A compound trigger that combines multiple conditions with AND/OR logic.
    Can be nested for complex conditions.
    """
    logic: CompoundLogic
    conditions: List["TriggerCondition | CompoundTrigger"] = Field(
        min_length=1,
        description="List of conditions or nested compound triggers"
    )

    def to_string(self) -> str:
        """Convert to human-readable string representation."""
        parts = []
        for cond in self.conditions:
            if isinstance(cond, CompoundTrigger):
                parts.append(f"({cond.to_string()})")
            else:
                parts.append(cond.to_string())
        return f" {self.logic.value} ".join(parts)


# Update forward reference
CompoundTrigger.model_rebuild()


# ============================================================================
# Language Skill Models
# ============================================================================

class SkillCategory(str, Enum):
    """Categories of language skills."""
    VOCABULARY = "vocabulary"
    GRAMMAR = "grammar"
    PRAGMATIC = "pragmatic"  # Greetings, requests, apologies, etc.
    CULTURAL = "cultural"
    PRONUNCIATION = "pronunciation"
    LISTENING = "listening"
    READING = "reading"


class LanguageSkill(BaseModel):
    """
    A specific language skill that can be tracked and leveled.

    Each skill has:
    - A difficulty level (A0 to A2)
    - A max level (0-100)
    - Prerequisites (other skills that should be learned first)
    - Evaluation criteria (how to determine if skill is used correctly)
    """
    id: str = Field(description="Unique identifier, e.g., 'vocab_greetings', 'grammar_present_ar'")
    name: BilingualText
    description: BilingualText
    category: SkillCategory
    difficulty: LanguageLevel
    max_level: int = Field(default=100, ge=1, le=100, description="Maximum level for this skill (0-100)")
    prerequisites: List[str] = Field(default=[], description="Skill IDs that should be learned first")
    weight: float = Field(default=1.0, ge=0.1, le=5.0, description="Weight for total skill point calculation")
    evaluation_criteria: List[str] = Field(
        description="How to evaluate if this skill is used correctly (for grammar checker)"
    )
    example_correct: List[BilingualText] = Field(
        default=[],
        description="Examples of correct usage"
    )
    example_incorrect: List[BilingualText] = Field(
        default=[],
        description="Examples of incorrect usage"
    )


class LanguageSkillList(BaseModel):
    skills: List[LanguageSkill]


# ============================================================================
# Skill Progression Trigger Models
# ============================================================================

class SkillProgressionTrigger(BaseModel):
    """
    A trigger that advances a skill level when conditions are met.

    Example: Advance "greetings" skill by 5 points when:
    - vocab_used_correctly: "hola" >= 3 AND
    - vocab_used_correctly: "buenos_dias" >= 2
    """
    skill_id: str = Field(description="ID of the skill to advance")
    points_awarded: int = Field(ge=1, le=100, description="Points to add to skill level")
    trigger: TriggerCondition | CompoundTrigger
    repeatable: bool = Field(default=False, description="Can this trigger fire multiple times?")
    cooldown_interactions: int = Field(
        default=0,
        ge=0,
        description="Number of interactions before trigger can fire again (if repeatable)"
    )
    description: str = Field(description="Human-readable description of what triggers this")


class SkillProgressionTriggerList(BaseModel):
    triggers: List[SkillProgressionTrigger]


# ============================================================================
# Level Progression Models
# ============================================================================

class SkillThreshold(BaseModel):
    """Minimum skill level required for a specific skill."""
    skill_id: str
    minimum_level: int = Field(ge=0, le=100)


class LevelProgressionRequirement(BaseModel):
    """
    Requirements to advance from one overall level to the next.

    Example: To advance from A0 to A0+:
    - Minimum skill levels for core A0 skills
    - Minimum total skill points
    - Optional: specific skills that must be at certain levels
    """
    from_level: LanguageLevel
    to_level: LanguageLevel

    # Core requirements
    minimum_total_skill_points: int = Field(
        ge=0,
        description="Minimum sum of all skill levels (0-1000 scale)"
    )

    # Specific skill requirements
    required_skill_thresholds: List[SkillThreshold] = Field(
        default=[],
        description="Minimum levels for specific skills"
    )

    # Flexible requirements (any N of these skills at threshold)
    flexible_skill_pool: List[str] = Field(
        default=[],
        description="Pool of skill IDs for flexible requirement"
    )
    flexible_skill_count: int = Field(
        default=0,
        ge=0,
        description="Number of skills from pool that must meet flexible_threshold"
    )
    flexible_threshold: int = Field(
        default=0,
        ge=0,
        le=100,
        description="Minimum level for flexible skills"
    )

    # Description
    description: str = Field(
        default="",
        description="Human-readable description of what this level represents"
    )


class LevelProgressionConfig(BaseModel):
    """Complete configuration for level progression system."""
    requirements: List[LevelProgressionRequirement]
    total_skill_point_cap: int = Field(
        default=1000,
        description="Maximum possible total skill points"
    )

    def get_requirement(self, from_level: LanguageLevel) -> Optional[LevelProgressionRequirement]:
        """Get the requirement to advance from a given level."""
        for req in self.requirements:
            if req.from_level == from_level:
                return req
        return None


# ============================================================================
# Validation Result Models
# ============================================================================

class TriggerValidationError(BaseModel):
    """An error found during trigger validation."""
    field: str
    message: str
    value: Optional[str] = None


class TriggerValidationResult(BaseModel):
    """Result of validating a trigger."""
    is_valid: bool
    errors: List[TriggerValidationError] = []
    warnings: List[str] = []
