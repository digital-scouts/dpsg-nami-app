---
title: Neuigkeiten
nav_order: 4
permalink: /neuigkeiten/
---

# Neuigkeiten

{% for post in site.posts %}
- {{ post.date | date: "%d.%m.%Y" }} · [{{ post.title }}]({{ post.url | relative_url }})
{% endfor %}
