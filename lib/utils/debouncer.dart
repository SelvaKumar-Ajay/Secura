import 'dart:async';
import 'package:flutter/material.dart';

/// [Debouncer] is a concept where we add a little delay on frequent used calls to avoid reduntant calls
/// This Ensure's user experience
/// [milliSecs] is require to perform the action after delay.
/// [_timer] used to create callback on completion of defined [milliSecs].
/// [action] todo action once timer completed the Duration time.
class Debouncer {
  final int milliSecs;
  VoidCallback? action;
  Timer? _timer;

  Debouncer({required this.milliSecs});

  run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliSecs), action);
  }

  dipose() {
    _timer?.cancel();
  }
}
