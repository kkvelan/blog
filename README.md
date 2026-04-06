# Blog

This is where I share **blogs**, **learnings**, and **development activities**. One place for what I'm building, what I'm exploring, and what I find worth writing down.

The site is built with Jekyll and GitHub Pages. Posts live in `_posts/`; each post can have its own folder for images. If you're here to read, head to the [live site](https://kkvelan.github.io/blog/) (or the Pages URL for this repo).

## Blog content style

See **[BLOG_STYLE.md](BLOG_STYLE.md)** (typography and emphasis rules for posts).

## Author workflow (preview first)

**Rule:** work in **`preview.html` first**. Do **not** create or edit **`post.md`** or **`_posts/`** until you are ready to **publish** (or until you are fixing an already-live post and want the preview to match).

1. **Draft** in a topic folder using **`preview.html` only** (open it locally in a browser). Use **relative** image paths (e.g. `./figure.svg`). `preview.html` is **gitignored** and never goes to GitHub.
2. **Publish** (go live): copy the content into **`post.md`** in that folder and **`_posts/YYYY-MM-DD-slug.md`**, add Jekyll **front matter**, and change image URLs to **`{{ site.baseurl }}/topic-folder/…`**. Then commit and push.

If something went live without a preview file, add **`preview.html`** anyway so future edits stay on the right path.

**Commit messages:** describe what changed in plain language; keep `git log` readable and professional.
