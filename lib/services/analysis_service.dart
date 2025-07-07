// lib/services/analysis_service.dart (ADAPTADO PARA GEOVIGILÂNCIA)

import 'package:flutter/foundation.dart';
// <<< MUDANÇA: Imports adaptados para os novos modelos >>>
import 'package:geovigilancia/models/vistoria_model.dart';
import 'package:geovigilancia/models/foco_model.dart';
import 'package:geovigilancia/models/analise_epidemiologica_result_model.dart'; // <<< Precisaremos criar este modelo

class AnalysisService {
  
  // <<< MUDANÇA: Função principal de análise, agora para um conjunto de vistorias (de um setor, bairro, etc.) >>>
  AnaliseEpidemiologicaResult getAnaliseEpidemiologica(List<Vistoria> vistorias, List<Foco> focos) {
    if (vistorias.isEmpty) {
      return AnaliseEpidemiologicaResult();
    }

    // --- Contagens Básicas ---
    final int totalImoveis = vistorias.length;
    final vistoriasTrabalhadas = vistorias.where((v) => v.status == StatusVisita.realizada).toList();
    final int totalImoveisTrabalhados = vistoriasTrabalhadas.length;
    
    final int totalRecusas = vistorias.where((v) => v.status == StatusVisita.recusa).length;
    final int totalFechados = vistorias.where((v) => v.status == StatusVisita.fechada).length;

    if (totalImoveisTrabalhados == 0) {
      return AnaliseEpidemiologicaResult(
        totalImoveis: totalImoveis,
        totalImoveisTrabalhados: 0,
        totalRecusas: totalRecusas,
        totalFechados: totalFechados,
        warnings: ["Nenhum imóvel foi trabalhado (visitado com sucesso). Os índices não podem ser calculados."],
      );
    }
    
    final vistoriasComFoco = vistoriasTrabalhadas.where((v) => v.resultado == "Com Foco").toList();
    final int totalImoveisComFoco = vistoriasComFoco.length;
    final int totalFocos = focos.length;
    final focosPositivos = focos.where((f) => f.larvasEncontradas).toList();
    final int totalFocosPositivos = focosPositivos.length;
    
    // --- Cálculo dos Índices Epidemiológicos ---
    
    // Índice de Infestação Predial (IIP): % de imóveis com focos
    final double iip = (totalImoveisComFoco / totalImoveisTrabalhados) * 100;

    // Índice de Breteau (IB): nº de recipientes positivos por 100 imóveis
    final double ib = (totalFocosPositivos / totalImoveisTrabalhados) * 100;

    // Índice de Pendência: % de imóveis não visitados por recusa ou por estarem fechados
    final double pendencia = ((totalRecusas + totalFechados) / totalImoveis) * 100;

    // --- Análise de Criadouros ---
    final Map<String, int> contagemPorTipoCriadouro = {};
    for (var foco in focos) {
      contagemPorTipoCriadouro.update(foco.tipoCriadouro, (value) => value + 1, ifAbsent: () => 1);
    }

    // Ordena os criadouros do mais comum para o menos comum
    final criadourosMaisComuns = contagemPorTipoCriadouro.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // --- Geração de Alertas e Insights ---
    List<String> warnings = [];
    if (iip >= 5.0) {
      warnings.add("Índice de Infestação Predial (${iip.toStringAsFixed(1)}%) em NÍVEL DE ALERTA ALTO. Risco de epidemia.");
    } else if (iip >= 1.0) {
       warnings.add("Índice de Infestação Predial (${iip.toStringAsFixed(1)}%) em NÍVEL DE ALERTA. Ações de controle são recomendadas.");
    }
    if (pendencia > 20.0) {
      warnings.add("Alto índice de pendência (${pendencia.toStringAsFixed(1)}%). Muitos imóveis não estão sendo vistoriados.");
    }
    
    return AnaliseEpidemiologicaResult(
      totalImoveis: totalImoveis,
      totalImoveisTrabalhados: totalImoveisTrabalhados,
      totalImoveisComFoco: totalImoveisComFoco,
      totalFocosEncontrados: totalFocos,
      totalFocosPositivos: totalFocosPositivos,
      totalRecusas: totalRecusas,
      totalFechados: totalFechados,
      indiceInfestacaoPredial: iip,
      indiceBreteau: ib,
      indicePendencia: pendencia,
      distribuicaoCriadouros: contagemPorTipoCriadouro,
      criadourosMaisComuns: criadourosMaisComuns.map((e) => e.key).toList(),
      warnings: warnings,
    );
  }

  // <<< REMOÇÃO: Todas as funções florestais foram removidas >>>
  // calcularVolumeComercialSmalian
  // gerarEquacaoSchumacherHall
  // aplicarEquacaoDeVolume
  // classificarSortimentos
  // getTalhaoInsights
  // _analisarListaDeArvores
  // simularDesbaste
  // analisarRendimentoPorDAP
  // gerarPlanoDeCubagem
  // getDistribuicaoDiametrica
  // _areaBasalPorArvore
  // _estimateVolume
  // _calculateAverage
  // criarMultiplasAtividadesDeCubagem
}