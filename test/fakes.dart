import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// path_provider backed by a temporary directory.
class FakePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  FakePathProvider(this.root);
  final Directory root;

  @override
  Future<String?> getApplicationDocumentsPath() async => (Directory('${root.path}/docs')..createSync(recursive: true)).path;

  @override
  Future<String?> getTemporaryPath() async => (Directory('${root.path}/tmp')..createSync(recursive: true)).path;

  @override
  Future<String?> getApplicationSupportPath() async => (Directory('${root.path}/support')..createSync(recursive: true)).path;
}

/// Records every call on a method channel and answers with [reply].
class ChannelRecorder {
  ChannelRecorder(String name, {Object? Function(MethodCall)? reply}) : channel = MethodChannel(name) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return reply?.call(call);
    });
  }

  final MethodChannel channel;
  final List<MethodCall> calls = [];

  Iterable<MethodCall> named(String method) => calls.where((c) => c.method == method);

  void dispose() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
}

/// Feeds compass headings to flutter_compass.
void mockCompass(List<double>? event) {
  // A null event is what devices without a magnetometer send.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
    const EventChannel('hemanthraj/flutter_compass'),
    MockStreamHandler.inline(onListen: (args, sink) {
      sink.success(event);
    }),
  );
}

/// Swallows calls to plugins the screen under test touches but the test
/// doesn't care about (wakelock, vibration, geolocator…).
void silencePlugins() {
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final name in ['vibration', 'flutter.baseflow.com/geolocator_android', 'flutter.baseflow.com/geolocator', 'dev.fluttercommunity.plus/share', 'home_widget']) {
    m.setMockMethodCallHandler(MethodChannel(name), (call) async => null);
  }
}
