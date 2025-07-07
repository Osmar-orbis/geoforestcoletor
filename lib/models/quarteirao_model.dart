// lib/models/quarteirao_model.dart

class Quarteirao {
  final int? id;
  
  // <<< MUDANÇA: Chaves estrangeiras renomeadas para refletir a nova hierarquia (Bairro) >>>
  final String bairroId; 
  final int bairroAtividadeId;
  
  // Propriedades do Quarteirão
  final String nome; // Ex: "001", "15-A", "Q-27"
  final double? areaHa; // Área em hectares, pode ser útil para densidade
  
  // <<< REMOÇÃO: Campos florestais removidos >>>
  // final double? idadeAnos;
  // final String? especie;
  // final String? espacamento;
  // double? volumeTotalTalhao;

  // Campo para exibição na UI (ex: "Bairro Centro")
  final String? bairroNome; 

  Quarteirao({
    this.id,
    required this.bairroId,
    required this.bairroAtividadeId,
    required this.nome,
    this.areaHa,
    this.bairroNome,
  });

  Quarteirao copyWith({
    int? id,
    String? bairroId,
    int? bairroAtividadeId,
    String? nome,
    double? areaHa,
    String? bairroNome,
  }) {
    return Quarteirao(
      id: id ?? this.id,
      bairroId: bairroId ?? this.bairroId,
      bairroAtividadeId: bairroAtividadeId ?? this.bairroAtividadeId,
      nome: nome ?? this.nome,
      areaHa: areaHa ?? this.areaHa,
      bairroNome: bairroNome ?? this.bairroNome,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bairroId': bairroId,
      'bairroAtividadeId': bairroAtividadeId,
      'nome': nome,
      'areaHa': areaHa,
      // Campos removidos não são mais mapeados
    };
  }

  factory Quarteirao.fromMap(Map<String, dynamic> map) {
    return Quarteirao(
      id: map['id'],
      // <<< MUDANÇA: Lendo as chaves renomeadas do banco >>>
      bairroId: map['bairroId'] ?? map['fazendaId'], // Mantém compatibilidade
      bairroAtividadeId: map['bairroAtividadeId'] ?? map['fazendaAtividadeId'], // Mantém compatibilidade
      nome: map['nome'],
      areaHa: map['areaHa'],
      bairroNome: map['bairroNome'] ?? map['fazendaNome'], // Mantém compatibilidade
    );
  }
}