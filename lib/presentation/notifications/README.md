# Notifications UI

- `app_snackbar.dart`: App-weiter Snackbar-Helper und einheitlicher Snackbar-Content für Erfolg, Warnung, Fehler, Info und Help
- `notifications_list.dart`: Listendarstellung aller Mitteilungen
- `urgent_notification_modal.dart`: Modal/Dialog für dringende Mitteilungen
- `notifications_story.dart`: Storybook-Story für UI-Review
- `app_snackbar_story.dart`: Storybook-Vorschau für alle Snackbar-Zustände und längere Nachrichten
- `notifications_list_test.dart`, `urgent_notification_modal_test.dart`, `app_snackbar_test.dart`: Widget-Tests

## Snackbar Usage

Für app-weites Feedback verwende `AppSnackbar.show(...)` oder `AppSnackbar.showOnMessenger(...)` aus `app_snackbar.dart` statt direkter `SnackBar(...)`-Erzeugung.

Die Story `App/Snackbars` ist in [lib/main_storybook.dart](../../main_storybook.dart) eingebunden und dient als visuelle Absicherung für:

- alle fünf Zustände
- Standardtitel und explizite Titel
- längere Nachrichten

## Storybook

Binde `NotificationsStory` in dein Storybook ein, z.B.:

```dart
import 'presentation/notifications/notifications_story.dart';
// ...
MaterialStory(
  name: 'Notifications',
  builder: (_) => const NotificationsStory(),
)
```
