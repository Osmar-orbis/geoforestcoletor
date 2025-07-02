// lib/models/imported_feature_model.dart (NOVO ARQUIVO)

import 'package:flutter_map/flutter_map.dart';

class ImportedFeature {
  final Polygon polygon;
  final Map<String, dynamic> properties;

  ImportedFeature({required this.polygon, required this.properties});
}