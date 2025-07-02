// lib/services/geojson_service.dart (VERSÃO COMPLETA E CORRIGIDA)

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
  // Novo método para importar múltiplos talhões com suas propriedades.
  Future<List<ImportedFeature>> importAndParseMultiTalhaoGeoJson() async {
    // Nova estratégia de solicitação de permissão para Android 13+
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
        return [];
      }
    }

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['geojson', 'json'],
    );

    if (result == null || result.files.single.path == null) {
      debugPrint("DEBUG: Nenhum arquivo selecionado.");
      return [];
    }

    try {
      final filePath = result.files.single.path!;
      final file = File(filePath);
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
          
          if (properties['talhao_nome'] == null || properties['fazenda_nome'] == null) {
              debugPrint("AVISO: Pulando polígono por falta de 'talhao_nome' ou 'fazenda_nome' nas propriedades.");
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

  // Método antigo mantido apenas por segurança, mas não é usado no novo fluxo.
  // Pode ser removido futuramente.
  Future<Map<String, dynamic>> importAndParseGeoJson() async {
     debugPrint("AVISO: O método obsoleto 'importAndParseGeoJson' foi chamado.");
     return {'polygons': [], 'points': []};
  }

  Polygon _createPolygon(List<LatLng> points, Map<String, dynamic> properties) {
    return Polygon(
      points: points,
      color: const Color(0xFF617359).withAlpha(100),
      borderColor: const Color(0xFF1D4433),
      borderStrokeWidth: 1.5,
      isFilled: true,
      label: properties['talhao_nome'] as String?,
      labelStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
    );
  }
}