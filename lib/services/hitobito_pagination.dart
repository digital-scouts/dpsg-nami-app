/// Seitengroesse fuer die Listen-Endpunkte des Syncs (`/api/people`,
/// `/api/roles`, `/api/groups`). Ohne `page[size]` liefert Hitobito (Graphiti)
/// nur 20 Eintraege pro Seite, was bei groesseren Staemmen dutzende
/// sequenzielle Requests bedeutet. 1000 ist das Graphiti-Maximum
/// (`max_page_size`); groessere Werte beantwortet die API mit 400.
const int hitobitoListPageSize = 1000;

/// Setzt `page[size]` auf [hitobitoListPageSize] und, falls noch keine
/// Sortierung angegeben ist, `sort=id`. Ohne feste Sortierung ist die
/// Reihenfolge zwischen den Seiten nicht stabil: Eintraege rutschen von einer
/// Seite auf die naechste, tauchen doppelt auf oder fehlen ganz (auf
/// dpsg.puzzle.ch beobachtet: 404 Personen, davon nur 333 verschiedene).
/// Wird auch auf `links.next` angewendet, damit beides ueber alle Seiten
/// gleich bleibt.
Uri withHitobitoListPaging(Uri uri) {
  final queryParameters = Map<String, String>.from(uri.queryParameters);
  queryParameters['page[size]'] = '$hitobitoListPageSize';
  queryParameters.putIfAbsent('sort', () => 'id');
  return uri.replace(queryParameters: queryParameters);
}

/// Setzt [filter] (z.B. `{'filter[id]': '1,2,3'}`) als Query-Parameter. Wird
/// pro Seite angewendet, damit der Filter nicht davon abhaengt, ob die API ihn
/// in `links.next` mitfuehrt.
Uri withHitobitoListFilter(Uri uri, Map<String, String> filter) {
  if (filter.isEmpty) {
    return uri;
  }
  return uri.replace(
    queryParameters: <String, String>{...uri.queryParameters, ...filter},
  );
}
