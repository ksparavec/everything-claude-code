#!/usr/bin/env python3
"""Adapt ECC's Claude Code skills for Kimi Code CLI.

Reads skills/ from the repo root, applies a deterministic set of rewrite
rules (paths, tool names, CLI examples), and writes the result to a staging
directory (default: build/kimi/skills/). The Makefile's install-kimi target
then rsyncs the staging directory into $KIMI_CODE_HOME/skills/
(default ~/.kimi-code/skills/).

The script is idempotent: the staging directory is wiped and rebuilt from
the pristine sources on every run, so `make install-kimi` can be repeated
at any time and always produces the same output.
"""

import argparse
import shutil
import sys
from pathlib import Path

# Skills whose Claude references are intentional (they describe Claude Code
# as an external tool being orchestrated, not as the host harness). These
# are copied verbatim.
EXCLUDED_SKILLS = {
    "claude-devfleet",
    "dmux-workflows",
}

# File extensions treated as text; rewrite rules are applied to these.
# Anything else is copied byte-for-byte.
TEXT_EXTENSIONS = {
    ".md", ".txt", ".sh", ".bash", ".py", ".js", ".mjs", ".cjs", ".ts",
    ".json", ".yaml", ".yml", ".toml", ".css", ".html", ".sql",
}

# Ordered rewrite rules (literal, first match order matters: more specific
# rules must precede the general ones they overlap with).
REWRITE_RULES = [
    # Skill-dir placeholder used by Kimi Code's skill loader.
    ("${CLAUDE_SKILL_DIR}", "${KIMI_SKILL_DIR}"),
    # User-level settings: Claude keeps them in settings.json, Kimi in config.toml.
    ("~/.claude/settings.json", "~/.kimi-code/config.toml"),
    (".claude/settings.json", ".kimi-code/config.toml"),
    # User-level home directory.
    ("~/.claude", "~/.kimi-code"),
    # Project-level config directory.
    (".claude/", ".kimi-code/"),
    # Project instruction file discovered by the harness.
    ("CLAUDE.md", "AGENTS.md"),
    # Non-interactive CLI invocation.
    ("claude -p", "kimi -p"),
    # Subagent dispatch tool name.
    ("Task tool", "Agent tool"),
    # Skill-local env-var convention (not a Claude runtime variable).
    ("CLAUDE_PACKAGE_MANAGER", "KIMI_PACKAGE_MANAGER"),
    # Product name in prose.
    ("Claude-specific", "Kimi-specific"),
    ("Claude Code", "Kimi Code"),
]

HOST_NOTE = (
    "> Host note: this copy was adapted for **Kimi Code CLI** by "
    "`make install-kimi` (`scripts/adapt-skills-kimi.py`). Paths, tool "
    "names, and CLI examples were rewritten from the Claude Code original. "
    "Invoke it as `/skill:{name}`.\n\n"
)


def rewrite_text(text: str, counters: dict) -> str:
    for old, new in REWRITE_RULES:
        hits = text.count(old)
        if hits:
            counters[old] = counters.get(old, 0) + hits
            text = text.replace(old, new)
    return text


def adapt_file(src: Path, dst: Path, counters: dict) -> bool:
    """Adapt one file. Returns True if the content was modified."""
    try:
        text = src.read_text(encoding="utf-8")
    except (UnicodeDecodeError, ValueError):
        shutil.copy2(src, dst)
        return False
    rewritten = rewrite_text(text, counters)
    if rewritten != text:
        dst.write_text(rewritten, encoding="utf-8")
        return True
    dst.write_text(text, encoding="utf-8")
    return False


def insert_host_note(skill_md: Path, skill_name: str) -> None:
    text = skill_md.read_text(encoding="utf-8")
    note = HOST_NOTE.format(name=skill_name)
    if text.startswith("---\n"):
        end = text.find("\n---\n", 4)
        if end != -1:
            insert_at = end + len("\n---\n")
            text = text[:insert_at] + "\n" + note + text[insert_at:]
            skill_md.write_text(text, encoding="utf-8")
            return
    # No frontmatter: prepend the note.
    skill_md.write_text(note + text, encoding="utf-8")


def adapt_skills(src_dir: Path, dest_dir: Path) -> int:
    if not src_dir.is_dir():
        print(f"error: source skills directory not found: {src_dir}", file=sys.stderr)
        return 1

    if dest_dir.exists():
        shutil.rmtree(dest_dir)
    dest_dir.mkdir(parents=True)

    counters: dict = {}
    skills = sorted(p for p in src_dir.iterdir() if p.is_dir())
    adapted_skills = 0
    modified_files = 0

    for skill in skills:
        excluded = skill.name in EXCLUDED_SKILLS
        for src_file in sorted(skill.rglob("*")):
            if not src_file.is_file():
                continue
            rel = src_file.relative_to(skill)
            dst_file = dest_dir / skill.name / rel
            dst_file.parent.mkdir(parents=True, exist_ok=True)
            if excluded or src_file.suffix.lower() not in TEXT_EXTENSIONS:
                shutil.copy2(src_file, dst_file)
            elif adapt_file(src_file, dst_file, counters):
                modified_files += 1
        if not excluded:
            staged_skill_md = dest_dir / skill.name / "SKILL.md"
            if staged_skill_md.is_file():
                insert_host_note(staged_skill_md, skill.name)
            adapted_skills += 1

    total_rewrites = sum(counters.values())
    print(f"skills: {len(skills)} total, {adapted_skills} adapted, "
          f"{len(EXCLUDED_SKILLS)} copied verbatim")
    print(f"files rewritten: {modified_files} ({total_rewrites} replacements)")
    for old, count in sorted(counters.items(), key=lambda kv: -kv[1]):
        new = dict(REWRITE_RULES)[old]
        print(f"  {count:4d}x  {old!r} -> {new!r}")
    print(f"staged in: {dest_dir}")
    return 0


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--src", type=Path, default=repo_root / "skills",
                        help="source skills directory (default: repo skills/)")
    parser.add_argument("--dest", type=Path, default=repo_root / "build" / "kimi" / "skills",
                        help="staging directory for adapted skills "
                             "(default: build/kimi/skills/)")
    args = parser.parse_args()
    return adapt_skills(args.src, args.dest)


if __name__ == "__main__":
    sys.exit(main())
