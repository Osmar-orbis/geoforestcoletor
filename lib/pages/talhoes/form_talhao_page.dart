// lib/pages/talhoes/form_talhao_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/talhao_model.dart';

class FormTalhaoPage extends StatefulWidget {
  // O formulário precisa saber a qual fazenda o novo talhão pertence.
  // Para isso, passamos a chave primária composta da fazenda.
  final String fazendaId;
  final int fazendaAtividadeId;

  const FormTalhaoPage({
    super.key,
    required this.fazendaId,
    required this.fazendaAtividadeId,
  });

  @override
  State<FormTalhaoPage> createState() => _FormTalhaoPageState();
}

class _FormTalhaoPageState extends State<FormTalhaoPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _areaController = TextEditingController();
  final _idadeController = TextEditingController();
  final _especieController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _areaController.dispose();
    _idadeController.dispose();
    _especieController.dispose();
    super.dispose();
  }

  Future<void> _salvarTalhao() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isSaving = true);

      final novoTalhao = Talhao(
        fazendaId: widget.fazendaId,
        fazendaAtividadeId: widget.fazendaAtividadeId,
        nome: _nomeController.text.trim(),
        areaHa: double.tryParse(_areaController.text.replaceAll(',', '.')),
        idadeAnos: double.tryParse(_idadeController.text.replaceAll(',', '.')),
        especie: _especieController.text.trim(),
      );

      try {
        final dbHelper = DatabaseHelper.instance;
        await dbHelper.insertTalhao(novoTalhao);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Talhão criado com sucesso!'), backgroundColor: Colors.green),
          );
          Navigator.of(context).pop(true); // Retorna 'true' para recarregar a lista
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao salvar talhão: $e'), backgroundColor: Colors.red),
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
        title: const Text('Novo Talhão'),
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
                  labelText: 'Nome ou Código do Talhão',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pin_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'O nome do talhão é obrigatório.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _especieController,
                decoration: const InputDecoration(
                  labelText: 'Espécie (ex: Eucalipto)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.eco_outlined),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _areaController,
                      decoration: const InputDecoration(
                        labelText: 'Área (ha)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.area_chart_outlined),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d*')),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _idadeController,
                      decoration: const InputDecoration(
                        labelText: 'Idade (anos)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.cake_outlined),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d*')),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _salvarTalhao,
                icon: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Salvando...' : 'Salvar Talhão'),
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