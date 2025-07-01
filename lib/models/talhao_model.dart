// lib/models/talhao_model.dart

class Talhao {
  final int? id;
  
  // Chaves estrangeiras
  final String fazendaId; 
  final int fazendaAtividadeId;
  
  // Propriedades do Talhão
  final String nome;
  final double? areaHa;
  final double? idadeAnos;
  final String? especie;

  // Campo para exibição na UI
  final String? fazendaNome;

  Talhao({
    this.id,
    required this.fazendaId,
    required this.fazendaAtividadeId,
    required this.nome,
    this.areaHa,
    this.idadeAnos,
    this.especie,
    this.fazendaNome, 
  });

  // >>> MÉTODO ADICIONADO AQUI <<<
  Talhao copyWith({
    int? id,
    String? fazendaId,
    int? fazendaAtividadeId,
    String? nome,
    double? areaHa,
    double? idadeAnos,
    String? especie,
    String? fazendaNome,
  }) {
    return Talhao(
      id: id ?? this.id,
      fazendaId: fazendaId ?? this.fazendaId,
      fazendaAtividadeId: fazendaAtividadeId ?? this.fazendaAtividadeId,
      nome: nome ?? this.nome,
      areaHa: areaHa ?? this.areaHa,
      idadeAnos: idadeAnos ?? this.idadeAnos,
      especie: especie ?? this.especie,
      fazendaNome: fazendaNome ?? this.fazendaNome,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fazendaId': fazendaId,
      'fazendaAtividadeId': fazendaAtividadeId,
      'nome': nome,
      'areaHa': areaHa,
      'idadeAnos': idadeAnos,
      'especie': especie,
    };
  }

  factory Talhao.fromMap(Map<String, dynamic> map) {
    return Talhao(
      id: map['id'],
      fazendaId: map['fazendaId'],
      fazendaAtividadeId: map['fazendaAtividadeId'],
      nome: map['nome'],
      areaHa: map['areaHa'],
      idadeAnos: map['idadeAnos'],
      especie: map['especie'],
      fazendaNome: map['fazendaNome'], 
    );
  }
}