import 'package:storybook_flutter/storybook_flutter.dart';

import '../presentation/notifications/notifications_story.dart';

Story notificationsListStory() =>
    const Story(name: 'Notifications/List', builder: _builder);

NotificationsStory _builder(context) => const NotificationsStory();
