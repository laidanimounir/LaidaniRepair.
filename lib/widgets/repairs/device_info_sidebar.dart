import 'package:flutter/material.dart';

class DeviceInfoSidebar extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final Color accentColor;
  final List<Map<String, dynamic>> photos;
  final List<Map<String, dynamic>> notifications;
  final List<Map<String, dynamic>> profiles;
  final String? currentTechnicianId;
  final bool isCanceled;
  final VoidCallback onUploadPhoto;
  final void Function(String path, String? caption) onViewPhoto;
  final void Function(Map<String, dynamic> photo) onDeletePhoto;
  final VoidCallback onAddNotification;
  final VoidCallback onSendWhatsApp;
  final void Function(List<Map<String, dynamic>> profiles, String? currentId) onAssignTechnician;

  const DeviceInfoSidebar({
    super.key,
    required this.ticket,
    required this.accentColor,
    required this.photos,
    required this.notifications,
    required this.profiles,
    required this.currentTechnicianId,
    required this.isCanceled,
    required this.onUploadPhoto,
    required this.onViewPhoto,
    required this.onDeletePhoto,
    required this.onAddNotification,
    required this.onSendWhatsApp,
    required this.onAssignTechnician,
  });

  static const Color _panelDark = Color(0xFF0A0F1A);
  static const Color _glassBorder = Color(0x1AFFFFFF);
  static const Color _textMuted = Color(0xFF8A9BB4);
  static const Color _bgCarbon = Color(0xFF050914);
  static const Color _neonCyan = Color(0xFF00E5FF);
  static const Color _neonEmerald = Color(0xFF10B981);

  @override
  Widget build(BuildContext context) {
    final isAnon = ticket['customer_id'] == null;
    final clientName = isAnon ? (ticket['client_name_temp'] ?? 'Anonyme') : (ticket['customers']?['full_name'] ?? 'Client');
    final clientPhone = isAnon ? (ticket['client_phone_temp'] ?? 'N/A') : (ticket['customers']?['phone_number'] ?? 'N/A');
    final currentName = profiles.where((p) => p['id'] == currentTechnicianId).map((p) => p['full_name'] as String).firstOrNull ?? 'Non affecté';

    return Container(
      width: 350,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(border: Border(right: BorderSide(color: _glassBorder))),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section('INFORMATIONS APPAREIL', Icons.smartphone),
            _infoTile('Modèle', ticket['device_name'] ?? 'N/A', Icons.phone_android),
            _infoTile('IMEI / SN', ticket['imei'] ?? 'N/A', Icons.qr_code_scanner),
            _infoTile('Code / Schéma', ticket['device_password'] ?? 'Aucun', Icons.lock_open),
            _infoTile('N° de série', ticket['serial_number'] ?? 'N/A', Icons.numbers),
            const SizedBox(height: 24),
            _section('DÉTAILS TECHNIQUES', Icons.tune),
            _infoTile('Verrouillage', (ticket['device_lock_type'] as String? ?? 'Aucun').toString(), Icons.lock),
            _infoTile('Code verrou', ticket['device_lock_code'] ?? 'N/A', Icons.vpn_key),
            const SizedBox(height: 24),
            _section('DIAGNOSTIC INITIAL', Icons.visibility),
            Text(ticket['pre_diagnostic'] ?? 'Aucun constat.', style: const TextStyle(color: _textMuted, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),
            _section('PHOTOS', Icons.camera_alt),
            _buildPhotosRow(),
            const SizedBox(height: 24),
            _section('NOTIFICATIONS CLIENT', Icons.notifications),
            _buildNotificationsSection(),
            const SizedBox(height: 24),
            _section('CLIENT', Icons.person),
            Text(clientName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(clientPhone, style: const TextStyle(color: _textMuted, fontSize: 13)),
            const SizedBox(height: 24),
            _section('TECHNICIEN AFFECTÉ', Icons.build),
            _buildTechnicianRow(currentName),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Icon(icon, color: accentColor, size: 18),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
      ]),
    );
  }

  Widget _infoTile(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, color: _textMuted, size: 16),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: _textMuted, fontSize: 10)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }

  Widget _buildPhotosRow() {
    return SizedBox(
      height: 80,
      child: Row(children: [
        Expanded(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length + 1,
            itemBuilder: (ctx, i) {
              if (i == 0) {
                return GestureDetector(
                  onTap: onUploadPhoto,
                  child: Container(
                    width: 70, height: 70, margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(color: _bgCarbon, borderRadius: BorderRadius.circular(8), border: Border.all(color: _glassBorder)),
                    child: const Icon(Icons.add_a_photo, color: _textMuted, size: 24),
                  ),
                );
              }
              final photo = photos[i - 1];
              final path = photo['storage_path'] as String? ?? '';
              final thumbUrl = (photo['signed_url'] as String?) ?? '';
              return GestureDetector(
                onTap: () => onViewPhoto(path, photo['caption'] as String?),
                onLongPress: () => onDeletePhoto(photo),
                child: Container(
                  width: 70, height: 70, margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _glassBorder),
                    image: thumbUrl.isNotEmpty ? DecorationImage(image: NetworkImage(thumbUrl), fit: BoxFit.cover) : null,
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _buildNotificationsSection() {
    return SizedBox(
      height: notifications.isEmpty ? 80 : 120,
      child: notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: onAddNotification,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: _neonCyan.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: _neonCyan.withOpacity(0.3))),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_alert, color: _neonCyan, size: 16), SizedBox(width: 8), Text('Nouvelle notification', style: TextStyle(color: _neonCyan, fontSize: 12))]),
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: onSendWhatsApp,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFF25D366).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.chat, color: Color(0xFF25D366), size: 12), SizedBox(width: 4), Text('Envoyer WA', style: TextStyle(color: Color(0xFF25D366), fontSize: 10))]),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: notifications.length,
                    itemBuilder: (ctx, i) {
                      final n = notifications[i];
                      final method = n['notification_method'] ?? '';
                      final status = n['notification_status'] ?? '';
                      final date = DateTime.tryParse(n['sent_at'] ?? '')?.toString().substring(0, 16) ?? '';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(children: [
                          Icon(_notifIcon(method), color: _textMuted, size: 14),
                          const SizedBox(width: 6),
                          Expanded(child: Text('$date $status', style: const TextStyle(color: _textMuted, fontSize: 11))),
                        ]),
                      );
                    },
                  ),
                ),
                GestureDetector(
                  onTap: onAddNotification,
                  child: const Row(children: [Icon(Icons.add, color: _neonCyan, size: 14), SizedBox(width: 4), Text('Ajouter', style: TextStyle(color: _neonCyan, fontSize: 11))]),
                ),
              ],
            ),
    );
  }

  Widget _buildTechnicianRow(String currentName) {
    return InkWell(
      onTap: isCanceled ? null : () => onAssignTechnician(profiles, currentTechnicianId),
      borderRadius: BorderRadius.circular(8),
      child: Row(children: [
        Icon(Icons.person_pin, color: currentTechnicianId != null ? _neonEmerald : _textMuted, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(currentName, style: TextStyle(color: currentTechnicianId != null ? Colors.white : _textMuted, fontSize: 13))),
        if (!isCanceled) const Icon(Icons.edit, size: 12, color: _textMuted),
      ]),
    );
  }

  static IconData _notifIcon(String method) {
    switch (method) {
      case 'WhatsApp': return Icons.chat;
      case 'Appel': return Icons.phone;
      case 'SMS': return Icons.message;
      default: return Icons.notifications;
    }
  }
}
