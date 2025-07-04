// lib/pages/analises/analise_volumetrica_page.dart (VERSÃO FINALÍSSIMA)

import 'package:flutter/material.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/cubagem_arvore_model.dart';
import 'package:geoforestcoletor/models/parcela_model.dart';
import 'package:geoforestcoletor/models/talhao_model.dart';
import 'package:geoforestcoletor/services/analysis_service.dart';

class AnaliseVolumetricaPage extends StatefulWidget {
  const AnaliseVolumetricaPage({super.key});

  @override
  State<AnaliseVolumetricaPage> createState() => _AnaliseVolumetricaPageState();
}

class _AnaliseVolumetricaPageState extends State<AnaliseVolumetricaPage> {
  final dbHelper = DatabaseHelper.instance;
  final analysisService = AnalysisService();

  bool _isLoading = true;
  String? _errorMessage;
  
  List<CubagemArvore> _arvoresCubadasDisponiveis = [];
  Map<String, List<CubagemArvore>> _arvoresPorTalhao = {};
  
  final Set<int> _arvoresSelecionadasIds = {};
  Map<String, dynamic>? _resultadoRegressao;
  Map<String, dynamic>? _tabelaProducaoInventario;
  Map<String, dynamic>? _tabelaProducaoSortimento; // <<< NOVO ESTADO
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final todasCubagens = await dbHelper.getTodasCubagens();
      _arvoresCubadasDisponiveis = todasCubagens.where((a) => a.alturaTotal > 0 && a.valorCAP > 0).toList();
      
      _arvoresPorTalhao.clear();
      for (var arvore in _arvoresCubadasDisponiveis) {
        final chave = arvore.talhaoId.toString();
        if (!_arvoresPorTalhao.containsKey(chave)) {
          _arvoresPorTalhao[chave] = [];
        }
        _arvoresPorTalhao[chave]!.add(arvore);
      }
    } catch (e) {
      _errorMessage = "Erro ao carregar dados: $e";
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleSelecaoTalhao(String chaveTalhao, bool? selecionado) {
    if (selecionado == null) return;
    
    final arvoresDoTalhao = _arvoresPorTalhao[chaveTalhao] ?? [];
    setState(() {
      if (selecionado) {
        for (var arvore in arvoresDoTalhao) {
          _arvoresSelecionadasIds.add(arvore.id!);
        }
      } else {
        for (var arvore in arvoresDoTalhao) {
          _arvoresSelecionadasIds.remove(arvore.id!);
        }
      }
    });
  }

  // =========================================================
  // <<< FUNÇÃO PRINCIPAL ATUALIZADA >>>
  // =========================================================
  Future<void> _gerarAnaliseCompleta() async {
    if (_arvoresSelecionadasIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Selecione pelo menos um talhão para gerar a equação.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _resultadoRegressao = null;
      _tabelaProducaoInventario = null;
      _tabelaProducaoSortimento = null;
    });

    final arvoresParaRegressao = _arvoresCubadasDisponiveis
        .where((a) => _arvoresSelecionadasIds.contains(a.id!))
        .toList();
    
    // 1. GERAR A EQUAÇÃO
    final resultadoRegressao = await analysisService.gerarEquacaoSchumacherHall(arvoresParaRegressao);

    if (resultadoRegressao['error'] != null) {
      if (mounted) {
        setState(() {
          _resultadoRegressao = resultadoRegressao;
          _isAnalyzing = false;
        });
      }
      return;
    }
    
    // 2. BUSCAR DADOS DE INVENTÁRIO E SORTIMENTO
    final talhaoIds = arvoresParaRegressao.map((a) => a.talhaoId!).toSet();
    final List<Parcela> parcelasDoInventario = [];
    final List<Talhao> talhoesDoInventario = [];
    final todosTalhoes = await dbHelper.getTalhoesComParcelasConcluidas();

    // Loop para buscar dados de inventário
    for (final talhaoId in talhaoIds) {
      final dadosAgregados = await dbHelper.getDadosAgregadosDoTalhao(talhaoId);
      final parcelas = dadosAgregados['parcelas'] as List<Parcela>;
      if (parcelas.isNotEmpty) {
        parcelasDoInventario.addAll(parcelas);
        final talhaoCorrespondente = todosTalhoes.firstWhere((t) => t.id == talhaoId, orElse: () => Talhao(id: talhaoId, fazendaId: '', fazendaAtividadeId: 0, nome: 'Desconhecido'));
        talhoesDoInventario.add(talhaoCorrespondente);
      }
    }
    
    // 3. APLICAR EQUAÇÃO NO INVENTÁRIO
    if (parcelasDoInventario.isNotEmpty) {
      final analiseInventario = analysisService.getTalhaoInsights(parcelasDoInventario, []);
      final arvoresDoInventario = (await dbHelper.getDadosAgregadosDoTalhao(talhaoIds.first))['arvores'];

      final arvoresDoInventarioComVolume = analysisService.aplicarEquacaoDeVolume(
        arvoresDoInventario: arvoresDoInventario,
        b0: resultadoRegressao['b0'],
        b1: resultadoRegressao['b1'],
        b2: resultadoRegressao['b2'],
      );
      
      final double volumeTotalAmostrado = arvoresDoInventarioComVolume.fold(0.0, (sum, arv) => sum + (arv.volume ?? 0.0));
      final double areaTotalAmostradaHa = analiseInventario.areaTotalAmostradaHa;
      final double volumePorHectare = areaTotalAmostradaHa > 0 ? volumeTotalAmostrado / areaTotalAmostradaHa : 0.0;
      
      _tabelaProducaoInventario = {
        'talhoes': talhoesDoInventario.map((t) => t.nome).join(', '),
        'volume_ha': volumePorHectare,
        'arvores_ha': analiseInventario.arvoresPorHectare,
        'area_basal_ha': analiseInventario.areaBasalPorHectare,
      };
    }

    // 4. APLICAR SORTIMENTO NAS ÁRVORES CUBADAS
    final definicoesSortimento = await dbHelper.getTodosSortimentos();
    if (definicoesSortimento.isNotEmpty) {
      final Map<String, double> volumesTotaisSortimento = {};
      double volumeTotalCubadoClassificado = 0;

      for (final arvoreCubada in arvoresParaRegressao) {
        final secoes = await dbHelper.getSecoesPorArvoreId(arvoreCubada.id!);
        final resultadoClassificacao = analysisService.classificarSortimentos(secoes, definicoesSortimento);
        
        resultadoClassificacao.forEach((nome, volume) {
          volumesTotaisSortimento.update(nome, (v) => v + volume, ifAbsent: () => volume);
          volumeTotalCubadoClassificado += volume;
        });
      }
      
      // 5. CALCULAR PORCENTAGENS
      final Map<String, double> pctSortimento = {};
      if(volumeTotalCubadoClassificado > 0) {
        volumesTotaisSortimento.forEach((nome, volume) {
          pctSortimento[nome] = (volume / volumeTotalCubadoClassificado) * 100;
        });
      }
      _tabelaProducaoSortimento = {'porcentagens': pctSortimento};
    }

    if (mounted) {
      setState(() {
        _resultadoRegressao = resultadoRegressao;
        _isAnalyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Análise Volumétrica')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
              : _buildContent(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isAnalyzing ? null : _gerarAnaliseCompleta,
        icon: _isAnalyzing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.functions),
        label: Text(_isAnalyzing ? 'Analisando...' : 'Gerar Análise Completa'),
      ),
    );
  }

  Widget _buildContent() {
    if (_arvoresPorTalhao.isEmpty) {
      return const Center(child: Text('Nenhuma árvore cubada com dados completos encontrada.'));
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 90),
      child: Column(
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('1. Selecione os Talhões Cubados', style: Theme.of(context).textTheme.titleLarge),
                  const Text('As árvores destes talhões serão usadas para gerar a equação de volume.', style: TextStyle(color: Colors.grey)),
                  const Divider(),
                   ..._arvoresPorTalhao.entries.map((entry) {
                      final chave = entry.key;
                      final arvoresDoTalhao = entry.value;
                      final nomeExibicao = "${arvoresDoTalhao.first.nomeFazenda} / ${arvoresDoTalhao.first.nomeTalhao}";
                      final todasSelecionadas = arvoresDoTalhao.every((a) => _arvoresSelecionadasIds.contains(a.id!));
                      
                      return CheckboxListTile(
                        title: Text(nomeExibicao, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${arvoresDoTalhao.length} árvores cubadas'),
                        value: todasSelecionadas,
                        onChanged: (selecionado) => _toggleSelecaoTalhao(chave, selecionado),
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    }),
                ],
              ),
            ),
          ),
          
          if (_resultadoRegressao != null) _buildResultCard(),
          if (_tabelaProducaoSortimento != null) _buildSortmentTable(), // <<< NOVO WIDGET
          if (_tabelaProducaoInventario != null) _buildProductionTable(),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
     if (_resultadoRegressao!['error'] != null) {
      return Card( margin: const EdgeInsets.only(top: 16), color: Colors.red.shade100, child: Padding( padding: const EdgeInsets.all(16.0), child: Text('Erro: ${_resultadoRegressao!['error']}', style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold)),),);
    }
    final double r2 = _resultadoRegressao!['R2'] ?? 0.0;
    final String equacao = _resultadoRegressao!['equacao'] ?? 'N/A';
    final int nAmostras = _resultadoRegressao!['n_amostras'] ?? 0;
    return Card(
      margin: const EdgeInsets.only(top: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('2. Equação de Volume Gerada', style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 24),
            Text('Equação:', style: TextStyle(color: Colors.grey.shade700)),
            Text(equacao, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'monospace')),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Coeficiente (R²):', style: TextStyle(color: Colors.grey.shade700)),Text(r2.toStringAsFixed(4), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),],),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Nº de Amostras Usadas:', style: TextStyle(color: Colors.grey.shade700)),Text(nAmostras.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),],),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // <<< NOVO WIDGET PARA A TABELA DE SORTIMENTO >>>
  // =========================================================
  Widget _buildSortmentTable() {
    final Map<String, double> porcentagens = _tabelaProducaoSortimento!['porcentagens'] ?? {};
    if (porcentagens.isEmpty) {
      return const SizedBox.shrink(); // Não mostra nada se não houver dados
    }

    final double volumeTotalHa = _tabelaProducaoInventario?['volume_ha'] ?? 0.0;
    
    return Card(
      margin: const EdgeInsets.only(top: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('3. Produção por Sortimento', style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 24),
            ...porcentagens.entries.map((entry) {
              final nomeSortimento = entry.key;
              final pct = entry.value;
              final volumeHaSortimento = volumeTotalHa * (pct / 100);
              return _buildStatRow(
                '$nomeSortimento:',
                '${volumeHaSortimento.toStringAsFixed(2)} m³/ha (${pct.toStringAsFixed(1)}%)'
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildProductionTable() {
    if (_tabelaProducaoInventario!['error'] != null) {
      return Card(margin: const EdgeInsets.only(top: 16), color: Colors.amber.shade100, child: Padding( padding: const EdgeInsets.all(16.0), child: Text('Aviso: ${_tabelaProducaoInventario!['error']}', style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold)),),);
    }
    return Card(
      margin: const EdgeInsets.only(top: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('4. Totais do Inventário', style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 24),
            Text('Aplicado aos talhões: ${_tabelaProducaoInventario!['talhoes']}', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
            const SizedBox(height: 16),
            _buildStatRow('Volume Total por Hectare:', '${(_tabelaProducaoInventario!['volume_ha'] as double).toStringAsFixed(2)} m³/ha'),
            _buildStatRow('Árvores por Hectare:', '${_tabelaProducaoInventario!['arvores_ha']}'),
            _buildStatRow('Área Basal por Hectare:', '${(_tabelaProducaoInventario!['area_basal_ha'] as double).toStringAsFixed(2)} m²/ha'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}