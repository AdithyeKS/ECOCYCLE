import re
import os

filepath = r'd:\ecocycle_new\ecocycle_new\lib\screens\admin_dashboard.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_theme_lines = [
    '                dialogBackgroundColor: Colors.white,\n',
    '                colorScheme: const ColorScheme.light(\n',
    '                  surface: Colors.white,\n',
    '                  surfaceTint: Colors.transparent,\n',
    '                ),\n'
]

output_lines = []
skip_until = None

for i, line in enumerate(lines):
    # Case 1: : ThemeData.light(),
    if ': ThemeData.light(),' in line:
        indent = line[:line.find(':')]
        output_lines.append(f'{indent}: ThemeData.light().copyWith(\n')
        output_lines.extend(new_theme_lines)
        output_lines.append(f'{indent}  ),\n')
        continue
    
    # Case 2: : ThemeData.light().copyWith( (caused by previous broken edit)
    # We want to normalize these if they are broken
    if ': ThemeData.light().copyWith(' in line and i + 1 < len(lines) and 'dialogBackgroundColor: Colors.white' in lines[i+1]:
        # This one is probably already fine or partially fixed, we'll keep it as is or re-process
        output_lines.append(line)
        continue

    output_lines.append(line)

with open(filepath, 'w', encoding='utf-8') as f:
    f.writelines(output_lines)

print(f"Successfully processed {filepath}")
