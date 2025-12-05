import 'package:flutter/material.dart';

class CallToAction {
  final Color color;
  final String label;
  final Uri externalLink;

  const CallToAction({
    required this.color,
    required this.label,
    required this.externalLink,
  });
}

class MessageOfTheDay {
  final String header;
  final String bodyMarkdown;
  final CallToAction? action;

  const MessageOfTheDay({
    required this.header,
    required this.bodyMarkdown,
    this.action,
  });

  bool get hasContent =>
      header.isNotEmpty || bodyMarkdown.isNotEmpty || (action != null);
}
