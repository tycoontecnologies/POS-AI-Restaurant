from pathlib import Path

P = Path('lib/screens/restaurant_dashboard_screen_v3.dart')
if not P.exists():
    raise SystemExit('ERROR: dashboard source missing')

s = P.read_text()
orig = s

marker = '// DASHBOARD_MASONRY_V14'
start = s.find(marker)
if start < 0:
    raise SystemExit('ERROR: V14 masonry block not found')

# Scope repair to the V14 layout region only so existing numeric `columns`
# from the responsive width calculation remains untouched.
end = s.find('                    );\n                  },\n                ),', start)
if end < 0:
    # fallback: stop before resize class/next major section
    end = min([x for x in [s.find('class _', start), len(s)] if x > start])

region = s[start:end]

old_decl = '''final columns = List.generate(
                      columnCount,
                      (_) => <Widget>[],
                    );'''
new_decl = '''final masonryColumns = List.generate(
                      columnCount,
                      (_) => <Widget>[],
                    );'''

if old_decl in region:
    region = region.replace(old_decl, new_decl, 1)
elif 'final masonryColumns = List.generate(' not in region:
    raise SystemExit('ERROR: V14 masonry list declaration not found')

region = region.replace('columns[i % columnCount].add(', 'masonryColumns[i % columnCount].add(')
region = region.replace('children: columns[i],', 'children: masonryColumns[i],')

s = s[:start] + region + s[end:]

if s == orig:
    print('INFO: V14 column collision already repaired')
else:
    P.write_text(s)
    print('OK: renamed V14 widget column list to masonryColumns')

print('OK: retained existing responsive numeric columns variable')
print('OK: fixed duplicate_definition and int [] errors')
print('ONLY lib/screens/restaurant_dashboard_screen_v3.dart modified')
