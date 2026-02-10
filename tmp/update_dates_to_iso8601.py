#!/usr/bin/env python3
"""
Update date formats to ISO 8601 datetime format.
Convert YYYY-MM-DD to YYYY-MM-DDT00:00:00 for historical dates.
Use 2026-02-10T15:00:00 for current timestamps.
"""

import re
import sys
from pathlib import Path

CURRENT_DATETIME = "2026-02-10T15:00:00"

# Patterns to match and convert
# Pattern: date-only format that needs time component added
# Excludes dates already in ISO 8601 format with T or in JSON examples
DATE_PATTERNS = [
    # YAML frontmatter fields
    (r'(fix_date:\s*")(\d{4}-\d{2}-\d{2})(")', r'\g<1>\g<2>T00:00:00\g<3>'),
    (r'(review_date:\s*")(\d{4}-\d{2}-\d{2})(")', r'\g<1>\g<2>T00:00:00\g<3>'),
    (r'(created_date:\s*")(\d{4}-\d{2}-\d{2})(")', r'\g<1>\g<2>T00:00:00\g<3>'),
    (r'(last_updated:\s*")(\d{4}-\d{2}-\d{2})(")', r'\g<1>\g<2>T00:00:00\g<3>'),

    # Document control table fields: | **Date** | YYYY-MM-DD |
    (r'(\| \*\*Date\*\* \| )(\d{4}-\d{2}-\d{2})( \|)', r'\g<1>\g<2>T00:00:00\g<3>'),
    (r'(\| \*\*Date Created\*\* \| )(\d{4}-\d{2}-\d{2})( \|)', r'\g<1>\g<2>T00:00:00\g<3>'),
    (r'(\| \*\*Last Updated\*\* \| )(\d{4}-\d{2}-\d{2})( \|)', r'\g<1>\g<2>T00:00:00\g<3>'),
    (r'(\| \*\*Review Date\*\* \| )(\d{4}-\d{2}-\d{2})( \|)', r'\g<1>\g<2>T00:00:00\g<3>'),
    (r'(\| \*\*Fix Date\*\* \| )(\d{4}-\d{2}-\d{2})( \|)', r'\g<1>\g<2>T00:00:00\g<3>'),

    # Plain text fields: **Last Updated:** YYYY-MM-DD or **Last Updated**: YYYY-MM-DD
    (r'(\*\*Last Updated:\*\* )(\d{4}-\d{2}-\d{2})($|\n)', r'\g<1>\g<2>T00:00:00\g<3>'),
    (r'(\*\*Last Updated\*\*: )(\d{4}-\d{2}-\d{2})($|\n)', r'\g<1>\g<2>T00:00:00\g<3>'),
    (r'(\*\*Fix Date\*\*: )(\d{4}-\d{2}-\d{2})($|\n)', r'\g<1>\g<2>T00:00:00\g<3>'),
    (r'(\*\*Review Date\*\*: )(\d{4}-\d{2}-\d{2})($|\n)', r'\g<1>\g<2>T00:00:00\g<3>'),

    # Generated line at the end of documents
    (r'(\| )(\d{4}-\d{2}-\d{2})(\*$)', r'\g<1>\g<2>T00:00:00\g<3>'),
    (r'(Generated.*\| )(\d{4}-\d{2}-\d{2})(\*)', r'\g<1>\g<2>T00:00:00\g<3>'),
    (r'(doc-brd-fixer v\d+\.\d+ \| )(\d{4}-\d{2}-\d{2})(\*)', r'\g<1>\g<2>T00:00:00\g<3>'),
    (r'(doc-brd-reviewer v\d+\.\d+ \| )(\d{4}-\d{2}-\d{2})(\*)', r'\g<1>\g<2>T00:00:00\g<3>'),

    # Version history tables: | 1.0 | YYYY-MM-DD | Author |
    (r'(\| \d+\.\d+ \| )(\d{4}-\d{2}-\d{2})( \| )', r'\g<1>\g<2>T00:00:00\g<3>'),

    # Change log tables: | YYYY-MM-DD | Change | (also handles PRD-00 index completion dates)
    (r'(\| )(\d{4}-\d{2}-\d{2})( \| (?!start|end|[^|]*T))', r'\g<1>\g<2>T00:00:00\g<3>'),

    # Generated line marker: > **Generated**: YYYY-MM-DD
    (r'(> \*\*Generated\*\*: )(\d{4}-\d{2}-\d{2})($|\n)', r'\g<1>\g<2>T00:00:00\g<3>'),

    # Report generated line
    (r'(Review Mode \| )(\d{4}-\d{2}-\d{2})(\*)', r'\g<1>\g<2>T00:00:00\g<3>'),

    # Generated at the end of PRDs: *Generated: YYYY-MM-DD
    (r'(\*Generated: )(\d{4}-\d{2}-\d{2})([ \|*])', r'\g<1>\g<2>T00:00:00\g<3>'),

    # Table cells with date at end: | Complete | YYYY-MM-DD |
    (r'(\| Complete \| )(\d{4}-\d{2}-\d{2})( \|)', r'\g<1>\g<2>T00:00:00\g<3>'),

    # Last Generation row: | Last Generation | YYYY-MM-DD |
    (r'(\| Last Generation \| )(\d{4}-\d{2}-\d{2})( \|)', r'\g<1>\g<2>T00:00:00\g<3>'),

    # Validation/Report Date fields: **Validation Date**: YYYY-MM-DD or **Report Generated**: YYYY-MM-DD
    (r'(\*\*Validation Date\*\*: )(\d{4}-\d{2}-\d{2})($|\n)', r'\g<1>\g<2>T00:00:00\g<3>'),
    (r'(\*\*Report Generated\*\*: )(\d{4}-\d{2}-\d{2})($|\n)', r'\g<1>\g<2>T00:00:00\g<3>'),
    (r'(\*\*Next Review Date\*\*: )(\d{4}-\d{2}-\d{2})($|\n)', r'\g<1>\g<2>T00:00:00\g<3>'),

    # **Generated:** YYYY-MM-DD
    (r'(\*\*Generated:\*\* )(\d{4}-\d{2}-\d{2})($|\n)', r'\g<1>\g<2>T00:00:00\g<3>'),

    # Generated at end without asterisk: *Generated: YYYY-MM-DD | ...
    (r'(\*Generated: )(\d{4}-\d{2}-\d{2})($|\n)', r'\g<1>\g<2>T00:00:00\g<3>'),

    # ADR header: > **Date**: YYYY-MM-DD
    (r'(> \*\*Date\*\*: )(\d{4}-\d{2}-\d{2})($|\n)', r'\g<1>\g<2>T00:00:00\g<3>'),

    # Approval Date in tables: | Approval Date | YYYY-MM-DD |
    (r'(\| Approval Date \| )(\d{4}-\d{2}-\d{2})( \|)', r'\g<1>\g<2>T00:00:00\g<3>'),

    # Analysis revised: *Analysis revised YYYY-MM-DD
    (r'(\*Analysis revised )(\d{4}-\d{2}-\d{2})( )', r'\g<1>\g<2>T00:00:00\g<3>'),
]

def update_file_dates(filepath: Path) -> tuple[bool, int]:
    """
    Update dates in a file to ISO 8601 format.
    Returns (changed, count) - whether file was modified and number of changes.
    """
    try:
        content = filepath.read_text(encoding='utf-8')
    except Exception as e:
        print(f"  Error reading {filepath}: {e}")
        return False, 0

    original_content = content
    total_changes = 0

    for pattern, replacement in DATE_PATTERNS:
        new_content, count = re.subn(pattern, replacement, content)
        if count > 0:
            content = new_content
            total_changes += count

    if content != original_content:
        try:
            filepath.write_text(content, encoding='utf-8')
            return True, total_changes
        except Exception as e:
            print(f"  Error writing {filepath}: {e}")
            return False, 0

    return False, 0


def process_directory(directory: Path, pattern: str = "*.md") -> dict:
    """
    Process all matching files in directory (excluding backup folders).
    """
    results = {
        'total': 0,
        'modified': 0,
        'changes': 0,
        'files': []
    }

    for filepath in sorted(directory.rglob(pattern)):
        # Skip backup folders and tmp
        if '.backup' in str(filepath) or '/tmp/' in str(filepath):
            continue

        results['total'] += 1
        changed, count = update_file_dates(filepath)

        if changed:
            results['modified'] += 1
            results['changes'] += count
            results['files'].append((str(filepath), count))
            print(f"  Updated: {filepath.name} ({count} changes)")

    return results


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python update_dates_to_iso8601.py <directory>")
        sys.exit(1)

    directory = Path(sys.argv[1])
    if not directory.exists():
        print(f"Error: Directory {directory} does not exist")
        sys.exit(1)

    print(f"Processing {directory}...")
    results = process_directory(directory)

    print(f"\nSummary:")
    print(f"  Total files scanned: {results['total']}")
    print(f"  Files modified: {results['modified']}")
    print(f"  Total changes: {results['changes']}")

    if results['files']:
        print(f"\nModified files:")
        for filepath, count in results['files']:
            print(f"  {filepath}: {count} changes")
