---
name: alpha-research
description: Search, read, and query research papers via the alphaxiv MCP server (2.5M+ arXiv papers). Use when the user asks about academic papers, wants to find research on a topic, needs to read a specific paper, ask questions about a paper, or inspect a paper's code repository.
---

# Alpha Research (alphaxiv MCP)

Paper access runs through the `alphaxiv` MCP server (authenticated with an API key, configured at user scope).

## Tools

| MCP tool | Use |
|---|---|
| `discover_papers` | Search papers by topic/query — the default entry point |
| `get_paper_content` | Read a paper's content (arXiv id or URL) |
| `answer_pdf_queries` | Ask specific questions about a paper's PDF (e.g. "what optimizer did they use?") |
| `read_files_from_github_repository` | Read files from a paper's GitHub repo — overview or specific paths |
| `list_library` / folder tools | Inspect and organize the user's alphaXiv library |

## Coverage caveat

alphaXiv indexes arXiv: computer science, math, physics, statistics, quantitative biology/finance, EE. It does **not** cover PubMed/clinical/biomedical literature (Cell, Nature, etc.). For biomedical topics, complement with WebSearch/WebFetch and say so in provenance.

## When to use

- Academic paper search, reading, Q&A → `alphaxiv` MCP tools
- Current topics (products, releases, docs) → WebSearch/WebFetch
- Mixed topics → combine both

## Degradation

If the MCP tools are not visible in the current session (e.g. some headless runs), fall back to:
- arXiv directly: WebFetch on `https://arxiv.org/abs/<id>` and `https://arxiv.org/list/<category>/recent`
- Semantic Scholar API via Bash: `curl "https://api.semanticscholar.org/graph/v1/paper/search?query=<q>&fields=title,abstract,year,citationCount,url"`

Record the degradation in the run's provenance sidecar.
