// lib/models/tipo_criadouro_model.dart

class TipoCriadouro {
  final int? id;
  final String nome; // Ex: "Pneu", "Vaso de Planta", "Caixa d'água"

  // <<< REMOÇÃO: Campos de sortimento florestal removidos. >>>
  // final double comprimento;
  // final double diametroMinimo;
  // final double diametroMaximo;

  TipoCriadouro({
    this.id,
    required this.nome,
  });

  TipoCriadouro copyWith({
    int? id,
    String? nome,
  }) {
    return TipoCriadouro(
      id: id ?? this.id,
      nome: nome ?? this.nome,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
    };
  }

  factory TipoCriadouro.fromMap(Map<String, dynamic> map) {
    return TipoCriadouro(
      id: map['id'],
      nome: map['nome'] ?? '',
    );
  }
}