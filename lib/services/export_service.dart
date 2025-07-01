// lib/services/export_service.dart

import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
// Removi o import do flutter_archive que não estava sendo usado aqui para manter limpo.
import 'package:flutter_map/flutter_map.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/analise_result_model.dart';
import 'package:geoforestcoletor/models/arvore_model.dart';
import 'package:geoforestcoletor/models/parcela_model.dart';
import 'package:geoforestcoletor/models/sample_point.dart';
import 'package:geoforestcoletor/models/talhao_model.dart';
import 'package:geoforestcoletor/services/analysis_service.dart';
import 'package:geoforestcoletor/services/pdf_service.dart';
import 'package:geoforestcoletor/services/permission_service.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:proj4dart/proj4dart.dart' as proj4;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:geoforestcoletor/models/cubagem_arvore_model.dart';

class ExportService {
  
  // =========================================================================
  // <<< MÉTODO ORIGINAL (EXPORTAÇÃO PADRÃO) - SEM ALTERAÇÕES >>>
  // =========================================================================
  Future<void> exportarDados(BuildContext context) async {
    final dbHelper = DatabaseHelper.instance;
    final permissionService = PermissionService();

    final bool hasPermission = await permissionService.requestStoragePermission();
    if (!hasPermission) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Permissão de acesso ao armazenamento negada.'),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Buscando dados para exportação...')));

    try {
      // Usa o método antigo que busca apenas parcelas não exportadas
      final List<Parcela> parcelas = await dbHelper.getUnexportedConcludedParcelas();

      if (parcelas.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhuma parcela nova para exportar.'), backgroundColor: Colors.orange));
        }
        return;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gerando arquivo CSV...')));
      }

      final prefs = await SharedPreferences.getInstance();
      final nomeLider = prefs.getString('nome_lider') ?? 'N/A';
      final nomesAjudantes = prefs.getString('nomes_ajudantes') ?? 'N/A';
      final nomeZona = prefs.getString('zona_utm_selecionada') ?? 'SIRGAS 2000 / UTM Zona 22S';
      final codigoEpsg = zonasUtmSirgas2000[nomeZona]!;
      final projWGS84 = proj4.Projection.get('EPSG:4326')!;
      final projUTM = proj4.Projection.get('EPSG:$codigoEpsg')!;

      List<List<dynamic>> rows = [];
      rows.add(['Lider_Equipe', 'Ajudantes', 'ID_Db_Parcela', 'Codigo_Fazenda', 'Fazenda', 'Talhao', 'ID_Coleta_Parcela', 'Area_m2', 'Largura_m', 'Comprimento_m', 'Raio_m', 'Espacamento', 'Observacao_Parcela', 'Easting', 'Northing', 'Data_Coleta', 'Status_Parcela', 'Linha', 'Posicao_na_Linha', 'Fuste_Num', 'Codigo_Arvore', 'Codigo_Arvore_2', 'CAP_cm', 'Altura_m', 'Dominante']);
      
      final List<int> idsParaMarcar = [];

      for (var p in parcelas) {
        idsParaMarcar.add(p.dbId!);
        String easting = '', northing = '';
        if (p.latitude != null && p.longitude != null) {
          var pUtm = projWGS84.transform(projUTM, proj4.Point(x: p.longitude!, y: p.latitude!));
          easting = pUtm.x.toStringAsFixed(2);
          northing = pUtm.y.toStringAsFixed(2);
        }

        final arvores = await dbHelper.getArvoresDaParcela(p.dbId!);
        if (arvores.isEmpty) {
          rows.add([nomeLider, nomesAjudantes, p.dbId, p.idFazenda, p.nomeFazenda, p.nomeTalhao, p.idParcela, p.areaMetrosQuadrados, p.largura, p.comprimento, p.raio, p.espacamento, p.observacao, easting, northing, p.dataColeta?.toIso8601String(), p.status.name, null, null, null, null, null, null, null, null]);
        } else {
          Map<String, int> fusteCounter = {};
          for (final a in arvores) {
            String key = '${a.linha}-${a.posicaoNaLinha}';
            fusteCounter[key] = (fusteCounter[key] ?? 0) + 1;
            rows.add([nomeLider, nomesAjudantes, p.dbId, p.idFazenda, p.nomeFazenda, p.nomeTalhao, p.idParcela, p.areaMetrosQuadrados, p.largura, p.comprimento, p.raio, p.espacamento, p.observacao, easting, northing, p.dataColeta?.toIso8601String(), p.status.name, a.linha, a.posicaoNaLinha, fusteCounter[key], a.codigo.name, a.codigo2?.name, a.cap, a.altura, a.dominante ? 'Sim' : 'Não']);
          }
        }
      }

      final dir = await getApplicationDocumentsDirectory();
      final hoje = DateTime.now();
      final pastaData = DateFormat('yyyy-MM-dd').format(hoje);
      final pastaDia = Directory('${dir.path}/$pastaData');
      if (!await pastaDia.exists()) await pastaDia.create(recursive: true);
      
      // Nome padrão do arquivo
      final fName = 'geoforest_export_coleta_${DateFormat('HH-mm-ss').format(hoje)}.csv';
      final path = '${pastaDia.path}/$fName';
      
      await File(path).writeAsString(const ListToCsvConverter().convert(rows));
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        await Share.shareXFiles([XFile(path)], subject: 'Exportação GeoForest - Coleta de Campo');
        // Ao final, marca as parcelas como exportadas
        await dbHelper.marcarParcelasComoExportadas(idsParaMarcar);
      }
    } catch (e, s) {
      debugPrint('Erro na exportação de dados: $e\n$s');
      if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha na exportação: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
  }

  // =========================================================================
  // <<< NOVO MÉTODO PARA O BACKUP COMPLETO >>>
  // =========================================================================
  Future<void> exportarTodasAsParcelasBackup(BuildContext context) async {
    final dbHelper = DatabaseHelper.instance;
    final permissionService = PermissionService();

    final bool hasPermission = await permissionService.requestStoragePermission();
    if (!hasPermission) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Permissão de acesso ao armazenamento negada.'),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Buscando dados para o backup completo...')));

    try {
      // *** 1. CHAMA O NOVO MÉTODO DO BANCO DE DADOS ***
      final List<Parcela> parcelas = await dbHelper.getTodasAsParcelasConcluidasParaBackup();

      if (parcelas.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhuma parcela concluída encontrada para o backup.'), backgroundColor: Colors.orange));
        }
        return;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gerando arquivo de backup...')));
      }

      // O resto da lógica de gerar o CSV é idêntica
      final prefs = await SharedPreferences.getInstance();
      final nomeLider = prefs.getString('nome_lider') ?? 'N/A';
      final nomesAjudantes = prefs.getString('nomes_ajudantes') ?? 'N/A';
      final nomeZona = prefs.getString('zona_utm_selecionada') ?? 'SIRGAS 2000 / UTM Zona 22S';
      final codigoEpsg = zonasUtmSirgas2000[nomeZona]!;
      final projWGS84 = proj4.Projection.get('EPSG:4326')!;
      final projUTM = proj4.Projection.get('EPSG:$codigoEpsg')!;

      List<List<dynamic>> rows = [];
      rows.add(['Lider_Equipe', 'Ajudantes', 'ID_Db_Parcela', 'Codigo_Fazenda', 'Fazenda', 'Talhao', 'ID_Coleta_Parcela', 'Area_m2', 'Largura_m', 'Comprimento_m', 'Raio_m', 'Espacamento', 'Observacao_Parcela', 'Easting', 'Northing', 'Data_Coleta', 'Status_Parcela', 'Linha', 'Posicao_na_Linha', 'Fuste_Num', 'Codigo_Arvore', 'Codigo_Arvore_2', 'CAP_cm', 'Altura_m', 'Dominante']);
      
      for (var p in parcelas) {
        String easting = '', northing = '';
        if (p.latitude != null && p.longitude != null) {
          var pUtm = projWGS84.transform(projUTM, proj4.Point(x: p.longitude!, y: p.latitude!));
          easting = pUtm.x.toStringAsFixed(2);
          northing = pUtm.y.toStringAsFixed(2);
        }

        final arvores = await dbHelper.getArvoresDaParcela(p.dbId!);
        if (arvores.isEmpty) {
          rows.add([nomeLider, nomesAjudantes, p.dbId, p.idFazenda, p.nomeFazenda, p.nomeTalhao, p.idParcela, p.areaMetrosQuadrados, p.largura, p.comprimento, p.raio, p.espacamento, p.observacao, easting, northing, p.dataColeta?.toIso8601String(), p.status.name, null, null, null, null, null, null, null, null]);
        } else {
          Map<String, int> fusteCounter = {};
          for (final a in arvores) {
            String key = '${a.linha}-${a.posicaoNaLinha}';
            fusteCounter[key] = (fusteCounter[key] ?? 0) + 1;
            rows.add([nomeLider, nomesAjudantes, p.dbId, p.idFazenda, p.nomeFazenda, p.nomeTalhao, p.idParcela, p.areaMetrosQuadrados, p.largura, p.comprimento, p.raio, p.espacamento, p.observacao, easting, northing, p.dataColeta?.toIso8601String(), p.status.name, a.linha, a.posicaoNaLinha, fusteCounter[key], a.codigo.name, a.codigo2?.name, a.cap, a.altura, a.dominante ? 'Sim' : 'Não']);
          }
        }
      }

      final dir = await getApplicationDocumentsDirectory();
      final hoje = DateTime.now();
      final pastaData = DateFormat('yyyy-MM-dd').format(hoje);
      final pastaDia = Directory('${dir.path}/$pastaData');
      if (!await pastaDia.exists()) await pastaDia.create(recursive: true);
      
      // *** 2. NOME DO ARQUIVO DIFERENTE ***
      final fName = 'geoforest_BACKUP_COMPLETO_${DateFormat('HH-mm-ss').format(hoje)}.csv';
      final path = '${pastaDia.path}/$fName';
      
      await File(path).writeAsString(const ListToCsvConverter().convert(rows));
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        await Share.shareXFiles([XFile(path)], subject: 'Backup Completo GeoForest');
        // *** 3. NÃO MARCA AS PARCELAS COMO EXPORTADAS ***
      }
    } catch (e, s) {
      debugPrint('Erro no backup completo: $e\n$s');
      if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha no backup: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> exportarProjetosCompletos({
    required BuildContext context,
    required List<int> projetoIds,
  }) async {
    if (projetoIds.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preparando dados para exportação...')));

    try {
      final dbHelper = DatabaseHelper.instance;
      final List<Map<String, dynamic>> features = [];

      for (final projetoId in projetoIds) {
        final projeto = await dbHelper.getProjetoById(projetoId);
        if (projeto == null) continue;

        final atividades = await dbHelper.getAtividadesDoProjeto(projetoId);
        for (final atividade in atividades) {
          final fazendas =
              await dbHelper.getFazendasDaAtividade(atividade.id!);
          for (final fazenda in fazendas) {
            final talhoes = await dbHelper.getTalhoesDaFazenda(
                fazenda.id, fazenda.atividadeId);
            for (final talhao in talhoes) {
              final parcelas = await dbHelper.getParcelasDoTalhao(talhao.id!);
              for (final parcela in parcelas) {
                features.add({
                  'type': 'Feature',
                  'geometry': parcela.latitude != null
                      ? {
                          'type': 'Point',
                          'coordinates': [parcela.longitude, parcela.latitude],
                        }
                      : null,
                  'properties': {
                    'tipo_feature': 'parcela_planejada',
                    'projeto_nome': projeto.nome,
                    'projeto_empresa': projeto.empresa,
                    'projeto_responsavel': projeto.responsavel,
                    'atividade_tipo': atividade.tipo,
                    'atividade_descricao': atividade.descricao,
                    'fazenda_id': fazenda.id,
                    'fazenda_nome': fazenda.nome,
                    'fazenda_municipio': fazenda.municipio,
                    'fazenda_estado': fazenda.estado,
                    'talhao_nome': talhao.nome,
                    'talhao_especie': talhao.especie,
                    'talhao_area_ha': talhao.areaHa,
                    'talhao_idade_anos': talhao.idadeAnos,
                    'parcela_id_plano': parcela.idParcela,
                    'parcela_area_m2': parcela.areaMetrosQuadrados,
                    'parcela_espacamento': parcela.espacamento,
                    'parcela_status_inicial': parcela.status.name,
                  }
                });
              }
            }
          }
        }
      }

      if (features.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Nenhuma parcela encontrada nos projetos selecionados para exportar.'),
            backgroundColor: Colors.orange,
          ));
        }
        return;
      }

      final Map<String, dynamic> geoJson = {
        'type': 'FeatureCollection',
        'features': features,
      };

      const jsonEncoder = JsonEncoder.withIndent('  ');
      final geoJsonString = jsonEncoder.convert(geoJson);

      final directory = await getApplicationDocumentsDirectory();
      final hoje = DateTime.now();
      final fName =
          'Exportacao_Projetos_GeoForest_${DateFormat('yyyyMMdd_HHmm').format(hoje)}.geojson';
      final path = '${directory.path}/$fName';

      await File(path).writeAsString(geoJsonString);

      if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        await Share.shareXFiles(
          [XFile(path)],
          subject: 'Carga de Projeto GeoForest',
        );
      }
    } catch (e, s) {
      debugPrint('Erro na exportação de projeto: $e\n$s');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Falha na exportação: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<void> exportProjectAsGeoJson({
    required BuildContext context,
    required List<Polygon> areaPolygons,
    required List<SamplePoint> samplePoints,
    required String farmName,
    required String blockName,
  }) async {
    final List<SamplePoint> pontosConcluidos = samplePoints
        .where((ponto) => ponto.status == SampleStatus.completed)
        .toList();

    if (areaPolygons.isEmpty && pontosConcluidos.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nenhuma área ou amostra concluída para exportar.'),
          backgroundColor: Colors.orange,
        ));
      }
      return;
    }

    if (areaPolygons.isNotEmpty && pontosConcluidos.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Aviso: Nenhuma amostra concluída foi encontrada. Exportando apenas a área do projeto.'),
          backgroundColor: Colors.orange,
        ));
      }
    }

    try {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gerando arquivo GeoJSON...')));
      }

      final Map<String, dynamic> geoJson = {
        'type': 'FeatureCollection',
        'features': <Map<String, dynamic>>[],
      };

      for (final polygon in areaPolygons) {
        final coordinates =
            polygon.points.map((p) => [p.longitude, p.latitude]).toList();
        geoJson['features'].add({
          'type': 'Feature',
          'geometry': {'type': 'Polygon', 'coordinates': [coordinates]},
          'properties': {
            'type': 'area',
            'farmName': farmName,
            'blockName': blockName
          },
        });
      }

      for (final point in pontosConcluidos) {
        geoJson['features'].add({
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [point.position.longitude, point.position.latitude],
          },
          'properties': {
            'type': 'plot',
            'id': point.id,
            'status': point.status.name,
          },
        });
      }

      const jsonEncoder = JsonEncoder.withIndent('  ');
      final geoJsonString = jsonEncoder.convert(geoJson);

      final directory = await getApplicationDocumentsDirectory();
      final hoje = DateTime.now();
      final nomePastaData = DateFormat('yyyy-MM-dd').format(hoje);
      final pastaDoDia = Directory('${directory.path}/$nomePastaData');
      if (!await pastaDoDia.exists()) await pastaDoDia.create(recursive: true);

      final fileName =
          'Projeto_${farmName.replaceAll(' ', '_')}_${blockName.replaceAll(' ', '_')}.geojson';
      final path = '${pastaDoDia.path}/$fileName';

      await File(path).writeAsString(geoJsonString);

      if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        await Share.shareXFiles(
          [XFile(path)],
          subject: 'Projeto de Amostragem GeoForest: $farmName - $blockName',
        );
      }
    } catch (e, s) {
      debugPrint('Erro na exportação para GeoJSON: $e\n$s');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Falha na exportação: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<void> exportarAnaliseTalhaoCsv({
    required BuildContext context,
    required Talhao talhao,
    required TalhaoAnalysisResult analise,
  }) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gerando arquivo CSV...')));

      List<List<dynamic>> rows = [];

      rows.add(['Resumo do Talhão']);
      rows.add(['Métrica', 'Valor']);
      rows.add(['Fazenda', talhao.fazendaNome ?? 'N/A']);
      rows.add(['Talhão', talhao.nome]);
      rows.add(['Nº de Parcelas Amostradas', analise.totalParcelasAmostradas]);
      rows.add(['Nº de Árvores Medidas', analise.totalArvoresAmostradas]);
      rows.add([
        'Área Total Amostrada (ha)',
        analise.areaTotalAmostradaHa.toStringAsFixed(4)
      ]);
      rows.add(['']);
      rows.add(['Resultados por Hectare']);
      rows.add(['Métrica', 'Valor']);
      rows.add(['Árvores / ha', analise.arvoresPorHectare]);
      rows.add([
        'Área Basal (G) m²/ha',
        analise.areaBasalPorHectare.toStringAsFixed(2)
      ]);
      rows.add([
        'Volume Estimado m³/ha',
        analise.volumePorHectare.toStringAsFixed(2)
      ]);
      rows.add(['']);
      rows.add(['Estatísticas da Amostra']);
      rows.add(['Métrica', 'Valor']);
      rows.add(['CAP Médio (cm)', analise.mediaCap.toStringAsFixed(1)]);
      rows.add(['Altura Média (m)', analise.mediaAltura.toStringAsFixed(1)]);
      rows.add(['']);

      rows.add(['Distribuição Diamétrica (CAP)']);
      rows.add(['Classe (cm)', 'Nº de Árvores', '%']);

      final totalArvoresVivas =
          analise.distribuicaoDiametrica.values.fold(0, (a, b) => a + b);

      analise.distribuicaoDiametrica.forEach((pontoMedio, contagem) {
        final inicioClasse = pontoMedio - 2.5;
        final fimClasse = pontoMedio + 2.5 - 0.1;
        final porcentagem =
            totalArvoresVivas > 0 ? (contagem / totalArvoresVivas) * 100 : 0;
        rows.add([
          '${inicioClasse.toStringAsFixed(1)} - ${fimClasse.toStringAsFixed(1)}',
          contagem,
          '${porcentagem.toStringAsFixed(1)}%',
        ]);
      });

      final dir = await getApplicationDocumentsDirectory();
      final hoje = DateTime.now();
      final fName =
          'analise_talhao_${talhao.nome}_${DateFormat('yyyy-MM-dd_HH-mm').format(hoje)}.csv';
      final path = '${dir.path}/$fName';

      final csvData = const ListToCsvConverter().convert(rows);
      await File(path).writeAsString(csvData, encoding: utf8);

      if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        await Share.shareXFiles([XFile(path)],
            subject: 'Análise do Talhão ${talhao.nome}');
      }
    } catch (e, s) {
      debugPrint('Erro ao exportar análise CSV: $e\n$s');
      if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Falha na exportação: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
    }
  }
  
  Future<void> exportarAmostrasComoGeoJson({
    required BuildContext context,
    required List<Talhao> talhoes,
  }) async {
    if (talhoes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Nenhum talhão selecionado para exportar.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gerando arquivo GeoJSON...')));

    try {
      final dbHelper = DatabaseHelper.instance;
      List<Map<String, dynamic>> features = [];

      for (final talhao in talhoes) {
        final parcelas = await dbHelper.getParcelasDoTalhao(talhao.id!);
        for (final parcela in parcelas) {
          if (parcela.latitude != null && parcela.longitude != null) {
            features.add({
              'type': 'Feature',
              'geometry': {
                'type': 'Point',
                'coordinates': [parcela.longitude, parcela.latitude],
              },
              'properties': {
                'tipo_feature': 'parcela_coletada',
                'fazenda_nome': talhao.fazendaNome,
                'talhao_nome': talhao.nome,
                'parcela_id': parcela.idParcela,
                'status': parcela.status.name,
                'data_coleta': parcela.dataColeta?.toIso8601String(),
              },
            });
          }
        }
      }

      if (features.isEmpty) {
         if (context.mounted) {
           ScaffoldMessenger.of(context).removeCurrentSnackBar();
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
             content: Text('Nenhuma parcela com coordenadas geográficas encontrada para exportar.'),
             backgroundColor: Colors.orange,
           ));
         }
         return;
      }
      
      final Map<String, dynamic> geoJson = {
        'type': 'FeatureCollection',
        'features': features,
      };

      const jsonEncoder = JsonEncoder.withIndent('  ');
      final geoJsonString = jsonEncoder.convert(geoJson);

      final directory = await getApplicationDocumentsDirectory();
      final hoje = DateTime.now();
      final fName = 'exportacao_analise_amostras_${DateFormat('yyyyMMdd_HHmm').format(hoje)}.geojson';
      final path = '${directory.path}/$fName';

      await File(path).writeAsString(geoJsonString);

      if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        await Share.shareXFiles(
          [XFile(path)],
          subject: 'Exportação de Amostras (GeoJSON) - GeoForest',
        );
      }
    } catch (e, s) {
      debugPrint('Erro na exportação para GeoJSON: $e\n$s');
      if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Falha na exportação GeoJSON: ${e.toString()}'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> exportarTudoComoZip({
    required BuildContext context,
    required List<Talhao> talhoes,
  }) async {
    if (talhoes.isEmpty) return;

    final dbHelper = DatabaseHelper.instance;
    final List<int> talhaoIds = talhoes.map((t) => t.id!).toList();

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Iniciando exportação completa...'),
      duration: Duration(seconds: 20),
    ));

    try {
      final directory = await getApplicationDocumentsDirectory();
      final hoje = DateTime.now();
      final nomePasta = 'Exportacao_Completa_${DateFormat('yyyy-MM-dd_HH-mm').format(hoje)}';
      final pastaDeExportacao = Directory('${directory.path}/$nomePasta');
      if (await pastaDeExportacao.exists()) {
        await pastaDeExportacao.delete(recursive: true);
      }
      await pastaDeExportacao.create(recursive: true);

      await _gerarCsvParcelas(dbHelper, talhaoIds, '${pastaDeExportacao.path}/parcelas_coletadas.csv');
      await _gerarCsvCubagens(dbHelper, talhaoIds, '${pastaDeExportacao.path}/cubagens_realizadas.csv');
      await _gerarGeoJsonAmostras(dbHelper, talhoes, '${pastaDeExportacao.path}/amostras_coletadas.geojson');
      
      await exportarAnalisesPdf(
        context: context, 
        talhoes: talhoes,
        outputDirectoryPath: pastaDeExportacao.path,
      );

      final zipFilePath = '${directory.path}/$nomePasta.zip';
      final zipFile = File(zipFilePath);
      
      await ZipFile.createFromDirectory(sourceDir: pastaDeExportacao, zipFile: zipFile, recurseSubDirs: true);

      if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        await Share.shareXFiles([XFile(zipFilePath)], subject: 'Exportação Completa - GeoForest');
      }

    } catch (e, s) {
      debugPrint('Erro ao criar arquivo ZIP: $e\n$s');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Falha ao gerar pacote de exportação: ${e.toString()}'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _gerarCsvParcelas(DatabaseHelper dbHelper, List<int> talhaoIds, String outputPath) async {
    final String whereClause = 'talhaoId IN (${List.filled(talhaoIds.length, '?').join(',')}) AND status = ?';
    final List<dynamic> whereArgs = [...talhaoIds, StatusParcela.concluida.name];
    final List<Map<String, dynamic>> parcelasMaps = await (await dbHelper.database).query('parcelas', where: whereClause, whereArgs: whereArgs);

    if (parcelasMaps.isEmpty) return;

    List<List<dynamic>> rows = [];
    rows.add(['ID_Db_Parcela', 'Codigo_Fazenda', 'Fazenda', 'Talhao', 'ID_Coleta_Parcela', 'Area_m2', 'Espacamento', 'Linha', 'Posicao_na_Linha', 'Codigo_Arvore', 'CAP_cm', 'Altura_m', 'Dominante']);
    
    for (var pMap in parcelasMaps) {
      final arvores = await dbHelper.getArvoresDaParcela(pMap['id'] as int);
      for (final a in arvores) {
        rows.add([pMap['id'], pMap['idFazenda'], pMap['nomeFazenda'], pMap['nomeTalhao'], pMap['idParcela'], pMap['areaMetrosQuadrados'], pMap['espacamento'], a.linha, a.posicaoNaLinha, a.codigo.name, a.cap, a.altura, a.dominante ? 'Sim' : 'Não']);
      }
    }
    
    await File(outputPath).writeAsString(const ListToCsvConverter().convert(rows));
  }

  Future<void> _gerarCsvCubagens(DatabaseHelper dbHelper, List<int> talhaoIds, String outputPath) async {
    final String whereClause = 'talhaoId IN (${List.filled(talhaoIds.length, '?').join(',')})';
    final List<Map<String, dynamic>> arvoresMaps = await (await dbHelper.database).query('cubagens_arvores', where: whereClause, whereArgs: talhaoIds);

    if (arvoresMaps.isEmpty) return;

    List<List<dynamic>> rows = [];
    rows.add(['id_fazenda', 'fazenda', 'talhao', 'identificador_arvore', 'altura_total_m', 'cap_cm', 'altura_medicao_m', 'circunferencia_cm', 'casca1_mm', 'casca2_mm']);
    
    for (var aMap in arvoresMaps) {
      final secoes = await dbHelper.getSecoesPorArvoreId(aMap['id'] as int);
      for (var s in secoes) {
        rows.add([aMap['id_fazenda'], aMap['nome_fazenda'], aMap['nome_talhao'], aMap['identificador'], aMap['alturaTotal'], aMap['valorCAP'], s.alturaMedicao, s.circunferencia, s.casca1_mm, s.casca2_mm]);
      }
    }
    await File(outputPath).writeAsString(const ListToCsvConverter().convert(rows));
  }

  Future<void> _gerarGeoJsonAmostras(DatabaseHelper dbHelper, List<Talhao> talhoes, String outputPath) async {
      List<Map<String, dynamic>> features = [];

      for (final talhao in talhoes) {
        final parcelas = await dbHelper.getParcelasDoTalhao(talhao.id!);
        for (final parcela in parcelas) {
          if (parcela.latitude != null && parcela.longitude != null) {
            features.add({
              'type': 'Feature',
              'geometry': {'type': 'Point', 'coordinates': [parcela.longitude, parcela.latitude]},
              'properties': {'talhao_nome': talhao.nome, 'parcela_id': parcela.idParcela, 'status': parcela.status.name}
            });
          }
        }
      }

      if (features.isEmpty) return;
      
      final Map<String, dynamic> geoJson = {'type': 'FeatureCollection', 'features': features};
      const jsonEncoder = JsonEncoder.withIndent('  ');
      final geoJsonString = jsonEncoder.convert(geoJson);
      await File(outputPath).writeAsString(geoJsonString);
  }

  Future<void> exportarAnalisesPdf({
    required BuildContext context,
    required List<Talhao> talhoes,
    String? outputDirectoryPath,
  }) async {
    final pdfService = PdfService();
    final dbHelper = DatabaseHelper.instance;
    final analysisService = AnalysisService();

    if (outputDirectoryPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Gerando relatórios em PDF...'),
        duration: Duration(seconds: 10),
      ));
    }

    try {
      String finalExportPath;

      if (outputDirectoryPath != null) {
        finalExportPath = outputDirectoryPath;
      } else {
        final downloadsDirectory = await pdfService.getDownloadsDirectory();
        if (downloadsDirectory == null) throw Exception("Pasta de downloads não encontrada.");

        final hoje = DateTime.now();
        final nomePasta = 'Relatorios_Analise_${DateFormat('yyyy-MM-dd_HH-mm').format(hoje)}';
        finalExportPath = '${downloadsDirectory.path}/GeoForest/Relatorios/$nomePasta';
        await Directory(finalExportPath).create(recursive: true);
      }

      int arquivosGerados = 0;

      for (final talhao in talhoes) {
        final dadosAgregados = await dbHelper.getDadosAgregadosDoTalhao(talhao.id!);
        final parcelasConcluidas = dadosAgregados['parcelas'] as List<Parcela>;
        final arvores = dadosAgregados['arvores'] as List<Arvore>;

        if (parcelasConcluidas.isEmpty || arvores.isEmpty) {
          debugPrint("Pulando Talhão ${talhao.nome} por falta de dados concluídos.");
          continue;
        }

        final analise = analysisService.getTalhaoInsights(parcelasConcluidas, arvores);
        await pdfService.gerarRelatorioAnalisePdf(talhao, analise, finalExportPath);
        arquivosGerados++;
      }
      
      if (outputDirectoryPath == null) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        if (arquivosGerados > 0) {
          await showDialog(
              context: context, 
              builder: (ctx) => AlertDialog(
                title: const Text('Exportação Concluída'),
                content: Text('$arquivosGerados relatórios em PDF foram salvos na pasta. Deseja abri-la?'),
                actions: [
                  TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Fechar')),
                  FilledButton(onPressed: (){
                    OpenFile.open(finalExportPath);
                    Navigator.of(ctx).pop();
                  }, child: const Text('Abrir Pasta')),
                ],
              )
            );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Nenhum relatório foi gerado. Verifique os dados dos talhões.'),
            backgroundColor: Colors.orange,
          ));
        }
      }

    } catch (e) {
      debugPrint("Erro ao exportar múltiplos PDFs: $e");
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erro na exportação: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _gerarCsvCubagem(BuildContext context, List<CubagemArvore> cubagens, String nomeArquivo, bool marcarComoExportado) async {
    final dbHelper = DatabaseHelper.instance;

    if (cubagens.isEmpty) {
        if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhuma cubagem encontrada para exportar.'), backgroundColor: Colors.orange));
        }
        return;
    }

    if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gerando CSV de cubagens...')));
    }

    List<List<dynamic>> rows = [];
    rows.add(['id_db_arvore', 'id_fazenda', 'fazenda', 'talhao', 'identificador_arvore', 'classe', 'altura_total_m', 'tipo_medida_cap', 'valor_cap', 'altura_base_m', 'altura_medicao_secao_m', 'circunferencia_secao_cm', 'casca1_mm', 'casca2_mm', 'dsc_cm']);

    final List<int> idsParaMarcar = [];

    for (var arvore in cubagens) {
        if (marcarComoExportado) {
            idsParaMarcar.add(arvore.id!);
        }
        final secoes = await dbHelper.getSecoesPorArvoreId(arvore.id!);
        if (secoes.isEmpty) {
            rows.add([arvore.id, arvore.idFazenda, arvore.nomeFazenda, arvore.nomeTalhao, arvore.identificador, arvore.classe, arvore.alturaTotal, arvore.tipoMedidaCAP, arvore.valorCAP, arvore.alturaBase, null, null, null, null, null]);
        } else {
            for (var secao in secoes) {
                rows.add([arvore.id, arvore.idFazenda, arvore.nomeFazenda, arvore.nomeTalhao, arvore.identificador, arvore.classe, arvore.alturaTotal, arvore.tipoMedidaCAP, arvore.valorCAP, arvore.alturaBase, secao.alturaMedicao, secao.circunferencia, secao.casca1_mm, secao.casca2_mm, secao.diametroSemCasca.toStringAsFixed(2)]);
            }
        }
    }

    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/$nomeArquivo';
    
    await File(path).writeAsString(const ListToCsvConverter().convert(rows));

    if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        await Share.shareXFiles([XFile(path)], subject: 'Exportação de Cubagens GeoForest');
        if (marcarComoExportado) {
            await dbHelper.marcarCubagensComoExportadas(idsParaMarcar);
        }
    }
}

/// Exporta apenas as cubagens novas (não exportadas).
Future<void> exportarNovasCubagens(BuildContext context) async {
    final dbHelper = DatabaseHelper.instance;
    try {
        final cubagens = await dbHelper.getUnexportedCubagens();
        final hoje = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
        final nomeArquivo = 'geoforest_export_cubagens_$hoje.csv';
        await _gerarCsvCubagem(context, cubagens, nomeArquivo, true);
    } catch (e) {
        if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao exportar cubagens: $e'), backgroundColor: Colors.red));
    }
}

/// Exporta TODAS as cubagens como backup.
Future<void> exportarTodasCubagensBackup(BuildContext context) async {
    final dbHelper = DatabaseHelper.instance;
    try {
        final cubagens = await dbHelper.getTodasCubagensParaBackup();
        final hoje = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
        final nomeArquivo = 'geoforest_BACKUP_CUBAGENS_$hoje.csv';
        await _gerarCsvCubagem(context, cubagens, nomeArquivo, false);
    } catch (e) {
        if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro no backup de cubagens: $e'), backgroundColor: Colors.red));
    }
}
}