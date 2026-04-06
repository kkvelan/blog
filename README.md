# Blog

This is where I share **blogs**, **learnings**, and **development activities**. One place for what I'm building, what I'm exploring, and what I find worth writing down.

The site is built with Jekyll and GitHub Pages. Posts live in `_posts/`; each post can have its own folder for images. If you're here to read, head to the [live site](https://kkvelan.github.io/blog/) (or the Pages URL for this repo).

## Author workflow (preview first)

1. **Draft** in a topic folder using **`preview.html` only** (open it locally in a browser). `preview.html` is gitignored.
2. **When pushing to the remote repo** (going live), add **`post.md`** in that folder and **`_posts/YYYY-MM-DD-slug.md`** with the same content, front matter, and image paths adjusted for Jekyll.

Do not create `post.md` or `_posts/` until publish time unless you are updating an already-published post.

**Commit messages:** describe changes in plain terms. Do **not** name specific editors, vendors, or AI products in commit subjects or bodies—keep `git log` neutral and professional.

**Assistants / automation:** follow [AGENTS.md](AGENTS.md): **never** edit `post.md` or `_posts/` during draft work; only **`preview.html`** until the author explicitly asks to publish or sync. Local rule folders (e.g. under `.gitignore`) are not pushed.
