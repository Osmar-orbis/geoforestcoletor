// lib/services/sampling_service.dart

import 'dart:math';
// import 'package:flutter/foundation.dart'; // <<< 1. IMPORT REMOVIDO
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geoforestcoletor/models/sample_point.dart'; // <<< IMPORT DO NOVO MODELO

class SamplingService {
  
  // <<< O TIPO DE RETORNO MUDOU PARA List<SamplePoint> >>>
  List<SamplePoint> generateGridSamplePoints({
    required List<Polygon> polygons,
    required double hectaresPerSample,
  }) {
    if (hectaresPerSample <= 0 || polygons.isEmpty) return [];

    final allPoints = polygons.expand((p) => p.points).toList();
    if (allPoints.isEmpty) return [];
    
    final bounds = LatLngBounds.fromPoints(allPoints);
    final double minLat = bounds.south;
    final double maxLat = bounds.north;
    final double minLon = bounds.west;
    final double maxLon = bounds.east;

    final double centerLatRad = ((minLat + maxLat) / 2) * (pi / 180.0);
    
    final double spacingInMeters = sqrt(hectaresPerSample * 10000);
    final double latStep = spacingInMeters / 111132.0;
    final double lonStep = spacingInMeters / (111320.0 * cos(centerLatRad));

    final List<SamplePoint> validSamplePoints = [];
    int pointId = 1; // <<< Contador para o número da parcela

    for (double lat = minLat; lat <= maxLat; lat += latStep) {
      for (double lon = minLon; lon <= maxLon; lon += lonStep) {
        final gridPoint = LatLng(lat, lon);
        
        for (final polygon in polygons) {
          if (_isPointInPolygon(gridPoint, polygon.points)) {
            // <<< CRIA O OBJETO SamplePoint E ADICIONA NA LISTA >>>
            validSamplePoints.add(SamplePoint(id: pointId, position: gridPoint));
            pointId++; // Incrementa o contador
            break; 
          }
        }
      }
    }

    return validSamplePoints;
  }

  /// Verifica se um ponto está dentro de um polígono usando o algoritmo Ray-casting.
  bool _isPointInPolygon(LatLng point, List<LatLng> polygonVertices) {
    if (polygonVertices.isEmpty) return false;
    
    int intersections = 0;
    for (int i = 0; i < polygonVertices.length; i++) {
      LatLng p1 = polygonVertices[i];
      LatLng p2 = polygonVertices[(i + 1) % polygonVertices.length];

      if ((p1.latitude > point.latitude) != (p2.latitude > point.latitude)) {
        double atX = (p2.longitude - p1.longitude) * (point.latitude - p1.latitude) / (p2.latitude - p1.latitude) + p1.longitude;
        if (point.longitude < atX) {
          intersections++;
        }
      }
    }
    return intersections % 2 == 1;
  }
}