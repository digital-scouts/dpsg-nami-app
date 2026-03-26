# Notifications UI

- `notifications_list.dart`: Listendarstellung aller Mitteilungen
- `urgent_notification_modal.dart`: Modal/Dialog für dringende Mitteilungen
- `notifications_story.dart`: Storybook-Story für UI-Review
- `notifications_list_test.dart`, `urgent_notification_modal_test.dart`: Widget-Tests

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
