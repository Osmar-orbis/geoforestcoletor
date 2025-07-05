import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:simple_animations/simple_animations.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    // Navega para a próxima tela após um tempo
    Timer(const Duration(seconds: 4), () { // Reduzi um pouco o tempo total
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/auth_check');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff00363a),
      body: Stack(
        children: [
          // Efeito de fundo com partículas animadas
          const Positioned.fill(child: AnimatedParticles(300)),
          
          // Logo com animação de Fade-In e leve zoom
          Center(
            child: PlayAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(seconds: 3),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.scale(
                    scale: 0.8 + (value * 0.2),
                    child: child,
                  ),
                );
              },
              child: Image.asset(
                'assets/images/splash_logo.png', 
                width: 250,
              ),
            ),
          ),
          
          // <<< MUDANÇA PRINCIPAL AQUI >>>
          // O WIDGET Positioned QUE CONTINHA A BARRA DE PROGRESSO FOI REMOVIDO.
          
        ],
      ),
    );
  }
}

// ---- WIDGETS AUXILIARES PARA A ANIMAÇÃO DE FUNDO ----
// (O resto do código permanece exatamente igual)

class AnimatedParticles extends StatefulWidget {
  final int numberOfParticles;
  const AnimatedParticles(this.numberOfParticles, {super.key});

  @override
  State<AnimatedParticles> createState() => _AnimatedParticlesState();
}

class _AnimatedParticlesState extends State<AnimatedParticles> {
  final Random random = Random();
  final List<ParticleModel> particles = [];
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final size = MediaQuery.of(context).size;
      setState(() {
        for (int i = 0; i < widget.numberOfParticles; i++) {
          particles.add(ParticleModel(random, size));
        }
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Container();
    }
    
    return LoopAnimationBuilder(
      tween: ConstantTween(1),
      duration: const Duration(days: 1),
      builder: (context, value, child) {
        _simulateParticles();
        return CustomPaint(
          painter: ParticlePainter(particles),
        );
      },
    );
  }

  void _simulateParticles() {
    for (var particle in particles) {
      particle.move();
    }
  }
}

class ParticlePainter extends CustomPainter {
  List<ParticleModel> particles;
  ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green.withAlpha(50)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.0;

    for (var particle in particles) {
      final alpha = (particle.size * 50).clamp(10, 255).toInt();
      paint.color = Colors.green.withAlpha(alpha);
      canvas.drawCircle(Offset(particle.x, particle.y), particle.size, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class ParticleModel {
  late double x;
  late double y;
  late double size;
  late double vx;
  late double vy;
  Random random;
  Size area;

  ParticleModel(this.random, this.area) {
    _init();
  }

  void _init() {
    x = random.nextDouble() * area.width;
    y = random.nextDouble() * area.height;
    size = 0.5 + random.nextDouble() * 2.5;
    double speed = (0.1 + random.nextDouble() * 0.4) / (size * 0.5); 
    double angle = random.nextDouble() * 2 * pi;
    vx = cos(angle) * speed;
    vy = sin(angle) * speed;
  }
  
  void move() {
    x += vx;
    y += vy;

    if (x > area.width + size) {
      x = -size;
    } else if (x < -size) {
      x = area.width + size;
    }

    if (y > area.height + size) {
      y = -size;
    } else if (y < -size) {
      y = area.height + size;
    }
  }
}