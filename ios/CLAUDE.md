# iOS-App (ios/)

Gilt zusaetzlich zu den Root-Regeln in [../CLAUDE.md](../CLAUDE.md).

## Swift-Formatierung

- Wenn Swift-Code geaendert wurde (z. B. unter ios/ oder ios/NamiAiKit), pruefe das Format vor Abschluss der Aufgabe: `swift format lint --strict --recursive <geaenderter Pfad>`.
- Behebe Verstoesse mit `swift format format --in-place --recursive <geaenderter Pfad>`.
- Das entspricht dem CI-Check in .github/workflows/validate-pull-requests.yml (Job "Validate iOS Swift"), der `swift format --recursive --in-place ios` gefolgt von `git diff --exit-code` ausfuehrt.

## Env und Xcode Cloud

- Wenn Env-Keys geaendert werden, halte .env.example, lokale .env, ios/ci_scripts/ci_pre_xcodebuild.sh und die Xcode-Cloud-Variablen synchron (siehe README.md).
