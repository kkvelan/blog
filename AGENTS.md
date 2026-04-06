# Instructions for AI assistants (blog repo)

This file is **tracked in git** so harness rules survive environments where `.cursor/` is not committed.

## Blog post workflow (strict)

| Phase | What to edit |
|-------|----------------|
| **Draft** | **`topic/preview.html` only** (plus assets in that folder: images, `.c` demos, etc.) |
| **Publish** | Only when the user **explicitly** asks: sync to **`topic/post.md`** and **`_posts/YYYY-MM-DD-slug.md`** |

**Do not** create or edit `post.md` or `_posts/**/*.md` during drafting. The canonical draft lives in **`preview.html`** until publish.

Cursor-specific detail: see `.cursor/rules/blog-post-harness.mdc` (same rules; `alwaysApply: true`).

Human-readable summary: [README.md § Author workflow](README.md#author-workflow-preview-first).
