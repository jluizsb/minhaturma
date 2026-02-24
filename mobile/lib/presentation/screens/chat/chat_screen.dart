import 'package:flutter/material.dart';

class ChatScreen extends StatelessWidget {
  final String groupId;
  const ChatScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat do Grupo')),
      body: const Center(child: Text('Chat — em construção')),
    );
  }
}
