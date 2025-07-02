// lib/providers/map_provider.dart (VERSÃO FINAL E COMPLETA)

import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/atividade_model.dart';
import 'package:geoforestcoletor/models/fazenda_model.dart';
import 'package:geoforestcoletor/models/parcela_model.dart';
import 'package:geoforestcoletor/models/sample_point.dart';
import 'package:geoforestcoletor/models/talhao_model.dart';
import 'package:geoforestcoletor/services/geojson_service.dart';
import 'package:geoforestcoletor/services/sampling_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:sqflite/sqflite.dart';

enum MapLayerType { ruas, satelite, sateliteMapbox }

class MapProvider with ChangeNotifier {
  final _geoJsonService = GeoJsonService();
  final _dbHelper = DatabaseHelper.instance;
  final _samplingService = SamplingService(); // Instância do serviço

  List<ImportedFeature> _importedFeatures = [];
  List<SamplePoint> _samplePoints = [];
  bool _isLoading = false;
  Atividade? _currentAtividade;
  MapLayerType _currentLayer = MapLayerType.satelite;
  Position? _currentUserPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isFollowingUser = false;
  bool _isDrawing = false;
  final List<LatLng> _drawnPoints = [];

  // Getters
  bool get isDrawing => _isDrawing;
  List<LatLng> get drawnPoints => _drawnPoints;
  List<Polygon> get polygons => _importedFeatures.map((f) => f.polygon).toList();
  List<SamplePoint> get samplePoints => _samplePoints;
  bool get isLoading => _isLoading;
  Atividade? get currentAtividade => _currentAtividade;
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
      if (_mapboxAccessToken.isEmpty) return _tileUrls[MapLayerType.satelite]!;
      return url.replaceAll('{accessToken}', _mapboxAccessToken);
    }
    return url;
  }
  
  void switchMapLayer() { /* ... código existente ... */ }
  void startDrawing() { /* ... código existente ... */ }
  void cancelDrawing() { /* ... código existente ... */ }
  void addDrawnPoint(LatLng point) { /* ... código existente ... */ }
  void undoLastDrawnPoint() { /* ... código existente ... */ }
  
  void saveDrawnPolygon() {
    if (_drawnPoints.length < 3) {
      cancelDrawing();
      return;
    }
    _importedFeatures.add(ImportedFeature(
      polygon: Polygon(points: List.from(_drawnPoints), color: const Color(0xFF617359).withAlpha(128), borderColor: const Color(0xFF1D4433), borderStrokeWidth: 2, isFilled: true),
      properties: {},
    ));
    _isDrawing = false;
    _drawnPoints.clear();
    notifyListeners();
  }

  void clearAllMapData() {
    _importedFeatures = [];
    _samplePoints = [];
    _currentAtividade = null;
    if (_isFollowingUser) toggleFollowingUser();
    if (_isDrawing) cancelDrawing();
    notifyListeners();
  }

  Future<String> processarCargaDeAtividade(Atividade atividade) async {
    _setLoading(true);
    _currentAtividade = atividade;
    _importedFeatures = [];
    _samplePoints = [];
    notifyListeners();

    final features = await _geoJsonService.importAndParseMultiTalhaoGeoJson();

    if (features.isEmpty) {
      _setLoading(false);
      return "Nenhum talhão válido foi encontrado no arquivo GeoJSON. Verifique o formato e as propriedades ('talhao_nome', 'fazenda_nome').";
    }

    int fazendasCriadas = 0;
    int talhoesCriados = 0;
    
    final Map<String, Fazenda> fazendaCache = {};
    
    for (final feature in features) {
      final props = feature.properties;
      final fazendaId = props['fazenda_id']?.toString() ?? props['fazenda_nome']?.toString();
      final talhaoNome = props['talhao_nome']?.toString();
      
      if (fazendaId == null || talhaoNome == null) continue;

      try {
        if (!fazendaCache.containsKey(fazendaId)) {
          final fazenda = Fazenda(
            id: fazendaId,
            atividadeId: atividade.id!,
            nome: props['fazenda_nome'],
            municipio: props['fazenda_municipio'] ?? 'N/I',
            estado: props['fazenda_estado'] ?? 'N/I',
          );
          await (await _dbHelper.database).insert('fazendas', fazenda.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
          fazendaCache[fazendaId] = fazenda;
          fazendasCriadas++;
        }
        
        Talhao talhao = Talhao(
          fazendaId: fazendaId,
          fazendaAtividadeId: atividade.id!,
          nome: talhaoNome,
          especie: props['talhao_especie']?.toString(),
          areaHa: (props['talhao_area_ha'] as num?)?.toDouble(),
          idadeAnos: (props['talhao_idade_anos'] as num?)?.toDouble(),
        );
        await _dbHelper.insertTalhao(talhao); // A chave primária é autoincremento, então não há conflito
        talhoesCriados++;

      } catch (e) {
        _setLoading(false);
        return "Erro ao processar o talhão '$talhaoNome': ${e.toString()}. Verifique os dados e tente novamente.";
      }
    }
    
    _importedFeatures = features;
    _setLoading(false);
    
    return "Importação concluída!\n- ${features.length} polígonos de talhão carregados.\n- ${fazendasCriadas} novas fazendas criadas.\n- ${talhoesCriados} novos talhões criados.";
  }

  // =========================================================================
  // <<< NOVO MÉTODO PARA GERAR AMOSTRAS >>>
  // =========================================================================
  Future<String> gerarAmostrasParaAtividade({required double hectaresPerSample}) async {
    if (_importedFeatures.isEmpty) {
      return "Nenhum polígono de talhão carregado. Importe uma carga primeiro.";
    }
    if (_currentAtividade == null) {
      return "Erro: Atividade atual não definida.";
    }

    _setLoading(true);

    final pontosGerados = _samplingService.generateMultiTalhaoSamplePoints(
      importedFeatures: _importedFeatures,
      hectaresPerSample: hectaresPerSample,
    );

    if (pontosGerados.isEmpty) {
      _setLoading(false);
      return "Nenhum ponto de amostra pôde ser gerado dentro dos polígonos.";
    }

    final List<Parcela> parcelasParaSalvar = [];
    int pointIdCounter = 1;

    for (final ponto in pontosGerados) {
      final props = ponto.properties;
      final fazendaId = props['fazenda_id']?.toString() ?? props['fazenda_nome']?.toString();
      final talhaoNome = props['talhao_nome']?.toString();

      if (fazendaId == null || talhaoNome == null) continue;

      // Busca o talhão correspondente no banco de dados.
      // Esta busca é crucial e depende da criação correta na etapa de importação.
      final talhoesDaFazenda = await _dbHelper.getTalhoesDaFazenda(fazendaId, _currentAtividade!.id!);
      final talhaoCorreto = talhoesDaFazenda.firstWhereOrNull((t) => t.nome == talhaoNome);

      if (talhaoCorreto != null) {
        parcelasParaSalvar.add(Parcela(
          talhaoId: talhaoCorreto.id,
          idParcela: pointIdCounter.toString(),
          areaMetrosQuadrados: 0,
          latitude: ponto.position.latitude,
          longitude: ponto.position.longitude,
          status: StatusParcela.pendente,
          dataColeta: DateTime.now(),
          nomeFazenda: talhaoCorreto.fazendaNome,
          idFazenda: talhaoCorreto.fazendaId,
          nomeTalhao: talhaoCorreto.nome,
        ));
        pointIdCounter++;
      } else {
        debugPrint("Aviso: Talhão '$talhaoNome' não encontrado no banco para o ponto gerado.");
      }
    }

    if (parcelasParaSalvar.isNotEmpty) {
      await _dbHelper.saveBatchParcelas(parcelasParaSalvar);
      await loadSamplesParaAtividade(_currentAtividade!);
    }
    
    _setLoading(false);
    return "${parcelasParaSalvar.length} amostras foram geradas e salvas com sucesso.";
  }

  // Novo método para carregar todas as amostras de uma atividade
  Future<void> loadSamplesParaAtividade(Atividade atividade) async {
    _setLoading(true);
    _samplePoints = [];
    final fazendas = await _dbHelper.getFazendasDaAtividade(atividade.id!);
    for (final fazenda in fazendas) {
      final talhoes = await _dbHelper.getTalhoesDaFazenda(fazenda.id, atividade.id!);
      for (final talhao in talhoes) {
        final parcelas = await _dbHelper.getParcelasDoTalhao(talhao.id!);
        for (final p in parcelas) {
           _samplePoints.add(SamplePoint(
              id: int.tryParse(p.idParcela) ?? 0,
              position: LatLng(p.latitude ?? 0, p.longitude ?? 0),
              status: p.status == StatusParcela.concluida ? SampleStatus.completed : SampleStatus.untouched,
              data: {'dbId': p.dbId}
          ));
        }
      }
    }
    _setLoading(false);
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