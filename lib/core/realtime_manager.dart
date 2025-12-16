import 'dart:async';
import 'package:flutter/foundation.dart';

class RealtimeManager extends ChangeNotifier {
  final Map<String, StreamController> _streams = {};

  StreamController<T> getStream<T>(String key) {
    if (!_streams.containsKey(key)) {
      _streams[key] = StreamController<T>.broadcast();
    }
    return _streams[key] as StreamController<T>;
  }

  void emit<T>(String key, T data) {
    if (_streams.containsKey(key)) {
      _streams[key]!.add(data);
    }
  }

  @override
  void dispose() {
    for (var stream in _streams.values) {
      stream.close();
    }
    super.dispose();
  }
}
