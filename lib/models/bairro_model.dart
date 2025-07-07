// lib/models/bairro_model.dart

class Bairro {
  // O id pode ser o código oficial do bairro ou um identificador único.
  final String id; 
  final int atividadeId;
  final String nome;
  final String municipio;
  final String estado;

  Bairro({
    required this.id,
    required this.atividadeId,
    required this.nome,
    required this.municipio,
    required this.estado,
  });

  // <<< Nenhuma mudança na lógica dos métodos, apenas renomeação da classe. >>>

  Bairro copyWith({
    String? id,
    int? atividadeId,
    String? nome,
    String? municipio,
    String? estado,
  }) {
    return Bairro(
      id: id ?? this.id,
      atividadeId: atividadeId ?? this.atividadeId,
      nome: nome ?? this.nome,
      municipio: municipio ?? this.municipio,
      estado: estado ?? this.estado,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'atividadeId': atividadeId,
      'nome': nome,
      'municipio': municipio,
      'estado': estado,
    };
  }

  factory Bairro.fromMap(Map<String, dynamic> map) {
    return Bairro(
      id: map['id'],
      atividadeId: map['atividadeId'],
      nome: map['nome'],
      municipio: map['municipio'],
      estado: map['estado'],
    );
  }
}