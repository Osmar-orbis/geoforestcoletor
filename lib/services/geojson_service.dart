// lib/services/geojson_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geoforestcoletor/models/sample_point.dart'; // <<< IMPORT NECESSÁRIO
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

class GeoJsonService {
  // =========================================================================
  // =========== MÉTODO ATUALIZADO PARA RETORNAR POLÍGONOS E PONTOS ==========
  // =========================================================================
  Future<Map<String, dynamic>> importAndParseGeoJson() async {
    var photosStatus = await Permission.photos.status;
    var videosStatus = await Permission.videos.status;

    if (!photosStatus.isGranted) photosStatus = await Permission.photos.request();
    if (!videosStatus.isGranted) videosStatus = await Permission.videos.request();

    if (!photosStatus.isGranted && !videosStatus.isGranted) {
      var storageStatus = await Permission.storage.request();
      if (!storageStatus.isGranted) {
        print("ERRO: Permissão de acesso a mídias/arquivos foi negada.");
        return {'polygons': [], 'points': []};
      }
    }

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['geojson', 'json'],
    );

    if (result == null || result.files.single.path == null) {
      print("DEBUG: Nenhum arquivo selecionado.");
      return {'polygons': [], 'points': []};
    }

    try {
      final filePath = result.files.single.path!;
      final file = File(filePath);
      final fileContent = await file.readAsString();

      if (fileContent.isEmpty) {
        print("ERRO: O conteúdo do arquivo está vazio!");
        return {'polygons': [], 'points': []};
      }
      
      final geoJsonData = json.decode(fileContent);

      if (geoJsonData['features'] == null) {
        print("ERRO: O JSON não contém a chave 'features'.");
        return {'polygons': [], 'points': []};
      }

      final List<Polygon> polygons = [];
      final List<SamplePoint> samplePoints = []; // <<< LISTA PARA GUARDAR OS PONTOS

      for (var feature in geoJsonData['features']) {
        final geometry = feature['geometry'];
        final properties = feature['properties'] ?? {};
        
        if (geometry != null) {
          // Lógica para Polígonos (sem alterações)
          if (geometry['type'] == 'Polygon') {
            final List<LatLng> points = [];
            for (var point in geometry['coordinates'][0]) {
              points.add(LatLng(point[1].toDouble(), point[0].toDouble()));
            }
            polygons.add(_createPolygon(points));
          } else if (geometry['type'] == 'MultiPolygon') {
            for (var polygonCoords in geometry['coordinates']) {
              final List<LatLng> points = [];
              for (var point in polygonCoords[0]) {
                points.add(LatLng(point[1].toDouble(), point[0].toDouble()));
              }
              polygons.add(_createPolygon(points));
            }
          }
          // =========================================================================
          // =================== LÓGICA PARA IMPORTAR PONTOS (PLOTS) =================
          // =========================================================================
          else if (geometry['type'] == 'Point' && properties['type'] == 'plot') {
            samplePoints.add(SamplePoint(
              id: properties['id'] ?? 0,
              position: LatLng(geometry['coordinates'][1].toDouble(), geometry['coordinates'][0].toDouble()),
              status: SampleStatus.values.firstWhere((e) => e.name == properties['status'], orElse: () => SampleStatus.untouched),
            ));
          }
        }
      }

      print("DEBUG: Processamento concluído. ${polygons.length} polígonos e ${samplePoints.length} pontos criados.");
      // Retorna um mapa contendo ambas as listas
      return {
        'polygons': polygons,
        'points': samplePoints,
      };

    } catch (e, s) {
      debugPrint("ERRO CRÍTICO: $e");
      debugPrint("Stacktrace: $s");
      return {'polygons': [], 'points': []};
    }
  }

  Polygon _createPolygon(List<LatLng> points) {
    return Polygon(
      points: points,
      color: const Color(0xFF617359).withAlpha(128),
      borderColor: const Color(0xFF1D4433),
      borderStrokeWidth: 2,
    );
  }
}