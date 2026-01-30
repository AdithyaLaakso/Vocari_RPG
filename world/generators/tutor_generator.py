"""
Tutor Generator

Generates prompts and instructions for a tutor agent to be implemented later.
This does NOT create a tutor agent - it generates the DATA/PROMPTS that describe
how a tutor agent should behave.

The tutor agent exists OUTSIDE the game world as a helpful guide, unlike NPCs
which are IN-WORLD characters.

Output: tutor.json containing:
- tutor_system_prompt: System prompt for the future tutor agent
- teaching_style: Description of how the tutor should teach
- intervention_triggers: When the tutor should intervene
- vocabulary_by_quest: Quest ID -> vocabulary words index
- grammar_by_level: Level -> grammar points curriculum
"""

from typing import Dict, Any, List
from .base_generator import BaseGenerator
from .models import TutorPromptData, BilingualText, GrammarCurriculum, LanguageLevel


class TutorGenerator(BaseGenerator):
    """Generates prompts and instructions for the tutor agent."""

    def generate(
        self,
        quests: Dict[str, Any],
        items: Dict[str, Any],
        npcs: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Generate tutor prompts and curriculum data."""
        print("  Generating tutor data...")

        # Build vocabulary index from quests
        vocab_by_quest = self._build_vocab_index(quests, items)

        # Generate grammar curriculum using the model's knowledge
        grammar_by_level = self._generate_grammar_curriculum()

        # Build the tutor system prompt
        tutor_system_prompt = self._generate_tutor_system_prompt()

        tutor_data = TutorPromptData(
            tutor_system_prompt=tutor_system_prompt,
            teaching_style=BilingualText(
                native_language="Encouraging and patient",
                target_language=self._get_teaching_style_translation()
            ),
            intervention_triggers=[
                "quest_complete",
                "new_vocabulary",
                "new_language_feature",
                "stuck_indicator",
                "level_milestone",
                "session_end"
            ],
            vocabulary_by_quest=vocab_by_quest,
            grammar_by_level=grammar_by_level
        )

        # Convert to dict for saving
        tutor_dict = tutor_data.model_dump()

        # Add additional metadata
        tutor_dict['_meta'] = {
            'target_language': self.target_language,
            'native_language': self.native_language,
            'total_quests_indexed': len(vocab_by_quest),
            'levels_covered': list(grammar_by_level.keys())
        }

        print(f"  Generated tutor data with {len(vocab_by_quest)} quest vocabularies")

        self.save_json(tutor_dict, "tutor.json")
        return tutor_dict

    def _build_vocab_index(
        self,
        quests: Dict[str, Any],
        items: Dict[str, Any]
    ) -> Dict[str, List[str]]:
        """Build vocabulary index from quests and items."""
        vocab_by_quest = {}

        for quest in quests.get('quests', []):
            quest_id = quest.get('id', '')
            if not quest_id:
                continue

            vocab_words = []

            # Extract target_vocabulary if present
            target_vocab = quest.get('target_vocabulary', [])
            for v in target_vocab:
                if isinstance(v, dict):
                    # BilingualText format
                    native = v.get('native_language', '')
                    target = v.get('target_language', '')
                    if native and target:
                        vocab_words.append(f"{target} ({native})")
                elif isinstance(v, str):
                    vocab_words.append(v)

            # Also extract vocabulary from quest description if no target_vocabulary
            if not vocab_words:
                desc = quest.get('description', {})
                if isinstance(desc, dict):
                    target_desc = desc.get('target_language', '')
                    if target_desc:
                        # Extract key words (simplified extraction)
                        words = self._extract_keywords(target_desc)
                        vocab_words.extend(words[:5])

            # Extract vocabulary from tasks
            for task in quest.get('tasks', []):
                task_desc = task.get('description', {})
                if isinstance(task_desc, dict):
                    target_task = task_desc.get('target_language', '')
                    if target_task:
                        words = self._extract_keywords(target_task)
                        for w in words[:2]:
                            if w not in vocab_words:
                                vocab_words.append(w)

            if vocab_words:
                vocab_by_quest[quest_id] = vocab_words[:10]  # Limit to 10 words per quest

        return vocab_by_quest

    def _extract_keywords(self, text: str) -> List[str]:
        """Extract potential vocabulary keywords from text.
        Simple extraction - just splits and filters short words."""
        if not text:
            return []

        # Common stop words to filter out
        stop_words = {
            'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been',
            'being', 'have', 'has', 'had', 'do', 'does', 'did', 'will',
            'would', 'could', 'should', 'may', 'might', 'must', 'shall',
            'to', 'of', 'in', 'for', 'on', 'with', 'at', 'by', 'from',
            'as', 'into', 'through', 'during', 'before', 'after', 'above',
            'below', 'between', 'under', 'and', 'but', 'or', 'nor', 'so',
            'yet', 'both', 'either', 'neither', 'not', 'only', 'own',
            'same', 'than', 'too', 'very', 'just', 'el', 'la', 'los',
            'las', 'un', 'una', 'unos', 'unas', 'de', 'en', 'con', 'por',
            'para', 'y', 'o', 'que', 'es', 'son', 'está', 'están'
        }

        words = []
        for word in text.split():
            # Clean punctuation
            clean = word.strip('.,!?;:()[]{}"\'-').lower()
            if clean and len(clean) > 2 and clean not in stop_words:
                words.append(clean)

        return words

    def _generate_grammar_curriculum(self) -> Dict[str, List[str]]:
        """Generate grammar curriculum using LLM to tailor it to the target language."""
        system_prompt = f"""You are a language education expert creating a grammar curriculum for learning {self.target_language}.

Create a progression from absolute beginner (A0) to pre-intermediate (A2) level.
Each level should have 3-5 specific grammar points appropriate for that level."""

        user_prompt = f"""Create a grammar curriculum for {self.target_language} learners whose native language is {self.native_language}.

Return a JSON object with this structure:
{{
    "A0": ["grammar point 1", "grammar point 2", ...],
    "A0+": ["grammar point 1", "grammar point 2", ...],
    "A1": ["grammar point 1", "grammar point 2", ...],
    "A1+": ["grammar point 1", "grammar point 2", ...],
    "A2": ["grammar point 1", "grammar point 2", ...]
}}

Guidelines:
- A0: Very basic (single words, basic greetings, simple affirmations)
- A0+: Simple phrases (basic present tense, articles, simple questions)
- A1: Simple sentences (regular verbs, negation, question words)
- A1+: Expanding (irregular verbs, past tense intro, conjunctions)
- A2: More complex (past/future distinction, conditionals intro, reflexives)

Be specific to {self.target_language} grammar (e.g., for Spanish include ser/estar, gendered nouns, etc.)"""

        try:
            result = self.call_openai_json(
                system_prompt=system_prompt,
                user_prompt=user_prompt,
            )
            return result
        except Exception as e:
            print(f"    Warning: Failed to generate grammar curriculum, using default: {e}")
            return self._get_default_grammar_curriculum()

    def _get_default_grammar_curriculum(self) -> Dict[str, List[str]]:
        """Fallback default grammar curriculum."""
        return {
            "A0": [
                "Basic greetings",
                "Yes/No responses",
                "Numbers 1-10",
                "Single word responses"
            ],
            "A0+": [
                "Articles (the, a/an equivalents)",
                "Basic present tense (to be)",
                "Simple questions",
                "Numbers 1-20"
            ],
            "A1": [
                "Regular verb conjugation (present)",
                "Question words (what, where, who)",
                "Negation",
                "Basic adjectives"
            ],
            "A1+": [
                "Irregular common verbs",
                "Past tense introduction",
                "Conjunctions (and, but, or)",
                "Prepositions of place"
            ],
            "A2": [
                "Past vs present distinction",
                "Future tense (going to)",
                "Comparatives",
                "Reflexive verbs",
                "Basic conditionals"
            ]
        }

    def _generate_tutor_system_prompt(self) -> str:
        """Generate the system prompt for the tutor agent."""
        return f"""You are a friendly language tutor helping the player learn {self.target_language}.

You exist OUTSIDE the game world - you're a helpful guide, not an in-game character.

Your role:
- Praise the player when they learn new words
- Explain vocabulary and grammar when asked
- Offer practice exercises after quests
- Give hints when the player is stuck
- Celebrate milestones

Teaching approach:
- Start simple, build complexity gradually
- Connect new words to what the player just experienced in-game
- Keep explanations brief and clear
- Use {self.native_language} for explanations, {self.target_language} for examples
- Be encouraging but not overly effusive
- Adapt to the player's current level

Intervention moments:
- When a quest is completed: Review vocabulary learned
- When new vocabulary is introduced: Brief explanation before it's needed
- When the player seems stuck: Offer contextual hints
- At level milestones: Celebrate and summarize progress
- At session end: Review and set goals

Remember: You are NOT a game character. You're a meta-level assistant helping the player
learn the language through their gaming experience. Be warm, patient, and supportive."""

    def _get_teaching_style_translation(self) -> str:
        """Get the teaching style description in target language."""
        translations = {
            'spanish': 'Alentador y paciente',
            'french': 'Encourageant et patient',
            'german': 'Ermutigend und geduldig',
            'italian': 'Incoraggiante e paziente',
            'portuguese': 'Encorajador e paciente',
            'japanese': '励ましのある、忍耐強い',
            'chinese': '鼓励和耐心',
            'korean': '격려하고 인내심 있는',
            'arabic': 'مشجع وصبور',
            'russian': 'Поддерживающий и терпеливый'
        }
        return translations.get(self.target_language.lower(), 'Encouraging and patient')
