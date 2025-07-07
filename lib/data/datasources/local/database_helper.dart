// lib/data/datasources/local/database_helper.dart (VERSÃO ADAPTADA PARA GEOVIGILÂNCIA)

import 'dart:convert';
import 'dart:math';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:proj4dart/proj4dart.dart' as proj4;
import 'package:sqflite/sqflite.dart';
import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart';

// <<< MUDANÇA 1: Imports dos novos modelos >>>
import 'package:geovigilancia/models/campanha_model.dart';
import 'package:geovigilancia/models/atividade_model.dart';
import 'package:geovigilancia/models/bairro_model.dart';
import 'package:geovigilancia/models/setor_model.dart';
import 'package:geovigilancia/models/vistoria_model.dart';
import 'package:geovigilancia/models/foco_model.dart';
import 'package:geovigilancia/models/tipo_criadouro_model.dart';
// Import de Serviços (se necessário adaptar)
import 'package:geovigilancia/services/analysis_service.dart';

// --- CONSTANTES DE PROJEÇÃO GEOGRÁFICA (Pode manter se for usar coordenadas UTM) ---
const Map<String, int> zonasUtmSirgas2000 = {
  'SIRGAS 2000 / UTM Zona 18S': 31978, 'SIRGAS 2000 / UTM Zona 19S': 31979,
  'SIRGAS 2000 / UTM Zona 20S': 31980, 'SIRGAS 2000 / UTM Zona 21S': 31981,
  'SIRGAS 2000 / UTM Zona 22S': 31982, 'SIRGAS 2000 / UTM Zona 23S': 31983,
  'SIRGAS 2000 / UTM Zona 24S': 31984, 'SIRGAS 2000 / UTM Zona 25S': 31985,
};

final Map<int, String> proj4Definitions = {
  31978: '+proj=utm +zone=18 +south +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs',
  31979: '+proj=utm +zone=19 +south +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs',
  31980: '+proj=utm +zone=20 +south +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs',
  31981: '+proj=utm +zone=21 +south +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs',
  31982: '+proj=utm +zone=22 +south +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs',
  31983: '+proj=utm +zone=23 +south +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs',
  31984: '+proj=utm +zone=24 +south +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs',
  31985: '+proj=utm +zone=25 +south +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs',
};

// --- CLASSE PRINCIPAL DO BANCO DE DADOS ---
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  DatabaseHelper._privateConstructor();
  factory DatabaseHelper() => _instance;
  static DatabaseHelper get instance => _instance;

  Future<Database> get database async => _database ??= await _initDatabase();

  Future<Database> _initDatabase() async {
    proj4.Projection.add('EPSG:4326', '+proj=longlat +datum=WGS84 +no_defs');
    proj4Definitions.forEach((epsg, def) {
      proj4.Projection.add('EPSG:$epsg', def);
    });

    return await openDatabase(
      join(await getDatabasesPath(), 'geovigilancia.db'),
      version: 1, // <<< MUDANÇA 2: Começando com a versão 1 para o novo app
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      // onUpgrade é chamado apenas se a versão aumentar.
    );
  }

  Future<void> _onConfigure(Database db) async => await db.execute('PRAGMA foreign_keys = ON');

  // <<< MUDANÇA 3: Estrutura do banco de dados completamente adaptada >>>
  Future<void> _onCreate(Database db, int version) async {
    // Hierarquia principal
    await db.execute('''
      CREATE TABLE campanhas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        orgao TEXT NOT NULL, -- ex: Secretaria de Saúde
        responsavel TEXT NOT NULL,
        dataCriacao TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE atividades (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        campanhaId INTEGER NOT NULL,
        tipo TEXT NOT NULL, -- ex: LIRAa, Rotina, Ponto Estratégico
        descricao TEXT NOT NULL,
        dataCriacao TEXT NOT NULL,
        FOREIGN KEY (campanhaId) REFERENCES campanhas (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE bairros (
        id TEXT NOT NULL,
        atividadeId INTEGER NOT NULL,
        nome TEXT NOT NULL,
        municipio TEXT NOT NULL,
        estado TEXT NOT NULL,
        PRIMARY KEY (id, atividadeId),
        FOREIGN KEY (atividadeId) REFERENCES atividades (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE setores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bairroId TEXT NOT NULL,
        bairroAtividadeId INTEGER NOT NULL,
        nome TEXT NOT NULL, -- ex: Quarteirão 01, Setor 12
        areaHa REAL,
        FOREIGN KEY (bairroId, bairroAtividadeId) REFERENCES bairros (id, atividadeId) ON DELETE CASCADE
      )
    ''');

    // Tabelas de Coleta
    await db.execute('''
      CREATE TABLE vistorias (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        setorId INTEGER, -- Opcional, vistoria pode ser avulsa
        identificadorImovel TEXT, -- Rua e número, ou código do imóvel
        tipoImovel TEXT NOT NULL, -- Residencial, Comércio, Terreno Baldio
        statusVisita TEXT NOT NULL, -- Realizada, Fechada, Recusa
        resultado TEXT, -- Com Foco, Sem Foco (só se visita for realizada)
        observacao TEXT,
        latitude REAL,
        longitude REAL,
        dataColeta TEXT NOT NULL,
        agenteId TEXT, -- Email ou ID do agente logado
        exportada INTEGER DEFAULT 0 NOT NULL,
        photoPaths TEXT, -- Fotos gerais do imóvel
        FOREIGN KEY (setorId) REFERENCES setores (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE focos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vistoriaId INTEGER NOT NULL,
        tipoCriadouro TEXT NOT NULL, -- Pneu, Vaso, Caixa d'água
        larvasEncontradas INTEGER NOT NULL, -- 0 para Não, 1 para Sim
        tratamentoRealizado TEXT, -- Eliminação, Larvicida, Orientação
        fotoUrl TEXT, -- Caminho para a foto específica do foco
        FOREIGN KEY (vistoriaId) REFERENCES vistorias (id) ON DELETE CASCADE
      )
    ''');
    
    // Tabela de apoio
    await db.execute('''
      CREATE TABLE tipos_criadouro (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL UNIQUE
      )
    ''');

    // Índices para otimizar buscas
    await db.execute('CREATE INDEX idx_focos_vistoriaId ON focos(vistoriaId)');
  }
  
  // Para um app novo, o onUpgrade pode ser vazio inicialmente.
  // Ele será usado quando você precisar alterar a estrutura do banco (ex: ir para a versão 2)
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Implementar migrações futuras aqui
  }

  // --- MÉTODOS CRUD: HIERARQUIA (ADAPTADOS) ---
  Future<int> insertCampanha(Campanha c) async => await (await database).insert('campanhas', c.toMap());
  Future<List<Campanha>> getTodasCampanhas() async {
    final maps = await (await database).query('campanhas', orderBy: 'dataCriacao DESC');
    return List.generate(maps.length, (i) => Campanha.fromMap(maps[i]));
  }
  Future<void> deleteCampanha(int id) async => await (await database).delete('campanhas', where: 'id = ?', whereArgs: [id]);
  
  Future<int> insertAtividade(Atividade a) async => await (await database).insert('atividades', a.toMap());
  Future<List<Atividade>> getAtividadesDaCampanha(int campanhaId) async {
    final maps = await (await database).query('atividades', where: 'campanhaId = ?', whereArgs: [campanhaId], orderBy: 'dataCriacao DESC');
    return List.generate(maps.length, (i) => Atividade.fromMap(maps[i]));
  }
  Future<void> deleteAtividade(int id) async => await (await database).delete('atividades', where: 'id = ?', whereArgs: [id]);

  Future<void> insertBairro(Bairro b) async => await (await database).insert('bairros', b.toMap(), conflictAlgorithm: ConflictAlgorithm.fail);
  Future<List<Bairro>> getBairrosDaAtividade(int atividadeId) async {
    final maps = await (await database).query('bairros', where: 'atividadeId = ?', whereArgs: [atividadeId], orderBy: 'nome');
    return List.generate(maps.length, (i) => Bairro.fromMap(maps[i]));
  }
  Future<void> deleteBairro(String id, int atividadeId) async => await (await database).delete('bairros', where: 'id = ? AND atividadeId = ?', whereArgs: [id, atividadeId]);

  Future<int> insertSetor(Setor s) async => await (await database).insert('setores', s.toMap());
  Future<List<Setor>> getSetoresDoBairro(String bairroId, int bairroAtividadeId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT S.*, B.nome as bairroNome 
      FROM setores S
      INNER JOIN bairros B ON B.id = S.bairroId AND B.atividadeId = S.bairroAtividadeId
      WHERE S.bairroId = ? AND S.bairroAtividadeId = ?
      ORDER BY S.nome ASC
    ''', [bairroId, bairroAtividadeId]);
    return List.generate(maps.length, (i) => Setor.fromMap(maps[i]));
  }
  Future<void> deleteSetor(int id) async => await (await database).delete('setores', where: 'id = ?', whereArgs: [id]);

  // --- MÉTODOS CRUD: COLETA (ADAPTADOS) ---
  
  // Salva uma vistoria e todos os seus focos em uma transação
  Future<Vistoria> saveFullVistoria(Vistoria v, List<Foco> focos) async {
    final db = await database;
    await db.transaction((txn) async {
      int vId;
      final vMap = v.toMap();
      if (v.dbId == null) {
        vMap.remove('id');
        vId = await txn.insert('vistorias', vMap);
        v.dbId = vId;
      } else {
        vId = v.dbId!;
        await txn.update('vistorias', vMap, where: 'id = ?', whereArgs: [vId]);
      }
      // Apaga focos antigos e insere os novos para garantir consistência
      await txn.delete('focos', where: 'vistoriaId = ?', whereArgs: [vId]);
      for (final f in focos) {
        final fMap = f.toMap();
        fMap['vistoriaId'] = vId;
        await txn.insert('focos', fMap);
      }
    });
    return v;
  }

  Future<Vistoria?> getVistoriaById(int id) async {
    final db = await database;
    final maps = await db.query('vistorias', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return Vistoria.fromMap(maps.first);
    return null;
  }
  
  Future<List<Vistoria>> getVistoriasDoSetor(int setorId) async {
    final db = await database;
    final maps = await db.query('vistorias', where: 'setorId = ?', whereArgs: [setorId], orderBy: 'dataColeta DESC');
    return List.generate(maps.length, (i) => Vistoria.fromMap(maps[i]));
  }

  Future<List<Foco>> getFocosDaVistoria(int vistoriaId) async {
    final db = await database;
    final maps = await db.query('focos', where: 'vistoriaId = ?', whereArgs: [vistoriaId], orderBy: 'id');
    return List.generate(maps.length, (i) => Foco.fromMap(maps[i]));
  }
  
  Future<void> deleteVistoria(int id) async {
    final db = await database;
    await db.delete('vistorias', where: 'id = ?', whereArgs: [id]); // O 'ON DELETE CASCADE' apaga os focos.
  }

  // --- MÉTODOS CRUD: TIPOS DE CRIADOURO ---
  Future<int> insertTipoCriadouro(TipoCriadouro tc) async => await (await database).insert('tipos_criadouro', tc.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<TipoCriadouro>> getTodosTiposCriadouro() async {
    final db = await database;
    final maps = await db.query('tipos_criadouro', orderBy: 'nome ASC');
    if (maps.isEmpty) {
      // Adiciona padrões se estiver vazio
      final padroes = ['Pneu', 'Vaso de Planta', 'Caixa d\'água', 'Lixo Acumulado', 'Calha', 'Garrafa PET'];
      for (var nome in padroes) {
        await insertTipoCriadouro(TipoCriadouro(nome: nome));
      }
      // Recarrega a lista
      final reloadedMaps = await db.query('tipos_criadouro', orderBy: 'nome ASC');
      return List.generate(reloadedMaps.length, (i) => TipoCriadouro.fromMap(reloadedMaps[i]));
    }
    return List.generate(maps.length, (i) => TipoCriadouro.fromMap(maps[i]));
  }

  Future<void> deleteTipoCriadouro(int id) async => await (await database).delete('tipos_criadouro', where: 'id = ?', whereArgs: [id]);
  
  
  // --- MÉTODOS DE IMPORTAÇÃO (TEMPLATE PARA ADAPTAÇÃO) ---
  // AVISO: A lógica de importação precisa ser totalmente refeita com base no novo formato de CSV/GeoJSON para dengue.
  // O código abaixo é um ponto de partida.
  
  Future<String> importarVistoriasDeEquipe(String csvContent, int atividadeIdAlvo) async {
    final db = await database;
    int vistoriasProcessadas = 0;
    int focosImportados = 0;
    int novosBairros = 0;
    int novosSetores = 0;

    // Adapte o delimitador conforme seu CSV
    final List<List<dynamic>> rows = const CsvToListConverter(fieldDelimiter: ',', eol: '\n').convert(csvContent);
    if (rows.length < 2) return "Erro: O arquivo CSV está vazio ou contém apenas o cabeçalho.";
    
    final headers = rows.first.map((h) => h.toString().trim()).toList();
    
    // Agrupar por vistoria antes de processar
    final vistoriasAgrupadas = groupBy(rows.sublist(1), (row) {
        final rowMap = Map.fromIterables(headers, row);
        return rowMap['ID_Vistoria']?.toString() ?? 'VISTORIA_PADRAO';
    });

    try {
      await db.transaction((txn) async {
        for (var entry in vistoriasAgrupadas.entries) {
            final grupoDeLinhas = entry.value;
            final primeiraLinhaMap = Map.fromIterables(headers, grupoDeLinhas.first);

            // *** Adapte os nomes das colunas do seu CSV aqui ***
            final idBairro = primeiraLinhaMap['ID_Bairro']?.toString() ?? 'BAIRRO_PADRAO';
            final nomeSetor = primeiraLinhaMap['Setor']?.toString() ?? 'SETOR_PADRAO';

            // 1. Encontrar ou criar Bairro e Setor
            // (A lógica de cache é uma boa prática para performance)
            Bairro? bairro = (await txn.query('bairros', where: 'id = ? AND atividadeId = ?', whereArgs: [idBairro, atividadeIdAlvo])).map((e) => Bairro.fromMap(e)).firstOrNull;
            if (bairro == null) {
                bairro = Bairro(id: idBairro, atividadeId: atividadeIdAlvo, nome: primeiraLinhaMap['Nome_Bairro'].toString(), municipio: 'N/I', estado: 'N/I');
                await txn.insert('bairros', bairro.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
                novosBairros++;
            }
            
            Setor? setor = (await txn.query('setores', where: 'nome = ? AND bairroId = ? AND bairroAtividadeId = ?', whereArgs: [nomeSetor, bairro.id, bairro.atividadeId])).map((e) => Setor.fromMap(e)).firstOrNull;
            if (setor == null) {
                setor = Setor(bairroId: bairro.id, bairroAtividadeId: bairro.atividadeId, nome: nomeSetor);
                final setorId = await txn.insert('setores', setor.toMap());
                setor = setor.copyWith(id: setorId);
                novosSetores++;
            }

            // 2. Inserir a Vistoria
            final novaVistoria = Vistoria(
                setorId: setor.id,
                identificadorImovel: primeiraLinhaMap['ID_Imovel']?.toString(),
                tipoImovel: primeiraLinhaMap['Tipo_Imovel']?.toString() ?? 'N/I',
                statusVisita: primeiraLinhaMap['Status_Visita']?.toString() ?? 'Realizada',
                resultado: primeiraLinhaMap['Resultado']?.toString(),
                latitude: double.tryParse(primeiraLinhaMap['Latitude']?.toString() ?? ''),
                longitude: double.tryParse(primeiraLinhaMap['Longitude']?.toString() ?? ''),
                dataColeta: DateTime.tryParse(primeiraLinhaMap['Data_Coleta']?.toString() ?? '') ?? DateTime.now(),
            );

            final vistoriaDbId = await txn.insert('vistorias', novaVistoria.toMap());
            vistoriasProcessadas++;
            
            // 3. Inserir os Focos associados a esta vistoria
            for (final linhaFoco in grupoDeLinhas) {
                final focoMap = Map.fromIterables(headers, linhaFoco);
                final tipoCriadouro = focoMap['Tipo_Criadouro']?.toString();
                if (tipoCriadouro != null && tipoCriadouro.isNotEmpty) {
                    final novoFoco = Foco(
                        vistoriaId: vistoriaDbId,
                        tipoCriadouro: tipoCriadouro,
                        larvasEncontradas: focoMap['Larvas_Encontradas']?.toString().toLowerCase() == 'sim',
                        tratamentoRealizado: focoMap['Tratamento']?.toString(),
                    );
                    await txn.insert('focos', novoFoco.toMap());
                    focosImportados++;
                }
            }
        }
      });
      return "Importação Concluída!\n\nVistorias: $vistoriasProcessadas\nFocos: $focosImportados\n\nEstruturas Criadas:\n- Bairros: $novosBairros\n- Setores: $novosSetores";
    } catch (e, s) {
      debugPrint("Erro ao importar CSV: $e\nStack Trace: $s");
      return "Erro Crítico: Ocorreu uma falha. Verifique o formato do CSV.\n\nDetalhe: ${e.toString()}";
    }
  }
}