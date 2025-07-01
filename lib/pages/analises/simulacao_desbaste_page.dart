// lib/pages/analise/simulacao_desbaste_page.dart

import 'package:flutter/material.dart';
import 'package:geoforestcoletor/models/arvore_model.dart';
import 'package:geoforestcoletor/models/parcela_model.dart';
import 'package:geoforestcoletor/services/analysis_service.dart';
import 'package:geoforestcoletor/models/analise_result_model.dart';

class SimulacaoDesbastePage extends StatefulWidget {
  final List<Parcela> parcelas;
  final List<Arvore> arvores;
  final TalhaoAnalysisResult analiseInicial;

  const SimulacaoDesbastePage({
    super.key,
    required this.parcelas,
    required this.arvores,
    required this.analiseInicial,
  });

  @override
  State<SimulacaoDesbastePage> createState() => _SimulacaoDesbastePageState();
}

class _SimulacaoDesbastePageState extends State<SimulacaoDesbastePage> {
  final _analysisService = AnalysisService();
  double _intensidadeDesbaste = 0.0; // Em porcentagem (0 a 40)
  late TalhaoAnalysisResult _resultadoSimulacao;

  @override
  void initState() {
    super.initState();
    // O estado inicial da simulação é a própria análise inicial
    _resultadoSimulacao = widget.analiseInicial;
  }

  void _rodarSimulacao(double novaIntensidade) {
    setState(() {
      _intensidadeDesbaste = novaIntensidade;
      // Chama o serviço de análise para obter os resultados pós-desbaste
      _resultadoSimulacao = _analysisService.simularDesbaste(
        widget.parcelas,
        widget.arvores,
        _intensidadeDesbaste,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulador de Desbaste'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildControleDesbaste(),
            const SizedBox(height: 24),
            _buildTabelaResultados(),
          ],
        ),
      ),
    );
  }

  Widget _buildControleDesbaste() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Intensidade do Desbaste: ${_intensidadeDesbaste.toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Remover as árvores mais finas (por CAP)',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            Slider(
              value: _intensidadeDesbaste,
              min: 0,
              max: 40, // Limite máximo de desbaste para a simulação
              divisions: 8, // Divide o slider em 8 partes (0, 5, 10, ..., 40)
              label: '${_intensidadeDesbaste.toStringAsFixed(0)}%',
              onChanged: (value) {
                // Atualiza o estado enquanto o slider é arrastado
                setState(() {
                  _intensidadeDesbaste = value;
                });
              },
              // Roda a simulação completa quando o usuário solta o slider
              onChangeEnd: (value) {
                _rodarSimulacao(value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabelaResultados() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Comparativo de Resultados', style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 20),
            // Tabela com os resultados
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2), // Coluna do Parâmetro
                1: FlexColumnWidth(1.2), // Coluna Antes
                2: FlexColumnWidth(1.2), // Coluna Depois
              },
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
              ),
              children: [
                _buildHeaderRow(),
                _buildDataRow(
                  'Árvores/ha',
                  widget.analiseInicial.arvoresPorHectare.toString(),
                  _resultadoSimulacao.arvoresPorHectare.toString(),
                ),
                _buildDataRow(
                  'CAP Médio',
                  '${widget.analiseInicial.mediaCap.toStringAsFixed(1)} cm',
                  '${_resultadoSimulacao.mediaCap.toStringAsFixed(1)} cm',
                ),
                 _buildDataRow(
                  'Altura Média',
                  '${widget.analiseInicial.mediaAltura.toStringAsFixed(1)} m',
                  '${_resultadoSimulacao.mediaAltura.toStringAsFixed(1)} m',
                ),
                _buildDataRow(
                  'Área Basal (G)',
                  '${widget.analiseInicial.areaBasalPorHectare.toStringAsFixed(2)} m²/ha',
                  '${_resultadoSimulacao.areaBasalPorHectare.toStringAsFixed(2)} m²/ha',
                ),
                _buildDataRow(
                  'Volume',
                  '${widget.analiseInicial.volumePorHectare.toStringAsFixed(2)} m³/ha',
                  '${_resultadoSimulacao.volumePorHectare.toStringAsFixed(2)} m³/ha',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TableRow _buildHeaderRow() {
    return TableRow(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
      ),
      children: [
        _buildHeaderCell('Parâmetro'),
        _buildHeaderCell('Antes'),
        _buildHeaderCell('Após'),
      ],
    );
  }

  TableRow _buildDataRow(String label, String valorAntes, String valorDepois) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
          child: Text(valorAntes, textAlign: TextAlign.center),
        ),
        Container(
          color: Colors.green.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
            child: Text(
              valorDepois,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }
}