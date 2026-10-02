import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../domain/taetigkeit/stufe.dart';
import '../statistik_farben.dart';

/// Rahmen einer Kachel: einzeiliger Titel, darunter der Inhalt, der auf die
/// feste Kachelgröße beschnitten wird. Mit [onTitel] wird der Titel zum
/// Verweis (z. B. auf alle Gruppen) und bekommt ein ›.
class KachelRahmen extends StatelessWidget {
  const KachelRahmen({
    super.key,
    required this.titel,
    required this.child,
    this.onTitel,
  });

  final String titel;
  final Widget child;
  final VoidCallback? onTitel;

  @override
  Widget build(BuildContext context) {
    final farben = StatistikFarben.of(context);
    return Material(
      color: farben.flaeche,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _titelZeile(context, farben),
            const SizedBox(height: 6),
            Expanded(child: ClipRect(child: child)),
          ],
        ),
      ),
    );
  }

  Widget _titelZeile(BuildContext context, StatistikFarben farben) {
    final text = Text(
      titel,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: farben.textGedaempft,
      ),
    );
    final onTitel = this.onTitel;
    if (onTitel == null) return text;
    return InkWell(
      key: const Key('kachel-titel-link'),
      onTap: onTitel,
      borderRadius: BorderRadius.circular(6),
      child: Row(
        children: [
          Flexible(child: text),
          Icon(
            Icons.chevron_right,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

/// Große Zahl, die bei Platzmangel schrumpft statt abgeschnitten zu werden.
class KachelZahl extends StatelessWidget {
  const KachelZahl(
    this.wert, {
    super.key,
    this.groesse = 34,
    this.einheit,
    this.zusatz,
    this.ausrichtung = Alignment.centerLeft,
  });

  final String wert;
  final double groesse;
  final String? einheit;

  /// Kleiner Zusatz direkt hinter der Zahl, z. B. „+3“.
  final String? zusatz;
  final AlignmentGeometry ausrichtung;

  @override
  Widget build(BuildContext context) {
    final farben = StatistikFarben.of(context);
    final klein = TextStyle(
      fontSize: groesse * 0.36 < 11 ? 11 : groesse * 0.36,
      fontWeight: FontWeight.w600,
      color: farben.textSchwach,
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: ausrichtung,
      child: Text.rich(
        TextSpan(
          text: wert,
          style: TextStyle(
            fontSize: groesse,
            fontWeight: FontWeight.w700,
            height: 1.05,
            letterSpacing: groesse >= 30 ? -0.5 : 0,
            color: farben.text,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          children: [
            if (zusatz != null) TextSpan(text: zusatz, style: klein),
            if (einheit != null) TextSpan(text: ' $einheit', style: klein),
          ],
        ),
        maxLines: 1,
        softWrap: false,
      ),
    );
  }
}

/// Füllt in einer Spalte den restlichen Platz und setzt [child] an den
/// unteren Rand (bzw. an [ausrichtung]). Reicht der Platz nicht, schrumpft
/// [child], statt die Kachel zu sprengen.
class KachelRest extends StatelessWidget {
  const KachelRest({
    super.key,
    required this.child,
    this.abstand = 6,
    this.ausrichtung = AlignmentDirectional.bottomStart,
  });

  final Widget child;

  /// Mindestabstand zum Inhalt darüber.
  final double abstand;
  final AlignmentGeometry ausrichtung;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(top: abstand),
        child: KachelEingepasst(ausrichtung: ausrichtung, child: child),
      ),
    );
  }
}

/// Gibt [child] die volle Breite und lässt es bei zu wenig Höhe als Ganzes
/// schrumpfen, statt überzulaufen. Für Inhalte ohne eigene flexible Teile.
class KachelEingepasst extends StatelessWidget {
  const KachelEingepasst({
    super.key,
    required this.child,
    this.ausrichtung = AlignmentDirectional.center,
  });

  final Widget child;
  final AlignmentGeometry ausrichtung;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: ausrichtung,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: ausrichtung,
          child: SizedBox(width: constraints.maxWidth, child: child),
        ),
      ),
    );
  }
}

/// Kleine graue Zeile unter einem Diagramm.
class KachelFuss extends StatelessWidget {
  const KachelFuss(this.text, {super.key, this.zeilen = 1});

  final String text;
  final int zeilen;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: zeilen,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        color: StatistikFarben.of(context).textSchwach,
      ),
    );
  }
}

/// Zustand ohne Daten.
class KachelLeer extends StatelessWidget {
  const KachelLeer(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          color: StatistikFarben.of(context).textSchwach,
        ),
      ),
    );
  }
}

/// Fortschritt zu einem Ziel als Balken in der Primärfarbe.
class KachelMeter extends StatelessWidget {
  const KachelMeter({super.key, required this.anteil});

  final double anteil;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wert = anteil.isFinite ? anteil.clamp(0.0, 1.0) : 0.0;
    return Container(
      height: 5,
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: wert,
        heightFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

/// Farbfeld mit Text, z. B. für Stufen-Legenden.
class KachelSchluessel extends StatelessWidget {
  const KachelSchluessel({
    super.key,
    required this.farbe,
    required this.text,
    this.wert,
    this.kontur,
    this.klein = false,
  });

  final Color farbe;
  final Color? kontur;
  final String text;
  final String? wert;
  final bool klein;

  @override
  Widget build(BuildContext context) {
    final farben = StatistikFarben.of(context);
    final groesse = klein ? 8.0 : 10.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: groesse,
          height: groesse,
          decoration: BoxDecoration(
            color: farbe,
            borderRadius: BorderRadius.circular(2.5),
            border: kontur != null ? Border.all(color: kontur!) : null,
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text.rich(
            TextSpan(
              text: text,
              children: [
                if (wert != null)
                  TextSpan(
                    text: ' $wert',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: farben.text,
                    ),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: klein ? 10.5 : 12,
              height: klein ? 1.2 : null,
              color: farben.textGedaempft,
            ),
          ),
        ),
      ],
    );
  }
}

/// Stufen-Schlüssel mit den Statistik-Farben.
KachelSchluessel stufenSchluessel(
  BuildContext context,
  Stufe stufe, {
  String? wert,
  bool klein = false,
}) {
  final farben = StatistikFarben.of(context);
  return KachelSchluessel(
    farbe: farben.stufe(stufe),
    kontur: farben.kontur(stufe),
    text: stufe.shortDisplayName,
    wert: wert,
    klein: klein,
  );
}

/// Zahl mit einer Nachkommastelle im Format der aktuellen Sprache.
String zahlMitKomma(BuildContext context, double? wert) {
  if (wert == null || !wert.isFinite) return '–';
  final sprache = Localizations.maybeLocaleOf(context)?.languageCode ?? 'de';
  return NumberFormat('0.0', sprache).format(wert);
}

String datumLang(DateTime datum) => DateFormat('dd.MM.yyyy').format(datum);

String datumKurz(DateTime datum) => DateFormat('dd.MM.').format(datum);
