import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laidani_repair/core/services/offline_service.dart';
import 'package:laidani_repair/core/services/offline_cache.dart';

final offlineServiceProvider = Provider<OfflineService>((ref) {
  final service = OfflineService();
  ref.onDispose(() => service.stopMonitoring());
  service.startMonitoring();
  return service;
});

final connectivityProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(offlineServiceProvider);
  return service.connectivityStream;
});

final isOnlineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.valueOrNull ?? true;
});

final offlineCacheProvider = Provider<OfflineCache>((ref) {
  return OfflineCache();
});

final pendingSyncCountProvider = FutureProvider<int>((ref) async {
  final cache = ref.watch(offlineCacheProvider);
  final items = await cache.getAll();
  return items.where((item) => item['synced'] != true).length;
});

final syncProvider = FutureProvider.family<void, String>((ref, key) async {
  final cache = ref.watch(offlineCacheProvider);
  final data = await cache.get(key);
  if (data == null) return;
  data['synced'] = true;
  await cache.set(key, data);
});
