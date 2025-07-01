// lib/pages/menu/map_import_page.dart (VERSÃO FINAL E CORRIGIDA)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/sample_point.dart';
import 'package:geoforestcoletor/models/talhao_model.dart';
import 'package:geoforestcoletor/pages/amostra/coleta_dados_page.dart';
import 'package:geoforestcoletor/providers/map_provider.dart';
import 'package:geoforestcoletor/services/export_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

class MapImportPage extends StatefulWidget {
  // A página agora depende de um Talhao para funcionar.
  final Talhao talhao;
  const MapImportPage({super.key, required this.talhao});

  @override
  State<MapImportPage> createState() => _MapImportPageState();
}

class _MapImportPageState extends State<MapImportPage> {
  final _mapController = MapController();
  final _exportService = ExportService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<MapProvider>();
      await provider.loadSamplesFromTalhao(widget.talhao);
      if (!mounted) return;
      // Centraliza o mapa nos polígonos, se existirem
      if (provider.polygons.isNotEmpty) {
        _mapController.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(provider.polygons.expand((p) => p.points).toList()), padding: const EdgeInsets.all(50.0)));
      }
    });
  }

  Color _getMarkerColor(SampleStatus status) {
    switch (status) { case SampleStatus.open: return Colors.orange.shade300; case SampleStatus.completed: return Colors.green; case SampleStatus.exported: return Colors.blue; case SampleStatus.untouched: return Colors.white; }
  }

  Color _getMarkerTextColor(SampleStatus status) {
    switch (status) { case SampleStatus.open: case SampleStatus.untouched: return Colors.black; case SampleStatus.completed: case SampleStatus.exported: return Colors.white; }
  }

  Future<void> _handleImport() async {
    final provider = context.read<MapProvider>();
    final bool success = await provider.importAndClear(widget.talhao);
    if (!mounted) return;

    if (success) {
      await provider.saveImportedProject(widget.talhao);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Arquivo lido e parcelas salvas no talhão!')));
      if (provider.polygons.isNotEmpty) {
        _mapController.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(provider.polygons.expand((p) => p.points).toList()), padding: const EdgeInsets.all(50.0)));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nenhum polígono ou ponto válido foi encontrado no arquivo.")));
      }
    }
  }

  Future<void> _handleGenerateSamples() async {
    final provider = context.read<MapProvider>();
    if (provider.polygons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Desenhe ou importe uma área primeiro.')));
      return;
    }

    final density = await _showDensityDialog();
    if (density == null || !mounted) return;
    
    final count = await provider.generateSamples(talhao: widget.talhao, hectaresPerSample: density);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count amostras geradas!')));
    }
  }

  Future<double?> _showDensityDialog() {
    final densityController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    return showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Densidade da Amostragem'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: densityController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Hectares por amostra', suffixText: 'ha'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Campo obrigatório';
              if (double.tryParse(value.replaceAll(',', '.')) == null) return 'Número inválido';
              return null;
            }
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, double.parse(densityController.text.replaceAll(',', '.')));
              }
            },
            child: const Text('Gerar'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLocationButtonPressed() async {
    final provider = context.read<MapProvider>();
    if (provider.isFollowingUser) {
      final currentPosition = provider.currentUserPosition;
      if (currentPosition != null) { _mapController.move(LatLng(currentPosition.latitude, currentPosition.longitude), 17.0); }
      return;
    }
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!mounted) return;
    if (!serviceEnabled) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Serviço de GPS desabilitado.'))); return; }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied && mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permissão de localização negada.'))); return; }
    }
    if (permission == LocationPermission.deniedForever && mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permissão negada permanentemente.'))); return; }
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Buscando sua localização...')));
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _mapController.move(LatLng(position.latitude, position.longitude), 17.0);
      provider.updateUserPosition(position);
      provider.toggleFollowingUser();
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível obter a localização: $e')));
    }
  }

  AppBar _buildDefaultAppBar(MapProvider mapProvider) {
    return AppBar(
      title: Text('Talhão: ${widget.talhao.nome}'),
      actions: [
        if (mapProvider.polygons.isNotEmpty)
          IconButton(icon: const Icon(Icons.grid_on_sharp), onPressed: _handleGenerateSamples, tooltip: 'Gerar Amostras'),
        IconButton(icon: const Icon(Icons.edit_location_alt_outlined), onPressed: () => mapProvider.startDrawing(), tooltip: 'Desenhar Área'),
        if (mapProvider.polygons.isNotEmpty || mapProvider.samplePoints.isNotEmpty)
          IconButton(icon: const Icon(Icons.share_outlined), onPressed: () => _exportService.exportProjectAsGeoJson(context: context, areaPolygons: mapProvider.polygons, samplePoints: mapProvider.samplePoints, farmName: mapProvider.currentTalhao?.fazendaId ?? '', blockName: mapProvider.currentTalhao?.nome ?? ''), tooltip: 'Exportar Projeto (GeoJSON)'),
        IconButton(icon: const Icon(Icons.file_upload_outlined), onPressed: mapProvider.isLoading ? null : _handleImport, tooltip: 'Importar Novo GeoJSON'),
      ],
    );
  }

  AppBar _buildDrawingAppBar(MapProvider mapProvider) {
    return AppBar(
      backgroundColor: Colors.grey.shade800,
      title: const Text('Desenhando a Área'),
      leading: IconButton(icon: const Icon(Icons.close), onPressed: () => mapProvider.cancelDrawing(), tooltip: 'Cancelar Desenho'),
      actions: [
        IconButton(icon: const Icon(Icons.undo), onPressed: () => mapProvider.undoLastDrawnPoint(), tooltip: 'Desfazer Último Ponto'),
        IconButton(icon: const Icon(Icons.check), onPressed: () => mapProvider.saveDrawnPolygon(), tooltip: 'Salvar Polígono'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapProvider = context.watch<MapProvider>();
    final currentUserPosition = mapProvider.currentUserPosition;
    final isDrawing = mapProvider.isDrawing;

    if (currentUserPosition != null && mapProvider.isFollowingUser) {
      _mapController.move(LatLng(currentUserPosition.latitude, currentUserPosition.longitude), _mapController.camera.zoom);
    }

    return Scaffold(
      appBar: isDrawing ? _buildDrawingAppBar(mapProvider) : _buildDefaultAppBar(mapProvider),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(-15.7, -47.8),
              initialZoom: 4,
              onPositionChanged: (MapPosition position, bool hasGesture) {
                if (hasGesture && mapProvider.isFollowingUser) {
                  context.read<MapProvider>().toggleFollowingUser();
                }
              },
              onTap: (tapPosition, point) {
                  if (isDrawing) {
                    mapProvider.addDrawnPoint(point);
                  }
              },
            ),
            children: [
              TileLayer(urlTemplate: mapProvider.currentTileUrl, userAgentPackageName: 'com.example.geoforestcoletor'),
              if (mapProvider.polygons.isNotEmpty) PolygonLayer(polygons: mapProvider.polygons),
              if (isDrawing && mapProvider.drawnPoints.isNotEmpty)
                PolylineLayer(polylines: [
                  Polyline(points: mapProvider.drawnPoints, strokeWidth: 2.0, color: Colors.red.withOpacity(0.8)),
                ]),
              if (isDrawing)
                MarkerLayer(
                  markers: mapProvider.drawnPoints.map((point) {
                    return Marker(
                      point: point,
                      width: 12,
                      height: 12,
                      child: Container(
                        decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                      ),
                    );
                  }).toList(),
                ),

              MarkerLayer(
                markers: mapProvider.samplePoints.map((samplePoint) {
                  final color = _getMarkerColor(samplePoint.status);
                  final textColor = _getMarkerTextColor(samplePoint.status);
                  return Marker(
                    width: 40.0, height: 40.0, point: samplePoint.position,
                    child: GestureDetector(
                      onTap: () async {
                        if (!mounted) return;
                        final dbId = samplePoint.data['dbId'] as int?;
                        if (dbId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro: ID da parcela não encontrado.'))); return; }
                        final parcela = await DatabaseHelper.instance.getParcelaById(dbId);
                        if (!mounted || parcela == null) return;
                        final foiAtualizado = await Navigator.push<bool>(context, MaterialPageRoute(builder: (context) => ColetaDadosPage(parcelaParaEditar: parcela)));
                        if (foiAtualizado == true && mounted) {
                          await context.read<MapProvider>().loadSamplesFromTalhao(widget.talhao);
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 4, offset: const Offset(2, 2))]),
                        child: Center(child: Text(samplePoint.id.toString(), style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14))),
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (currentUserPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 80.0, height: 80.0, point: LatLng(currentUserPosition.latitude, currentUserPosition.longitude),
                      child: Transform.rotate(
                        angle: (currentUserPosition.heading * (3.1415926535897932 / 180)),
                        child: const Icon(Icons.navigation, color: Colors.blue, size: 40, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (mapProvider.isLoading)
            Container(color: Colors.black.withOpacity(0.5), child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text("Processando...", style: TextStyle(color: Colors.white, fontSize: 16))]))),
          
          if (!isDrawing)
            Positioned(
              top: 10,
              left: 10,
              child: Column(
                children: [
                   FloatingActionButton(
                     onPressed: _handleLocationButtonPressed,
                     tooltip: 'Minha Localização',
                     heroTag: 'centerLocationFab',
                     backgroundColor: mapProvider.isFollowingUser ? Colors.blue : Theme.of(context).colorScheme.primary,
                     foregroundColor: Colors.white,
                     child: Icon(mapProvider.isFollowingUser ? Icons.gps_fixed : Icons.gps_not_fixed),
                   ),
                   const SizedBox(height: 10),
                   FloatingActionButton(
                     onPressed: () => context.read<MapProvider>().switchMapLayer(),
                     tooltip: 'Mudar Camada do Mapa',
                     heroTag: 'switchLayerFab',
                     mini: true,
                     child: Icon(mapProvider.currentLayer == MapLayerType.ruas
                         ? Icons.satellite_outlined
                         : (mapProvider.currentLayer == MapLayerType.satelite
                             ? Icons.terrain
                             : Icons.map_outlined)),
                   ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: null, 
    );
  }
}