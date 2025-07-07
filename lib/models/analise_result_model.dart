// lib/models/analise_epidemiologica_result_model.dart

class AnaliseEpidemiologicaResult {
  // Contagens
  final int totalImoveis;
  final int totalImoveisTrabalhados;
  final int totalImoveisComFoco;
  final int totalFocosEncontrados;
  final int totalFocosPositivos;
  final int totalRecusas;
  final int totalFechados;

  // Índices
  final double indiceInfestacaoPredial;
  final double indiceBreteau;
  final double indicePendencia;

  // Análise de Criadouros
  final Map<String, int> distribuicaoCriadouros;
  final List<String> criadourosMaisComuns;

  // Mensagens
  final List<String> warnings;
  final List<String> insights;

  AnaliseEpidemiologicaResult({
    this.totalImoveis = 0,
    this.totalImoveisTrabalhados = 0,
    this.totalImoveisComFoco = 0,
    this.totalFocosEncontrados = 0,
    this.totalFocosPositivos = 0,
    this.totalRecusas = 0,
    this.totalFechados = 0,
    this.indiceInfestacaoPredial = 0.0,
    this.indiceBreteau = 0.0,
    this.indicePendencia = 0.0,
    this.distribuicaoCriadouros = const {},
    this.criadourosMaisComuns = const [],
    this.warnings = const [],
    this.insights = const [],
  });
}