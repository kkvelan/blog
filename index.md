---
layout: default
title: Home
---

# Posts

<ul class="post-list">
  {% for post in site.posts %}
  <li>
    <a href="{{ post.url | relative_url }}">{{ post.title }}</a>
    <p class="post-meta">{{ post.date | date: "%b %-d, %Y" }}</p>
  </li>
  {% endfor %}
</ul>
