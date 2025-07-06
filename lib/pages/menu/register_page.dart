// lib/pages/menu/register_page.dart

import 'package:flutter/material.dart';
import 'package:geoforestcoletor/services/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    // Valida o formulário. Se os campos não estiverem corretos, o processo para.
    if (!_formKey.currentState!.validate()) {
      return; 
    }

    setState(() => _isLoading = true);

    try {
      // Chama o serviço de autenticação para criar o usuário.
      await _authService.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _nameController.text.trim(),
      );
      
      // Se a criação for bem-sucedida, mostra um feedback e volta para a tela de login.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conta criada com sucesso! Por favor, faça o login.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      // Se ocorrer qualquer erro, mostra a mensagem na tela.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar conta: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Garante que o estado de loading seja desativado.
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1D4433)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form( // O Form envolve todos os TextFormFields
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 20),
                
                // Logo
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/logo_2.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Título e Subtítulo
                const Text('Criar nova conta', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1D4433))),
                const SizedBox(height: 8),
                const Text('Preencha os dados para começar', style: TextStyle(fontSize: 16, color: Color(0xFF617359))),
                const SizedBox(height: 40),
                
                // Campo Nome
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nome completo', prefixIcon: Icon(Icons.person_outlined, color: Color(0xFF617359)), border: OutlineInputBorder()),
                  validator: (value) {
                    if (value == null || value.trim().length < 2) {
                      return 'Por favor, insira seu nome completo';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Campo Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF617359)), border: OutlineInputBorder()),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, insira seu email';
                    }
                    // <<< VALIDAÇÃO CORRIGIDA AQUI >>>
                    if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~-]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value)) {
                      return 'Por favor, insira um email válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Campo Senha
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    prefixIcon: const Icon(Icons.lock_outlined, color: Color(0xFF617359)),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: const Color(0xFF617359)),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'A senha deve ter pelo menos 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Campo Confirmar Senha
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirmar senha',
                    prefixIcon: const Icon(Icons.lock_outlined, color: Color(0xFF617359)),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: const Color(0xFF617359)),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'As senhas não coincidem';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                
                // Botão Criar Conta
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D4433),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Criar conta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Link para Login
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Já tem uma conta? ', style: TextStyle(color: Color(0xFF617359))),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fazer login', style: TextStyle(color: Color(0xFF1D4433), fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}