class QueuedOfflineException implements Exception {
  final String message;
  const QueuedOfflineException([this.message = 'İşlem kuyruğa alındı.']);

  @override
  String toString() => message;
}
