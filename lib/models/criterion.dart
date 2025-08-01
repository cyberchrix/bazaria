import 'dart:convert';
import 'package:logger/logger.dart';

final logger = Logger();

enum CriterionType {
  string,
  range,
  select,
  boolean,
  number,
}

class Criterion {
  final String id;
  final String label;
  final CriterionType type;
  final List<String>? options;
  final String? dependsOn; // ID du critère dont dépend celui-ci
  final Map<String, List<String>>? conditionalOptions; // Options conditionnelles
  final bool required;
  final String? unit; // Unité (kg, cm, etc.)
  final double? minValue;
  final double? maxValue;
  final String? placeholder;

  Criterion({
    required this.id,
    required this.label,
    required this.type,
    this.options,
    this.dependsOn,
    this.conditionalOptions,
    this.required = false,
    this.unit,
    this.minValue,
    this.maxValue,
    this.placeholder,
  });

  factory Criterion.fromJson(Map<String, dynamic> json) {
    logger.d('🔍 Parsing Criterion: ${json['label']}');
    
    // Gestion des options (peut être un array ou une string JSON)
    List<String>? options;
    if (json['options'] != null) {
      logger.d('📋 Options type: ${json['options'].runtimeType}');
      logger.d('📋 Options value: ${json['options']}');
      
      if (json['options'] is List) {
        // Convertir List<dynamic> en List<String>
        options = (json['options'] as List).map((item) => item.toString()).toList();
        logger.d('📋 Options parsed: $options');
      } else if (json['options'] is String) {
        try {
          options = List<String>.from(jsonDecode(json['options']));
        } catch (e) {
          // Si le parsing JSON échoue, on traite comme une string simple
          options = [json['options']];
        }
      }
    }

    return Criterion(
      id: json['\$id'] ?? json['id'] ?? '', // Utiliser $id d'Appwrite en priorité
      label: json['label'] ?? '',
      type: _parseCriterionType(json['type'] ?? 'string'),
      options: options,
      dependsOn: json['dependsOn'],
      conditionalOptions: json['conditionalOptions'] != null 
          ? (() {
              logger.d('📋 ConditionalOptions type: ${json['conditionalOptions'].runtimeType}');
              logger.d('📋 ConditionalOptions value: ${json['conditionalOptions']}');
              if (json['conditionalOptions'] is String) {
                try {
                  final decodedMap = jsonDecode(json['conditionalOptions']) as Map<String, dynamic>;
                  return _parseConditionalOptions(decodedMap);
                } catch (e) {
                  logger.e('❌ Erreur lors du décodage de conditionalOptions (string): $e');
                  return null;
                }
              } else {
                return _parseConditionalOptions(json['conditionalOptions']);
              }
            })()
          : null,
      required: json['required'] ?? false,
      unit: json['unit'],
      minValue: json['minValue']?.toDouble(),
      maxValue: json['maxValue']?.toDouble(),
      placeholder: json['placeholder'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'type': type.name,
      'options': options,
      'dependsOn': dependsOn,
      'conditionalOptions': conditionalOptions,
      'required': required,
      'unit': unit,
      'minValue': minValue,
      'maxValue': maxValue,
      'placeholder': placeholder,
    };
  }

  static CriterionType _parseCriterionType(String type) {
    switch (type.toLowerCase()) {
      case 'range':
        return CriterionType.range;
      case 'select':
        return CriterionType.select;
      case 'boolean':
        return CriterionType.boolean;
      case 'number':
        return CriterionType.number;
      default:
        return CriterionType.string;
    }
  }

  // Obtenir les options en fonction d'une valeur parente
  List<String>? getOptionsForParentValue(String? parentValue) {
    if (conditionalOptions == null || parentValue == null) {
      return options;
    }
    return conditionalOptions![parentValue] ?? options;
  }

  // Méthode helper pour parser les conditionalOptions
  static Map<String, List<String>> _parseConditionalOptions(dynamic conditionalOptions) {
    if (conditionalOptions is Map) {
      Map<String, List<String>> result = {};
      conditionalOptions.forEach((key, value) {
        if (value is List) {
          result[key.toString()] = value.map((item) => item.toString()).toList();
        }
      });
      return result;
    }
    return {};
  }
}

class CriterionValue {
  final String criterionId;
  final dynamic value;

  CriterionValue({
    required this.criterionId,
    required this.value,
  });

  factory CriterionValue.fromJson(Map<String, dynamic> json) {
    return CriterionValue(
      criterionId: json['id_criteria'] ?? '',
      value: json['value'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_criteria': criterionId,
      'value': value,
    };
  }
}

class CategoryCriteria {
  final String categoryId;
  final List<Criterion> criteria;

  CategoryCriteria({
    required this.categoryId,
    required this.criteria,
  });

  factory CategoryCriteria.fromJson(Map<String, dynamic> json) {
    return CategoryCriteria(
      categoryId: json['categoryId'] ?? '',
      criteria: (json['criteria'] as List<dynamic>?)
          ?.map((c) => Criterion.fromJson(c))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'categoryId': categoryId,
      'criteria': criteria.map((c) => c.toJson()).toList(),
    };
  }
} 