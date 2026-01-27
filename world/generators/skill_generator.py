"""
Skill Generator

Generates an extensive list of language-specific skills extracted from
the curriculum documents. Each skill has:
- A difficulty level (A0 to A2)
- Evaluation criteria (how to check if used correctly)
- Prerequisites (skills that should be learned first)

Skills are designed to be evaluatable deterministically using a grammar checker.
"""

from typing import Dict, Any, List
from .base_generator import BaseGenerator
from .models import (
    LanguageSkill,
    LanguageSkillList,
    LanguageLevel,
    BilingualText,
    SkillCategory,
)


class SkillGenerator(BaseGenerator):
    """Generates language-specific skills from curriculum documents."""

    # Skill categories with examples for prompting
    SKILL_CATEGORY_EXAMPLES = {
        SkillCategory.VOCABULARY: {
            "description": "Knowledge and correct usage of specific words",
            "examples": [
                "Basic greetings (hola, adiós)",
                "Numbers 1-10",
                "Colors",
                "Food vocabulary",
                "Family members"
            ]
        },
        SkillCategory.GRAMMAR: {
            "description": "Correct use of grammatical structures",
            "examples": [
                "Present tense conjugation of -ar verbs",
                "Gender agreement (el/la)",
                "Plural formation",
                "Question formation",
                "Negation"
            ]
        },
        SkillCategory.PRAGMATIC: {
            "description": "Appropriate language use in social contexts",
            "examples": [
                "Greeting appropriately",
                "Making polite requests",
                "Apologizing",
                "Thanking",
                "Leave-taking"
            ]
        },
        SkillCategory.CULTURAL: {
            "description": "Understanding cultural norms in communication",
            "examples": [
                "Formal vs informal address (tú/usted)",
                "Appropriate topics for small talk",
                "Cultural expressions and idioms"
            ]
        }
    }

    def generate(
        self,
        lore: Dict[str, Any],
        grammar_curriculum: Dict[str, List[str]]
    ) -> Dict[str, Any]:
        """Generate language skills from curriculum documents."""
        print("  Generating language skills...")

        # Get relevant content from embeddings
        vocab_content = self.get_relevant_content(
            "vocabulary words nouns verbs adjectives phrases expressions",
            top_k=15
        )

        grammar_content = self.get_relevant_content(
            "grammar conjugation tense verb noun adjective sentence structure",
            top_k=15
        )

        pragmatic_content = self.get_relevant_content(
            "conversation dialogue greeting request polite formal informal",
            top_k=10
        )

        # Generate skills for each category and level
        all_skills = []

        # Generate vocabulary skills
        print("    Generating vocabulary skills...")
        vocab_skills = self._generate_skills_for_category(
            SkillCategory.VOCABULARY,
            vocab_content,
            grammar_curriculum
        )
        all_skills.extend(vocab_skills)

        # Generate grammar skills
        print("    Generating grammar skills...")
        grammar_skills = self._generate_skills_for_category(
            SkillCategory.GRAMMAR,
            grammar_content,
            grammar_curriculum
        )
        all_skills.extend(grammar_skills)

        # Generate pragmatic skills
        print("    Generating pragmatic skills...")
        pragmatic_skills = self._generate_skills_for_category(
            SkillCategory.PRAGMATIC,
            pragmatic_content,
            grammar_curriculum
        )
        all_skills.extend(pragmatic_skills)

        # Build skill data
        skills_data = {
            "skills": [s.model_dump() for s in all_skills],
            "_skill_ids": [s.id for s in all_skills],
            "_skills_by_level": self._group_skills_by_level(all_skills),
            "_skills_by_category": self._group_skills_by_category(all_skills),
            "_meta": {
                "target_language": self.target_language,
                "native_language": self.native_language,
                "total_skills": len(all_skills)
            }
        }

        print(f"  Generated {len(all_skills)} skills")
        self.save_json(skills_data, "skills.json")
        return skills_data

    def _generate_skills_for_category(
        self,
        category: SkillCategory,
        content: str,
        grammar_curriculum: Dict[str, List[str]]
    ) -> List[LanguageSkill]:
        """Generate skills for a specific category across all levels."""

        system_prompt = f"""{self.get_base_system_prompt()}

You are generating LANGUAGE SKILLS for a language learning system.

IMPORTANT: Each skill must have EVALUATION CRITERIA that can be checked deterministically.
A grammar checker will be used to verify if the skill is used correctly.

SKILL CATEGORIES:
{self._format_category_info()}

For each skill, provide:
1. A unique ID (lowercase, underscores, e.g., "vocab_greetings_basic")
2. Name in both languages
3. Description of what the skill covers
4. Difficulty level (A0, A0+, A1, A1+, A2)
5. Evaluation criteria - SPECIFIC patterns that can be checked:
   - For vocabulary: "User produces the word X in correct context"
   - For grammar: "User produces sentences matching pattern X"
   - For pragmatic: "User uses phrase X appropriately in context Y"
6. Prerequisites (other skill IDs that should be learned first)
7. Example correct and incorrect usage"""

        user_prompt = f"""Generate {category.value} skills for {self.target_language}.

CURRICULUM CONTENT:
{content}

GRAMMAR CURRICULUM BY LEVEL:
{self._format_grammar_curriculum(grammar_curriculum)}

Generate skills following the LanguageSkillList schema.

REQUIREMENTS:
1. Generate 15-25 skills for this category
2. Distribute across all levels (A0 through A2):
   - A0: 4-6 skills (absolute basics)
   - A0+: 4-6 skills (simple phrases)
   - A1: 4-6 skills (basic sentences)
   - A1+: 3-5 skills (expanding)
   - A2: 2-4 skills (more complex)
3. Each skill must have 2-4 SPECIFIC evaluation criteria
4. Evaluation criteria must be checkable by a grammar checker:
   - Pattern matching (e.g., "sentence contains verb in present tense")
   - Word usage (e.g., "user uses word 'X' in a grammatically correct sentence")
   - Structure matching (e.g., "sentence follows Subject-Verb-Object pattern")
5. Prerequisites should reference other skill IDs you're generating
6. Include 2-3 example correct and incorrect usages

Category: {category.value}
Target language: {self.target_language}
Native language: {self.native_language}"""

        try:
            result = self.call_openai_structured(
                system_prompt=system_prompt,
                user_prompt=user_prompt,
                response_model=LanguageSkillList
            )
            return result.skills
        except Exception as e:
            print(f"    Warning: Failed to generate {category.value} skills: {e}")
            return self._get_fallback_skills(category)

    def _format_category_info(self) -> str:
        """Format skill category information for prompts."""
        lines = []
        for cat, info in self.SKILL_CATEGORY_EXAMPLES.items():
            lines.append(f"\n{cat.value.upper()}: {info['description']}")
            lines.append("  Examples:")
            for ex in info['examples']:
                lines.append(f"    - {ex}")
        return "\n".join(lines)

    def _format_grammar_curriculum(self, curriculum: Dict[str, List[str]]) -> str:
        """Format grammar curriculum for prompts."""
        lines = []
        for level, points in curriculum.items():
            lines.append(f"\n{level}:")
            for point in points:
                lines.append(f"  - {point}")
        return "\n".join(lines)

    def _group_skills_by_level(self, skills: List[LanguageSkill]) -> Dict[str, List[str]]:
        """Group skill IDs by difficulty level."""
        by_level = {}
        for skill in skills:
            level = skill.difficulty.value if isinstance(skill.difficulty, LanguageLevel) else skill.difficulty
            if level not in by_level:
                by_level[level] = []
            by_level[level].append(skill.id)
        return by_level

    def _group_skills_by_category(self, skills: List[LanguageSkill]) -> Dict[str, List[str]]:
        """Group skill IDs by category."""
        by_category = {}
        for skill in skills:
            cat = skill.category.value if isinstance(skill.category, SkillCategory) else skill.category
            if cat not in by_category:
                by_category[cat] = []
            by_category[cat].append(skill.id)
        return by_category

    def _get_fallback_skills(self, category: SkillCategory) -> List[LanguageSkill]:
        """Return fallback skills if generation fails."""
        if category == SkillCategory.VOCABULARY:
            return [
                LanguageSkill(
                    id="vocab_greetings_basic",
                    name=BilingualText(native_language="Basic Greetings", target_language="Saludos Básicos"),
                    description=BilingualText(
                        native_language="Basic greeting words like hello and goodbye",
                        target_language="Palabras de saludo básicas como hola y adiós"
                    ),
                    category=SkillCategory.VOCABULARY,
                    difficulty=LanguageLevel.A0,
                    max_level=100,
                    prerequisites=[],
                    weight=1.5,
                    evaluation_criteria=[
                        "User produces greeting word in appropriate context",
                        "User responds to greeting with appropriate greeting"
                    ],
                    example_correct=[
                        BilingualText(native_language="Hello! How are you?", target_language="¡Hola! ¿Cómo estás?")
                    ],
                    example_incorrect=[
                        BilingualText(native_language="Goodbye! How are you?", target_language="¡Adiós! ¿Cómo estás?")
                    ]
                )
            ]
        elif category == SkillCategory.GRAMMAR:
            return [
                LanguageSkill(
                    id="grammar_present_basic",
                    name=BilingualText(native_language="Basic Present Tense", target_language="Presente Básico"),
                    description=BilingualText(
                        native_language="Basic present tense verb forms",
                        target_language="Formas verbales del presente básico"
                    ),
                    category=SkillCategory.GRAMMAR,
                    difficulty=LanguageLevel.A0_PLUS,
                    max_level=100,
                    prerequisites=["vocab_greetings_basic"],
                    weight=2.0,
                    evaluation_criteria=[
                        "User produces sentence with correctly conjugated present tense verb",
                        "Subject-verb agreement is correct"
                    ],
                    example_correct=[
                        BilingualText(native_language="I speak Spanish", target_language="Yo hablo español")
                    ],
                    example_incorrect=[
                        BilingualText(native_language="I speaks Spanish", target_language="Yo hablas español")
                    ]
                )
            ]
        else:
            return [
                LanguageSkill(
                    id=f"{category.value}_basic",
                    name=BilingualText(native_language=f"Basic {category.value}", target_language=f"{category.value} básico"),
                    description=BilingualText(
                        native_language=f"Basic {category.value} skills",
                        target_language=f"Habilidades básicas de {category.value}"
                    ),
                    category=category,
                    difficulty=LanguageLevel.A0,
                    max_level=100,
                    prerequisites=[],
                    weight=1.0,
                    evaluation_criteria=["User demonstrates basic competency"],
                    example_correct=[],
                    example_incorrect=[]
                )
            ]
