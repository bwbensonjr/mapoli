#!/usr/bin/env bash
# Fix sitemap.xml after Quarto render:
#   1. Remove entries with relative URLs (missing https://)
#   2. Rewrite /index.html to / in absolute URLs
#   3. Remove duplicate <url> entries
#
# Usage:
#   As Quarto post-render: uses $QUARTO_PROJECT_OUTPUT_DIR
#   Standalone: _fix_sitemap.sh [output-dir]

OUTPUT_DIR="${1:-${QUARTO_PROJECT_OUTPUT_DIR:-../docs}}"
SITEMAP="$OUTPUT_DIR/sitemap.xml"

if [ ! -f "$SITEMAP" ]; then
    echo "fix_sitemap: $SITEMAP not found" >&2
    exit 1
fi

python3 -c "
import re, sys

with open('$SITEMAP', 'r') as f:
    content = f.read()

# Parse out individual <url>...</url> blocks
url_blocks = re.findall(r'<url>\s*<loc>(.*?)</loc>.*?</url>', content, re.DOTALL)

seen = set()
clean_entries = []
for match in re.finditer(r'(<url>\s*<loc>(.*?)</loc>.*?</url>)', content, re.DOTALL):
    block, loc = match.group(1), match.group(2)

    # Skip entries without absolute URLs
    if not loc.startswith('https://'):
        continue

    # Rewrite /index.html to /
    new_loc = re.sub(r'/index\.html$', '/', loc)
    if new_loc != loc:
        block = block.replace(loc, new_loc)

    # Skip duplicates
    if new_loc in seen:
        continue
    seen.add(new_loc)

    clean_entries.append(block)

output = '<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n'
output += '<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\n'
for entry in clean_entries:
    output += '  ' + entry + '\n'
output += '</urlset>\n'

with open('$SITEMAP', 'w') as f:
    f.write(output)

print(f'fix_sitemap: {len(clean_entries)} URLs (removed {len(url_blocks) - len(clean_entries)} bad/duplicate entries)')
"
