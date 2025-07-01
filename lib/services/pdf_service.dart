// lib/services/pdf_service.dart (VERSÃO CORRETA E COMPLETA)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/talhao_model.dart';
import 'package:geoforestcoletor/services/analysis_service.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_android/path_provider_android.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';

// Importa o novo arquivo de modelo
import 'package:geoforestcoletor/models/analise_result_model.dart';


class PdfService {

  Future<bool> _requestPermission() async {
    Permission permission;
    if (Platform.isAndroid) {
      permission = Permission.manageExternalStorage;
    } else {
      permission = Permission.storage;
    }
    if (await permission.isGranted) return true;
    var result = await permission.request();
    return result == PermissionStatus.granted;
  }
  
  Future<Directory?> getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      final PathProviderAndroid provider = PathProviderAndroid();
      final String? path = await provider.getDownloadsPath();
      if (path != null) return Directory(path);
      return null;
    }
    return await getApplicationDocumentsDirectory();
  }

  Future<void> _salvarEAbriPdf(BuildContext context, pw.Document pdf, String nomeArquivo) async {
    try {
      if (!await _requestPermission()) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permissão de armazenamento negada.'), backgroundColor: Colors.red));
        return;
      }
      final downloadsDirectory = await getDownloadsDirectory();
      if (downloadsDirectory == null) {
         if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível encontrar a pasta de Downloads.'), backgroundColor: Colors.red));
         return;
      }
      
      final relatoriosDir = Directory('${downloadsDirectory.path}/GeoForest/Relatorios');
      if (!await relatoriosDir.exists()) await relatoriosDir.create(recursive: true);
      
      final path = '${relatoriosDir.path}/$nomeArquivo';
      final file = File(path);
      await file.writeAsBytes(await pdf.save());

      if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        await showDialog(
          context: context, 
          builder: (ctx) => AlertDialog(
            title: const Text('Exportação Concluída'),
            content: Text('O relatório foi salvo em: ${relatoriosDir.path}. Deseja abri-lo?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Fechar')),
              FilledButton(onPressed: (){
                OpenFile.open(path);
                Navigator.of(ctx).pop();
              }, child: const Text('Abrir Arquivo')),
            ],
          )
        );
      }
    } catch (e) {
      debugPrint("Erro ao salvar/abrir PDF: $e");
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao gerar o PDF: $e')));
    }
  }

  Future<void> gerarRelatorioAnalisePdf(Talhao talhao, TalhaoAnalysisResult analise, String diretorioDeSaida) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (pw.Context ctx) => _buildHeader(talhao.fazendaNome ?? 'N/A', talhao.nome),
        footer: (pw.Context ctx) => _buildFooter(),
        build: (pw.Context ctx) {
          return [
            pw.Text('Análise de Talhão', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16), textAlign: pw.TextAlign.center),
            pw.Divider(height: 20),
            _buildResumoTalhaoPdf(analise),
            pw.SizedBox(height: 20),
            pw.Text('Distribuição Diamétrica (CAP)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.SizedBox(height: 10),
            _buildTabelaDistribuicaoPdf(analise),
          ];
        },
      ),
    );
    final nomeArquivo = 'Analise_${talhao.nome.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.pdf';
    final path = '$diretorioDeSaida/$nomeArquivo';
    final file = File(path);
    await file.writeAsBytes(await pdf.save());
  }
  
  Future<void> gerarRelatorioUnificadoPdf({
    required BuildContext context,
    required List<Talhao> talhoes,
  }) async {
    if (talhoes.isEmpty) return;
    
    final analysisService = AnalysisService();
    final dbHelper = DatabaseHelper.instance;
    final pdf = pw.Document(); 
    int talhoesProcessados = 0;

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Gerando relatório unificado...'),
      duration: Duration(seconds: 15),
    ));

    for (final talhao in talhoes) {
      final dadosAgregados = await dbHelper.getDadosAgregadosDoTalhao(talhao.id!);
      final parcelas = dadosAgregados['parcelas'];
      final arvores = dadosAgregados['arvores'];

      if (parcelas.isEmpty || arvores.isEmpty) {
        continue;
      }
      
      final analiseGeral = analysisService.getTalhaoInsights(parcelas, arvores);
      final rendimentoData = analysisService.analisarRendimentoPorDAP(parcelas, arvores);
      
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          header: (pw.Context ctx) => _buildHeader(talhao.fazendaNome ?? 'N/A', talhao.nome),
          footer: (pw.Context ctx) => _buildFooter(),
          build: (pw.Context ctx) {
            return [
              pw.Text('Análise do Talhão', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16), textAlign: pw.TextAlign.center),
              pw.Divider(height: 20),
              _buildResumoTalhaoPdf(analiseGeral),
              pw.SizedBox(height: 20),
              pw.Text('Distribuição Diamétrica (CAP)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
              pw.SizedBox(height: 10),
              _buildTabelaDistribuicaoPdf(analiseGeral),
              if (rendimentoData.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Text('Rendimento Comercial por Classe de DAP', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                pw.SizedBox(height: 10),
                _buildTabelaRendimentoPdf(rendimentoData),
              ],
            ];
          },
        ),
      );
      talhoesProcessados++;
    }

    if (talhoesProcessados == 0) {
      if(context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nenhum talhão com dados para gerar relatório.'),
          backgroundColor: Colors.orange,
        ));
      }
      return;
    }
    
    final hoje = DateTime.now();
    final nomeArquivo = 'Relatorio_Comparativo_GeoForest_${DateFormat('yyyy-MM-dd_HH-mm').format(hoje)}.pdf';
    await _salvarEAbriPdf(context, pdf, nomeArquivo);
  }

  Future<void> gerarPlanoCubagemPdf({
    required BuildContext context,
    required String nomeFazenda,
    required String nomeTalhao,
    required Map<String, int> planoDeCubagem,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (pw.Context context) => _buildHeader(nomeFazenda, nomeTalhao),
        footer: (pw.Context context) => _buildFooter(),
        build: (pw.Context context) {
          return [
            pw.SizedBox(height: 20),
            pw.Text(
              'Plano de Cubagem Estratificada por Classe Diamétrica',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
              textAlign: pw.TextAlign.center,
            ),
            pw.Divider(height: 20),
            _buildTabelaPlano(planoDeCubagem),
          ];
        },
      ),
    );
    await _salvarEAbriPdf(context, pdf,
        'plano_cubagem_${nomeTalhao.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.pdf');
  }

  Future<void> gerarRelatorioRendimentoPdf({
    required BuildContext context,
    required String nomeFazenda,
    required String nomeTalhao,
    required List<RendimentoDAP> dadosRendimento,
    required TalhaoAnalysisResult analiseGeral,
    required pw.ImageProvider graficoImagem,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (pw.Context context) => _buildHeader(nomeFazenda, nomeTalhao),
        footer: (pw.Context context) => _buildFooter(),
        build: (pw.Context context) {
          return [
            pw.Text(
              'Relatório de Rendimento Comercial por Classe Diamétrica',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
              textAlign: pw.TextAlign.center,
            ),
            pw.Divider(height: 20),
            _buildResumoTalhaoPdf(analiseGeral),
            pw.SizedBox(height: 20),
            pw.Center(
              child: pw.SizedBox(
                width: 400,
                child: pw.Image(graficoImagem),
              ),
            ),
            pw.SizedBox(height: 20),
            _buildTabelaRendimentoPdf(dadosRendimento),
          ];
        },
      ),
    );
    final nomeArquivo =
        'relatorio_rendimento_${nomeTalhao.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.pdf';
    await _salvarEAbriPdf(context, pdf, nomeArquivo);
  }

  pw.Widget _buildHeader(String nomeFazenda, String nomeTalhao) {
    return pw.Container(
      alignment: pw.Alignment.centerLeft,
      margin: const pw.EdgeInsets.only(bottom: 20.0),
      padding: const pw.EdgeInsets.only(bottom: 8.0),
      decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey, width: 2))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('GeoForest Coletor',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 20)),
              pw.SizedBox(height: 5),
              pw.Text('Fazenda: $nomeFazenda'),
              pw.Text('Talhão: $nomeTalhao'),
            ],
          ),
          pw.Text(
              'Data: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  pw.Widget _buildFooter() {
    return pw.Center(
      child: pw.Text(
        'Documento gerado pelo Analista GeoForest',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
      ),
    );
  }

  pw.Widget _buildResumoTalhaoPdf(TalhaoAnalysisResult result) {
    return pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey),
          borderRadius: pw.BorderRadius.circular(5),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          children: [
            _buildPdfStat(
                'Volume/ha', '${result.volumePorHectare.toStringAsFixed(1)} m³'),
            _buildPdfStat('Árvores/ha', result.arvoresPorHectare.toString()),
            _buildPdfStat(
                'Área Basal', '${result.areaBasalPorHectare.toStringAsFixed(1)} m²'),
          ],
        ));
  }

  pw.Widget _buildPdfStat(String label, String value) {
    return pw.Column(children: [
      pw.Text(value,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
      pw.Text(label,
          style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10)),
    ]);
  }

  pw.Widget _buildTabelaDistribuicaoPdf(TalhaoAnalysisResult analise) {
    final headers = ['Classe (CAP)', 'Nº de Árvores', '%'];
    final totalArvoresVivas = analise.distribuicaoDiametrica.values.fold(0, (a, b) => a + b);
    
    final data = analise.distribuicaoDiametrica.entries.map((entry) {
      final pontoMedio = entry.key;
      final contagem = entry.value;
      final inicioClasse = pontoMedio - 2.5;
      final fimClasse = pontoMedio + 2.5 - 0.1;
      final porcentagem = totalArvoresVivas > 0 ? (contagem / totalArvoresVivas) * 100 : 0;
      return [
        '${inicioClasse.toStringAsFixed(1)} - ${fimClasse.toStringAsFixed(1)}',
        contagem.toString(),
        '${porcentagem.toStringAsFixed(1)}%',
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
      cellAlignment: pw.Alignment.center,
      cellAlignments: {0: pw.Alignment.centerLeft},
    );
  }
  
  pw.Widget _buildTabelaRendimentoPdf(List<RendimentoDAP> dados) {
    final headers = ['Classe DAP', 'Volume (m³/ha)', '% do Total', 'Árv./ha'];
    
    final data = dados
        .map((item) => [
              item.classe,
              item.volumePorHectare.toStringAsFixed(1),
              '${item.porcentagemDoTotal.toStringAsFixed(1)}%',
              item.arvoresPorHectare.toString(),
            ])
        .toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
      cellAlignment: pw.Alignment.center,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
      },
    );
  }

  pw.Widget _buildTabelaPlano(Map<String, int> plano) {
    final headers = ['Classe Diamétrica (CAP)', 'Nº de Árvores para Cubar'];

    if (plano.isEmpty) {
      return pw.Center(child: pw.Text("Nenhum dado para gerar o plano."));
    }

    final data =
        plano.entries.map((entry) => [entry.key, entry.value.toString()]).toList();
    final total = plano.values.fold(0, (a, b) => a + b);
    data.add(['Total', total.toString()]);

    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
          children: headers
              .map((header) => pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(header,
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white),
                        textAlign: pw.TextAlign.center),
                  ))
              .toList(),
        ),
        ...data.asMap().entries.map((entry) {
          final index = entry.key;
          final rowData = entry.value;
          final bool isLastRow = index == data.length - 1;

          return pw.TableRow(
            children: rowData.asMap().entries.map((cellEntry) {
              final colIndex = cellEntry.key;
              final cellText = cellEntry.value;
              return pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  cellText,
                  textAlign:
                      colIndex == 1 ? pw.TextAlign.center : pw.TextAlign.left,
                  style: isLastRow
                      ? pw.TextStyle(fontWeight: pw.FontWeight.bold)
                      : const pw.TextStyle(),
                ),
              );
            }).toList(),
          );
        }),
      ],
    );
  }
}