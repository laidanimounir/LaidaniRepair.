import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:laidani_repair/core/constants/app_constants.dart';

class GroqService {
  static final GroqService _instance = GroqService._();
  factory GroqService() => _instance;
  GroqService._();

  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama3-70b-8192';

  Future<Map<String, dynamic>> _callGroq(List<Map<String, String>> messages) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AppConstants.groqApiKey}',
      },
      body: jsonEncode({
        'model': _model,
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 1024,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'] as String;
      final jsonStart = content.indexOf('{');
      final jsonEnd = content.lastIndexOf('}') + 1;
      if (jsonStart >= 0 && jsonEnd > jsonStart) {
        return jsonDecode(content.substring(jsonStart, jsonEnd)) as Map<String, dynamic>;
      }
      return {'raw': content};
    }
    throw Exception('Groq API error: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> diagnoseProblem({
    required String deviceType,
    required String brand,
    required String description,
  }) async {
    final messages = [
      {
        'role': 'system',
        'content': 'Tu es un expert en réparation d\'appareils électroniques. Réponds UNIQUEMENT avec un objet JSON valide contenant: probableCause (string), recommendedSteps (array of strings), difficulty (string: Facile/Moyen/Difficile), suggestedParts (array of strings).'
      },
      {
        'role': 'user',
        'content': 'Diagnostic pour un $brand ($deviceType). Problème: $description. Donne un diagnostic détaillé en JSON.'
      },
    ];

    final result = await _callGroq(messages);
    return {
      'probableCause': result['probableCause'] ?? 'Analyse non disponible',
      'recommendedSteps': result['recommendedSteps'] is List ? result['recommendedSteps'] : ['Étape 1: Inspection visuelle', 'Étape 2: Diagnostic approfondi'],
      'difficulty': result['difficulty'] ?? 'Moyen',
      'suggestedParts': result['suggestedParts'] is List ? result['suggestedParts'] : [],
    };
  }

  Future<Map<String, dynamic>> estimatePrice({
    required String deviceType,
    required String brand,
    required String problemDescription,
    List<Map<String, dynamic>>? similarRepairs,
  }) async {
    final similarInfo = similarRepairs != null && similarRepairs.isNotEmpty
        ? 'Réparations similaires: ${jsonEncode(similarRepairs)}'
        : '';
    final messages = [
      {
        'role': 'system',
        'content': 'Tu es un expert en estimation de prix de réparation. Réponds UNIQUEMENT avec un objet JSON valide contenant: minPrice (number en DA), maxPrice (number en DA), estimatedTime (string), confidence (string: Haute/Moyenne/Basse).'
      },
      {
        'role': 'user',
        'content': 'Estime le prix pour: $brand $deviceType. Problème: $problemDescription. $similarInfo'
      },
    ];

    final result = await _callGroq(messages);
    return {
      'minPrice': (result['minPrice'] as num?)?.toDouble() ?? 0,
      'maxPrice': (result['maxPrice'] as num?)?.toDouble() ?? 0,
      'estimatedTime': result['estimatedTime'] ?? 'Non spécifié',
      'confidence': result['confidence'] ?? 'Moyenne',
    };
  }

  Future<List<Map<String, dynamic>>> suggestParts({
    required String deviceType,
    required String brand,
    required String problemDescription,
    String? diagnosticNotes,
  }) async {
    final messages = [
      {
        'role': 'system',
        'content': 'Tu es un expert en pièces détachées. Réponds UNIQUEMENT avec un tableau JSON valide contenant des objets avec: partName (string), quantity (number).'
      },
      {
        'role': 'user',
        'content': 'Quelles pièces sont nécessaires pour réparer un $brand $deviceType avec ce problème: $problemDescription. Notes de diagnostic: ${diagnosticNotes ?? "Non fournies"}'
      },
    ];

    final result = await _callGroq(messages);
    if (result['raw'] != null) {
      final raw = result['raw'] as String;
      final arrStart = raw.indexOf('[');
      final arrEnd = raw.lastIndexOf(']') + 1;
      if (arrStart >= 0 && arrEnd > arrStart) {
        final list = jsonDecode(raw.substring(arrStart, arrEnd)) as List;
        return list.map((e) => {
          'partName': e['partName']?.toString() ?? '',
          'quantity': (e['quantity'] as num?)?.toInt() ?? 1,
        }).toList();
      }
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> suggestReorder(List<Map<String, dynamic>> products) async {
    final productList = products.map((p) => {
      'name': p['product_name'],
      'stock': p['stock_quantity'] ?? 0,
      'minStock': p['min_stock'] ?? 5,
    }).toList();

    final messages = [
      {
        'role': 'system',
        'content': 'Tu es un expert en gestion de stock. Réponds UNIQUEMENT avec un tableau JSON contenant des objets avec: productName (string), suggestedQuantity (number), urgency (string: Haute/Moyenne/Basse).'
      },
      {
        'role': 'user',
        'content': 'Analyse ce stock et suggère des réapprovisionnements: ${jsonEncode(productList)}'
      },
    ];

    final result = await _callGroq(messages);
    if (result['raw'] != null) {
      final raw = result['raw'] as String;
      final arrStart = raw.indexOf('[');
      final arrEnd = raw.lastIndexOf(']') + 1;
      if (arrStart >= 0 && arrEnd > arrStart) {
        final list = jsonDecode(raw.substring(arrStart, arrEnd)) as List;
        return list.map((e) => {
          'productName': e['productName']?.toString() ?? '',
          'suggestedQuantity': (e['suggestedQuantity'] as num?)?.toInt() ?? 0,
          'urgency': e['urgency']?.toString() ?? 'Moyenne',
        }).toList();
      }
    }
    return [];
  }

  Future<Map<String, dynamic>> analyzeCustomer({
    required List<Map<String, dynamic>> purchaseHistory,
    required List<Map<String, dynamic>> repairHistory,
    required String paymentBehavior,
    required int loyaltyPoints,
  }) async {
    final messages = [
      {
        'role': 'system',
        'content': 'Tu es un expert en analyse de fidélité client. Réponds UNIQUEMENT avec un objet JSON valide contenant: valueScore (number 0-100), churnRisk (string: Faible/Moyen/Élevé), personalizedOffer (string), bestContactTime (string).'
      },
      {
        'role': 'user',
        'content': 'Analyse ce client: Achats: ${jsonEncode(purchaseHistory)}, Réparations: ${jsonEncode(repairHistory)}, Paiements: $paymentBehavior, Points: $loyaltyPoints'
      },
    ];

    final result = await _callGroq(messages);
    return {
      'valueScore': (result['valueScore'] as num?)?.toDouble() ?? 0,
      'churnRisk': result['churnRisk'] ?? 'Moyen',
      'personalizedOffer': result['personalizedOffer'] ?? 'Offre standard',
      'bestContactTime': result['bestContactTime'] ?? 'En journée',
    };
  }
}
