import 'package:flutter/material.dart';
import 'package:nami/utilities/helper_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wiredash/wiredash.dart';

const nami3WishLabel = Label(id: 'label-myqcoisom3', title: 'NaMi 3.0 Wunsch');

/// Dauerhafter Hinweis am unteren Bildschirmrand, dass NaMi 3.0 und eine neue
/// App in Arbeit sind und diese App nicht mehr weiterentwickelt wird.
class Nami3InfoBanner extends StatelessWidget {
  const Nami3InfoBanner({super.key});

  static final Uri infoUrl = Uri.parse('https://ncm.dpsg.de');

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: colorScheme.onTertiaryContainer);

    return Material(
      color: colorScheme.tertiaryContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          child: Row(
            children: [
              Icon(
                Icons.campaign_outlined,
                size: 20,
                color: colorScheme.onTertiaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => launchUrl(infoUrl),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text:
                              'NaMi 3.0 und eine neue App sind in Arbeit, diese App wird nicht mehr weiterentwickelt. Infos: ',
                        ),
                        TextSpan(
                          text: 'ncm.dpsg.de',
                          style: const TextStyle(
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    style: textStyle,
                  ),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onTertiaryContainer,
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => openWiredash(
                  context,
                  'Wunsch neue App',
                  options: const WiredashFeedbackOptions(
                    labels: [nami3WishLabel],
                  ),
                ),
                child: const Text(
                  'Wünsche\näußern',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
