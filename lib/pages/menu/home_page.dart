// lib/pages/menu/home_page.dart (VERSÃO COMPLETA E CORRIGIDA)

import 'package:flutter/material.dart';
import 'package:geoforestcoletor/pages/analises/analise_selecao_page.dart';
import 'package:geoforestcoletor/pages/menu/configuracoes_page.dart';
import 'package:geoforestcoletor/pages/projetos/lista_projetos_page.dart';
import 'package:geoforestcoletor/pages/planejamento/selecao_atividade_mapa_page.dart'; // <<< IMPORT ADICIONADO
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

    // Função interna para o sub-diálogo da coleta de parcelas
    void _mostrarDialogoParcelas(BuildContext mainDialogContext) {
      showDialog(
        context: mainDialogContext,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Tipo de Exportação de Coleta'),
          content: const Text(
              'Deseja exportar apenas os dados novos ou um backup completo de todas as coletas de parcela?'),
          actions: [
            TextButton(
              child: const Text('Apenas Novas'),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                exportService.exportarDados(context);
              },
            ),
            ElevatedButton(
              child: const Text('Todas (Backup)'),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                exportService.exportarTodasAsParcelasBackup(context);
              },
            ),
          ],
        ),
      );
    }

    // Função interna para o sub-diálogo da cubagem
    void _mostrarDialogoCubagem(BuildContext mainDialogContext) {
      showDialog(
        context: mainDialogContext,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Tipo de Exportação de Cubagem'),
          content: const Text(
              'Deseja exportar apenas os dados novos ou um backup completo de todas as cubagens?'),
          actions: [
            TextButton(
              child: const Text('Apenas Novas'),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                exportService.exportarNovasCubagens(context);
              },
            ),
            ElevatedButton(
              child: const Text('Todas (Backup)'),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                exportService.exportarTodasCubagensBackup(context);
              },
            ),
          ],
        ),
      );
    }

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
              child: Text('Escolha o que deseja exportar',
                  style: Theme.of(context).textTheme.titleLarge),
            ),

            // --- Opção 1: Coletas de Parcela (chama o sub-diálogo) ---
            ListTile(
              leading:
                  const Icon(Icons.table_rows_outlined, color: Colors.green),
              title: const Text('Coletas de Parcela (CSV)'),
              subtitle: const Text('Exporta os dados de parcelas e árvores.'),
              onTap: () {
                Navigator.of(ctx).pop(); // Fecha o menu principal
                _mostrarDialogoParcelas(
                    context); // Abre o diálogo de escolha para parcelas
              },
            ),

            // --- Opção 2: Cubagens (chama o sub-diálogo) ---
            ListTile(
              leading:
                  const Icon(Icons.table_chart_outlined, color: Colors.brown),
              title: const Text('Cubagens Rigorosas (CSV)'),
              subtitle: const Text('Exporta os dados de cubagens e seções.'),
              onTap: () {
                Navigator.of(ctx).pop(); // Fecha o menu principal
                _mostrarDialogoCubagem(
                    context); // Abre o diálogo de escolha para cubagens
              },
            ),

            const Divider(), // Separador visual

            // --- Opção 3: Mapa ---
            ListTile(
              leading: const Icon(Icons.map_outlined, color: Colors.purple),
              title: const Text('Projeto do Mapa (GeoJSON)'),
              subtitle:
                  const Text('Exporta os polígonos e pontos do mapa atual.'),
              onTap: () {
                Navigator.of(ctx).pop();
                if (mapProvider.polygons.isEmpty &&
                    mapProvider.samplePoints.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          'Não há projeto carregado no mapa para exportar.')));
                  return;
                }
                // ==========================================================
                // <<< CHAMADA CORRIGIDA AQUI >>>
                // Os parâmetros farmName e blockName foram removidos.
                // ==========================================================
                exportService.exportProjectAsGeoJson(
                  context: context,
                  areaPolygons: mapProvider.polygons,
                  samplePoints: mapProvider.samplePoints,
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
            // CARD PROJETOS (Mantido)
            MenuCard(
              icon: Icons.folder_copy_outlined,
              label: 'Projetos e Coletas',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ListaProjetosPage(title: 'Meus Projetos'),
                ),
              ),
            ),
            
            // NOVO CARD
            MenuCard(
              icon: Icons.map_outlined,
              label: 'Planejamento de Campo',
              onTap: () {
                // <<< NAVEGAÇÃO CORRIGIDA AQUI >>>
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            const SelecaoAtividadeMapaPage()));
              },
            ),

            // CARD ANALISTA (Mantido)
            MenuCard(
              icon: Icons.insights_outlined,
              label: 'GeoForest Analista',
              onTap: () => _abrirAnalistaDeDados(context),
            ),
            
            // CARD IMPORTAR (Movido e ajustado)
            MenuCard(
              icon: Icons.download_for_offline_outlined,
              label: 'Importar Coletas (CSV)',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ListaProjetosPage(title: 'Importar para...', isImporting: true),
                ),
              ),
            ),
            
            // CARD EXPORTAR (Movido)
            MenuCard(
              icon: Icons.upload_file_outlined,
              label: 'Exportar Dados',
              onTap: () => _mostrarDialogoExportacao(context),
            ),
            
            // CARD CONFIGURAÇÕES (Mantido)
            MenuCard(
              icon: Icons.settings_outlined,
              label: 'Configurações',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ConfiguracoesPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}