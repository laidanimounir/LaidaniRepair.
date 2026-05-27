import 'dart:async';
import 'dart:io';

class OfflineService {
  static final OfflineService _instance = OfflineService._();
  factory OfflineService() => _instance;
  OfflineService._();

  final _streamController = StreamController<bool>.broadcast();
  bool _isOnline = true;
  Timer? _timer;

  Stream<bool> get connectivityStream => _streamController.stream;
  bool get isOnline => _isOnline;

  void startMonitoring() {
    _checkConnectivity();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _checkConnectivity());
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      final online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (online != _isOnline) {
        _isOnline = online;
        _streamController.add(_isOnline);
      }
    } on SocketException {
      if (_isOnline) {
        _isOnline = false;
        _streamController.add(false);
      }
    }
  }

  void stopMonitoring() {
    _timer?.cancel();
  }

  void dispose() {
    _timer?.cancel();
    _streamController.close();
  }
}
