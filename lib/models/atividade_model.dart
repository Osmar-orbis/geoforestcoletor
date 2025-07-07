// lib/models/atividade_model.dart

// <<< MUDANÇA: O enum foi simplificado e adaptado para a vigilância. >>>
// Você pode adicionar mais tipos conforme a necessidade do seu município.
enum TipoAtividadeSaude {
  liraa("Levantamento Rápido (LIRAa)"),
  rotina("Visita de Rotina"),
  pontoEstrategico("Visita a Ponto Estratégico"),
  denuncia("Atendimento a Denúncia"),
  bloqueio("Bloqueio de Transmissão");

  const TipoAtividadeSaude(this.descricao);
  final String descricao;
}

class Atividade {
  final int? id;
  // <<< MUDANÇA: Renomeado de 'projetoId' para 'campanhaId' para consistência. >>>
  final int campanhaId; 
  final String tipo; // Ex: "LIRAa", "Rotina", etc.
  final String descricao;
  final DateTime dataCriacao;

  // <<< REMOÇÃO: O campo 'metodoCubagem' não é mais necessário. >>>

  Atividade({
    this.id,
    required this.campanhaId,
    required this.tipo,
    required this.descricao,
    required this.dataCriacao,
  });

  Atividade copyWith({
    int? id,
    int? campanhaId,
    String? tipo,
    String? descricao,
    DateTime? dataCriacao,
  }) {
    return Atividade(
      id: id ?? this.id,
      campanhaId: campanhaId ?? this.campanhaId,
      tipo: tipo ?? this.tipo,
      descricao: descricao ?? this.descricao,
      dataCriacao: dataCriacao ?? this.dataCriacao,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      // <<< MUDANÇA: Chave do mapa atualizada. >>>
      'campanhaId': campanhaId,
      'tipo': tipo,
      'descricao': descricao,
      'dataCriacao': dataCriacao.toIso8601String(),
    };
  }

  factory Atividade.fromMap(Map<String, dynamic> map) {
    return Atividade(
      id: map['id'],
      // <<< MUDANÇA: Verifica tanto o novo nome ('campanhaId') quanto o antigo ('projetoId'). >>>
      campanhaId: map['campanhaId'] ?? map['projetoId'],
      tipo: map['tipo'],
      descricao: map['descricao'],
      dataCriacao: DateTime.parse(map['dataCriacao']),
    );
  }
}