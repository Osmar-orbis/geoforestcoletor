// lib/providers/map_provider.dart (VERSÃO FINAL - CORREÇÃO DE ENUM)

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
  final _samplingService = SamplingService();
  
  // Adicionando o RouteObserver
  static final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

  List<ImportedFeature> _importedFeatures = [];
  List<SamplePoint> _samplePoints = [];
  bool _isLoading = false;
  Atividade? _currentAtividade;
  Talhao? _currentTalhao; // Adicionando para o contexto do mapa
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
  Talhao? get currentTalhao => _currentTalhao; // Getter para o talhão atual
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
  
  void switchMapLayer() {
    _currentLayer = MapLayerType.values[(_currentLayer.index + 1) % MapLayerType.values.length];
    notifyListeners();
  }

  void startDrawing() {
    if (!_isDrawing) {
      _isDrawing = true;
      _drawnPoints.clear();
      notifyListeners();
    }
  }

  void cancelDrawing() {
    if (_isDrawing) {
      _isDrawing = false;
      _drawnPoints.clear();
      notifyListeners();
    }
  }

  void addDrawnPoint(LatLng point) {
    if (_isDrawing) {
      _drawnPoints.add(point);
      notifyListeners();
    }
  }

  void undoLastDrawnPoint() {
    if (_isDrawing && _drawnPoints.isNotEmpty) {
      _drawnPoints.removeLast();
      notifyListeners();
    }
  }
  
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
    _currentTalhao = null; // Limpa o talhão também
    if (_isFollowingUser) toggleFollowingUser();
    if (_isDrawing) cancelDrawing();
    notifyListeners();
  }

  // Novo método para definir o talhão atual
  void setCurrentTalhao(Talhao talhao) {
    _currentTalhao = talhao;
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
      return "Nenhum talhão válido foi encontrado no arquivo GeoJSON. Verifique o formato e as propriedades.";
    }

    int fazendasCriadas = 0;
    int talhoesCriados = 0;
    
    final Map<String, Fazenda> fazendaCache = {};
    
    for (final feature in features) {
      final props = feature.properties;
      final fazendaIdentificador = (props['fazenda_id'] ?? props['fazenda_nome'] ?? props['fazenda'])?.toString();
      final talhaoIdentificador = (props['talhao_nome'] ?? props['talhao_id'] ?? props['talhao'])?.toString();
      
      if (fazendaIdentificador == null || talhaoIdentificador == null) {
        debugPrint("Aviso: Pulando polígono por falta de identificador de fazenda/talhão. Propriedades encontradas: $props");
        continue;
      }

      try {
        if (!fazendaCache.containsKey(fazendaIdentificador)) {
          final fazenda = Fazenda(
            id: fazendaIdentificador,
            atividadeId: atividade.id!,
            nome: props['fazenda']?.toString() ?? fazendaIdentificador,
            municipio: props['municipio']?.toString() ?? 'N/I',
            estado: props['estado']?.toString() ?? 'N/I',
          );
          await (await _dbHelper.database).insert('fazendas', fazenda.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
          fazendaCache[fazendaIdentificador] = fazenda;
          fazendasCriadas++;
        }
        
        Talhao talhao = Talhao(
          fazendaId: fazendaIdentificador,
          fazendaAtividadeId: atividade.id!,
          nome: talhaoIdentificador,
          especie: props['especie']?.toString(),
          areaHa: (props['area_ha'] as num?)?.toDouble(),
          idadeAnos: (props['idade_anos'] as num?)?.toDouble(),
          fazendaNome: fazendaCache[fazendaIdentificador]?.nome,
        );
        final talhaoId = await _dbHelper.insertTalhao(talhao);
        feature.properties['db_talhao_id'] = talhaoId;
        feature.properties['db_fazenda_id'] = fazendaIdentificador;
        feature.properties['db_fazenda_nome'] = fazendaCache[fazendaIdentificador]?.nome;
        feature.properties['db_talhao_nome'] = talhaoIdentificador;
        talhoesCriados++;

      } catch (e) {
        _setLoading(false);
        return "Erro ao processar o talhão '$talhaoIdentificador': ${e.toString()}. Verifique os dados e tente novamente.";
      }
    }
    
    _importedFeatures = features;
    _setLoading(false);
    
    return "Importação concluída!\n- ${features.length} polígonos de talhão carregados.\n- ${fazendasCriadas} novas fazendas criadas.\n- ${talhoesCriados} novos talhões criados.";
  }

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
      final talhaoIdSalvo = props['db_talhao_id'] as int?;

      if (talhaoIdSalvo != null) {
         parcelasParaSalvar.add(Parcela(
          talhaoId: talhaoIdSalvo,
          idParcela: pointIdCounter.toString(),
          areaMetrosQuadrados: 0,
          latitude: ponto.position.latitude,
          longitude: ponto.position.longitude,
          status: StatusParcela.pendente,
          dataColeta: DateTime.now(),
          nomeFazenda: props['db_fazenda_nome']?.toString(),
          idFazenda: props['db_fazenda_id']?.toString(),
          nomeTalhao: props['db_talhao_nome']?.toString(),
        ));
        pointIdCounter++;
      } else {
        debugPrint("Aviso: Talhão com propriedades '$props' não encontrado no banco para o ponto gerado.");
      }
    }

    if (parcelasParaSalvar.isNotEmpty) {
      await _dbHelper.saveBatchParcelas(parcelasParaSalvar);
      await loadSamplesParaAtividade(_currentAtividade!);
    }
    
    _setLoading(false);
    return "${parcelasParaSalvar.length} amostras foram geradas e salvas com sucesso.";
  }
  
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
              status: _getSampleStatus(p), // <<< CORREÇÃO APLICADA AQUI
              data: {'dbId': p.dbId}
          ));
        }
      }
    }
    _setLoading(false);
  }

  // Função auxiliar para traduzir o status
  SampleStatus _getSampleStatus(Parcela parcela) {
    if (parcela.exportada) {
      return SampleStatus.exported;
    }
    switch (parcela.status) {
      case StatusParcela.concluida:
        return SampleStatus.completed;
      case StatusParcela.emAndamento:
        return SampleStatus.open;
      case StatusParcela.pendente:
      default:
        return SampleStatus.untouched;
    }
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