#!/usr/bin/env python3
"""Publish GitHub release atomically only after verifying uploaded assets."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent

# Import release_metadata dynamically
spec = importlib.util.spec_from_file_location('release_metadata', ROOT / 'scripts/release_metadata.py')
release_metadata = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release_metadata)


def api(run, endpoint: str, *, method: str = 'GET', payload: dict | None = None, paginate: bool = False):
    args = ['gh', 'api', endpoint, '--method', method]
    options = {'capture_output': True, 'text': True}
    if paginate:
        args.extend(['--paginate', '--slurp'])
    if payload is not None:
        args.extend(['--input', '-'])
        options['input'] = json.dumps(payload)
    
    response = run(args, **options)
    if response.returncode != 0:
        detail = response.stderr.strip() or response.stdout.strip() or f'exit status {response.returncode}'
        raise RuntimeError(f"GitHub API {method} {endpoint} failed: {detail}")
    return json.loads(response.stdout)


def publish(root: Path, tag: str, repo: str, run=subprocess.run):
    meta = release_metadata.metadata(root, tag)
    dist_dir = root / 'dist/releases'
    dmg_path = dist_dir / meta['dmg']
    checksum_path = dist_dir / 'SHA256SUMS.txt'
    
    if not dmg_path.exists():
        raise FileNotFoundError(f"Missing release DMG: {dmg_path}")
    if not checksum_path.exists():
        raise FileNotFoundError(f"Missing checksum file: {checksum_path}")
    
    assets = [dmg_path, checksum_path]
    
    # Verify local checksum
    with dmg_path.open('rb') as f:
        digest = hashlib.sha256(f.read()).hexdigest()
    
    expected_line = f"{digest}  {dmg_path.name}"
    if expected_line not in checksum_path.read_text():
        raise ValueError(f"DMG checksum does not match {checksum_path}")
    
    print(f"✔ Local SHA-256 verified: {digest}")
    
    # Check existing releases
    releases_endpoint = f"repos/{repo}/releases"
    pages = api(run, releases_endpoint + '?per_page=100', paginate=True)
    matches = [r for page in pages for r in (page if isinstance(page, list) else [page]) if r.get('tag_name') == tag]
    
    existing = matches[0] if matches else None
    if existing and not existing.get('draft', False):
        raise ValueError(f"Release {tag} is already published on GitHub. Will not overwrite.")
    
    previous_tag = release_metadata.previous_release_tag(pages, tag)
    combined = release_metadata.combined_metadata(root, tag, previous_tag)
    
    release_title = f"IDMac {meta['version']}"
    
    if existing is None:
        print(f"==> Creating Draft Release for {tag}...")
        existing = api(run, releases_endpoint, method='POST', payload={
            'tag_name': tag,
            'name': release_title,
            'body': combined['notes'],
            'draft': True,
            'prerelease': False
        })
    
    release_id = existing['id']
    endpoint = f"{releases_endpoint}/{release_id}"
    
    print(f"==> Uploading assets to draft release {release_id}...")
    run(['gh', 'release', 'upload', tag, *map(str, assets), '--repo', repo, '--clobber'], check=True)
    
    # Verify remote upload status
    uploaded = api(run, endpoint)
    remote_assets = {a['name']: a for a in uploaded.get('assets', [])}
    
    for asset in assets:
        if asset.name not in remote_assets:
            raise RuntimeError(f"Asset failed to upload: {asset.name}")
        item = remote_assets[asset.name]
        if item.get('state') != 'uploaded':
            raise RuntimeError(f"Asset not in uploaded state: {asset.name}")
        if item.get('size') != asset.stat().st_size:
            raise RuntimeError(f"Asset size mismatch for {asset.name}")
    
    print("✔ All assets verified on GitHub servers.")
    print("==> Publishing release live...")
    
    published = api(run, endpoint, method='PATCH', payload={
        'draft': False,
        'name': release_title,
        'body': combined['notes']
    })
    
    html_url = published.get('html_url')
    print(f"🚀 Release successfully published: {html_url}")


def main():
    parser = argparse.ArgumentParser(description="Publish verified release to GitHub.")
    parser.add_argument("tag", help="Release tag (e.g. v1.0.3)")
    parser.add_argument("--repo", required=True, help="GitHub repository (owner/repo)")
    args = parser.parse_args()
    
    publish(ROOT, args.tag, args.repo)


if __name__ == '__main__':
    main()

