import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nami/domain/settings/address_settings_repository.dart';
import 'package:nami/presentation/widgets/skeletton_map.dart';

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

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    widget.repository.loadAddress().then((value) {
      if (value != null) _controller.text = value;
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
          "Die Adresse wird verwendet, um den Stamm auf der Karte zu verorten und die Entfernung von Mitgliedern zum Heim anzuzeigen.",
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
            _controller.text = selection;
            // TODO: Trigger map region download
            widget.onDownloadRegion?.call();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Adresse gespeichert')),
            );
          },
          fieldViewBuilder: (context, textController, focusNode, onSubmitted) {
            textController.text = _controller.text;
            return TextFormField(
              controller: textController,
              focusNode: focusNode,
              decoration: const InputDecoration(labelText: 'Heim-Adresse'),
            );
          },
        ),
        const SizedBox(height: 12),
        const MapSkeleton(),
      ],
    );
  }
}
