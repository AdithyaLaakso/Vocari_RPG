#!/usr/bin/env python3
"""
Language Learning RPG World Generator

Creates an immersive RPG world designed to teach a target language
from absolute zero (A0) to A2 fluency level.
"""

import argparse
import re
import shutil
import sys
from pathlib import Path

from embeddings import DocumentEmbedder
from generators.world_orchestrator import WorldOrchestrator


def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Generate a language learning RPG world from documents"
    )
    parser.add_argument(
        "--target-language",
        "-t",
        required=True,
        help="The language to learn (e.g., 'Spanish', 'French', 'Japanese')"
    )
    parser.add_argument(
        "--native-language",
        "-n",
        required=True,
        help="The learner's native language (e.g., 'English')"
    )

    # Mutually exclusive group for document source vs existing embeddings
    source_group = parser.add_mutually_exclusive_group(required=True)
    source_group.add_argument(
        "--documents",
        "-d",
        help="Path to directory containing language learning documents"
    )
    source_group.add_argument(
        "--embeddings",
        "-e",
        help="Path to existing embeddings directory (reuse embeddings from a previous run)"
    )

    parser.add_argument(
        "--output",
        "-o",
        default="./output",
        help="Output directory for generated world files (default: ./output)"
    )
    parser.add_argument(
        "--force-rebuild",
        "-f",
        action="store_true",
        help="Force rebuild embeddings even if they exist (only with -d)"
    )
    return parser.parse_args()


def get_next_version_path(base_output: Path, native_lang: str, target_lang: str) -> Path:
    """
    Determine the next version directory path.

    Structure: output/n-{native}-t-{target}/v{N}/
    """
    # Normalize language names (lowercase, no spaces)
    native_normalized = native_lang.lower().replace(" ", "-")
    target_normalized = target_lang.lower().replace(" ", "-")

    # Create language combination directory name
    lang_dir_name = f"n-{native_normalized}-t-{target_normalized}"
    lang_dir = base_output / lang_dir_name

    # Find the next version number
    if not lang_dir.exists():
        next_version = 1
    else:
        # Find existing version directories
        version_pattern = re.compile(r'^v(\d+)$')
        existing_versions = []

        for item in lang_dir.iterdir():
            if item.is_dir():
                match = version_pattern.match(item.name)
                if match:
                    existing_versions.append(int(match.group(1)))

        if existing_versions:
            next_version = max(existing_versions) + 1
        else:
            next_version = 1

    version_path = lang_dir / f"v{next_version}"
    return version_path


def main():
    args = parse_arguments()

    # Create versioned output directory structure
    base_output = Path(args.output)
    version_path = get_next_version_path(
        base_output,
        args.native_language,
        args.target_language
    )
    version_path.mkdir(parents=True, exist_ok=True)

    print(f"=== Language Learning RPG World Generator ===")
    print(f"Target Language: {args.target_language}")
    print(f"Native Language: {args.native_language}")

    if args.documents:
        # Mode 1: Generate new embeddings from documents
        doc_path = Path(args.documents)
        if not doc_path.exists():
            print(f"Error: Document directory '{args.documents}' does not exist")
            sys.exit(1)

        if not doc_path.is_dir():
            print(f"Error: '{args.documents}' is not a directory")
            sys.exit(1)

        print(f"Documents: {args.documents}")
        print(f"Output: {version_path}")
        print()

        # Step 1: Create/load document embeddings (version-specific)
        print("Step 1: Processing document embeddings...")
        embedder = DocumentEmbedder(
            doc_path=doc_path,
            output_path=version_path,
            force_rebuild=args.force_rebuild
        )
        embedder.process()
        print("  Embeddings ready.")

    else:
        # Mode 2: Reuse existing embeddings
        embed_path = Path(args.embeddings)
        if not embed_path.exists():
            print(f"Error: Embeddings directory '{args.embeddings}' does not exist")
            sys.exit(1)

        if not embed_path.is_dir():
            print(f"Error: '{args.embeddings}' is not a directory")
            sys.exit(1)

        # Check for required embedding files
        embeddings_file = embed_path / "embeddings.pkl"
        metadata_file = embed_path / "embeddings_metadata.json"

        if not embeddings_file.exists() or not metadata_file.exists():
            print(f"Error: Embeddings directory must contain 'embeddings.pkl' and 'embeddings_metadata.json'")
            print(f"  Found: {list(embed_path.glob('*.pkl'))} and {list(embed_path.glob('*.json'))}")
            sys.exit(1)

        print(f"Embeddings: {args.embeddings}")
        print(f"Output: {version_path}")
        print()

        # Step 1: Copy embeddings to new version directory
        print("Step 1: Copying existing embeddings...")
        shutil.copy(embeddings_file, version_path / "embeddings.pkl")
        shutil.copy(metadata_file, version_path / "embeddings_metadata.json")

        # Load the embedder from the copied files
        embedder = DocumentEmbedder(
            doc_path=embed_path,  # Not used for loading, but required
            output_path=version_path,
            force_rebuild=False
        )
        embedder.load_existing()
        print(f"  Loaded {len(embedder.chunks)} chunks from existing embeddings.")

    print()

    # Step 2: Generate the world (in version-specific directory)
    print("Step 2: Generating RPG world...")
    orchestrator = WorldOrchestrator(
        embedder=embedder,
        target_language=args.target_language,
        native_language=args.native_language,
        output_path=version_path
    )
    orchestrator.generate()
    print()

    print("=== World Generation Complete ===")
    print(f"Output files saved to: {version_path}")
    print("\nGenerated files:")
    for f in version_path.iterdir():
        if f.is_file() and f.suffix == '.json':
            print(f"  - {f.name}")


if __name__ == "__main__":
    main()
