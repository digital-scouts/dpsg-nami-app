import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nami/domain/member/member_address_utils.dart';
import 'package:nami/domain/settings/address_settings_repository.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/widgets/address_map_preview.dart';

class StammAddressSettings extends StatefulWidget {
  final AddressSettingsRepository repository;
  final Future<List<String>> Function(String query) autocompleteProvider;
  final VoidCallback? onDownloadRegion; // TODO: Implement map region download

  const StammAddressSettings({
    super.key,
    required this.repository,
    required this.autocompleteProvider,
    this.onDownloadRegion,
  });

  @override
  State<StammAddressSettings> createState() => _StammAddressSettingsState();
}

class _StammAddressSettingsState extends State<StammAddressSettings> {
  late final TextEditingController _controller;
  Timer? _debounce;
  String _lastQuery = '';
  List<String> _results = [];
  String? _savedAddress;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    widget.repository.loadAddress().then((value) {
      if (!mounted) {
        return;
      }
      setState(() {
        _savedAddress = value;
        if (value != null) {
          _controller.text = value;
        }
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppLocalizations.of(context).t('address_help'),
          style: theme.textTheme.bodyMedium,
        ),
        Autocomplete<String>(
          optionsBuilder: (TextEditingValue value) async {
            final query = value.text;
            if (query.length < 5) {
              _results = [];
              return const Iterable<String>.empty();
            }

            if (_lastQuery == query) {
              return _results;
            }
            _lastQuery = query;

            _debounce?.cancel();
            final completer = Completer<Iterable<String>>();
            _debounce = Timer(const Duration(milliseconds: 400), () async {
              _results = await widget.autocompleteProvider(query);
              completer.complete(_results);
            });
            return completer.future;
          },
          onSelected: (selection) async {
            await widget.repository.saveAddress(selection);
            setState(() {
              _savedAddress = selection;
              _controller.text = selection;
            });
            // TODO: Trigger map region download
            widget.onDownloadRegion?.call();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context).t('address_saved')),
              ),
            );
          },
          fieldViewBuilder: (context, textController, focusNode, onSubmitted) {
            textController.text = _controller.text;
            return TextFormField(
              controller: textController,
              focusNode: focusNode,
              style: Theme.of(context).textTheme.bodySmall,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).t('address_label'),
                labelStyle: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        if ((_savedAddress ?? '').trim().isNotEmpty)
          AddressMapPreview(
            addressText: (_savedAddress ?? '').trim(),
            cacheKey: 'stamm:0',
            addressFingerprint: MemberAddressUtils.fingerprintFromText(
              (_savedAddress ?? '').trim(),
            ),
            wifiOnlyRefresh: true,
          ),
      ],
    );
  }
}
