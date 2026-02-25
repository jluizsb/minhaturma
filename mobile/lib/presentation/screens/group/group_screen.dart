import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/group_provider.dart';
import '../../../data/models/group_model.dart';

class GroupScreen extends ConsumerStatefulWidget {
  const GroupScreen({super.key});

  @override
  ConsumerState<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends ConsumerState<GroupScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Criar grupo
  final _createNameController = TextEditingController();
  final _createDescController = TextEditingController();
  final _createFormKey = GlobalKey<FormState>();

  // Entrar em grupo
  final _joinCodeController = TextEditingController();
  final _joinFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(groupProvider.notifier).loadGroups();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _createNameController.dispose();
    _createDescController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  void _onGroupEntered() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/map');
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupState = ref.watch(groupProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grupos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.group), text: 'Meus Grupos'),
            Tab(icon: Icon(Icons.add_circle_outline), text: 'Criar'),
            Tab(icon: Icon(Icons.login), text: 'Entrar'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MyGroupsTab(
            groups: groupState.groups,
            isLoading: groupState.isLoading,
            error: groupState.error,
            onEnterMap: _onGroupEntered,
            onRetry: () => ref.read(groupProvider.notifier).loadGroups(),
          ),
          _CreateGroupTab(
            formKey: _createFormKey,
            nameController: _createNameController,
            descController: _createDescController,
            isLoading: groupState.isLoading,
            error: groupState.error,
            onSubmit: () async {
              if (_createFormKey.currentState?.validate() != true) return;
              final group = await ref.read(groupProvider.notifier).createGroup(
                    _createNameController.text.trim(),
                    _createDescController.text.trim(),
                  );
              if (group != null && mounted) _onGroupEntered();
            },
          ),
          _JoinGroupTab(
            formKey: _joinFormKey,
            codeController: _joinCodeController,
            isLoading: groupState.isLoading,
            error: groupState.error,
            onSubmit: () async {
              if (_joinFormKey.currentState?.validate() != true) return;
              final group = await ref.read(groupProvider.notifier).joinGroup(
                    _joinCodeController.text.trim().toUpperCase(),
                  );
              if (group != null && mounted) _onGroupEntered();
            },
          ),
        ],
      ),
    );
  }
}

// ── Aba: Meus Grupos ──────────────────────────────────────────────────────────

class _MyGroupsTab extends StatelessWidget {
  final List<GroupModel> groups;
  final bool isLoading;
  final String? error;
  final VoidCallback onEnterMap;
  final VoidCallback onRetry;

  const _MyGroupsTab({
    required this.groups,
    required this.isLoading,
    required this.error,
    required this.onEnterMap,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }
    if (groups.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Você ainda não pertence a nenhum grupo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Crie um ou entre com um código de convite.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: groups.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (ctx, i) {
        final g = groups[i];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.group)),
          title: Text(g.name),
          subtitle: Text('${g.memberCount} membro${g.memberCount == 1 ? '' : 's'} · código: ${g.inviteCode}'),
          trailing: ElevatedButton(
            onPressed: onEnterMap,
            child: const Text('Abrir mapa'),
          ),
        );
      },
    );
  }
}

// ── Aba: Criar Grupo ──────────────────────────────────────────────────────────

class _CreateGroupTab extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController descController;
  final bool isLoading;
  final String? error;
  final VoidCallback onSubmit;

  const _CreateGroupTab({
    required this.formKey,
    required this.nameController,
    required this.descController,
    required this.isLoading,
    required this.error,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nome do grupo',
                prefixIcon: Icon(Icons.group),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Informe um nome' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Descrição (opcional)',
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: isLoading ? null : onSubmit,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: const Text('Criar grupo'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Aba: Entrar em Grupo ──────────────────────────────────────────────────────

class _JoinGroupTab extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController codeController;
  final bool isLoading;
  final String? error;
  final VoidCallback onSubmit;

  const _JoinGroupTab({
    required this.formKey,
    required this.codeController,
    required this.isLoading,
    required this.error,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            TextFormField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Código de convite',
                prefixIcon: Icon(Icons.vpn_key),
                border: OutlineInputBorder(),
                hintText: 'Ex: AB12CD34',
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Informe o código' : null,
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: isLoading ? null : onSubmit,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: const Text('Entrar no grupo'),
            ),
          ],
        ),
      ),
    );
  }
}
