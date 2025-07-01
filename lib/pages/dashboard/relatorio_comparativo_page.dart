// lib/pages/dashboard/relatorio_comparativo_page.dart

import 'package:flutter/material.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/talhao_model.dart';
import 'package:geoforestcoletor/pages/dashboard/talhao_dashboard_page.dart';
import 'package:geoforestcoletor/services/pdf_service.dart';
import 'package:geoforestcoletor/models/enums.dart';
import 'package:geoforestcoletor/services/analysis_service.dart';

// Classe de configuração para o resultado do diálogo
class PlanoConfig {
  final MetodoDistribuicaoCubagem metodoDistribuicao;
  final int quantidade;
  final String metodoCubagem; // 'Fixas' ou 'Relativas'

  PlanoConfig({
    required this.metodoDistribuicao,
    required this.quantidade,
    required this.metodoCubagem,
  });
}

class RelatorioComparativoPage extends StatefulWidget {
  final List<Talhao> talhoesSelecionados;
  const RelatorioComparativoPage({super.key, required this.talhoesSelecionados});

  @override
  State<RelatorioComparativoPage> createState() => _RelatorioComparativoPageState();
}

class _RelatorioComparativoPageState extends State<RelatorioComparativoPage> {
  final Map<String, List<Talhao>> _talhoesPorFazenda = {};
  final dbHelper = DatabaseHelper.instance;
  final pdfService = PdfService();

  @override
  void initState() {
    super.initState();
    _agruparTalhoes();
  }

  void _agruparTalhoes() {
    for (var talhao in widget.talhoesSelecionados) {
      final fazendaNome = talhao.fazendaNome ?? 'Fazenda Desconhecida';
      if (!_talhoesPorFazenda.containsKey(fazendaNome)) {
        _talhoesPorFazenda[fazendaNome] = [];
      }
      _talhoesPorFazenda[fazendaNome]!.add(talhao);
    }
  }

  Future<void> _exportarAnaliseUnificadaPdf() async {
    if (widget.talhoesSelecionados.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nenhum talhão para exportar.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    await pdfService.gerarRelatorioUnificadoPdf(
      context: context,
      talhoes: widget.talhoesSelecionados,
    );
  }

  Future<PlanoConfig?> _mostrarDialogoDeConfiguracaoLote() async {
    final quantidadeController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    
    MetodoDistribuicaoCubagem metodoDistribuicao = MetodoDistribuicaoCubagem.fixoPorTalhao;
    String metodoCubagem = 'Fixas';

    return showDialog<PlanoConfig>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Configurar Plano de Cubagem'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('1. Como distribuir as árvores?', style: TextStyle(fontWeight: FontWeight.bold)),
                      RadioListTile<MetodoDistribuicaoCubagem>(
                        title: const Text('Quantidade Fixa por Talhão'),
                        value: MetodoDistribuicaoCubagem.fixoPorTalhao,
                        groupValue: metodoDistribuicao,
                        onChanged: (v) => setDialogState(() => metodoDistribuicao = v!),
                        contentPadding: EdgeInsets.zero,
                      ),
                      RadioListTile<MetodoDistribuicaoCubagem>(
                        title: const Text('Total Proporcional à Área'),
                        value: MetodoDistribuicaoCubagem.proporcionalPorArea,
                        groupValue: metodoDistribuicao,
                        onChanged: (v) => setDialogState(() => metodoDistribuicao = v!),
                        contentPadding: EdgeInsets.zero,
                      ),
                      TextFormField(
                        controller: quantidadeController,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: metodoDistribuicao == MetodoDistribuicaoCubagem.fixoPorTalhao
                              ? 'Nº de árvores por talhão'
                              : 'Nº total de árvores para o lote',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.isEmpty || int.tryParse(v) == null || int.parse(v) <= 0) ? 'Valor inválido' : null,
                      ),
                      const Divider(height: 32),
                      const Text('2. Qual o método de medição?', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: metodoCubagem,
                        items: const [
                          DropdownMenuItem(value: 'Fixas', child: Text('Seções Fixas')),
                          DropdownMenuItem(value: 'Relativas', child: Text('Seções Relativas')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => metodoCubagem = value);
                          }
                        },
                        decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.of(ctx).pop(
                        PlanoConfig(
                          metodoDistribuicao: metodoDistribuicao,
                          quantidade: int.parse(quantidadeController.text),
                          metodoCubagem: metodoCubagem,
                        ),
                      );
                    }
                  },
                  child: const Text('Gerar Planos'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  // <<< FUNÇÃO PRINCIPAL MODIFICADA >>>
  Future<void> _gerarPlanosDeCubagemParaSelecionados() async {
    final PlanoConfig? config = await _mostrarDialogoDeConfiguracaoLote();
    if (config == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Gerando atividades e planos no banco de dados...'),
      backgroundColor: Colors.blue,
      duration: Duration(seconds: 15),
    ));
    
    final analysisService = AnalysisService();
    try {
      // 1. CHAMA A FUNÇÃO E AGUARDA O RETORNO DOS PLANOS GERADOS
      final planosGerados = await analysisService.criarMultiplasAtividadesDeCubagem(
        talhoes: widget.talhoesSelecionados,
        metodo: config.metodoDistribuicao,
        quantidade: config.quantidade,
        metodoCubagem: config.metodoCubagem,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).removeCurrentSnackBar();

      if (planosGerados.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nenhum plano foi gerado. Verifique os dados dos talhões.'),
          backgroundColor: Colors.orange,
        ));
        return;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Atividades criadas! Gerando PDF dos planos...'),
        backgroundColor: Colors.green,
      ));

      // 2. PASSA OS PLANOS GERADOS PARA O PDF SERVICE
      await pdfService.gerarPdfUnificadoDePlanosDeCubagem(
        context: context, 
        planosPorTalhao: planosGerados,
      );

    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao gerar atividades: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatório Comparativo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _exportarAnaliseUnificadaPdf,
            tooltip: 'Exportar Análises (PDF Unificado)',
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: _talhoesPorFazenda.keys.length,
        itemBuilder: (context, index) {
          final fazendaNome = _talhoesPorFazenda.keys.elementAt(index);
          final talhoesDaFazenda = _talhoesPorFazenda[fazendaNome]!;
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: ExpansionTile(
              title: Text(fazendaNome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              initiallyExpanded: true,
              children: talhoesDaFazenda.map((talhao) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Theme.of(context).dividerColor)),
                    clipBehavior: Clip.antiAlias,
                    child: ExpansionTile(
                      title: Text('Talhão: ${talhao.nome}', style: const TextStyle(fontWeight: FontWeight.w500)),
                      children: [TalhaoDashboardContent(talhao: talhao)],
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
      // <<< BOTÃO FLUTUANTE COM O ESTILO DO BOTÃO VERMELHO >>>
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _gerarPlanosDeCubagemParaSelecionados,
        icon: const Icon(Icons.picture_as_pdf_outlined), // Ícone de PDF
        label: const Text('Gerar Planos de Cubagem'),
        tooltip: 'Gerar planos de cubagem para os talhões selecionados',
        backgroundColor: Theme.of(context).colorScheme.error, // Cor vermelha do tema
        foregroundColor: Colors.white, // Cor do texto e ícone
      ),
    );
  }
}