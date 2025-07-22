import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:nami/presentation/navigation/navigation_cubit.dart';
import 'package:nami/utilities/helper_functions.dart';
import 'package:url_launcher/url_launcher.dart';

/// Widget für einen einzelnen Drawer-Menüpunkt
class DrawerItem extends StatelessWidget {
  const DrawerItem({
    super.key,
    required this.icon,
    required this.label,
    required this.tab,
    required this.selectedTab,
  });

  final IconData icon;
  final String label;
  final NavigationTab tab;
  final NavigationTab selectedTab;

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedTab == tab;
    final itemColor = isSelected
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : Theme.of(context).colorScheme.onSurface;

    return InkWell(
      splashColor: Colors.grey.withAlpha((0.1 * 255).round()),
      highlightColor: Colors.transparent,
      onTap: () {
        Navigator.pop(context); // Drawer schließen
        context.read<NavigationCubit>().switchTo(tab);
      },
      child: Stack(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
            child: Row(
              children: <Widget>[
                const SizedBox(width: 6.0),
                const Padding(padding: EdgeInsets.all(4.0)),
                Icon(icon, color: itemColor),
                const Padding(padding: EdgeInsets.all(4.0)),
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: itemColor),
                  textAlign: TextAlign.left,
                ),
              ],
            ),
          ),
          if (isSelected)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(2),
                    bottomRight: Radius.circular(2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Widget für den Header-Bereich des Drawers mit Benutzerinformationen
class CustomDrawerHeader extends StatelessWidget {
  const CustomDrawerHeader({
    super.key,
    required this.userName,
    this.gruppierungName,
    this.mitgliedsnummer,
  });

  final String userName;
  final String? gruppierungName;
  final String? mitgliedsnummer;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: topPadding + 16.0,
        left: 16.0,
        right: 16.0,
        bottom: 16.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          if (userName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(
                userName,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              'Mitgliedsnummer: $mitgliedsnummer',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              'Gruppierung: $gruppierungName',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget für den Support-Bereich des Drawers
class DrawerSupportSection extends StatelessWidget {
  const DrawerSupportSection({super.key});

  void _showSupportModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const SupportModal();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.support),
          title: const Text('Entwicklung unterstützen'),
          onTap: () => _showSupportModal(context),
        ),
        const Center(
          child: Text(
            'Entwickelt mit ❤️ in Hamburg',
            style: TextStyle(fontSize: 14),
          ),
        ),
        const SizedBox(height: 8),
        Divider(height: 1, color: Theme.of(context).dividerColor),
      ],
    );
  }
}

/// Widget für den Logout-Bereich des Drawers
class DrawerLogoutSection extends StatelessWidget {
  const DrawerLogoutSection({super.key, required this.onLogoutTap});

  final VoidCallback onLogoutTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        ListTile(
          title: Text(
            'Abmelden',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.left,
          ),
          trailing: const Icon(Icons.power_settings_new, color: Colors.red),
          onTap: onLogoutTap,
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom),
      ],
    );
  }
}

/// Widget für das Support-Modal
class SupportModal extends StatefulWidget {
  const SupportModal({super.key});

  @override
  State<SupportModal> createState() => _SupportModalState();
}

class _SupportModalState extends State<SupportModal> {
  final InAppReview inAppReview = InAppReview.instance;
  bool _isReviewAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkReviewAvailability();
  }

  Future<void> _checkReviewAvailability() async {
    final isAvailable = await inAppReview.isAvailable();
    setState(() {
      _isReviewAvailable = isAvailable;
    });
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Entwicklung unterstützen'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Deine Unterstützung hilft mir, die App weiter zu verbessern und neue Funktionen zu entwickeln.',
          ),
          const SizedBox(height: 16),
          if (!Platform.isIOS)
            ListTile(
              leading: const Icon(Icons.payment),
              title: const Text('Paypal Spenden'),
              onTap: () => _launchURL(
                'https://www.paypal.com/donate/?hosted_button_id=5YJVWMBN72G3A',
              ),
            ),
          if (!Platform.isIOS)
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('Github Sponsor'),
              onTap: () =>
                  _launchURL('https://github.com/sponsors/JanneckLange'),
            ),
          if (Platform.isIOS)
            ListTile(
              leading: const Icon(Icons.web),
              title: const Text('Neuigkeiten'),
              onTap: () =>
                  _launchURL('https://digital-scouts.github.io/dpsg-nami-app/'),
            ),
          if (_isReviewAvailable)
            ListTile(
              leading: const Icon(Icons.thumb_up),
              title: const Text('App bewerten'),
              onTap: () => inAppReview.requestReview(),
            ),
          ListTile(
            leading: const Icon(Icons.feedback),
            title: const Text('Feedback geben'),
            onTap: () => openWiredash(context, 'Entwickler loben'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Besonderer Dank an',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('DPSG Santa Lucia, Vinzent, Lasse'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Schließen'),
        ),
      ],
    );
  }
}
