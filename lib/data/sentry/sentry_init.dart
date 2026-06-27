import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

export 'package:sentry_flutter/sentry_flutter.dart' show SentryWidget;

/// Whether the Sentry SDK is available for use.
@pragma('vm:platform-const-if', !kDebugMode)
bool get isSentryAvailable => false;

/// Whether Sentry was initialized when the app started.
bool get isSentryEnabled => false;

FutureOr<void> initSentry(FutureOr<void> Function() appRunner) async {
  SentryWidgetsFlutterBinding.ensureInitialized();
  return appRunner();
}

@visibleForTesting
void populateSentryOptions(SentryFlutterOptions options) {}

/// Tests typically don't use [initSentry] so this just sets the flag
/// so we don't get late initialization errors.
@visibleForTesting
void disableSentryForTesting() {}
