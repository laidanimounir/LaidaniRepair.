import 'package:supabase_flutter/supabase_flutter.dart';

class TicketEventLogger {
  TicketEventLogger._();

  static Future<void> log({
    required String ticketId,
    required String eventType,
    String? oldValue,
    String? newValue,
    String? notes,
  }) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    final insertData = <String, dynamic>{
      'ticket_id': ticketId,
      'event_type': eventType,
      'old_value': oldValue ?? '',
      'new_value': newValue ?? '',
      'created_by': user?.id,
    };
    if (notes != null && notes.isNotEmpty) {
      insertData['notes'] = notes;
    }
    await client.from('repair_ticket_events').insert(insertData);
  }
}
