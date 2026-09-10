import 'dart:async';

class RefreshService {
  RefreshService._();

  static final StreamController<void> _controller =
      StreamController<void>.broadcast();

  static Stream<void> get stream => _controller.stream;

  static void notify() {
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }

  static void dispose() {
    _controller.close();
  }
}