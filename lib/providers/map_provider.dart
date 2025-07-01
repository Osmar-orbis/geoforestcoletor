// lib/providers/map_provider.dart (VERSÃO FINAL, LIMPA E CORRIGIDA)

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/parcela_model.dart';
import 'package:geoforestcoletor/models/sample_point.dart';
import 'package:geoforestcoletor/models/talhao_model.dart';
import 'package:geoforestcoletor/services/geojson_service.dart';
import 'package:geoforestcoletor/services/sampling_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum MapLayerType { ruas, satelite, sateliteMapbox }

class MapProvider with ChangeNotifier {
  final _geoJsonService = GeoJsonService();
  final _dbHelper = DatabaseHelper.instance;

  List<Polygon> _polygons = [];
  List<SamplePoint> _samplePoints = [];
  bool _isLoading = false;
  
  Talhao? _currentTalhao;

  MapLayerType _currentLayer = MapLayerType.satelite;
  
  Position? _currentUserPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isFollowingUser = false;
  
  bool _isDrawing = false;
  final List<LatLng> _drawnPoints = [];

  // Getters
  bool get isDrawing => _isDrawing;
  List<LatLng> get drawnPoints => _drawnPoints;
  List<Polygon> get polygons => _polygons;
  List<SamplePoint> get samplePoints => _samplePoints;
  bool get isLoading => _isLoading;
  Talhao? get currentTalhao => _currentTalhao;
  MapLayerType get currentLayer => _currentLayer;
  Position? get currentUserPosition => _currentUserPosition;
  bool get isFollowingUser => _isFollowingUser;

  final Map<MapLayerType, String> _tileUrls = {
    MapLayerType.ruas: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    MapLayerType.satelite: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    MapLayerType.sateliteMapbox: 'https://api.mapbox.com/styles/v1/mapbox/satellite-v9/tiles/256/{z}/{x}/{y}@2x?access_token={accessToken}',
  };
  final String _mapboxAccessToken = 'pk.eyJ1IjoiZ2VvZm9yZXN0YXBwIiwiYSI6ImNtY2FyczBwdDAxZmYybHB1OWZlbG1pdW0ifQ.5HeYC0moMJ8dzZzVXKTPrg';

  String get currentTileUrl {
    String url = _tileUrls[_currentLayer]!;
    if (url.contains('{accessToken}')) {
      if (_mapboxAccessToken.isEmpty) {
        return _tileUrls[MapLayerType.satelite]!;
      }
      return url.replaceAll('{accessToken}', _mapboxAccessToken);
    }
    return url;
  }
  
  void switchMapLayer() {
    final layers = MapLayerType.values;
    final nextIndex = (_currentLayer.index + 1) % layers.length;
    _currentLayer = layers[nextIndex];
    notifyListeners();
  }
  
  void startDrawing() {
    clearDrawing();
    _isDrawing = true;
    notifyListeners();
  }

  void cancelDrawing() {
    _isDrawing = false;
    _drawnPoints.clear();
    notifyListeners();
  }

  void clearDrawing() {
    _polygons.clear();
    _drawnPoints.clear();
    notifyListeners();
  }

  void addDrawnPoint(LatLng point) {
    if (!_isDrawing) return;
    _drawnPoints.add(point);
    notifyListeners();
  }

  void undoLastDrawnPoint() {
    if (_drawnPoints.isNotEmpty) {
      _drawnPoints.removeLast();
      notifyListeners();
    }
  }

  void saveDrawnPolygon() {
    if (_drawnPoints.length < 3) {
      cancelDrawing();
      return;
    }
    _polygons.add(Polygon(points: List.from(_drawnPoints), color: const Color(0xFF617359).withAlpha(128), borderColor: const Color(0xFF1D4433), borderStrokeWidth: 2, isFilled: true));
    _isDrawing = false;
    _drawnPoints.clear();
    notifyListeners();
  }

  void clearAllMapData() {
    _polygons = [];
    _samplePoints = [];
    _currentTalhao = null; // Limpa o talhão atual
    if (_isFollowingUser) {
      toggleFollowingUser();
    }
    if (_isDrawing) {
      cancelDrawing();
    }
    notifyListeners();
  }

  Future<bool> importAndClear(Talhao talhao) async {
    _setLoading(true);
    _currentTalhao = talhao;
    _polygons = [];
    _samplePoints = [];
    notifyListeners();

    final importedData = await _geoJsonService.importAndParseGeoJson();
    _polygons = importedData['polygons'] as List<Polygon>;
    _samplePoints = importedData['points'] as List<SamplePoint>;
    _setLoading(false);
    return _polygons.isNotEmpty || _samplePoints.isNotEmpty;
  }

  Future<void> loadSamplesFromTalhao(Talhao talhao) async {
    _setLoading(true);
    _currentTalhao = talhao;
    final parcelasDoBanco = await _dbHelper.getParcelasDoTalhao(talhao.id!);
    _samplePoints = parcelasDoBanco.map((parcela) {
      SampleStatus status;
      switch (parcela.status) {
        case StatusParcela.concluida: status = SampleStatus.completed; break;
        case StatusParcela.emAndamento: status = SampleStatus.open; break;
        default: status = SampleStatus.untouched;
      }
      if (parcela.exportada) { status = SampleStatus.exported; }
      return SamplePoint(
        id: int.tryParse(parcela.idParcela) ?? 0,
        position: LatLng(parcela.latitude ?? 0, parcela.longitude ?? 0),
        status: status,
        data: {'dbId': parcela.dbId}
      );
    }).toList();
    _setLoading(false);
  }

  Future<void> saveImportedProject(Talhao talhao) async {
    if (_samplePoints.isEmpty) return;
    _setLoading(true);
    _currentTalhao = talhao;
    final List<Parcela> novasParcelas = _samplePoints.map((point) => Parcela(
      talhaoId: talhao.id,
      idParcela: point.id.toString(),
      latitude: point.position.latitude,
      longitude: point.position.longitude,
      status: StatusParcela.pendente,
      dataColeta: DateTime.now(),
      areaMetrosQuadrados: 0,
      exportada: false
    )).toList();
    await _dbHelper.saveBatchParcelas(novasParcelas);
    await loadSamplesFromTalhao(talhao);
    _setLoading(false);
  }
  
  Future<int> generateSamples({required Talhao talhao, required double hectaresPerSample}) async {
    if (_polygons.isEmpty) return 0;
    _setLoading(true);
    _currentTalhao = talhao;
    final points = await compute(_generatePointsInBackground, {'polygons': _polygons, 'hectaresPerSample': hectaresPerSample});
    final List<Parcela> novasParcelas = points.map((point) => Parcela(
      talhaoId: talhao.id,
      idParcela: point.id.toString(),
      latitude: point.position.latitude,
      longitude: point.position.longitude,
      status: StatusParcela.pendente,
      dataColeta: DateTime.now(),
      areaMetrosQuadrados: 0,
      exportada: false
    )).toList();
    await _dbHelper.saveBatchParcelas(novasParcelas);
    await loadSamplesFromTalhao(talhao);
    _setLoading(false);
    return _samplePoints.length;
  }
  
  static List<SamplePoint> _generatePointsInBackground(Map<String, dynamic> params) {
    final samplingService = SamplingService();
    final List<Polygon> polygons = params['polygons'];
    final double hectaresPerSample = params['hectaresPerSample'];
    return samplingService.generateGridSamplePoints(polygons: polygons, hectaresPerSample: hectaresPerSample);
  }

  void toggleFollowingUser() {
    if (_isFollowingUser) {
      _positionStreamSubscription?.cancel();
      _isFollowingUser = false;
    } else {
      const locationSettings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 1);
      _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
        _currentUserPosition = position;
        notifyListeners();
      });
      _isFollowingUser = true;
    }
    notifyListeners();
  }

  void updateUserPosition(Position position) {
    _currentUserPosition = position;
    notifyListeners();
  }
  
  @override
  void dispose() { 
    _positionStreamSubscription?.cancel(); 
    super.dispose(); 
  }
  
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}