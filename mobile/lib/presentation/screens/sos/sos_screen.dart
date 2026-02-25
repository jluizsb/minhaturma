import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';

class SOSScreen extends StatelessWidget {
  const SOSScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Emergência'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Pressione o botão para alertar sua turma', textAlign: TextAlign.center),
            const SizedBox(height: 32),
            GestureDetector(
              // TODO: chamar SOSService.trigger()
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('SOS enviado para sua turma!')),
              ),
              child: Container(
                width: 180,
                height: 180,
                decoration: const BoxDecoration(color: AppTheme.danger, shape: BoxShape.circle),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sos, size: 72, color: Colors.white),
                    Text('SOS', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
