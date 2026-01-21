#!/usr/bin/env python3
"""
ISBN Validator and Fixer for BiblioGenius Curated Lists

Uses Open Library API to validate ISBNs and find correct ones.
Run with: python validate_isbns.py --fix

Dependencies: pip install requests pyyaml
"""

import argparse
import glob
import os
import re
import time
from pathlib import Path

try:
    import requests
    import yaml
except ImportError:
    print("Please install dependencies: pip install requests pyyaml")
    exit(1)

OPEN_LIBRARY_SEARCH = "https://openlibrary.org/search.json"
OPEN_LIBRARY_ISBN = "https://openlibrary.org/isbn/{}.json"

# Cache to avoid repeated API calls
isbn_cache = {}


def validate_isbn(isbn: str) -> bool:
    """Validate ISBN-10 or ISBN-13 checksum."""
    isbn = isbn.replace("-", "").replace(" ", "")
    
    if len(isbn) == 10:
        # ISBN-10 validation
        if not isbn[:-1].isdigit() or (isbn[-1] not in "0123456789Xx"):
            return False
        total = sum((10 - i) * (int(c) if c.isdigit() else 10) for i, c in enumerate(isbn))
        return total % 11 == 0
    elif len(isbn) == 13:
        # ISBN-13 validation
        if not isbn.isdigit():
            return False
        total = sum(int(c) * (1 if i % 2 == 0 else 3) for i, c in enumerate(isbn))
        return total % 10 == 0
    return False


def search_book_isbn(title: str, author: str = None):
    """Search Open Library for a book and return its ISBN-13."""
    query = title
    if author:
        query = f"{title} {author}"
    
    # Check cache
    cache_key = query.lower().strip()
    if cache_key in isbn_cache:
        return isbn_cache[cache_key]
    
    try:
        params = {"q": query, "limit": 5, "fields": "isbn,title,author_name"}
        response = requests.get(OPEN_LIBRARY_SEARCH, params=params, timeout=10)
        response.raise_for_status()
        data = response.json()
        
        if data.get("docs"):
            for doc in data["docs"]:
                isbns = doc.get("isbn", [])
                # Prefer ISBN-13
                for isbn in isbns:
                    if len(isbn) == 13 and isbn.startswith("978"):
                        isbn_cache[cache_key] = isbn
                        return isbn
                # Fallback to any ISBN
                if isbns:
                    isbn_cache[cache_key] = isbns[0]
                    return isbns[0]
        
        isbn_cache[cache_key] = None
        return None
    except Exception as e:
        print(f"  Error searching for '{query}': {e}")
        return None


def check_isbn_exists(isbn: str) -> bool:
    """Check if ISBN exists in Open Library."""
    try:
        response = requests.head(OPEN_LIBRARY_ISBN.format(isbn), timeout=5)
        return response.status_code == 200
    except:
        return False


def parse_note(note: str) -> tuple[str, str]:
    """Extract title and author from note field."""
    # Format: "Title - Author (Year)" or "Title - Author"
    match = re.match(r"(.+?)\s*-\s*(.+?)(?:\s*\(.*\))?$", note)
    if match:
        return match.group(1).strip(), match.group(2).strip()
    return note, None


def process_yaml_file(filepath: Path, fix: bool = False) -> dict:
    """Process a single YAML file and validate ISBNs."""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
        data = yaml.safe_load(content)
    
    if not data or 'books' not in data:
        return {"file": str(filepath), "books": 0, "valid": 0, "invalid": 0, "fixed": 0}
    
    stats = {"file": str(filepath.name), "books": len(data['books']), "valid": 0, "invalid": 0, "fixed": 0, "not_found": 0}
    
    for i, book in enumerate(data['books']):
        isbn = book.get('isbn', '')
        note = book.get('note', '')
        
        if not isbn:
            stats['invalid'] += 1
            continue
        
        # Check if ISBN is a valid format
        is_valid_format = validate_isbn(isbn)
        
        if is_valid_format:
            stats['valid'] += 1
        else:
            stats['invalid'] += 1
            print(f"  ⚠ Invalid ISBN format: {isbn} ({note})")
            
            if fix:
                title, author = parse_note(note)
                new_isbn = search_book_isbn(title, author)
                time.sleep(0.5)  # Rate limiting
                
                if new_isbn and validate_isbn(new_isbn):
                    print(f"    ✓ Found: {new_isbn}")
                    data['books'][i]['isbn'] = new_isbn
                    stats['fixed'] += 1
                else:
                    print(f"    ✗ Could not find valid ISBN")
                    stats['not_found'] += 1
    
    # Write back if fixes were made
    if fix and stats['fixed'] > 0:
        with open(filepath, 'w', encoding='utf-8') as f:
            yaml.dump(data, f, allow_unicode=True, default_flow_style=False, sort_keys=False)
        print(f"  → Saved {stats['fixed']} fixes to {filepath.name}")
    
    return stats


def main():
    parser = argparse.ArgumentParser(description="Validate ISBNs in curated list YAML files")
    parser.add_argument("--fix", action="store_true", help="Attempt to fix invalid ISBNs using Open Library")
    parser.add_argument("--path", type=Path, default=Path("../assets/curated_lists"), help="Path to curated lists directory")
    args = parser.parse_args()
    
    curated_path = args.path
    if not curated_path.exists():
        # Try relative to script location
        curated_path = Path(__file__).parent.parent / "assets" / "curated_lists"
    
    if not curated_path.exists():
        print(f"Error: Could not find curated lists directory at {curated_path}")
        return
    
    yaml_files = list(curated_path.rglob("*.yml"))
    yaml_files = [f for f in yaml_files if f.name != "index.yml"]
    
    print(f"Found {len(yaml_files)} YAML files to validate\n")
    
    total_stats = {"books": 0, "valid": 0, "invalid": 0, "fixed": 0, "not_found": 0}
    
    for filepath in sorted(yaml_files):
        print(f"Checking {filepath.name}...")
        stats = process_yaml_file(filepath, fix=args.fix)
        
        for key in total_stats:
            total_stats[key] += stats.get(key, 0)
    
    print("\n" + "=" * 50)
    print("SUMMARY")
    print("=" * 50)
    print(f"Total books: {total_stats['books']}")
    print(f"Valid ISBNs: {total_stats['valid']}")
    print(f"Invalid ISBNs: {total_stats['invalid']}")
    if args.fix:
        print(f"Fixed: {total_stats['fixed']}")
        print(f"Could not find: {total_stats['not_found']}")
    
    validity_rate = (total_stats['valid'] / total_stats['books'] * 100) if total_stats['books'] > 0 else 0
    print(f"\nValidity rate: {validity_rate:.1f}%")


if __name__ == "__main__":
    main()
