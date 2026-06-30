import 'package:flutter/material.dart';
import 'package:laidani_repair/constants/repair_status.dart';
import 'package:laidani_repair/services/print_service.dart';

class TicketHeaderWidget extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final Color accentColor;
  final bool isDesktop;
  final VoidCallback onBack;
  final VoidCallback onDuplicate;
  final VoidCallback onCancel;
  final VoidCallback? onPrintComplete;

  const TicketHeaderWidget({
    super.key,
    required this.ticket,
    required this.accentColor,
    required this.isDesktop,
    required this.onBack,
    required this.onDuplicate,
    required this.onCancel,
    this.onPrintComplete,
  });

  @override
  Widget build(BuildContext context) {
    final qrHash = ticket['qr_code_hash']?.toString() ?? 'TICKET';
    final shortHash = qrHash.length > 8 ? qrHash.substring(0, 8) : qrHash;
    final isCanceled = ticket['status'] == RepairStatus.annule;
    final lastPrinted = _lastPrintedText();

    return Container(
      height: isDesktop ? 72 : 56,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0F1A),
        border: Border(bottom: BorderSide(color: Color(0x1AFFFFFF))),
      ),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onBack),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DOSSIER #${shortHash.toUpperCase()}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: isDesktop ? 16 : 14, letterSpacing: 1), overflow: TextOverflow.ellipsis),
                if (lastPrinted != null)
                  Text(lastPrinted, style: const TextStyle(color: Color(0xFF8A9BB4), fontSize: 9)),
              ],
            ),
          ),
          _buildStatusBadge(ticket['status'] ?? 'En attente'),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Imprimer bon de dépôt',
            child: IconButton(
              icon: Icon(Icons.print, color: accentColor, size: 18),
              onPressed: () => _print(context),
            ),
          ),
          if (!isCanceled)
            _buildOverflowMenu(),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = Color(RepairStatus.statusColor(status));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
      child: Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildOverflowMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white, size: 18),
      color: const Color(0xFF0A0F1A),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'duplicate', child: Text('Dupliquer le ticket', style: TextStyle(color: Color(0xFF00E5FF)))),
        PopupMenuItem(value: 'cancel', child: Text('Annuler le dossier (Retour Stock)', style: TextStyle(color: Colors.redAccent))),
        PopupMenuItem(value: 'id_label', child: Text('Étiquette d\'identification', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12))),
      ],
      onSelected: (val) {
        if (val == 'cancel') onCancel();
        if (val == 'duplicate') onDuplicate();
        if (val == 'id_label') _printIdLabel();
      },
    );
  }

  void _printIdLabel() {
    PrintService.printDeviceIdentificationLabel(ticket: ticket);
  }

  String? _lastPrintedText() {
    final d = ticket['customer_ticket_printed_at'] as String? ?? ticket['device_label_printed_at'] as String?;
    if (d == null) return null;
    final parsed = DateTime.tryParse(d);
    if (parsed == null) return null;
    return 'Dernière impression: ${parsed.day}/${parsed.month}/${parsed.year} ${parsed.hour}:${parsed.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _print(BuildContext context) async {
    await PrintService.printFull(ticket: ticket, parts: const [], context: context);
    onPrintComplete?.call();
  }
}

// Re-export for compatibility
class TicketHeaderWidgetOld {
  static Widget build(BuildContext context, Map<String, dynamic> ticket, Color color) {
    return TicketHeaderWidget(
      ticket: ticket,
      accentColor: color,
      isDesktop: MediaQuery.of(context).size.width >= 850,
      onBack: () => Navigator.of(context).pop(),
      onDuplicate: () {},
      onCancel: () {},
    );
  }
}
