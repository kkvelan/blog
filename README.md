# Blog - GitHub Pages

One place for writing random things, what I know, and what I learn. Posts live in `_posts/`; GitHub Pages builds the site when you push. **Preview is the final file** for local review: `preview.html` is written directly from `_posts/` (no scripts).

## Repo structure

- **`_posts/`** – Source for each post (`YYYY-MM-DD-slug.md`). Jekyll builds the site from here.
- **`<slug>/`** – One folder per post (e.g. `rust-ai-workloads-backend/`) for images and **`preview.html`** (the final file you open to review). `preview.html` is written directly from the corresponding post in `_posts/`; no migration or tmp scripts.

## What goes in the repo (and what does not)

**Required in both local and remote** (for GitHub Pages to build):

| Path | Purpose |
|------|--------|
| `_config.yml` | Jekyll site config, baseurl, plugins |
| `_layouts/` | HTML layouts (default, post) |
| `_posts/` | Post Markdown files (source for site and preview) |
| `assets/` | CSS and other static assets |
| `index.md` | Homepage |
| `Gemfile` | Jekyll / GitHub Pages deps |
| `<slug>/` | Per-post folder for images and `preview.html` |

**Never push:** `**/preview.html` (if you prefer to keep it local), `_site/`, `.env`, **private tokens**, API keys. These are in `.gitignore`.

## Adding a new post

1. Add a file in `_posts/` named **`YYYY-MM-DD-your-slug.md`** with front matter and Markdown:

```yaml
---
layout: post
title: "Your post title"
date: 2025-03-10 14:00:00 +0000
---

Your content in **Markdown** here...
```

2. For images, create a folder with the same slug (e.g. `your-slug/`) and put images there. In the post use:

`![Description]({{ site.baseurl }}/your-slug/image.jpg)`

3. **Preview:** To review locally, regenerate **`<slug>/preview.html`** from the corresponding post in `_posts/` (e.g. convert the Markdown to HTML and wrap it in the same layout and styles). Open that file in a browser. No scripts are run.

4. Commit and push:

```bash
git add _posts/ your-slug/
git commit -m "Add post: Your post title"
git push
```

## Quick start (first-time setup)

1. Create the repo on GitHub (e.g. `blog`).
2. Set `baseurl` in `_config.yml`: `""` for `kkvelan.github.io`, or `"/blog"` for repo `blog`.
3. Push; enable GitHub Pages: Settings → Pages → Deploy from branch → main.

## Local Jekyll (optional)

```bash
bundle install
bundle exec jekyll serve
```

Open http://localhost:4000/blog (or http://localhost:4000 if `baseurl` is empty).

## Viewing style

Black background, white text. Use fenced code blocks with a language (e.g. ` ```rust `, ` ```yaml `) for syntax highlighting. Images and tables are styled in the theme.
