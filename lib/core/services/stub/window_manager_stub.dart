// Web stub for window_manager
class WindowOptions {
  final dynamic size;
  final dynamic minimumSize;
  final bool center;
  final String title;
  const WindowOptions({this.size, this.minimumSize, this.center = false, this.title = ''});
}

final windowManager = _WindowManagerStub();

class _WindowManagerStub {
  Future<void> ensureInitialized() async {}
  Future<void> waitUntilReadyToShow(WindowOptions _, Future<void> Function() callback) async {
    await callback();
  }
  Future<void> show() async {}
  Future<void> focus() async {}
}
