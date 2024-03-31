import 'package:flutter/material.dart';
import 'package:nami/utilities/app.state.dart';
import 'package:nami/utilities/nami/nami_rechte.dart';
import 'package:provider/provider.dart';

class LoadingInfoScreen extends StatefulWidget {
  final ValueNotifier<List<AllowedFeatures>> rechteProgressNotifier;
  final ValueNotifier<String?> gruppierungProgressNotifier;
  final ValueNotifier<bool?> metaProgressNotifier;
  final ValueNotifier<bool?> memberOverviewProgressNotifier;
  final ValueNotifier<double> memberAllProgressNotifier;
  final bool loadAll;

  const LoadingInfoScreen({
    super.key,
    required this.rechteProgressNotifier,
    required this.gruppierungProgressNotifier,
    required this.metaProgressNotifier,
    required this.memberOverviewProgressNotifier,
    required this.memberAllProgressNotifier,
    this.loadAll = false,
  });

  @override
  LoadingInfoScreenState createState() => LoadingInfoScreenState();
}

class LoadingInfoScreenState extends State<LoadingInfoScreen> {
  @override
  void initState() {
    super.initState();
    widget.rechteProgressNotifier.addListener(_updateProgress);
    widget.gruppierungProgressNotifier.addListener(_updateProgress);
    widget.metaProgressNotifier.addListener(_updateProgress);
    widget.memberOverviewProgressNotifier.addListener(_updateProgress);
    widget.memberAllProgressNotifier.addListener(_updateProgress);
  }

  @override
  void dispose() {
    widget.rechteProgressNotifier.removeListener(_updateProgress);
    widget.gruppierungProgressNotifier.removeListener(_updateProgress);
    widget.metaProgressNotifier.removeListener(_updateProgress);
    widget.memberOverviewProgressNotifier.removeListener(_updateProgress);
    widget.memberAllProgressNotifier.removeListener(_updateProgress);
    super.dispose();
  }

  void _updateProgress() {
    setState(() {
      // This will trigger a rebuild of the widget with the new progress value.
    });
  }

  bool get _isDone =>
      widget.rechteProgressNotifier.value.isNotEmpty &&
      widget.memberOverviewProgressNotifier.value == true &&
      (widget.loadAll
          ? widget.gruppierungProgressNotifier.value != null &&
              widget.memberAllProgressNotifier.value == 1 &&
              widget.metaProgressNotifier.value == true
          : widget.memberAllProgressNotifier.value == 1);

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        child: Scaffold(
          drawerEnableOpenDragGesture: false,
          body: ListView(
            children: [
              _buildLoadingStatusRow(
                  'Rechte', widget.rechteProgressNotifier.value),
              if (widget.loadAll)
                _buildLoadingStatusRow(
                    'Gruppierung', widget.gruppierungProgressNotifier.value),
              if (widget.loadAll)
                _buildLoadingStatusRow(
                    'Meta', widget.metaProgressNotifier.value),
              _buildLoadingStatusRow('Member Overview',
                  widget.memberOverviewProgressNotifier.value),
              if (widget.loadAll)
                _buildLoadingStatusRow(
                    'Member All', widget.memberAllProgressNotifier.value),
              if (_isDone)
                ElevatedButton(
                  onPressed: () {
                    AppStateHandler().setReadyState();
                    Navigator.pop(context);
                  },
                  child: const Text('Success'),
                ),
              if (context.watch<AppStateHandler>().syncState == SyncState.error)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);

                    AppStateHandler().setLoggedOutState();
                  },
                  child: const Text('Fehler. Du wirst ausgeloggt.'),
                )
              else if (context.watch<AppStateHandler>().syncState ==
                  SyncState.offline)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                      'Keine Netzwerkverbindung. Versuch es später erneut'),
                )
            ],
          ),
        ));
  }

  Widget _buildLoadingStatusRow(String label, dynamic value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        if (value is bool?) ...[
          if (value == true) // bool is true
            const Icon(Icons.check, color: Colors.green)
          else if (value == false) // bool is false
            const Icon(Icons.error, color: Colors.red)
          else // bool is null
            const CircularProgressIndicator(),
        ] else if (value is double) ...[
          if (value != 1)
            CircularProgressIndicator(value: value), // double is not 1
          Text('${(value * 100).toStringAsFixed(0)}%'),
        ] else if (value is String) ...[
          Text(value),
        ] else if (value is List<AllowedFeatures>)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: value.map((e) => Text(e.toReadableString())).toList(),
          )
        else if (value == null)
          const CircularProgressIndicator()
        else ...[
          const Icon(Icons.error, color: Colors.red),
        ],
      ],
    );
  }
}
