import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laidani_repair/core/providers/supabase_provider.dart';

final promotionsListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  return client.from('promotions').select().order('created_at', ascending: false);
});

final promotionsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.from('promotions').stream(primaryKey: ['id']).order('created_at', ascending: false);
});
