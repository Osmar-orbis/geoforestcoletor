// lib/services/geojson_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

// Classe auxiliar para transportar o polígono e seus metadados.
class ImportedFeature {
  final Polygon polygon;
  final Map<String, dynamic> properties;

  ImportedFeature({required this.polygon, required this.properties});
}

class GeoJsonService {
  Future<File?> _pickFile() async {
    // Permissão para Android 13+
    Map<Permission, PermissionStatus> statuses = await [
      Permission.photos,
      Permission.videos,
      Permission.audio,
    ].request();

    bool permissionGranted = statuses.values.any((status) => status.isGranted || status.isLimited);

    if (!permissionGranted) {
      debugPrint("AVISO: Permissão de mídia negada. Tentando fallback para 'storage'.");
      if (await Permission.storage.request().isDenied) {
        debugPrint("ERRO: A permissão de storage (fallback) também foi negada.");
        return null;
      }
    }

    // <<< CORREÇÃO: Procura por .geojson E .json >>>
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['geojson', 'json'],
    );

    if (result == null || result.files.single.path == null) {
      debugPrint("DEBUG: Nenhum arquivo selecionado.");
      return null;
    }
    return File(result.files.single.path!);
  }

  // Método para importar polígonos (Carga de Talhões)
  Future<List<ImportedFeature>> importAndParseMultiTalhaoGeoJson() async {
    final file = await _pickFile();
    if (file == null) return [];

    try {
      final fileContent = await file.readAsString();
      if (fileContent.isEmpty) {
        debugPrint("ERRO: O conteúdo do arquivo está vazio!");
        return [];
      }
      
      final geoJsonData = json.decode(fileContent);

      if (geoJsonData['features'] == null) {
        debugPrint("ERRO: O JSON não contém a chave 'features'.");
        return [];
      }

      final List<ImportedFeature> importedFeatures = [];

      for (var feature in geoJsonData['features']) {
        final geometry = feature['geometry'];
        final properties = feature['properties'] as Map<String, dynamic>? ?? {};
        
        if (geometry != null && (geometry['type'] == 'Polygon' || geometry['type'] == 'MultiPolygon')) {
          
          final talhaoId = properties['talhao_nome'] ?? properties['talhao_id'] ?? properties['talhao'];
          final fazendaId = properties['fazenda_nome'] ?? properties['fazenda_id'] ?? properties['fazenda'];

          if (talhaoId == null || fazendaId == null) {
              debugPrint("AVISO: Pulando polígono por falta de um identificador de talhão/fazenda. Propriedades encontradas: $properties");
              continue;
          }

          void processPolygonCoordinates(List polygonCoords) {
              final List<LatLng> points = [];
              for (var point in polygonCoords[0]) {
                points.add(LatLng(point[1].toDouble(), point[0].toDouble()));
              }
              if (points.isNotEmpty) {
                importedFeatures.add(
                  ImportedFeature(
                    polygon: _createPolygon(points, properties),
                    properties: properties,
                  )
                );
              }
          }

          if (geometry['type'] == 'Polygon') {
             processPolygonCoordinates(geometry['coordinates']);
          } else if (geometry['type'] == 'MultiPolygon') {
            for (var singlePolygonCoords in geometry['coordinates']) {
              processPolygonCoordinates(singlePolygonCoords);
            }
          }
        }
      }

      debugPrint("DEBUG: Processamento concluído. ${importedFeatures.length} polígonos importados com propriedades.");
      return importedFeatures;

    } catch (e, s) {
      debugPrint("ERRO CRÍTICO ao importar GeoJSON: $e");
      debugPrint("Stacktrace: $s");
      return [];
    }
  }
  
  Future<List<Map<String, dynamic>>> importAmostragemGeoJson() async {
    final file = await _pickFile();
    if (file == null) return [];

    try {
      final fileContent = await file.readAsString();
      if (fileContent.isEmpty) {
        debugPrint("ERRO: O conteúdo do arquivo de amostragem está vazio!");
        return [];
      }
      
      final geoJsonData = json.decode(fileContent);

      if (geoJsonData['features'] == null) {
        debugPrint("ERRO: O JSON não contém a chave 'features'.");
        return [];
      }

      final List<Map<String, dynamic>> importedPoints = [];
      for (var feature in geoJsonData['features']) {
        final geometry = feature['geometry'];
        final properties = feature['properties'] as Map<String, dynamic>? ?? {};

        if (geometry != null && geometry['type'] == 'Point' && geometry['coordinates'] != null) {
          final pointProperties = Map<String, dynamic>.from(properties);
          pointProperties['longitude'] = geometry['coordinates'][0];
          pointProperties['latitude'] = geometry['coordinates'][1];
          importedPoints.add(pointProperties);
        }
      }
      
      debugPrint("DEBUG: Importação de amostragem concluída. ${importedPoints.length} pontos lidos.");
      return importedPoints;
      
    } catch (e, s) {
      debugPrint("ERRO CRÍTICO ao importar GeoJSON de amostragem: $e");
      debugPrint("Stacktrace: $s");
      return [];
    }
  }

  Polygon _createPolygon(List<LatLng> points, Map<String, dynamic> properties) {
    final label = (properties['talhao_nome'] ?? properties['talhao_id'] ?? properties['talhao'])?.toString();
    
    return Polygon(
      points: points,
      color: const Color(0xFF617359).withAlpha(100),
      borderColor: const Color(0xFF1D4433),
      borderStrokeWidth: 1.5,
      isFilled: true,
      label: label,
      labelStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10),
    );
  }
}