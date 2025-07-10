import 'package:flutter/material.dart';
import 'package:nami/utilities/app.state.dart';
import 'package:provider/provider.dart';

class AuthenticateScreen extends StatelessWidget {
  const AuthenticateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.only(bottom: 200),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    context.read<AppStateHandler>().setLoggedOutState();
                  },
                  label: const Text("Abmelden"),
                  icon: const Icon(Icons.logout),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () async {
                    await context.read<AppStateHandler>().setAuthenticatedState(
                      true,
                    );
                  },
                  label: const Text("Mit Biometrie erneut versuchen"),
                  icon: const Icon(Icons.fingerprint),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
