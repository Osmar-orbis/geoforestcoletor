// lib/pages/atividades/form_atividade_page.dart
import 'package:flutter/material.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/atividade_model.dart';

class FormAtividadePage extends StatefulWidget {
  final int projetoId;

  const FormAtividadePage({super.key, required this.projetoId});

  @override
  State<FormAtividadePage> createState() => _FormAtividadePageState();
}

class _FormAtividadePageState extends State<FormAtividadePage> {
  final _formKey = GlobalKey<FormState>();
  final _tipoController = TextEditingController();
  final _descricaoController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _tipoController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  Future<void> _salvarAtividade() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      final novaAtividade = Atividade(
        projetoId: widget.projetoId,
        tipo: _tipoController.text.trim(),
        descricao: _descricaoController.text.trim(),
        dataCriacao: DateTime.now(), // Define a data de criação no momento do salvamento
      );

      try {
        final dbHelper = DatabaseHelper.instance;
        await dbHelper.insertAtividade(novaAtividade);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Atividade criada com sucesso!'), backgroundColor: Colors.green),
          );
          Navigator.of(context).pop(true); // Retorna 'true' para recarregar a lista
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
        title: const Text('Nova Atividade'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _tipoController,
                decoration: const InputDecoration(
                  labelText: 'Tipo da Atividade (ex: Inventário, Cubagem)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
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
                label: Text(_isSaving ? 'Salvando...' : 'Salvar Atividade'),
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