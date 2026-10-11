#!/usr/bin/env bash
# Runs the committed example integration suite in a disposable macOS app.
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
flutter_bin="${FLUTTER_BIN:-flutter}"
harness_dir="$(mktemp -d "${TMPDIR:-/tmp}/router_observer_integration.XXXXXX")"

cleanup() {
  if [[ "${KEEP_INTEGRATION_HARNESS:-0}" == "1" ]]; then
    printf 'Integration harness retained at %s\n' "$harness_dir"
  else
    # This path is created exclusively by mktemp above.
    rm -rf -- "$harness_dir"
  fi
}
trap cleanup EXIT

"$flutter_bin" create --platforms=macos --project-name=router_observer_integration \
  --no-pub "$harness_dir"

# JSON string quoting is also valid YAML and handles spaces in local paths.
python3 - "$package_root" "$harness_dir" <<'PY'
import json
import pathlib
import sys

package_root = pathlib.Path(sys.argv[1])
harness_dir = pathlib.Path(sys.argv[2])
(harness_dir / 'pubspec.yaml').write_text(f'''name: router_observer_integration
publish_to: none
environment:
  sdk: ">=3.13.5 <4.0.0"
  flutter: ">=3.47.7"
dependencies:
  flutter:
    sdk: flutter
  router_observer:
    path: {json.dumps(str(package_root))}
  router_observer_example:
    path: {json.dumps(str(package_root / 'example'))}
dev_dependencies:
  flutter_lints: ^6.0.0
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
flutter:
  uses-material-design: true
''')
PY

mkdir -p "$harness_dir/integration_test"
cp "$package_root/example/integration_test/navigation_test.dart" \
  "$harness_dir/integration_test/navigation_test.dart"
cp "$package_root/example/analysis_options.yaml" "$harness_dir/analysis_options.yaml"
# flutter create generates a counter-app test unrelated to this suite.
rm -f -- "$harness_dir/test/widget_test.dart"

cd "$harness_dir"
"$flutter_bin" pub get
"$flutter_bin" analyze --fatal-infos
"$flutter_bin" test integration_test/navigation_test.dart -d macos --reporter expanded
