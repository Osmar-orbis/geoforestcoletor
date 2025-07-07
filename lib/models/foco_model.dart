// lib/models/foco_model.dart

class Foco {
  int? id;
  // Chave estrangeira para a vistoria a que este foco pertence.
  int vistoriaId;

  // <<< MUDANÇA: Campos principais para descrever o foco. >>>
  final String tipoCriadouro;       // Ex: "Pneu", "Vaso de Planta"
  final bool larvasEncontradas;     // true se encontrou larvas de Aedes
  final String? tratamentoRealizado; // Ex: "Eliminação Mecânica", "Larvicida"
  final String? fotoUrl;             // Caminho para a foto específica do foco

  // <<< REMOÇÃO: Todos os campos florestais foram removidos. >>>
  // cap, altura, linha, posicaoNaLinha, fimDeLinha, dominante, codigo, etc.

  Foco({
    this.id,
    required this.vistoriaId,
    required this.tipoCriadouro,
    required this.larvasEncontradas,
    this.tratamentoRealizado,
    this.fotoUrl,
  });

  Foco copyWith({
    int? id,
    int? vistoriaId,
    String? tipoCriadouro,
    bool? larvasEncontradas,
    String? tratamentoRealizado,
    String? fotoUrl,
  }) {
    return Foco(
      id: id ?? this.id,
      vistoriaId: vistoriaId ?? this.vistoriaId,
      tipoCriadouro: tipoCriadouro ?? this.tipoCriadouro,
      larvasEncontradas: larvasEncontradas ?? this.larvasEncontradas,
      tratamentoRealizado: tratamentoRealizado ?? this.tratamentoRealizado,
      fotoUrl: fotoUrl ?? this.fotoUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vistoriaId': vistoriaId,
      'tipoCriadouro': tipoCriadouro,
      // Salva o booleano como um inteiro (0 ou 1) no banco de dados.
      'larvasEncontradas': larvasEncontradas ? 1 : 0,
      'tratamentoRealizado': tratamentoRealizado,
      'fotoUrl': fotoUrl,
    };
  }

  factory Foco.fromMap(Map<String, dynamic> map) {
    return Foco(
      id: map['id'],
      vistoriaId: map['vistoriaId'],
      tipoCriadouro: map['tipoCriadouro'] ?? '',
      // Lê o inteiro do banco e converte de volta para booleano.
      larvasEncontradas: map['larvasEncontradas'] == 1,
      tratamentoRealizado: map['tratamentoRealizado'],
      fotoUrl: map['fotoUrl'],
    );
  }
}