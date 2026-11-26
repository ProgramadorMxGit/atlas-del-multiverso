import 'package:flutter/services.dart';

Stream<bool> androidConnectivity() => const EventChannel(
  'dev.cartografia.atlas/network',
).receiveBroadcastStream().cast<bool>();
