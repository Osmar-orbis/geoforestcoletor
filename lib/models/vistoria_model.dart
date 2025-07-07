// lib/models/vistoria_model.dart

import 'dart:convert';
import 'package:flutter/material.dart';
// Importa o modelo Foco, que será o próximo a ser criado.
import 'package:geovigilancia/models/foco_model.dart'; 

// <<< MUDANÇA: Novo enum para o status da visita domiciliar. >>>
enum StatusVisita {
  realizada(Icons.check_circle_outline, Colors.green),
  fechada(Icons.lock_outline, Colors.orange),
  recusa(Icons.do_not_disturb_on_outlined, Colors.red),
  pendente(Icons.pending_outlined, Colors.grey); // Mantemos 'pendente' para planejamento

  final IconData icone;
  final Color cor;
  
  const StatusVisita(this.icone, this.cor);
}

// <<< MUDANÇA: Classe renomeada de Parcela para Vistoria. >>>
class Vistoria {
  int? dbId;
  int? setorId; // Chave estrangeira para o setor (antigo talhaoId)
  DateTime? dataColeta;
  
  // <<< MUDANÇA: Campos de identificação adaptados. >>>
  final String? idBairro; // antigo idFazenda
  final String? nomeBairro; // antigo nomeFazenda
  final String? nomeSetor; // antigo nomeTalhao

  // <<< MUDANÇA: Campos principais completamente adaptados para a vistoria. >>>
  final String? identificadorImovel; // antigo idParcela (ex: Rua X, 123)
  final String tipoImovel; // Ex: Residencial, Comercial, Terreno Baldio
  final String? resultado; // Ex: "Com Foco", "Sem Foco"
  
  final String? observacao;
  final double? latitude;
  final double? longitude;
  StatusVisita status;
  bool exportada;
  bool isSynced;
  List<String> photoPaths; // Para fotos GERAIS do imóvel
  
  // Lista de focos encontrados nesta vistoria.
  List<Foco> focos;

  // <<< REMOÇÃO: Campos de área e dimensões foram removidos. >>>
  // areaMetrosQuadrados, largura, comprimento, raio

  Vistoria({
    this.dbId,
    this.setorId,
    this.identificadorImovel,
    required this.tipoImovel,
    this.resultado,
    this.idBairro,
    this.nomeBairro,
    this.nomeSetor,
    this.observacao,
    this.latitude,
    this.longitude,
    this.dataColeta,
    this.status = StatusVisita.pendente,
    this.exportada = false,
    this.isSynced = false,
    this.photoPaths = const [],
    this.focos = const [],
  });

  Vistoria copyWith({
    int? dbId,
    int? setorId,
    String? idBairro,
    String? nomeBairro,
    String? nomeSetor,
    String? identificadorImovel,
    String? tipoImovel,
    String? resultado,
    String? observacao,
    double? latitude,
    double? longitude,
    DateTime? dataColeta,
    StatusVisita? status,
    bool? exportada,
    bool? isSynced,
    List<String>? photoPaths,
    List<Foco>? focos,
  }) {
    return Vistoria(
      dbId: dbId ?? this.dbId,
      setorId: setorId ?? this.setorId,
      idBairro: idBairro ?? this.idBairro,
      nomeBairro: nomeBairro ?? this.nomeBairro,
      nomeSetor: nomeSetor ?? this.nomeSetor,
      identificadorImovel: identificadorImovel ?? this.identificadorImovel,
      tipoImovel: tipoImovel ?? this.tipoImovel,
      resultado: resultado ?? this.resultado,
      observacao: observacao ?? this.observacao,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      dataColeta: dataColeta ?? this.dataColeta,
      status: status ?? this.status,
      exportada: exportada ?? this.exportada,
      isSynced: isSynced ?? this.isSynced,
      photoPaths: photoPaths ?? this.photoPaths,
      focos: focos ?? this.focos,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': dbId,
      'setorId': setorId,
      'idBairro': idBairro, // antigo idFazenda
      'nomeBairro': nomeBairro, // antigo nomeFazenda
      'nomeSetor': nomeSetor, // antigo nomeTalhao
      'identificadorImovel': identificadorImovel,
      'tipoImovel': tipoImovel,
      'resultado': resultado,
      'observacao': observacao,
      'latitude': latitude,
      'longitude': longitude,
      'dataColeta': dataColeta?.toIso8601String(),
      // <<< MUDANÇA: O nome do campo no banco é 'statusVisita' >>>
      'statusVisita': status.name, 
      'exportada': exportada ? 1 : 0,
      'isSynced': isSynced ? 1 : 0,
      'photoPaths': jsonEncode(photoPaths),
    };
  }

  factory Vistoria.fromMap(Map<String, dynamic> map) {
    List<String> paths = [];
    if (map['photoPaths'] != null) {
      try {
        paths = List<String>.from(jsonDecode(map['photoPaths']));
      } catch (e) {
        debugPrint("Erro ao decodificar photoPaths: $e");
      }
    }

    return Vistoria(
      dbId: map['id'],
      setorId: map['setorId'] ?? map['talhaoId'], // Compatibilidade
      idBairro: map['idBairro'] ?? map['idFazenda'], // Compatibilidade
      nomeBairro: map['nomeBairro'] ?? map['nomeFazenda'], // Compatibilidade
      nomeSetor: map['nomeSetor'] ?? map['nomeTalhao'], // Compatibilidade
      identificadorImovel: map['identificadorImovel'] ?? map['idParcela'], // Compatibilidade
      tipoImovel: map['tipoImovel'] ?? '', // Campo novo
      resultado: map['resultado'], // Campo novo
      observacao: map['observacao'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      dataColeta: map['dataColeta'] != null ? DateTime.parse(map['dataColeta']) : null,
      status: StatusVisita.values.firstWhere(
            (e) => e.name == (map['statusVisita'] ?? map['status']), // Lê o novo e o antigo
        orElse: () => StatusVisita.pendente,
      ),
      exportada: map['exportada'] == 1,
      isSynced: map['isSynced'] == 1,
      photoPaths: paths,
    );
  }
}