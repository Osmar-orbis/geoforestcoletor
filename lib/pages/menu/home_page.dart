// lib/pages/menu/home_page.dart

import 'package:flutter/material.dart';
import 'package:geoforestcoletor/pages/analises/analise_selecao_page.dart';
import 'package:geoforestcoletor/pages/menu/configuracoes_page.dart';
import 'package:geoforestcoletor/pages/menu/sobre_page.dart';
import 'package:geoforestcoletor/pages/projetos/lista_projetos_page.dart';
import 'package:geoforestcoletor/providers/map_provider.dart';
import 'package:geoforestcoletor/services/export_service.dart';
import 'package:geoforestcoletor/widgets/menu_card.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});
  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  void _abrirAnalistaDeDados(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AnaliseSelecaoPage()),
    );
  }

  void _mostrarDialogoExportacao(BuildContext context) {
  final exportService = ExportService();
  final mapProvider = context.read<MapProvider>();

  showModalBottomSheet(
    context: context,
    builder: (ctx) => Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
            child: Text('Escolha o que deseja exportar', style: Theme.of(context).textTheme.titleLarge),
          ),
          ListTile(
            leading: const Icon(Icons.table_rows_outlined, color: Colors.green),
            title: const Text('Coletas de Parcela (CSV)'),
            subtitle: const Text('Exporta os dados de parcelas e árvores.'),
            onTap: () {
              Navigator.of(ctx).pop();
              exportService.exportarDados(context); 
            },
          ),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined, color: Colors.brown),
            title: const Text('Cubagens Rigorosas (CSV)'),
            subtitle: const Text('Exporta os dados de cubagens e seções.'),
            onTap: () {
              Navigator.of(ctx).pop();
              // TODO: Implementar exportarCubagens no ExportService
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Função de exportar cubagens a ser implementada.')));
            },
          ),
          ListTile(
            leading: const Icon(Icons.map_outlined, color: Colors.purple),
            title: const Text('Projeto do Mapa (GeoJSON)'),
            subtitle: const Text('Exporta os polígonos e pontos do mapa atual.'),
            onTap: () {
              Navigator.of(ctx).pop();
              // A verificação estava um pouco diferente, vamos usar a que você tinha
              if (mapProvider.polygons.isEmpty && mapProvider.samplePoints.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não há projeto carregado no mapa para exportar.')));
                return;
              }
              exportService.exportProjectAsGeoJson(
                context: context,
                // CORREÇÃO: Usar os nomes corretos do seu MapProvider
                areaPolygons: mapProvider.polygons, // <-- CORREÇÃO AQUI
                samplePoints: mapProvider.samplePoints,
                farmName: mapProvider.currentTalhao?.fazendaNome ?? 'N/A', // <-- CORREÇÃO AQUI
                blockName: mapProvider.currentTalhao?.nome ?? 'N/A',       // <-- CORREÇÃO AQUI
              );
            },
          ),
        ],
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12.0,
          mainAxisSpacing: 12.0,
          childAspectRatio: 1.0,
          children: [
            MenuCard(
              icon: Icons.insights_outlined,
              label: 'GeoForest Analista',
              onTap: () => _abrirAnalistaDeDados(context),
            ),
            MenuCard(
              icon: Icons.folder_copy_outlined,
              label: 'Projetos',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ListaProjetosPage(title: 'Meus Projetos', isImporting: false),
                ),
              ),
            ),
            MenuCard(
              icon: Icons.upload_file_outlined,
              label: 'Exportar Dados',
              onTap: () => _mostrarDialogoExportacao(context),
            ),
            MenuCard(
              icon: Icons.download_for_offline_outlined,
              label: 'Importar Coletas',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ListaProjetosPage(title: 'Importar para...', isImporting: true),
                ),
              ),
            ),
            MenuCard(
              icon: Icons.settings_outlined,
              label: 'Configurações',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ConfiguracoesPage()),
              ),
            ),
            MenuCard(
              icon: Icons.info_outline,
              label: 'Sobre',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SobrePage()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}