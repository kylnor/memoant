"""LLM structuring via Ollama. Extract summary, topics, actions, etc."""

import json
import time
import urllib.request

from .config import OLLAMA_MODEL, OLLAMA_URL

EXTRACT_PROMPT = """You are analyzing a transcript from a personal audio recording. Extract structured information.

TRANSCRIPT:
{transcript}

Respond with ONLY valid JSON (no markdown, no explanation):
{{
  "summary": "2-3 sentence summary of what happened",
  "topics": ["topic1", "topic2"],
  "action_items": ["action1", "action2"],
  "decisions": ["decision1"],
  "entities": ["person/place/org mentioned"],
  "key_quotes": ["notable direct quotes"],
  "sphere": "one of: Work|Ventures|Family|Finance|Health|Learning",
  "tags": ["tag1", "tag2"],
  "sentiment": "one of: positive|negative|neutral|mixed",
  "conversation_type": "one of: meeting|phone_call|dictation|brainstorm|ambient"
}}

Rules:
- sphere must be exactly one of: Work, Ventures, Family, Finance, Health, Learning
- conversation_type: meeting (2+ people scheduled), phone_call (2 people remote), dictation (1 person notes), brainstorm (1 person thinking aloud), ambient (background/unclear)
- If unsure about a field, use null or empty array
- Keep summary concise, action_items specific, tags lowercase
"""


def extract_structure(transcript: str, model: str = OLLAMA_MODEL, retries: int = 2) -> dict:
    """Call Ollama to extract structured data from transcript.

    Returns dict with: summary, topics, action_items, decisions, entities,
    key_quotes, sphere, tags, sentiment, conversation_type.
    Returns partial dict with error field on failure.
    """
    if len(transcript) > 12000:
        transcript = transcript[:12000] + "\n\n[TRANSCRIPT TRUNCATED]"

    prompt = EXTRACT_PROMPT.format(transcript=transcript)

    for attempt in range(retries + 1):
        try:
            payload = json.dumps({
                "model": model,
                "prompt": prompt,
                "stream": False,
                "options": {"temperature": 0},
            }).encode()

            req = urllib.request.Request(
                f"{OLLAMA_URL}/api/generate",
                data=payload,
                headers={"Content-Type": "application/json"},
            )
            resp = json.loads(
                urllib.request.urlopen(req, timeout=120).read()
            )
            text = resp.get("response", "").strip()
            tokens = resp.get("eval_count", 0)
            duration = resp.get("total_duration", 0) / 1e9

            # Parse JSON from response (handle markdown code blocks)
            if "```" in text:
                text = text.split("```")[1]
                if text.startswith("json"):
                    text = text[4:]

            parsed = json.loads(text)

            valid_spheres = {"Work", "Ventures", "Family", "Finance", "Health", "Learning"}
            if parsed.get("sphere") not in valid_spheres:
                parsed["sphere"] = None

            valid_types = {"meeting", "phone_call", "dictation", "brainstorm", "ambient"}
            if parsed.get("conversation_type") not in valid_types:
                parsed["conversation_type"] = None

            parsed["_tokens"] = tokens
            parsed["_duration"] = duration
            return parsed

        except (json.JSONDecodeError, KeyError, urllib.error.URLError) as e:
            if attempt < retries:
                time.sleep(2)
            else:
                return {
                    "summary": None,
                    "topics": [],
                    "action_items": [],
                    "decisions": [],
                    "entities": [],
                    "key_quotes": [],
                    "sphere": None,
                    "tags": [],
                    "sentiment": None,
                    "conversation_type": None,
                    "error": f"LLM extraction failed: {e}",
                }
