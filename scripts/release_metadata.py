#!/usr/bin/env python3
"""Validate release metadata and compile release notes from versions.md."""
import argparse
import json
from pathlib import Path
import plistlib
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent


def metadata(root: Path, tag: str) -> dict:
    info_path = root / 'Resources/Info.plist'
    if not info_path.exists():
        raise FileNotFoundError(f"Missing {info_path}")
    
    info = plistlib.loads(info_path.read_bytes())
    version = info['CFBundleShortVersionString']
    build = str(info['CFBundleVersion'])
    
    # Verify tag matches vX.Y.Z
    if not re.fullmatch(r'v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)', tag) or tag != 'v' + version:
        raise ValueError(f"Tag {tag!r} does not match app version v{version}")
    
    versions_file = root / 'versions.md'
    if not versions_file.exists():
        raise FileNotFoundError(f"Missing {versions_file}")
    
    notes = versions_file.read_text()
    entries = list(re.finditer(r'^## (\S+) \(build (\d+)\)[^\n]*$', notes, re.M))
    if not entries:
        raise ValueError("No version entries found in versions.md")
    
    top_version, top_build = entries[0].groups()
    if (top_version, top_build) != (version, build):
        raise ValueError(
            f"Latest versions.md entry ({top_version} build {top_build}) "
            f"does not match Info.plist ({version} build {build})"
        )
    
    section_end = entries[1].start() if len(entries) > 1 else len(notes)
    section = notes[entries[0].start():section_end].strip() + '\n'
    
    for category in ['Added', 'Modified', 'Removed']:
        if f'### {category}\n' not in section:
            raise ValueError(f"Release section for {version} is missing '### {category}'")
    
    dmg_name = f"IDMac-{version}-macOS-arm64.dmg"
    return {
        'tag': tag,
        'version': version,
        'build': build,
        'dmg': dmg_name,
        'notes': section
    }


def version_tuple(tag: str):
    if not isinstance(tag, str) or not re.fullmatch(r'v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)', tag):
        return None
    return tuple(map(int, tag[1:].split('.')))


def published_releases(repo: str, run=subprocess.run):
    res = run(
        ['gh', 'api', f'repos/{repo}/releases?per_page=100', '--method', 'GET', '--paginate', '--slurp'],
        capture_output=True, text=True
    )
    if res.returncode != 0:
        return []
    try:
        return json.loads(res.stdout)
    except Exception:
        return []


def previous_release_tag(pages, current_tag: str):
    current = version_tuple(current_tag)
    if current is None:
        return None
    candidates = []
    for page in pages:
        for release in (page if isinstance(page, list) else [page]):
            tag = release.get('tag_name')
            ver = version_tuple(tag)
            if ver and ver < current and not release.get('draft', False) and not release.get('prerelease', False):
                candidates.append((ver, tag))
    return max(candidates)[1] if candidates else None


def combined_metadata(root: Path, tag: str, previous_tag: str | None = None) -> dict:
    meta = metadata(root, tag)
    if not previous_tag:
        return meta
    
    notes = (root / 'versions.md').read_text()
    entries = list(re.finditer(r'^## (\S+) \(build (\d+)\)[^\n]*$', notes, re.M))
    
    categories = {'Added': [], 'Modified': [], 'Removed': []}
    seen = {k: set() for k in categories}
    
    for idx, entry in enumerate(entries):
        v_str = entry.group(1)
        if previous_tag and ('v' + v_str) == previous_tag:
            break
        
        section_end = entries[idx + 1].start() if idx + 1 < len(entries) else len(notes)
        section_text = notes[entry.end():section_end]
        
        for cat in categories:
            match = re.search(rf'### {cat}\s*\n(.*?)(?=\n###|\Z)', section_text, re.DOTALL)
            if match:
                for line in match.group(1).strip().splitlines():
                    cleaned = line.strip()
                    if cleaned.startswith('-') and cleaned not in seen[cat]:
                        # Skip placeholder 'None.'
                        if cleaned.lower() not in ('- none.', '- none'):
                            seen[cat].add(cleaned)
                            categories[cat].append(cleaned)
    
    body_parts = [f"## IDMac {meta['version']}"]
    for cat in ['Added', 'Modified', 'Removed']:
        body_parts.append(f"\n### {cat}")
        items = categories[cat]
        if items:
            body_parts.extend(items)
        else:
            body_parts.append("- None.")
    
    meta['notes'] = '\n'.join(body_parts).strip() + '\n'
    return meta


def main():
    parser = argparse.ArgumentParser(description="Validate release metadata and prepare notes.")
    parser.add_argument("tag", help="Release tag (e.g. v1.0.3)")
    parser.add_argument("--repo", default=None, help="GitHub repository (owner/repo)")
    args = parser.parse_args()
    
    previous_tag = None
    if args.repo:
        pages = published_releases(args.repo)
        previous_tag = previous_release_tag(pages, args.tag)
    
    meta = combined_metadata(ROOT, args.tag, previous_tag)
    
    out_dir = ROOT / '.build/release'
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / 'release-notes.md').write_text(meta['notes'])
    
    print(f"✔ Validated metadata for {meta['version']} (build {meta['build']})")
    print(f"✔ Generated release notes in {out_dir / 'release-notes.md'}")


if __name__ == '__main__':
    main()

