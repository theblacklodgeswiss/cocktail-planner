/// Shares one in-flight run of [task] across concurrent callers. The slot is
/// cleared when the run finishes, so later calls start a new run.
class SharedFuture<T> {
  Future<T>? _inFlight;

  Future<T> run(Future<T> Function() task) {
    final running = _inFlight;
    if (running != null) return running;
    final future = task().whenComplete(() => _inFlight = null);
    _inFlight = future;
    return future;
  }
}
