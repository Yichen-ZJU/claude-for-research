---
name: preview
description: Preview or export Markdown, PDF, HTML, or code artifacts using shell/browser tools. Use when the user wants to review a written artifact, export a report, or view a rendered document.
---

# Preview

Render or open artifacts with shell/browser tools.

## Linux (this machine)

```bash
xdg-open <file.md>          # opens in default app
xdg-open <file.pdf>         # opens in PDF viewer

# Markdown -> HTML
pandoc input.md -o output.html --standalone --metadata title="Report"

# Markdown -> PDF (needs a LaTeX engine)
pandoc input.md -o output.pdf
pandoc input.md -o output.pdf --pdf-engine=xelatex   # better for CJK
```

## Headless alternatives

When no display is available or the export is the artifact itself:

```bash
pandoc input.md -o output.html   # always works offline
wc -l output.html && ls -la output.html
```

## Rules

- Verify the output file exists and is non-trivial (`stat`, `wc`) before saying the export succeeded.
- If `pandoc` or a PDF engine is missing, say so and offer the HTML fallback or `pip install`/`apt` options.
- For figures, open or export the actual image file; do not claim a render you did not produce.
