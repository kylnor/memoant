"""Obsidian note generator. Creates YAML-frontmatter markdown files from pipeline output."""

import os
import re
from datetime import datetime


def _sanitize_filename(name: str) -> str:
    """Make a string safe for filenames."""
    name = re.sub(r'[<>:"/\\|?*]', '', name)
    name = re.sub(r'\s+', ' ', name).strip()
    return name[:100]  # cap length


def _format_duration(seconds: float) -> str:
    """Format seconds as HH:MM:SS or MM:SS."""
    m, s = divmod(int(seconds), 60)
    h, m = divmod(m, 60)
    if h > 0:
        return f"{h}:{m:02d}:{s:02d}"
    return f"{m}:{s:02d}"


def _format_timestamp(seconds: float) -> str:
    """Format seconds as [MM:SS]."""
    m, s = divmod(int(seconds), 60)
    return f"[{m:02d}:{s:02d}]"


def generate_note(record: dict, notes_dir: str) -> str:
    """Generate an Obsidian markdown note from a pipeline result.

    Args:
        record: dict from pipeline.process_file() with all fields
        notes_dir: directory to write the .md file to

    Returns:
        path to the created .md file
    """
    os.makedirs(notes_dir, exist_ok=True)

    # Build title from calendar match or structured summary
    cal_title = record.get("calendar_event_title")
    summary = record.get("summary") or ""
    conv_type = record.get("conversation_type") or "recording"

    if cal_title:
        title = cal_title
    elif summary:
        # Use first sentence of summary as title
        first_sentence = summary.split(".")[0].strip()
        title = first_sentence[:80] if first_sentence else conv_type.title()
    else:
        title = conv_type.title()

    # Build filename: YYYY-MM-DD Title.md
    recorded_at = record.get("recorded_at", "")
    try:
        dt = datetime.fromisoformat(recorded_at)
        date_prefix = dt.strftime("%Y-%m-%d")
        time_str = dt.strftime("%H:%M")
    except (ValueError, TypeError):
        date_prefix = datetime.now().strftime("%Y-%m-%d")
        time_str = ""

    safe_title = _sanitize_filename(title)
    filename = f"{date_prefix} {safe_title}.md"
    filepath = os.path.join(notes_dir, filename)

    # Avoid overwriting
    if os.path.exists(filepath):
        base, ext = os.path.splitext(filename)
        counter = 2
        while os.path.exists(os.path.join(notes_dir, f"{base} ({counter}){ext}")):
            counter += 1
        filename = f"{base} ({counter}){ext}"
        filepath = os.path.join(notes_dir, filename)

    # Build frontmatter
    tags = record.get("tags") or []
    if isinstance(tags, str):
        import json
        try:
            tags = json.loads(tags)
        except (json.JSONDecodeError, TypeError):
            tags = []

    sphere = record.get("sphere") or ""
    duration = record.get("duration_seconds", 0)
    speaker_count = record.get("speaker_count", 1)

    fm_lines = [
        "---",
        f"title: \"{title}\"",
        f"date: {date_prefix}",
    ]
    if time_str:
        fm_lines.append(f"time: \"{time_str}\"")
    fm_lines.extend([
        f"type: {conv_type}",
        f"sphere: {sphere}",
        f"duration: \"{_format_duration(duration)}\"",
        f"speakers: {speaker_count}",
        f"words: {record.get('word_count', 0)}",
    ])
    if record.get("calendar_event_id"):
        fm_lines.append(f"calendar_event: \"{record['calendar_event_id']}\"")
    if tags:
        fm_lines.append("tags:")
        for tag in tags:
            fm_lines.append(f"  - {tag}")
    fm_lines.append(f"source: \"{record.get('source_file', '')}\"")
    fm_lines.append("---")

    # Build body sections
    body_parts = []

    # Summary
    if summary:
        body_parts.append(f"## Summary\n\n{summary}")

    # Action Items
    action_items = record.get("action_items") or []
    if isinstance(action_items, str):
        import json
        try:
            action_items = json.loads(action_items)
        except (json.JSONDecodeError, TypeError):
            action_items = []
    if action_items:
        items = "\n".join(f"- [ ] {item}" for item in action_items)
        body_parts.append(f"## Action Items\n\n{items}")

    # Key Points
    topics = record.get("topics") or []
    if isinstance(topics, str):
        import json
        try:
            topics = json.loads(topics)
        except (json.JSONDecodeError, TypeError):
            topics = []
    if topics:
        points = "\n".join(f"- {t}" for t in topics)
        body_parts.append(f"## Key Points\n\n{points}")

    # Decisions
    decisions = record.get("decisions") or []
    if isinstance(decisions, str):
        import json
        try:
            decisions = json.loads(decisions)
        except (json.JSONDecodeError, TypeError):
            decisions = []
    if decisions:
        items = "\n".join(f"- {d}" for d in decisions)
        body_parts.append(f"## Decisions\n\n{items}")

    # Key Quotes
    key_quotes = record.get("key_quotes") or []
    if isinstance(key_quotes, str):
        import json
        try:
            key_quotes = json.loads(key_quotes)
        except (json.JSONDecodeError, TypeError):
            key_quotes = []
    if key_quotes:
        quotes = "\n".join(f"> {q}" for q in key_quotes)
        body_parts.append(f"## Key Quotes\n\n{quotes}")

    # Transcript
    transcript = record.get("transcript") or record.get("transcript_plain") or ""
    if transcript:
        # Format with speaker turns if available
        segments = record.get("segments") or []
        if isinstance(segments, str):
            import json
            try:
                segments = json.loads(segments)
            except (json.JSONDecodeError, TypeError):
                segments = []

        if segments and isinstance(segments, list) and len(segments) > 1:
            # Use segments for formatted transcript
            formatted_lines = []
            for seg in segments:
                ts = _format_timestamp(seg.get("start", 0))
                speaker = seg.get("speaker", "")
                text = seg.get("text", "")
                if speaker:
                    formatted_lines.append(f"**{ts} {speaker}:** {text}")
                else:
                    formatted_lines.append(f"**{ts}** {text}")
            body_parts.append(f"## Transcript\n\n" + "\n\n".join(formatted_lines))
        else:
            body_parts.append(f"## Transcript\n\n{transcript}")

    # Assemble
    content = "\n".join(fm_lines) + "\n\n" + "\n\n".join(body_parts) + "\n"

    with open(filepath, "w") as f:
        f.write(content)

    return filepath
