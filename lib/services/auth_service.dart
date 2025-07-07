// lib/services/auth_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geovigilancia/services/licensing_service.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Instância do Firestore
  final LicensingService _licensingService = LicensingService();

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    // Mantém seu login de super-dev para testes rápidos
    if (email == 'teste@geoforest.com') {
      print('Usuário super-dev detectado. Pulando verificação de licença.');
      return _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    }

    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw FirebaseAuthException(code: 'user-not-found', message: 'Usuário não encontrado após o login.');
      }

      // A verificação de licença continua a mesma no login
      await _licensingService.checkAndRegisterDevice(userCredential.user!);
      
      return userCredential;

    } on LicenseException catch (e) {
      print('Erro de licença: ${e.message}. Deslogando usuário.');
      await signOut(); 
      rethrow;

    } on FirebaseAuthException {
      rethrow;
    }
  }

  // MÉTODO DE CRIAÇÃO DE USUÁRIO ATUALIZADO
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    // 1. Cria o usuário no Firebase Authentication
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.updateDisplayName(displayName);

    // 2. Se a criação do usuário for bem-sucedida, cria a licença trial
    if (credential.user != null) {
      await _criarLicencaTrialParaNovoUsuario(credential.user!);
    }
    
    return credential;
  }
  
  // NOVO MÉTODO PRIVADO PARA CRIAR A LICENÇA TRIAL AUTOMATICAMENTE
  Future<void> _criarLicencaTrialParaNovoUsuario(User user) async {
    // Usa o UID (ID único) do usuário como o ID do documento do cliente
    final clienteRef = _firestore.collection('clientes').doc(user.uid); 
    
    // Verifica se já existe um documento para este usuário (medida de segurança)
    final docSnapshot = await clienteRef.get();
    if (docSnapshot.exists) {
      print("Documento de cliente já existe para o usuário ${user.uid}. Pulando criação do trial.");
      return;
    }

    // Calcula a data de fim do trial (7 dias a partir de agora)
    final dataFimTrial = DateTime.now().add(const Duration(days: 7));

    // Cria o documento do novo cliente com a licença de trial
    await clienteRef.set({
      'nomeCliente': user.displayName ?? user.email, // Salva o nome do cliente
      'usuariosPermitidos': [user.email], // Adiciona o próprio e-mail à lista de permitidos
      'planoId': 'basico', // Define o plano padrão para o trial (pode ser "trial" se você criar um)
      'statusAssinatura': 'trial',
      'trial': {
        'ativo': true,
        'dataInicio': Timestamp.now(), // Data e hora atual
        'dataFim': Timestamp.fromDate(dataFimTrial), // Data e hora daqui a 7 dias
      }
    });

    print("Licença trial criada com sucesso para o usuário ${user.email}");
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  User? get currentUser => _firebaseAuth.currentUser;
}