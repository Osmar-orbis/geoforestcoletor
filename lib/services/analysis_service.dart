// lib/services/analysis_service.dart

import 'dart:math';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/atividade_model.dart';
import 'package:geoforestcoletor/models/cubagem_arvore_model.dart';
import 'package:geoforestcoletor/models/enums.dart';
import 'package:geoforestcoletor/models/talhao_model.dart';
import 'package:geoforestcoletor/models/arvore_model.dart';
import 'package:geoforestcoletor/models/parcela_model.dart';
import 'package:geoforestcoletor/models/analise_result_model.dart';

class AnalysisService {
  static const double FATOR_DE_FORMA = 0.45;

  // --- MÉTODOS DE ANÁLISE EXISTENTES (sem alterações) ---

  TalhaoAnalysisResult getTalhaoInsights(List<Parcela> parcelasDoTalhao, List<Arvore> todasAsArvores) {
    if (parcelasDoTalhao.isEmpty || todasAsArvores.isEmpty) {
      return TalhaoAnalysisResult();
    }
    
    final double areaTotalAmostradaM2 = parcelasDoTalhao.map((p) => p.areaMetrosQuadrados).reduce((a, b) => a + b);
    if (areaTotalAmostradaM2 == 0) return TalhaoAnalysisResult();
    
    // A variável é definida aqui
    final double areaTotalAmostradaHa = areaTotalAmostradaM2 / 10000;

    // E passada como parâmetro para o método interno
    return _analisarListaDeArvores(todasAsArvores, areaTotalAmostradaHa, parcelasDoTalhao.length);
  }

  TalhaoAnalysisResult _analisarListaDeArvores(List<Arvore> arvoresDoConjunto, double areaAmostradaHa, int numeroDeParcelas) {
    if (arvoresDoConjunto.isEmpty || areaAmostradaHa <= 0) {
      return TalhaoAnalysisResult();
    }
    
    final List<Arvore> arvoresVivas = arvoresDoConjunto.where((a) => a.codigo == Codigo.normal).toList();

    if (arvoresVivas.isEmpty) {
      return TalhaoAnalysisResult(warnings: ["Nenhuma árvore viva encontrada nas amostras para análise."]);
    }

    final double mediaCap = _calculateAverage(arvoresVivas.map((a) => a.cap).toList());
    final List<double> alturasValidas = arvoresVivas.map((a) => a.altura).whereType<double>().toList();
    final double mediaAltura = alturasValidas.isNotEmpty ? _calculateAverage(alturasValidas) : 0.0;
    
    final double areaBasalTotalAmostrada = arvoresVivas.map((a) => _areaBasalPorArvore(a.cap)).reduce((a, b) => a + b);
    final double areaBasalPorHectare = areaBasalTotalAmostrada / areaAmostradaHa; // Usada aqui

    final double volumeTotalAmostrado = arvoresVivas.map((a) => _estimateVolume(a.cap, a.altura ?? mediaAltura)).reduce((a, b) => a + b);
    final double volumePorHectare = volumeTotalAmostrado / areaAmostradaHa; // Usada aqui
    
    final int arvoresPorHectare = (arvoresVivas.length / areaAmostradaHa).round(); // Usada aqui

    List<String> warnings = [];
    List<String> insights = [];
    List<String> recommendations = [];
    
    final int arvoresMortas = arvoresDoConjunto.length - arvoresVivas.length;
    final double taxaMortalidade = (arvoresMortas / arvoresDoConjunto.length) * 100;
    if (taxaMortalidade > 15) {
      warnings.add("Mortalidade de ${taxaMortalidade.toStringAsFixed(1)}% detectada, valor considerado alto.");
    }

    if (areaBasalPorHectare > 38) {
      insights.add("A Área Basal (${areaBasalPorHectare.toStringAsFixed(1)} m²/ha) indica um povoamento muito denso.");
      recommendations.add("O talhão é um forte candidato para desbaste. Use a ferramenta de simulação para avaliar cenários.");
    } else if (areaBasalPorHectare < 20) {
      insights.add("A Área Basal (${areaBasalPorHectare.toStringAsFixed(1)} m²/ha) está baixa, indicando um povoamento aberto ou muito jovem.");
    }

    final Map<double, int> distribuicao = getDistribuicaoDiametrica(arvoresVivas);

    return TalhaoAnalysisResult(
      areaTotalAmostradaHa: areaAmostradaHa,
      totalArvoresAmostradas: arvoresDoConjunto.length,
      totalParcelasAmostradas: numeroDeParcelas,
      mediaCap: mediaCap,
      mediaAltura: mediaAltura,
      areaBasalPorHectare: areaBasalPorHectare,
      volumePorHectare: volumePorHectare,
      arvoresPorHectare: arvoresPorHectare,
      distribuicaoDiametrica: distribuicao, 
      warnings: warnings,
      insights: insights,
      recommendations: recommendations,
    );
  }

  TalhaoAnalysisResult simularDesbaste(List<Parcela> parcelasOriginais, List<Arvore> todasAsArvores, double porcentagemRemocao) {
    if (parcelasOriginais.isEmpty || porcentagemRemocao <= 0) {
      return getTalhaoInsights(parcelasOriginais, todasAsArvores);
    }
    
    final List<Arvore> arvoresVivas = todasAsArvores.where((a) => a.codigo == Codigo.normal).toList();
    if (arvoresVivas.isEmpty) {
      return getTalhaoInsights(parcelasOriginais, todasAsArvores);
    }

    arvoresVivas.sort((a, b) => a.cap.compareTo(b.cap));
    
    final int quantidadeRemover = (arvoresVivas.length * (porcentagemRemocao / 100)).floor();
    final List<Arvore> arvoresRemanescentes = arvoresVivas.sublist(quantidadeRemover);
    
    final double areaTotalAmostradaM2 = parcelasOriginais.map((p) => p.areaMetrosQuadrados).reduce((a, b) => a + b);
    final double areaTotalAmostradaHa = areaTotalAmostradaM2 / 10000;

    return _analisarListaDeArvores(arvoresRemanescentes, areaTotalAmostradaHa, parcelasOriginais.length);
  }
  
  List<RendimentoDAP> analisarRendimentoPorDAP(List<Parcela> parcelasDoTalhao, List<Arvore> todasAsArvores) {
    if (parcelasDoTalhao.isEmpty || todasAsArvores.isEmpty) {
      return [];
    }
    
    final double areaTotalAmostradaM2 = parcelasDoTalhao.map((p) => p.areaMetrosQuadrados).reduce((a, b) => a + b);
    if (areaTotalAmostradaM2 == 0) return [];
    
    final double areaTotalAmostradaHa = areaTotalAmostradaM2 / 10000;
    final List<Arvore> arvoresVivas = todasAsArvores.where((a) => a.codigo == Codigo.normal).toList();
    final List<double> alturasValidas = arvoresVivas.map((a) => a.altura).whereType<double>().toList();
    final double mediaAltura = alturasValidas.isNotEmpty ? _calculateAverage(alturasValidas) : 0.0;

    for (var arv in arvoresVivas) {
      arv.volume = _estimateVolume(arv.cap, arv.altura ?? mediaAltura);
    }
    
    final Map<String, List<Arvore>> arvoresPorClasse = {
      '8-18 cm': [],
      '18-23 cm': [],
      '23-35 cm': [],
      '> 35 cm': [],
      'Outros': [],
    };

    for (var arv in arvoresVivas) {
      final double dap = arv.cap / pi;
      if (dap >= 8 && dap < 18) {
        arvoresPorClasse['8-18 cm']!.add(arv);
      } else if (dap >= 18 && dap < 23) {
        arvoresPorClasse['18-23 cm']!.add(arv);
      } else if (dap >= 23 && dap < 35) {
        arvoresPorClasse['23-35 cm']!.add(arv);
      } else if (dap >= 35) {
        arvoresPorClasse['> 35 cm']!.add(arv);
      } else {
        arvoresPorClasse['Outros']!.add(arv);
      }
    }

    final double volumeTotal = arvoresPorClasse.values
        .expand((arvores) => arvores)
        .map((arv) => arv.volume ?? 0)
        .fold(0.0, (a, b) => a + b);

    final List<RendimentoDAP> resultadoFinal = [];

    arvoresPorClasse.forEach((classe, arvores) {
      if (arvores.isNotEmpty) {
        final double volumeClasse = arvores.map((a) => a.volume ?? 0).reduce((a, b) => a + b);
        final double volumeHa = volumeClasse / areaTotalAmostradaHa;
        final double porcentagem = (volumeTotal > 0) ? (volumeClasse / volumeTotal) * 100 : 0;
        final int arvoresHa = (arvores.length / areaTotalAmostradaHa).round();
        
        resultadoFinal.add(RendimentoDAP(
          classe: classe,
          volumePorHectare: volumeHa,
          porcentagemDoTotal: porcentagem,
          arvoresPorHectare: arvoresHa,
        ));
      }
    });

    return resultadoFinal;
  }

  Map<String, int> gerarPlanoDeCubagem(
    Map<double, int> distribuicaoAmostrada,
    int totalArvoresAmostradas,
    int totalArvoresParaCubar,
    {int larguraClasse = 5}
  ) {
    if (totalArvoresAmostradas == 0 || totalArvoresParaCubar == 0) return {};

    final Map<String, int> plano = {};

    for (var entry in distribuicaoAmostrada.entries) {
      final pontoMedio = entry.key;
      final contagemNaClasse = entry.value;

      final double proporcao = contagemNaClasse / totalArvoresAmostradas;
      
      final int arvoresParaCubarNestaClasse = (proporcao * totalArvoresParaCubar).round();
      
      final inicioClasse = pontoMedio - (larguraClasse / 2);
      final fimClasse = pontoMedio + (larguraClasse / 2) - 0.1;
      final String rotuloClasse = "${inicioClasse.toStringAsFixed(1)} - ${fimClasse.toStringAsFixed(1)} cm";

      if (arvoresParaCubarNestaClasse > 0) {
        plano[rotuloClasse] = arvoresParaCubarNestaClasse;
      }
    }
    
    int somaAtual = plano.values.fold(0, (a, b) => a + b);
    int diferenca = totalArvoresParaCubar - somaAtual;
    
    if (diferenca != 0 && plano.isNotEmpty) {
      String classeParaAjustar = plano.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      plano.update(classeParaAjustar, (value) => value + diferenca, ifAbsent: () => diferenca);
      
      if (plano[classeParaAjustar]! <= 0) {
        plano.remove(classeParaAjustar);
      }
    }

    return plano;
  }
  
  Map<double, int> getDistribuicaoDiametrica(List<Arvore> arvores, {int larguraClasse = 5}) {
    if (arvores.isEmpty) return {};

    final Map<int, int> contagemPorClasse = {};
    
    for (final arvore in arvores) {
      if (arvore.codigo == Codigo.normal && arvore.cap > 0) {
        final int classeBase = (arvore.cap / larguraClasse).floor() * larguraClasse;
        contagemPorClasse.update(classeBase, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    
    final sortedKeys = contagemPorClasse.keys.toList()..sort();
    final Map<double, int> resultadoFinal = {};
    for (final key in sortedKeys) {
      final double pontoMedio = key.toDouble() + (larguraClasse / 2.0);
      resultadoFinal[pontoMedio] = contagemPorClasse[key]!;
    }

    return resultadoFinal;
  }

  double _areaBasalPorArvore(double cap) {
    if (cap <= 0) return 0;
    final double dap = cap / pi;
    return (pi * pow(dap, 2)) / 40000;
  }

  double _estimateVolume(double cap, double altura) {
    if (cap <= 0 || altura <= 0) return 0;
    final areaBasal = _areaBasalPorArvore(cap);
    return areaBasal * altura * FATOR_DE_FORMA;
  }

  double _calculateAverage(List<double> numbers) {
    if (numbers.isEmpty) return 0;
    return numbers.reduce((a, b) => a + b) / numbers.length;
  }

  // --- MÉTODOS NOVOS PARA CRIAÇÃO DE ATIVIDADE DE CUBAGEM ---

  Future<void> criarMultiplasAtividadesDeCubagem({
    required List<Talhao> talhoes,
    required MetodoDistribuicaoCubagem metodo,
    required int quantidade,
    required String metodoCubagem, // Parâmetro novo
  }) async {
    final dbHelper = DatabaseHelper.instance;
    Map<int, int> quantidadesPorTalhao = {};

    if (metodo == MetodoDistribuicaoCubagem.fixoPorTalhao) {
      for (final talhao in talhoes) {
        quantidadesPorTalhao[talhao.id!] = quantidade;
      }
    } else if (metodo == MetodoDistribuicaoCubagem.proporcionalPorArea) {
      double areaTotalDoLote = talhoes.map((t) => t.areaHa ?? 0.0).fold(0.0, (prev, area) => prev + area);
      if (areaTotalDoLote <= 0) {
        throw Exception("A área total dos talhões selecionados é zero. Não é possível calcular a proporção.");
      }
      int arvoresDistribuidas = 0;
      for (int i = 0; i < talhoes.length; i++) {
        final talhao = talhoes[i];
        final areaTalhao = talhao.areaHa ?? 0.0;
        final proporcao = areaTalhao / areaTotalDoLote;
        if (i == talhoes.length - 1) {
          quantidadesPorTalhao[talhao.id!] = quantidade - arvoresDistribuidas;
        } else {
          final qtdParaEsteTalhao = (quantidade * proporcao).round();
          quantidadesPorTalhao[talhao.id!] = qtdParaEsteTalhao;
          arvoresDistribuidas += qtdParaEsteTalhao;
        }
      }
    }

    for (final talhao in talhoes) {
      final totalArvoresParaCubar = quantidadesPorTalhao[talhao.id!] ?? 0;
      if (totalArvoresParaCubar <= 0) continue;
      
      final dadosAgregados = await dbHelper.getDadosAgregadosDoTalhao(talhao.id!);
      final parcelas = dadosAgregados['parcelas'] as List<Parcela>;
      final arvores = dadosAgregados['arvores'] as List<Arvore>;

      if (parcelas.isEmpty || arvores.isEmpty) continue;
      
      final analiseResult = getTalhaoInsights(parcelas, arvores);
      
      await criarAtividadeDeCubagemPorPlano(
        talhaoOriginal: talhao,
        analiseOriginal: analiseResult,
        totalArvoresParaCubar: totalArvoresParaCubar,
        metodoCubagem: metodoCubagem, // Passa o parâmetro adiante
      );
    }
  }

  Future<void> criarAtividadeDeCubagemPorPlano({
    required Talhao talhaoOriginal,
    required TalhaoAnalysisResult analiseOriginal,
    required int totalArvoresParaCubar,
    required String metodoCubagem, // Parâmetro novo
  }) async {
    final dbHelper = DatabaseHelper.instance;
    final projeto = await dbHelper.getProjetoPelaAtividade(talhaoOriginal.fazendaAtividadeId);
    if (projeto == null) throw Exception("Não foi possível encontrar o projeto pai para o talhão ${talhaoOriginal.nome}.");
    
    final plano = gerarPlanoDeCubagem(analiseOriginal.distribuicaoDiametrica, analiseOriginal.totalArvoresAmostradas, totalArvoresParaCubar);
    if (plano.isEmpty) throw Exception("Não foi possível gerar o plano de cubagem para o talhão ${talhaoOriginal.nome}.");

    final novaAtividade = Atividade(
      projetoId: projeto.id!,
      tipo: 'Cubagem - $metodoCubagem', // Tipo da atividade agora reflete o método
      descricao: 'Plano para o talhão ${talhaoOriginal.nome} com $totalArvoresParaCubar árvores.',
      dataCriacao: DateTime.now(),
    );

    final List<CubagemArvore> placeholders = [];
    plano.forEach((classe, quantidade) {
      for (int i = 1; i <= quantidade; i++) {
        final classeSanitizada = classe.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '-');
        placeholders.add(
          CubagemArvore(
            nomeFazenda: talhaoOriginal.fazendaNome ?? 'N/A',
            idFazenda: talhaoOriginal.fazendaId,
            nomeTalhao: talhaoOriginal.nome,
            classe: classe,
            identificador: 'PLANO-${classeSanitizada}-${i.toString().padLeft(2, '0')}',
            alturaTotal: 0,
            valorCAP: 0,
            alturaBase: 1.30,
            tipoMedidaCAP: 'fita',
          ),
        );
      }
    });

    await dbHelper.criarAtividadeComPlanoDeCubagem(novaAtividade, placeholders);
  }
}