---
title: Gerätesupport
parent: Handbuch
nav_order: 10.5
---

# Gerätesupport
{: .no_toc }

Die App läuft auf iPhone, iPad und Android und nutzt breite Fenster wie beim aufgeklappten iPhone Duo mit einer Seitenleiste.
{: .lead }

<div class="duo gross"><img src="{{ '/assets/img/geraete/duo_statistik.jpg' | relative_url }}" alt="Statistik auf dem aufgeklappten iPhone Duo"></div>

1. TOC
{:toc}

## Was sich auf breiten Fenstern ändert

Maßgeblich ist die Breite des Fensters, nicht das Gerät. Im Split View verhält sich ein iPad also wie ein schmales Gerät.

- **Schmal** (iPhone, iPad mini hoch, Split View): Leiste unten, Inhalt über die volle Breite <i class="ref">1</i>.
- **Ab 840 pt** (iPhone Duo aufgeklappt, iPad quer, iPad 13" hoch): Seitenleiste links mit den vier Bereichen, darunter Karte und Qualifikationen, die Einstellungen am unteren Rand <i class="ref">2</i> <i class="ref">3</i>. Unterseiten öffnen daneben, die Seitenleiste bleibt sichtbar.
- **Ab 1200 pt** (iPad 13" quer): breite Seitenleiste mit Text neben dem Symbol.
- Listen und Karten sind höchstens 800 pt breit und stehen mittig. Die Statistik nutzt die volle Breite.

{% include geraete.html items="phone:screens/mitglieder:iPhone|tablet:geraete/ipad_mitglieder:iPad hoch|duo:geraete/duo_mitglieder:iPhone Duo aufgeklappt" %}

Karte und Qualifikationen öffnen sich direkt neben der Seitenleiste <i class="ref">4</i>. Klappst du das Duo zu oder auf, bleibt die App auf derselben Seite.

{% include geraete.html items="duo:geraete/duo_karte:Karte aus der Seitenleiste" start=4 %}

## Unterstützte Geräte

| Gerät | Voraussetzung | Darstellung |
|:--|:--|:--|
| iPhone | ab iOS 16 | Hochformat, Leiste unten |
| iPhone Duo | ab iOS 16 | zugeklappt wie das iPhone, aufgeklappt mit Seitenleiste |
| iPad | ab iPadOS 16 | Hoch- und Querformat, auch Split View und Stage Manager |
| Android-Telefon | ab Android 7 | Hochformat, Leiste unten |
| Android-Tablet und Foldable | ab Android 7 | Hochformat, passt sich der Breite an wie auf dem iPad |
