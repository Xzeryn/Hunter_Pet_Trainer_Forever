#!/usr/bin/env python3
"""Write the tagged version's CHANGELOG.md section to .RECENT_CHANGES.md."""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHANGELOG = ROOT / "CHANGELOG.md"
OUTPUT = ROOT / ".RECENT_CHANGES.md"
HEADING = re.compile(r"^## \[([^\]]+)\]")
FOOTER_LINK = re.compile(r"^\[[^\]]+\]:\s+\S+")


def version_from_tag(tag: str) -> str:
	tag = (tag or "").strip()
	if tag.startswith("v") or tag.startswith("V"):
		return tag[1:]
	return tag


def parse_sections(text: str) -> list[tuple[str, str]]:
	sections: list[tuple[str, str]] = []
	current_name = ""
	current_lines: list[str] = []
	for line in text.splitlines():
		match = HEADING.match(line)
		if match:
			if current_name:
				sections.append((current_name, "\n".join(current_lines).strip()))
			current_name = match.group(1)
			current_lines = [line]
		elif current_name and not FOOTER_LINK.match(line):
			current_lines.append(line)
	if current_name:
		sections.append((current_name, "\n".join(current_lines).strip()))
	return sections


def section_has_notes(body: str) -> bool:
	for line in body.splitlines()[1:]:
		stripped = line.strip()
		if stripped and not stripped.startswith("#"):
			return True
	return False


def pick_section(sections: list[tuple[str, str]], version: str) -> str:
	if version:
		for name, body in sections:
			if name.split(" ")[0].lstrip("vV") == version:
				if not section_has_notes(body):
					raise SystemExit(f"CHANGELOG.md has [ {name} ] but no notes.")
				return body
		raise SystemExit(f"CHANGELOG.md has no ## [{version}] section for this tag.")

	for name, body in sections:
		if name.split(" ")[0].lower() == "unreleased":
			continue
		if section_has_notes(body):
			return body
	raise SystemExit("CHANGELOG.md has no version section with notes.")


def main() -> int:
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument(
		"version",
		nargs="?",
		default=version_from_tag(os.environ.get("GITHUB_REF_NAME", "")),
		help="Version without the leading v (defaults to GITHUB_REF_NAME)",
	)
	args = parser.parse_args()
	if not CHANGELOG.is_file():
		raise SystemExit(f"Missing {CHANGELOG}")

	body = pick_section(parse_sections(CHANGELOG.read_text(encoding="utf-8")), args.version)
	OUTPUT.write_text(body + "\n", encoding="utf-8")
	print(f"Wrote {OUTPUT.name} from CHANGELOG.md [{args.version or 'latest'}]")
	return 0


if __name__ == "__main__":
	sys.exit(main())
