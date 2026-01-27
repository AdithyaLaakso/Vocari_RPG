"""
Document Embedding System

Handles creating, storing, and querying OpenAI embeddings
for language learning documents.
"""

import json
import hashlib
import pickle
from pathlib import Path
from typing import List, Dict, Any, Optional
import os

try:
    from openai import OpenAI
except ImportError:
    print("Please install openai: pip install openai")
    raise

import numpy as np


class DocumentEmbedder:
    """Manages document embeddings for the language learning content."""

    SUPPORTED_EXTENSIONS = {'.txt', '.md', '.pdf', '.json', '.csv'}
    EMBEDDING_MODEL = "text-embedding-3-small"
    CHUNK_SIZE = 1000  # Characters per chunk
    CHUNK_OVERLAP = 200  # Overlap between chunks

    def __init__(
        self,
        doc_path: Path,
        output_path: Path,
        force_rebuild: bool = False
    ):
        self.doc_path = doc_path
        self.output_path = output_path
        self.force_rebuild = force_rebuild
        self.embeddings_file = output_path / "embeddings.pkl"
        self.metadata_file = output_path / "embeddings_metadata.json"
        self.client = OpenAI()

        self.documents: List[Dict[str, Any]] = []
        self.embeddings: Optional[np.ndarray] = None
        self.chunks: List[Dict[str, Any]] = []

    def _compute_directory_hash(self) -> str:
        """Compute a hash of all documents to detect changes."""
        hasher = hashlib.md5()

        for file_path in sorted(self.doc_path.rglob("*")):
            if file_path.is_file() and file_path.suffix.lower() in self.SUPPORTED_EXTENSIONS:
                hasher.update(str(file_path).encode())
                hasher.update(str(file_path.stat().st_mtime).encode())
                hasher.update(str(file_path.stat().st_size).encode())

        return hasher.hexdigest()

    def _should_rebuild(self) -> bool:
        """Check if embeddings need to be rebuilt."""
        if self.force_rebuild:
            return True

        if not self.embeddings_file.exists() or not self.metadata_file.exists():
            return True

        try:
            with open(self.metadata_file, 'r') as f:
                metadata = json.load(f)

            current_hash = self._compute_directory_hash()
            if metadata.get('directory_hash') != current_hash:
                return True

            return False
        except Exception:
            return True

    def _read_file(self, file_path: Path) -> str:
        """Read content from a file."""
        suffix = file_path.suffix.lower()

        if suffix in {'.txt', '.md'}:
            with open(file_path, 'r', encoding='utf-8') as f:
                return f.read()

        elif suffix == '.json':
            with open(file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
                return json.dumps(data, indent=2)

        elif suffix == '.csv':
            with open(file_path, 'r', encoding='utf-8') as f:
                return f.read()

        elif suffix == '.pdf':
            try:
                import fitz  # pymupdf
                doc = fitz.open(file_path)
                text = ""
                for page in doc:
                    text += page.get_text() + "\n"
                doc.close()
                return text
            except ImportError:
                print(f"  Warning: pymupdf not installed, skipping {file_path}")
                return ""

        return ""

    def _chunk_text(self, text: str, source: str) -> List[Dict[str, Any]]:
        """Split text into overlapping chunks."""
        chunks = []
        start = 0

        while start < len(text):
            end = start + self.CHUNK_SIZE
            chunk_text = text[start:end]

            # Try to break at sentence boundary
            if end < len(text):
                last_period = chunk_text.rfind('.')
                last_newline = chunk_text.rfind('\n')
                break_point = max(last_period, last_newline)
                if break_point > self.CHUNK_SIZE // 2:
                    chunk_text = chunk_text[:break_point + 1]
                    end = start + break_point + 1

            if chunk_text.strip():
                chunks.append({
                    'text': chunk_text.strip(),
                    'source': source,
                    'start_char': start,
                    'end_char': end
                })

            start = end - self.CHUNK_OVERLAP

        return chunks

    def _load_documents(self) -> List[Dict[str, Any]]:
        """Load all documents from the directory."""
        documents = []

        for file_path in self.doc_path.rglob("*"):
            if file_path.is_file() and file_path.suffix.lower() in self.SUPPORTED_EXTENSIONS:
                print(f"  Loading: {file_path.name}")
                content = self._read_file(file_path)
                if content:
                    documents.append({
                        'path': str(file_path),
                        'name': file_path.name,
                        'content': content
                    })

        return documents

    def _create_embeddings(self, texts: List[str]) -> np.ndarray:
        """Create embeddings for a list of texts using OpenAI API."""
        embeddings = []
        batch_size = 100  # OpenAI allows up to 2048, but we'll be conservative

        for i in range(0, len(texts), batch_size):
            batch = texts[i:i + batch_size]
            print(f"  Creating embeddings batch {i // batch_size + 1}...")

            response = self.client.embeddings.create(
                model=self.EMBEDDING_MODEL,
                input=batch
            )

            for item in response.data:
                embeddings.append(item.embedding)

        return np.array(embeddings)

    def _save_embeddings(self):
        """Save embeddings and metadata to disk."""
        # Save embeddings
        with open(self.embeddings_file, 'wb') as f:
            pickle.dump({
                'embeddings': self.embeddings,
                'chunks': self.chunks
            }, f)

        # Save metadata
        metadata = {
            'directory_hash': self._compute_directory_hash(),
            'num_documents': len(self.documents),
            'num_chunks': len(self.chunks),
            'embedding_model': self.EMBEDDING_MODEL,
            'documents': [{'name': d['name'], 'path': d['path']} for d in self.documents]
        }

        with open(self.metadata_file, 'w') as f:
            json.dump(metadata, f, indent=2)

    def _load_embeddings(self):
        """Load embeddings from disk."""
        with open(self.embeddings_file, 'rb') as f:
            data = pickle.load(f)
            self.embeddings = data['embeddings']
            self.chunks = data['chunks']

        with open(self.metadata_file, 'r') as f:
            metadata = json.load(f)
            print(f"  Loaded {metadata['num_chunks']} chunks from {metadata['num_documents']} documents")

    def load_existing(self):
        """Load existing embeddings without checking directory hash.

        Use this when copying embeddings from another location.
        """
        if not self.embeddings_file.exists() or not self.metadata_file.exists():
            raise FileNotFoundError(
                f"Embeddings files not found at {self.output_path}. "
                "Expected 'embeddings.pkl' and 'embeddings_metadata.json'"
            )

        with open(self.embeddings_file, 'rb') as f:
            data = pickle.load(f)
            self.embeddings = data['embeddings']
            self.chunks = data['chunks']

        with open(self.metadata_file, 'r') as f:
            self.metadata = json.load(f)

    def process(self):
        """Process documents and create/load embeddings."""
        if self._should_rebuild():
            print("  Building new embeddings...")

            # Load documents
            self.documents = self._load_documents()
            if not self.documents:
                raise ValueError("No documents found in the specified directory")

            # Create chunks
            self.chunks = []
            for doc in self.documents:
                doc_chunks = self._chunk_text(doc['content'], doc['name'])
                self.chunks.extend(doc_chunks)

            print(f"  Created {len(self.chunks)} chunks from {len(self.documents)} documents")

            # Create embeddings
            texts = [chunk['text'] for chunk in self.chunks]
            self.embeddings = self._create_embeddings(texts)

            # Save
            self._save_embeddings()
            print("  Embeddings saved.")
        else:
            print("  Loading existing embeddings...")
            self._load_embeddings()

    def query(self, query_text: str, top_k: int = 5) -> List[Dict[str, Any]]:
        """Query the embeddings and return the most relevant chunks."""
        if self.embeddings is None:
            raise ValueError("Embeddings not loaded. Call process() first.")

        # Create query embedding
        response = self.client.embeddings.create(
            model=self.EMBEDDING_MODEL,
            input=[query_text]
        )
        query_embedding = np.array(response.data[0].embedding)

        # Compute cosine similarity
        similarities = np.dot(self.embeddings, query_embedding) / (
            np.linalg.norm(self.embeddings, axis=1) * np.linalg.norm(query_embedding)
        )

        # Get top-k indices
        top_indices = np.argsort(similarities)[-top_k:][::-1]

        results = []
        for idx in top_indices:
            results.append({
                'text': self.chunks[idx]['text'],
                'source': self.chunks[idx]['source'],
                'similarity': float(similarities[idx])
            })

        return results

    def get_all_content(self) -> str:
        """Get all document content concatenated."""
        if not self.chunks:
            self._load_embeddings()

        return "\n\n".join([chunk['text'] for chunk in self.chunks])

    def get_content_summary(self, max_chunks: int = 20) -> str:
        """Get a summary of content from various parts of the documents."""
        if not self.chunks:
            self._load_embeddings()

        # Sample chunks evenly across the document set
        step = max(1, len(self.chunks) // max_chunks)
        sampled = [self.chunks[i] for i in range(0, len(self.chunks), step)][:max_chunks]

        return "\n\n---\n\n".join([
            f"[From {chunk['source']}]\n{chunk['text']}"
            for chunk in sampled
        ])
