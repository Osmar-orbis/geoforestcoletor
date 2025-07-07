// lib/pages/atividades/form_atividade_page.dart (ADAPTADO PARA GEOVIGILÂNCIA)

import 'package:flutter/material.dart';
import 'package:geovigilancia/data/datasources/local/database_helper.dart';
import 'package:geovigilancia/models/atividade_model.dart';

class FormAtividadePage extends StatefulWidget {
  // <<< MUDANÇA: Recebe 'campanhaId' em vez de 'projetoId' >>>
  final int campanhaId;
  final Atividade? atividadeParaEditar;

  const FormAtividadePage({
    super.key,
    required this.campanhaId,
    this.atividadeParaEditar,
  });

  bool get isEditing => atividadeParaEditar != null;

  @override
  State<FormAtividadePage> createState() => _FormAtividadePageState();
}

class _FormAtividadePageState extends State<FormAtividadePage> {
  final _formKey = GlobalKey<FormState>();
  // <<< MUDANÇA: Controller para o Dropdown >>>
  String? _tipoSelecionado;
  final _descricaoController = TextEditingController();

  bool _isSaving = false;

  // Lista de tipos de atividade para o dropdown
  final List<String> _tiposDeAtividade = [
    'LIRAa',
    'Visita de Rotina',
    'Ponto Estratégico',
    'Atendimento a Denúncia',
    'Bloqueio de Transmissão',
    'Outra',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      final atividade = widget.atividadeParaEditar!;
      // Garante que o tipo selecionado exista na lista, ou usa 'Outra'
      _tipoSelecionado = _tiposDeAtividade.contains(atividade.tipo) ? atividade.tipo : 'Outra';
      _descricaoController.text = atividade.descricao;
    }
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    super.dispose();
  }

  // <<< MUDANÇA: Lógica de salvar adaptada para Campanha e sem cubagem >>>
  Future<void> _salvarAtividade() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      final atividade = Atividade(
        id: widget.isEditing ? widget.atividadeParaEditar!.id : null,
        campanhaId: widget.campanhaId,
        tipo: _tipoSelecionado!,
        descricao: _descricaoController.text.trim(),
        dataCriacao: widget.isEditing ? widget.atividadeParaEditar!.dataCriacao : DateTime.now(),
      );

      try {
        final dbHelper = DatabaseHelper.instance;
        final db = await dbHelper.database;
        
        if (widget.isEditing) {
          await db.update(
            'atividades',
            atividade.toMap(),
            where: 'id = ?',
            whereArgs: [atividade.id],
          );
        } else {
          await db.insert('atividades', atividade.toMap());
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Atividade ${widget.isEditing ? "atualizada" : "criada"} com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao salvar atividade: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar Atividade' : 'Nova Atividade'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // <<< MUDANÇA: TextFormField trocado por DropdownButtonFormField >>>
              DropdownButtonFormField<String>(
                value: _tipoSelecionado,
                items: _tiposDeAtividade
                    .map((tipo) => DropdownMenuItem(value: tipo, child: Text(tipo)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _tipoSelecionado = value;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Tipo da Atividade',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'O tipo da atividade é obrigatório.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descricaoController,
                decoration: const InputDecoration(
                  labelText: 'Descrição (Opcional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _salvarAtividade,
                icon: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Salvando...' : (widget.isEditing ? 'Atualizar Atividade' : 'Salvar Atividade')),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}