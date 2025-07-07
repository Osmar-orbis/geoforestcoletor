// lib/models/campanha_model.dart

class Campanha {
  final int? id;
  final String nome; // Ex: "LIRAa - Jan/2024", "Campanha de Verão"
  final String orgao; // <<< CAMPO RENOMEADO de 'empresa' para 'orgao' (Ex: "Secretaria de Saúde de...")
  final String responsavel; // Ex: "Coordenador de Endemias", "Agente Supervisor"
  final DateTime dataCriacao;

  Campanha({
    this.id,
    required this.nome,
    required this.orgao, // <<< ADAPTADO
    required this.responsavel,
    required this.dataCriacao,
  });

  Campanha copyWith({
    int? id,
    String? nome,
    String? orgao, // <<< ADAPTADO
    String? responsavel,
    DateTime? dataCriacao,
  }) {
    return Campanha(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      orgao: orgao ?? this.orgao, // <<< ADAPTADO
      responsavel: responsavel ?? this.responsavel,
      dataCriacao: dataCriacao ?? this.dataCriacao,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'orgao': orgao, // <<< ADAPTADO
      'responsavel': responsavel,
      'dataCriacao': dataCriacao.toIso8601String(),
    };
  }

  factory Campanha.fromMap(Map<String, dynamic> map) {
    return Campanha(
      id: map['id'],
      nome: map['nome'],
      // <<< MUDANÇA: Verifica tanto o novo nome ('orgao') quanto o antigo ('empresa') por compatibilidade >>>
      orgao: map['orgao'] ?? map['empresa'] ?? '', 
      responsavel: map['responsavel'],
      dataCriacao: DateTime.parse(map['dataCriacao']),
    );
  }
}