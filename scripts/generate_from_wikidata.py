#!/usr/bin/env python3
"""
BiblioGenius Curated Lists Generator

Generates curated book lists from Wikidata queries.
Output format: YAML files compatible with BiblioGenius app.

Usage:
    python generate_from_wikidata.py --prize nobel --output ../bibliogenius-app/assets/curated_lists/awards/
    python generate_from_wikidata.py --prize goncourt --years 2000-2024
    python generate_from_wikidata.py --author "Gabriel García Márquez"
"""

import argparse
import json
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Optional
from urllib.parse import quote

try:
    import requests
except ImportError:
    print("Please install requests: pip install requests")
    sys.exit(1)

WIKIDATA_ENDPOINT = "https://query.wikidata.org/sparql"

# Prize IDs in Wikidata
PRIZES = {
    "nobel": {
        "id": "Q37922",  # Nobel Prize in Literature
        "title": {
            "fr": "Prix Nobel de Littérature",
            "en": "Nobel Prize in Literature",
            "de": "Nobelpreis für Literatur",
            "es": "Premio Nobel de Literatura"
        },
        "description": {
            "fr": "Les lauréats du prix Nobel de littérature et leurs œuvres majeures.",
            "en": "Nobel Prize in Literature laureates and their major works.",
            "de": "Nobelpreisträger für Literatur und ihre wichtigsten Werke.",
            "es": "Laureados del Premio Nobel de Literatura y sus obras principales."
        }
    },
    "goncourt": {
        "id": "Q192297",  # Prix Goncourt
        "title": {
            "fr": "Prix Goncourt",
            "en": "Prix Goncourt",
            "de": "Prix Goncourt",
            "es": "Premio Goncourt"
        },
        "description": {
            "fr": "Les romans lauréats du plus prestigieux prix littéraire français.",
            "en": "Award-winning novels of France's most prestigious literary prize.",
            "de": "Prämierte Romane des prestigeträchtigsten französischen Literaturpreises.",
            "es": "Novelas galardonadas con el premio literario más prestigioso de Francia."
        }
    },
    "pulitzer_fiction": {
        "id": "Q192841",  # Pulitzer Prize for Fiction
        "title": {
            "fr": "Prix Pulitzer de la Fiction",
            "en": "Pulitzer Prize for Fiction",
            "de": "Pulitzer-Preis für Belletristik",
            "es": "Premio Pulitzer de Ficción"
        },
        "description": {
            "fr": "Les romans lauréats du prestigieux prix Pulitzer américain.",
            "en": "Award-winning novels of the prestigious American Pulitzer Prize.",
            "de": "Prämierte Romane des renommierten amerikanischen Pulitzer-Preises.",
            "es": "Novelas galardonadas con el prestigioso premio Pulitzer estadounidense."
        }
    },
    "booker": {
        "id": "Q160082",  # Booker Prize
        "title": {
            "fr": "Booker Prize",
            "en": "Booker Prize",
            "de": "Booker Prize",
            "es": "Premio Booker"
        },
        "description": {
            "fr": "Les romans lauréats du prestigieux prix littéraire britannique.",
            "en": "Award-winning novels of the prestigious British literary prize.",
            "de": "Prämierte Romane des renommierten britischen Literaturpreises.",
            "es": "Novelas galardonadas con el prestigioso premio literario británico."
        }
    },
    "renaudot": {
        "id": "Q282350",  # Prix Renaudot
        "title": {
            "fr": "Prix Renaudot",
            "en": "Prix Renaudot",
            "de": "Prix Renaudot",
            "es": "Premio Renaudot"
        },
        "description": {
            "fr": "Les romans lauréats du prix Renaudot, décerné le même jour que le Goncourt.",
            "en": "Award-winning novels of the Prix Renaudot, awarded on the same day as the Goncourt.",
            "de": "Prämierte Romane des Prix Renaudot, der am selben Tag wie der Goncourt verliehen wird.",
            "es": "Novelas galardonadas con el Premio Renaudot, otorgado el mismo día que el Goncourt."
        }
    },
    "femina": {
        "id": "Q210392",  # Prix Femina
        "title": {
            "fr": "Prix Femina",
            "en": "Prix Femina",
            "de": "Prix Femina",
            "es": "Premio Femina"
        },
        "description": {
            "fr": "Les romans lauréats du prix Femina, décerné par un jury exclusivement féminin.",
            "en": "Award-winning novels of the Prix Femina, awarded by an all-female jury.",
            "de": "Prämierte Romane des Prix Femina, der von einer rein weiblichen Jury verliehen wird.",
            "es": "Novelas galardonadas con el Premio Femina, otorgado por un jurado exclusivamente femenino."
        }
    }
}


def query_wikidata(sparql: str) -> list:
    """Execute a SPARQL query against Wikidata."""
    headers = {
        "Accept": "application/json",
        "User-Agent": "BiblioGenius List Generator/1.0"
    }
    
    try:
        response = requests.get(
            WIKIDATA_ENDPOINT,
            params={"query": sparql, "format": "json"},
            headers=headers,
            timeout=60
        )
        response.raise_for_status()
        data = response.json()
        return data.get("results", {}).get("bindings", [])
    except requests.RequestException as e:
        print(f"Error querying Wikidata: {e}")
        return []


def get_prize_winners(prize_id: str, start_year: int = 1900, end_year: int = 2025) -> list:
    """Get books that won a specific prize."""
    
    # Query for works that received the prize
    sparql = f"""
    SELECT DISTINCT ?work ?workLabel ?authorLabel ?year ?isbn13 ?isbn10 WHERE {{
      ?work wdt:P166 wd:{prize_id} .  # received award
      ?work wdt:P50 ?author .          # has author
      
      OPTIONAL {{ ?work wdt:P577 ?pubDate . BIND(YEAR(?pubDate) AS ?year) }}
      OPTIONAL {{ ?work wdt:P212 ?isbn13 . }}  # ISBN-13
      OPTIONAL {{ ?work wdt:P957 ?isbn10 . }}  # ISBN-10
      
      SERVICE wikibase:label {{ bd:serviceParam wikibase:language "fr,en,de,es" . }}
    }}
    ORDER BY DESC(?year)
    LIMIT 100
    """
    
    results = query_wikidata(sparql)
    
    books = []
    seen_works = set()
    
    for item in results:
        work_id = item.get("work", {}).get("value", "")
        if work_id in seen_works:
            continue
        seen_works.add(work_id)
        
        title = item.get("workLabel", {}).get("value", "Unknown")
        author = item.get("authorLabel", {}).get("value", "Unknown")
        year = item.get("year", {}).get("value", "")
        isbn13 = item.get("isbn13", {}).get("value", "")
        isbn10 = item.get("isbn10", {}).get("value", "")
        
        isbn = isbn13 or isbn10
        if isbn:
            # Clean ISBN (remove hyphens)
            isbn = re.sub(r'[^0-9X]', '', isbn.upper())
        
        books.append({
            "title": title,
            "author": author,
            "year": year,
            "isbn": isbn,
            "wikidata_id": work_id.split("/")[-1] if work_id else None
        })
    
    return books


def get_author_works(author_name: str) -> list:
    """Get notable works by an author."""
    
    sparql = f"""
    SELECT DISTINCT ?work ?workLabel ?year ?isbn13 ?isbn10 WHERE {{
      ?author rdfs:label "{author_name}"@en .
      ?work wdt:P50 ?author .
      ?work wdt:P31 wd:Q7725634 .  # instance of literary work
      
      OPTIONAL {{ ?work wdt:P577 ?pubDate . BIND(YEAR(?pubDate) AS ?year) }}
      OPTIONAL {{ ?work wdt:P212 ?isbn13 . }}
      OPTIONAL {{ ?work wdt:P957 ?isbn10 . }}
      
      SERVICE wikibase:label {{ bd:serviceParam wikibase:language "fr,en,de,es" . }}
    }}
    ORDER BY ?year
    LIMIT 50
    """
    
    results = query_wikidata(sparql)
    
    books = []
    for item in results:
        title = item.get("workLabel", {}).get("value", "Unknown")
        year = item.get("year", {}).get("value", "")
        isbn13 = item.get("isbn13", {}).get("value", "")
        isbn10 = item.get("isbn10", {}).get("value", "")
        
        isbn = isbn13 or isbn10
        if isbn:
            isbn = re.sub(r'[^0-9X]', '', isbn.upper())
        
        books.append({
            "title": title,
            "author": author_name,
            "year": year,
            "isbn": isbn
        })
    
    return books


def generate_yaml(
    list_id: str,
    title: dict,
    description: dict,
    books: list,
    contributor: str = "BiblioGenius (Wikidata)",
    tags: list = None
) -> str:
    """Generate YAML content for a curated list."""
    
    lines = [
        f"# Auto-generated from Wikidata",
        f"# Generated: {datetime.now().isoformat()}",
        "",
        f"id: {list_id}",
        "version: 1",
        "",
        "title:"
    ]
    
    for lang, text in title.items():
        lines.append(f'  {lang}: "{escape_yaml(text)}"')
    
    lines.append("")
    lines.append("description:")
    for lang, text in description.items():
        lines.append(f'  {lang}: "{escape_yaml(text)}"')
    
    lines.append("")
    lines.append(f'contributor: "{contributor}"')
    
    if tags:
        lines.append(f"tags: [{', '.join(tags)}]")
    
    lines.append("")
    lines.append("books:")
    
    for book in books:
        if book.get("isbn"):
            note = f"{book['title']} - {book['author']}"
            if book.get("year"):
                note += f" ({book['year']})"
            lines.append(f'  - isbn: "{book["isbn"]}"')
            lines.append(f'    note: "{escape_yaml(note)}"')
        elif book.get("wikidata_id"):
            # Fallback: use Wikidata ID if no ISBN
            lines.append(f'  # No ISBN found: {book["title"]} - {book["author"]}')
            lines.append(f'  # Wikidata: {book["wikidata_id"]}')
    
    return "\n".join(lines)


def escape_yaml(text: str) -> str:
    """Escape special characters for YAML strings."""
    return text.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n')


def sanitize_filename(name: str) -> str:
    """Create a safe filename from a string."""
    name = name.lower()
    name = re.sub(r'[àáâãäå]', 'a', name)
    name = re.sub(r'[èéêë]', 'e', name)
    name = re.sub(r'[ìíîï]', 'i', name)
    name = re.sub(r'[òóôõö]', 'o', name)
    name = re.sub(r'[ùúûü]', 'u', name)
    name = re.sub(r'[ç]', 'c', name)
    name = re.sub(r'[^a-z0-9]+', '-', name)
    name = re.sub(r'^-+|-+$', '', name)
    return name


def main():
    parser = argparse.ArgumentParser(
        description="Generate curated book lists from Wikidata"
    )
    parser.add_argument(
        "--prize",
        choices=list(PRIZES.keys()),
        help="Literary prize to generate list for"
    )
    parser.add_argument(
        "--author",
        help="Author name to generate bibliography for"
    )
    parser.add_argument(
        "--years",
        help="Year range (e.g., 2000-2024)"
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("."),
        help="Output directory for generated YAML files"
    )
    parser.add_argument(
        "--list-prizes",
        action="store_true",
        help="List available prizes"
    )
    parser.add_argument(
        "--all-prizes",
        action="store_true",
        help="Generate lists for all available prizes"
    )
    
    args = parser.parse_args()
    
    if args.list_prizes:
        print("Available prizes:")
        for key, info in PRIZES.items():
            print(f"  {key}: {info['title']['en']}")
        return
    
    # Parse year range
    start_year, end_year = 1900, 2025
    if args.years:
        parts = args.years.split("-")
        if len(parts) == 2:
            start_year, end_year = int(parts[0]), int(parts[1])
    
    # Ensure output directory exists
    args.output.mkdir(parents=True, exist_ok=True)
    
    if args.all_prizes:
        for prize_key in PRIZES.keys():
            generate_prize_list(prize_key, start_year, end_year, args.output)
    elif args.prize:
        generate_prize_list(args.prize, start_year, end_year, args.output)
    elif args.author:
        generate_author_list(args.author, args.output)
    else:
        parser.print_help()


def generate_prize_list(prize_key: str, start_year: int, end_year: int, output_dir: Path):
    """Generate a list for a literary prize."""
    prize = PRIZES[prize_key]
    
    print(f"Fetching {prize['title']['en']} winners from Wikidata...")
    books = get_prize_winners(prize["id"], start_year, end_year)
    
    if not books:
        print(f"  No books found for {prize_key}")
        return
    
    books_with_isbn = [b for b in books if b.get("isbn")]
    print(f"  Found {len(books)} books, {len(books_with_isbn)} with ISBNs")
    
    yaml_content = generate_yaml(
        list_id=f"wikidata-{prize_key}",
        title=prize["title"],
        description=prize["description"],
        books=books,
        tags=["prix", "generated", prize_key]
    )
    
    output_file = output_dir / f"wikidata-{prize_key}.yml"
    output_file.write_text(yaml_content, encoding="utf-8")
    print(f"  Written to {output_file}")


def generate_author_list(author_name: str, output_dir: Path):
    """Generate a bibliography for an author."""
    
    print(f"Fetching works by {author_name} from Wikidata...")
    books = get_author_works(author_name)
    
    if not books:
        print(f"  No books found for {author_name}")
        return
    
    books_with_isbn = [b for b in books if b.get("isbn")]
    print(f"  Found {len(books)} books, {len(books_with_isbn)} with ISBNs")
    
    list_id = sanitize_filename(f"author-{author_name}")
    
    title = {
        "fr": f"Bibliographie de {author_name}",
        "en": f"Bibliography of {author_name}",
        "de": f"Bibliographie von {author_name}",
        "es": f"Bibliografía de {author_name}"
    }
    
    description = {
        "fr": f"Les œuvres de {author_name}.",
        "en": f"Works by {author_name}.",
        "de": f"Werke von {author_name}.",
        "es": f"Obras de {author_name}."
    }
    
    yaml_content = generate_yaml(
        list_id=list_id,
        title=title,
        description=description,
        books=books,
        tags=["auteur", "bibliographie", "generated"]
    )
    
    output_file = output_dir / f"{list_id}.yml"
    output_file.write_text(yaml_content, encoding="utf-8")
    print(f"  Written to {output_file}")


if __name__ == "__main__":
    main()
