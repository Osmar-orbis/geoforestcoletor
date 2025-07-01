// lib/widgets/informacoes_adicionais_dialog.dart (NOVO ARQUIVO)

import 'package:flutter/material.dart';

class InformacoesAdicionaisDialog extends StatefulWidget {
  final String? espacamentoInicial;
  final double? idadeInicial;
  final double? areaTalhaoInicial;

  const InformacoesAdicionaisDialog({
    super.key,
    this.espacamentoInicial,
    this.idadeInicial,
    this.areaTalhaoInicial,
  });

  @override
  State<InformacoesAdicionaisDialog> createState() => _InformacoesAdicionaisDialogState();
}

class _InformacoesAdicionaisDialogState extends State<InformacoesAdicionaisDialog> {
  final _formKey = GlobalKey<FormState>();
  final _espacamentoController = TextEditingController();
  final _idadeController = TextEditingController();
  final _areaTalhaoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _espacamentoController.text = widget.espacamentoInicial ?? '';
    if (widget.idadeInicial != null) {
      _idadeController.text = widget.idadeInicial.toString().replaceAll('.', ',');
    }
    if (widget.areaTalhaoInicial != null) {
      _areaTalhaoController.text = widget.areaTalhaoInicial.toString().replaceAll('.', ',');
    }
  }

  @override
  void dispose() {
    _espacamentoController.dispose();
    _idadeController.dispose();
    _areaTalhaoController.dispose();
    super.dispose();
  }

  void _salvar() {
    if (_formKey.currentState!.validate()) {
      final resultado = {
        'espacamento': _espacamentoController.text.trim().isNotEmpty ? _espacamentoController.text.trim() : null,
        'idade': _idadeController.text.isNotEmpty ? double.tryParse(_idadeController.text.replaceAll(',', '.')) : null,
        'areaTalhao': _areaTalhaoController.text.isNotEmpty ? double.tryParse(_areaTalhaoController.text.replaceAll(',', '.')) : null,
      };
      Navigator.of(context).pop(resultado);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Informações Adicionais'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _espacamentoController,
                decoration: const InputDecoration(
                  labelText: 'Espaçamento (ex: 3x2)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _idadeController,
                decoration: const InputDecoration(
                  labelText: 'Idade da Floresta (anos)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _areaTalhaoController,
                decoration: const InputDecoration(
                  labelText: 'Área do Talhão (ha)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _salvar,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}