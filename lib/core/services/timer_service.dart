import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Timer state
class TimerState {
  final int totalSeconds;
  final int remainingSeconds;
  final bool isRunning;
  final bool hasExpired;

  const TimerState({
    required this.totalSeconds,
    required this.remainingSeconds,
    this.isRunning = false,
    this.hasExpired = false,
  });

  TimerState copyWith({
    int? totalSeconds,
    int? remainingSeconds,
    bool? isRunning,
    bool? hasExpired,
  }) =>
      TimerState(
        totalSeconds: totalSeconds ?? this.totalSeconds,
        remainingSeconds: remainingSeconds ?? this.remainingSeconds,
        isRunning: isRunning ?? this.isRunning,
        hasExpired: hasExpired ?? this.hasExpired,
      );

  double get progress =>
      totalSeconds == 0 ? 0 : 1 - (remainingSeconds / totalSeconds);

  String get formattedTime {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Timer service using Riverpod StateNotifier
class TimerNotifier extends StateNotifier<TimerState> {
  Timer? _ticker;
  VoidCallback? _onExpired;

  TimerNotifier()
      : super(const TimerState(
          totalSeconds: 0,
          remainingSeconds: 0,
        ));

  /// [durationSeconds] — 倒數秒數（不再乘以 60）
  void setup(int durationSeconds, {VoidCallback? onExpired}) {
    _ticker?.cancel();
    _ticker = null;
    _onExpired = onExpired;
    state = TimerState(
      totalSeconds: durationSeconds,
      remainingSeconds: durationSeconds,
    );
  }

  void start() {
    if (state.isRunning || state.hasExpired) return;
    state = state.copyWith(isRunning: true);
    _ticker = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  void pause() {
    _ticker?.cancel();
    state = state.copyWith(isRunning: false);
  }

  void resume() {
    if (state.hasExpired) return;
    state = state.copyWith(isRunning: true);
    _ticker = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  void reset(int durationSeconds) {
    _ticker?.cancel();
    state = TimerState(
      totalSeconds: durationSeconds,
      remainingSeconds: durationSeconds,
    );
  }

  void _tick(Timer timer) {
    if (state.remainingSeconds <= 1) {
      timer.cancel();
      state = state.copyWith(
        remainingSeconds: 0,
        isRunning: false,
        hasExpired: true,
      );
      _onExpired?.call();
    } else {
      state = state.copyWith(
        remainingSeconds: state.remainingSeconds - 1,
      );
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

typedef VoidCallback = void Function();

final timerProvider = StateNotifierProvider<TimerNotifier, TimerState>(
  (ref) => TimerNotifier(),
);
