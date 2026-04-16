import 'package:flutter/widgets.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

import '../presentation/notifications/notifications_story.dart';

Story notificationsListStory() =>
    const Story(name: 'App/Feedback/Benachrichtigungen', builder: _builder);

NotificationsStory _builder(BuildContext context) => const NotificationsStory();
