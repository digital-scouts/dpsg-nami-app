---
layout: post
title:  "Alles von vorne: Großer Rework der NaMi App!"
date:   2025-12-03 18:00:00 +0100
categories: jekyll update
---

Die Entwickler unter euch kennen es vermutlich. Man lernt eine neue Sprache und arbeitet mit viel Unterstützung, in meinem Fall von ChatGPT und Copilot, an einem großen Projekt. Kaum ist man fertig, gibt es viele Stellen, die man gerne neu machen würde. Auf dem bisherigen Weg hat man einfach viel gelernt und möchte das Gelernte anwenden - es verbessern.

So ging es mir mit der NaMi App. Anfangs habe ich auf Unit Tests verzichtet, weil ich lieber schneller ergebnisse haben wollte. Nach dem Launch wollte ich diese dann aber nachholen. Dabei habe ich gemerkt, dass die Architektur der App, wenn man es überhaupt so nennen kann, gar keine Unit Tests zulässt. Alle Klassen sind sehr groß und stark miteinander verknüfft. Änderungen an einer Stelle haben oft unvorhersehbare Auswirkungen an anderen Stellen und Fehler lassen sich schlicht finden, da sie mehreren Orten versteckt sein können.
Außerdem steht mit dem aktuellen Umbau der NaMi auch ein großer Umbau für die App an: Die NaMi bekommt ein neues Backend, das viele neue Möglichkeiten eröffnet. Diese möchte ich auch in der App nutzen. Doch so einfach ist der ausstausch des Backends in der aktuellen Architektur nicht möglich.

Daher ist der Neubau der NaMi vermutlich Fluch und Segen zugleich. Zum einen bedeutet es viel arbeit, zum anderen Lohnt sich ein größere Umbau jetzt mehr denn je.

Auch wenn ich jetzt viel Arbeit in die Mülltonne werfe, war es ein großes lerning für mich und ich konnte auch bereits viel Feedback von Nutzern der App sammeln, das ich jetzt einbauen kann.

Fokus liegt dieses mal auf austauschbaren Komponenten, klaren Schnittstellen und Testbarkeit. Alle Widgets existieren unabhängig von der Datenquelle und werden ausschließlich über In- und Outputs gesteuert. Mit Hilfe von Storybook können diese Widgets auch unabhängig von der App entwickelt und getestet werden.

Der Aktuelle Stand des Reworks ist auf dem Branch [refactor/bigAppRebuild](https://github.com/digital-scouts/dpsg-nami-app/tree/refactor/bigAppRebuild) zu finden. Dort sind bereits viele Widgets implementiert die über Storybook getestet werden können.
Die nächsten Schritte sind es dann die App Flows mit State Management: BLoC / Cubit zu implementieren und die Datenquelle anzubinden.
