import 'package:flutter/material.dart';
import 'package:laidani_repair/constants/repair_status.dart';

class RepairPartsWidget extends StatelessWidget {
  final List<Map<String, dynamic>> parts;
  final Color accentColor;
  final bool isCanceled;
  final bool isOwner;
  final VoidCallback onAddPart;
  final void Function(Map<String, dynamic>) onEditPart;
  final void Function(Map<String, dynamic>) onChangeStatus;
  final void Function(Map<String, dynamic>) onRemovePart;
  final VoidCallback onSuggestAI;

  const RepairPartsWidget({
    super.key,
    required this.parts,
    required this.accentColor,
    required this.isCanceled,
    required this.isOwner,
    required this.onAddPart,
    required this.onEditPart,
    required this.onChangeStatus,
    required this.onRemovePart,
    required this.onSuggestAI,
  });

  static const Color _panelDark = Color(0xFF0A0F1A);
  static const Color _glassBorder = Color(0x1AFFFFFF);
  static const Color _textMuted = Color(0xFF8A9BB4);
  static const Color _bgCarbon = Color(0xFF050914);
  static const Color _neonCyan = Color(0xFF00E5FF);

  double get _totalCost => parts.where((p) => p['part_status'] != 'Retourné').fold(0.0, (sum, p) {
        final price = (p['charged_price'] as num?)?.toDouble() ?? 0;
        final qty = (p['quantity'] as num?)?.toInt() ?? 1;
        return sum + (price * qty);
      });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: _glassBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('PIÈCES CONSOMMÉES (${_totalCost.toStringAsFixed(0)} DA)', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  if (isOwner && !isCanceled)
                    TextButton.icon(onPressed: onSuggestAI, icon: const Icon(Icons.psychology, size: 14, color: Color(0xFF9C27B0)), label: const Text('IA', style: TextStyle(color: Color(0xFF9C27B0), fontSize: 11))),
                  if (!isCanceled)
                    IconButton(icon: Icon(Icons.add_circle, color: accentColor, size: 20), onPressed: onAddPart, tooltip: 'Ajouter une pièce'),
                ]),
              ],
            ),
          ),
          if (parts.isEmpty)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucune pièce consommée', style: TextStyle(color: _textMuted)))),
          ...parts.map((part) => _buildPartRow(part)),
        ],
      ),
    );
  }

  Widget _buildPartRow(Map<String, dynamic> part) {
    final partStatus = part['part_status'] as String? ?? RepairStatus.partUtilise;
    final qty = (part['quantity'] as num?)?.toInt() ?? 1;
    final price = (part['charged_price'] as num?)?.toDouble() ?? 0;
    final total = price * qty;
    final productName = part['products']?['product_name'] ?? 'Inconnu';
    final isRemoved = partStatus == RepairStatus.partRetourne || partStatus == RepairStatus.partDefectueux;
    final statusColor = Color(RepairStatus.partStatusColor(partStatus));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: isRemoved ? Colors.redAccent.withOpacity(0.05) : _bgCarbon, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: statusColor.withOpacity(0.3))),
          child: Text(partStatus, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(productName, style: TextStyle(color: isRemoved ? _textMuted : Colors.white, fontSize: 13, fontWeight: FontWeight.w600, decoration: isRemoved ? TextDecoration.lineThrough : null)),
            const SizedBox(height: 2),
            Text('$qty × ${price.toStringAsFixed(0)} DA = ${total.toStringAsFixed(0)} DA', style: const TextStyle(color: _textMuted, fontSize: 11)),
          ]),
        ),
        if (!isCanceled && !isRemoved) ...[
          IconButton(icon: const Icon(Icons.edit_outlined, color: _textMuted, size: 18), tooltip: 'Modifier', onPressed: () => onEditPart(part)),
          IconButton(icon: const Icon(Icons.swap_horiz, color: _textMuted, size: 18), tooltip: 'État', onPressed: () => onChangeStatus(part)),
          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18), tooltip: 'Supprimer', onPressed: () => onRemovePart(part)),
        ],
      ]),
    );
  }
}
