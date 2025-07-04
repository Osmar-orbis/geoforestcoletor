// lib/pages/analises/form_sortimento_page.dart (ARQUIVO NOVO E COMPLETO)

import 'package:flutter/material.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/sortimento_model.dart';

class FormSortimentoPage extends StatefulWidget {
  final SortimentoModel? sortimentoParaEditar;

  const FormSortimentoPage({super.key, this.sortimentoParaEditar});

  bool get isEditing => sortimentoParaEditar != null;

  @override
  State<FormSortimentoPage> createState() => _FormSortimentoPageState();
}

class _FormSortimentoPageState extends State<FormSortimentoPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _comprimentoController = TextEditingController();
  final _dminController = TextEditingController();
  final _dmaxController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      final s = widget.sortimentoParaEditar!;
      _nomeController.text = s.nome;
      _comprimentoController.text = s.comprimento.toString().replaceAll('.', ',');
      _dminController.text = s.diametroMinimo.toString().replaceAll('.', ',');
      _dmaxController.text = s.diametroMaximo.toString().replaceAll('.', ',');
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _comprimentoController.dispose();
    _dminController.dispose();
    _dmaxController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final sortimento = SortimentoModel(
      id: widget.sortimentoParaEditar?.id,
      nome: _nomeController.text.trim(),
      comprimento: double.parse(_comprimentoController.text.replaceAll(',', '.')),
      diametroMinimo: double.parse(_dminController.text.replaceAll(',', '.')),
      diametroMaximo: double.parse(_dmaxController.text.replaceAll(',', '.')),
    );

    try {
      await DatabaseHelper.instance.insertSortimento(sortimento);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Sortimento ${widget.isEditing ? 'atualizado' : 'salvo'} com sucesso!'),
          backgroundColor: Colors.green,
        ));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
  
  String? _validadorNumero(String? v) {
      if (v == null || v.trim().isEmpty) return 'Obrigatório';
      if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Número inválido';
      return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar Sortimento' : 'Novo Sortimento'),
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
                decoration: const InputDecoration(labelText: 'Nome do Produto (Ex: Serraria 6m)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.label_outline)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _comprimentoController,
                decoration: const InputDecoration(labelText: 'Comprimento (m)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.straighten_outlined)),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _validadorNumero,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dminController,
                decoration: const InputDecoration(labelText: 'Diâmetro Mínimo na Ponta Fina (cm)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.arrow_downward)),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _validadorNumero,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dmaxController,
                decoration: const InputDecoration(labelText: 'Diâmetro Máximo na Ponta Fina (cm)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.arrow_upward)),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _validadorNumero,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _salvar,
                icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save_outlined),
                label: const Text('Salvar Definição'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}