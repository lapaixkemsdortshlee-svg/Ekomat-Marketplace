---
name: markitdown
description: Convert files (PDF, Word .docx, PowerPoint .pptx, Excel .xlsx, images, audio, HTML, CSV, JSON, XML, EPub, ZIP, YouTube URLs) into clean LLM-ready Markdown using Microsoft's markitdown tool. Use when the user shares a document or asks to "convert to markdown", "extract text from this PDF", "turn this doc/slide/spreadsheet into markdown", "read this PDF/Word/PowerPoint", "transcribe this audio", or drops a binary file that needs to become readable text. For AyitiMarket, this is how PDFs like the deployment guide become docs/*.md.
---

# markitdown — files to Markdown

[microsoft/markitdown](https://github.com/microsoft/markitdown) converts many file formats to Markdown optimized for LLM consumption. It is a Python tool, not a packaged agent skill, so this skill wraps it via `uvx` (no permanent install needed — dependencies are fetched on demand, which suits the ephemeral remote environment).

## Supported inputs

PDF, Word (.docx), PowerPoint (.pptx), Excel (.xlsx / .xls), images (EXIF + OCR), audio (EXIF + speech transcription), HTML, CSV, JSON, XML, EPub, ZIP (iterates contents), YouTube URLs, and more.

## How to run

Prefer `uvx` so nothing has to be installed persistently. Use the `[all]` extras to guarantee PDF / Office / audio support (the bare package omits some parsers):

```bash
# Convert a file to Markdown (writes alongside, or redirect where you want)
uvx --from 'markitdown[all]' markitdown path/to/file.pdf > path/to/file.md

# From stdin
cat file.docx | uvx --from 'markitdown[all]' markitdown > out.md

# Explicit output flag also works
uvx --from 'markitdown[all]' markitdown slides.pptx -o slides.md
```

For quick common formats (HTML/CSV/JSON) the lighter `uvx --from markitdown markitdown` is enough and faster.

If markitdown will be used repeatedly in one session, install once to skip re-resolution:

```bash
uv tool install 'markitdown[all]'   # then just: markitdown file.pdf
```

## Conventions for this repo

- Converted docs go under `docs/` (e.g. a PDF guide → `docs/<name>.md`), matching how `AyitiMarketDeploymentGuide.pdf` became `docs/DEPLOYMENT-GUIDE.md`.
- Review the output: markitdown is faithful but scanned PDFs rely on OCR and tables can need light cleanup. Fix obvious artifacts before committing.
- Keep the original binary out of the repo unless the user wants it tracked; commit the Markdown.

## Notes / limits

- First run in a session downloads dependencies (numpy, onnxruntime, magika, parsers) — expect a short delay.
- Audio transcription and some image OCR need the `[all]` extras and may call external models depending on version; check output before trusting it.
- It extracts and structures existing content; it does not summarize or translate. Do that as a separate step (e.g. Kreyòl translation for AyitiMarket content).
