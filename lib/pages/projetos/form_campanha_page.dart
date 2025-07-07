// lib/pages/campanhas/form_campanha_page.dart (ADAPTADO PARA GEOVIGILÂNCIA)

import 'package:flutter/material.dart';
import 'package:geovigilancia/data/datasources/local/database_helper.dart';
// <<< MUDANÇA: Importa o modelo Campanha em vez de Projeto >>>
import 'package:geovigilancia/models/campanha_model.dart'; 

class FormCampanhaPage extends StatefulWidget {
  // <<< MUDANÇA: Parâmetro para edição agora é do tipo Campanha >>>
  final Campanha? campanhaParaEditar;

  const FormCampanhaPage({
    super.key,
    this.campanhaParaEditar,
  });

  bool get isEditing => campanhaParaEditar != null;

  @override
  State<FormCampanhaPage> createState() => _FormCampanhaPageState();
}

class _FormCampanhaPageState extends State<FormCampanhaPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  // <<< MUDANÇA: Controller de 'empresa' renomeado para 'orgao' >>>
  final _orgaoController = TextEditingController();
  final _responsavelController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      final campanha = widget.campanhaParaEditar!;
      _nomeController.text = campanha.nome;
      _orgaoController.text = campanha.orgao;
      _responsavelController.text = campanha.responsavel;
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _orgaoController.dispose();
    _responsavelController.dispose();
    super.dispose();
  }

  // <<< MUDANÇA: Lógica de salvar adaptada para o objeto Campanha >>>
  Future<void> _salvarCampanha() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      
      final campanha = Campanha(
        id: widget.isEditing ? widget.campanhaParaEditar!.id : null,
        nome: _nomeController.text.trim(),
        orgao: _orgaoController.text.trim(),
        responsavel: _responsavelController.text.trim(),
        dataCriacao: widget.isEditing ? widget.campanhaParaEditar!.dataCriacao : DateTime.now(),
      );

      try {
        final dbHelper = DatabaseHelper.instance;
        final db = await dbHelper.database;
        
        if (widget.isEditing) {
          await db.update(
            'campanhas', // <<< MUDANÇA: Nome da tabela
            campanha.toMap(),
            where: 'id = ?',
            whereArgs: [campanha.id],
          );
        } else {
          await dbHelper.insertCampanha(campanha); // <<< MUDANÇA: Método específico
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Campanha ${widget.isEditing ? "atualizada" : "criada"} com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao salvar a campanha: $e'), backgroundColor: Colors.red),
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
        title: Text(widget.isEditing ? 'Editar Campanha' : 'Nova Campanha'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome da Campanha',
                  hintText: 'Ex: LIRAa - Jan/2024',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.campaign_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'O nome da campanha é obrigatório.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // <<< MUDANÇA: Campo 'Empresa' adaptado para 'Órgão' >>>
              TextFormField(
                controller: _orgaoController,
                decoration: const InputDecoration(
                  labelText: 'Órgão Responsável',
                  hintText: 'Ex: Secretaria de Saúde',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.corporate_fare_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'O nome do órgão é obrigatório.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _responsavelController,
                decoration: const InputDecoration(
                  labelText: 'Responsável Técnico',
                  hintText: 'Ex: Coordenador de Endemias',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                 validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'O nome do responsável é obrigatório.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _salvarCampanha, // <<< MUDANÇA: Chama o método adaptado
                icon: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Salvando...' : (widget.isEditing ? 'Atualizar Campanha' : 'Salvar Campanha')),
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