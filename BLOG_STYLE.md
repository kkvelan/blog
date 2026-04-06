# Blog content style (kkvelan/blog)

These rules apply to **`_posts/`**, topic **`post.md`**, and **`preview.html`** bodies.

## Typography

- **Do not use the Unicode em dash (U+2014, `—`).** Use a comma, a period, a colon, parentheses, or a hyphen where it fits normal English.
- Prefer **straight ASCII apostrophes** in contractions (`it's`, `don't`) in new posts unless a title demands otherwise.

## Emphasis

- **Avoid heavy `**bold**`.** Headings already provide structure.
- Use **`backticks`** for commands (`id`), syscall names, register names, short code, and file paths.
- Use **bold sparingly**: at most an occasional short phrase for real emphasis, not every technical noun.

## Voice

- Plain, simple English first. Short sentences when explaining hardware or the kernel.

## SVG figures

- Keep **all text inside `.svg` files ASCII-only** (straight quotes, hyphens, colons). Bad bytes (smart quotes, control characters) can **break rendering** or show empty boxes in browsers.

## Images in Jekyll posts

- In **`_posts/*.md`** and **`post.md`**, use the **`relative_url`** filter, not raw `site.baseurl` inside Markdown links, so paths resolve on GitHub Pages:

  `![Alt]({{ '/topic-folder/diagram.svg' | relative_url }})`

## Workflow

- Draft in **`preview.html`** first; sync to **`post.md`** and **`_posts/`** when publishing (see [README.md](README.md)).

## Editor automation (local)

If you use Cursor, a rule file at **`.cursor/rules/blog-content.mdc`** can mirror this document. That folder is **gitignored** here; copy the rules to a new machine by reading this file or recreating the rule.
