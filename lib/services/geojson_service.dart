// lib/services/geojson_service.dart (VERSÃO FINAL COM IMPORT CORRETO)

import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart'; // <<< IMPORT ADICIONADO AQUI
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

// Modelo para polígonos importados
class ImportedPolygonFeature {
  final Polygon polygon;
  final Map<String, dynamic> properties;

  ImportedPolygonFeature({required this.polygon, required this.properties});
}

// Modelo para pontos importados
class ImportedPointFeature {
  final LatLng position;
  final Map<String, dynamic> properties;

  ImportedPointFeature({required this.position, required this.properties});
}


class GeoJsonService {
  Future<File?> _pickFile() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.photos, Permission.videos, Permission.audio, Permission.storage,
    ].request();

    if (!statuses.values.any((s) => s.isGranted)) {
       debugPrint("Permissões de armazenamento/mídia negadas.");
       return null;
    }

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['geojson', 'json'],
    );

    if (result == null || result.files.single.path == null) {
      debugPrint("Nenhum arquivo selecionado.");
      return null;
    }
    return File(result.files.single.path!);
  }

  // Novo método específico para importar polígonos
  Future<List<ImportedPolygonFeature>> importPolygons() async {
    final file = await _pickFile();
    if (file == null) return [];

    try {
      final fileContent = await file.readAsString();
      if (fileContent.isEmpty) return [];
      
      final geoJsonData = json.decode(fileContent);
      if (geoJsonData['features'] == null) return [];

      final List<ImportedPolygonFeature> importedPolygons = [];

      for (var feature in geoJsonData['features']) {
        final geometry = feature['geometry'];
        final properties = feature['properties'] as Map<String, dynamic>? ?? {};
        
        if (geometry != null && (geometry['type'] == 'Polygon' || geometry['type'] == 'MultiPolygon')) {
          
          void processPolygonCoordinates(List polygonCoords) {
              final List<LatLng> points = [];
              for (var point in polygonCoords[0]) { // Acessa a primeira lista que contém os pontos
                points.add(LatLng(point[1].toDouble(), point[0].toDouble()));
              }
              if (points.isNotEmpty) {
                importedPolygons.add(
                  ImportedPolygonFeature(
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
      return importedPolygons;
    } catch (e, s) {
      debugPrint("ERRO ao importar polígonos GeoJSON: $e\nStacktrace: $s");
      return [];
    }
  }
  
  // Novo método específico para importar pontos
  Future<List<ImportedPointFeature>> importPoints() async {
    final file = await _pickFile();
    if (file == null) return [];

    try {
      final fileContent = await file.readAsString();
      if (fileContent.isEmpty) return [];
      
      final geoJsonData = json.decode(fileContent);
      if (geoJsonData['features'] == null) return [];

      final List<ImportedPointFeature> importedPoints = [];
      for (var feature in geoJsonData['features']) {
        final geometry = feature['geometry'];
        final properties = feature['properties'] as Map<String, dynamic>? ?? {};

        if (geometry != null && geometry['type'] == 'Point' && geometry['coordinates'] != null) {
          final position = LatLng(geometry['coordinates'][1].toDouble(), geometry['coordinates'][0].toDouble());
          importedPoints.add(ImportedPointFeature(position: position, properties: properties));
        }
      }
      return importedPoints;
    } catch (e, s) {
      debugPrint("ERRO ao importar pontos GeoJSON: $e\nStacktrace: $s");
      return [];
    }
  }

  // Função auxiliar para criar polígonos (sem alteração)
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