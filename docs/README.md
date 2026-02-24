# MinhaTurma — Documentação

Documentação técnica do projeto MinhaTurma, app multiplataforma de localização e comunicação familiar em tempo real.

## Índice

| Arquivo | Conteúdo |
|---|---|
| [architecture.md](./architecture.md) | Arquitetura geral, stack, fluxos de dados e decisões técnicas |
| [backend.md](./backend.md) | API FastAPI: modelos, endpoints, segurança, banco e Redis |
| [mobile.md](./mobile.md) | App Flutter: estado, serviços, navegação e telas |
| [tests.md](./tests.md) | Estratégia de testes, como rodar e o que cada suite cobre |
| [setup.md](./setup.md) | Como configurar o ambiente local de desenvolvimento |

## Estado do projeto

### Implementado
- [x] Autenticação completa e2e (RF01): registro, login, logout, refresh, /me
- [x] Suíte de testes: 42 backend (pytest) + 53 Flutter
- [x] Infraestrutura local: PostgreSQL + Redis via Docker Compose
- [x] Navegação protegida por autenticação (GoRouter + Riverpod)

### Pendente
- [ ] Localização em tempo real via WebSocket (RF03)
- [ ] Chat com mensagens e mídia (RF04)
- [ ] Botão SOS com push notification (RF05)
- [ ] Geofences / alertas de entrada e saída (RF06)
- [ ] Telas restantes do Flutter (mapa, chat, perfil, grupo)
- [ ] AWS (ECS, RDS, ElastiCache, S3, Cognito)
- [ ] CI/CD (GitHub Actions)

## Convenções

- **Commits**: Conventional Commits (`feat:`, `fix:`, `test:`, `docs:`)
- **Idioma**: Português para mensagens de interface; inglês para nomes de código
- **Testes**: Todo código novo deve acompanhar testes. Sincronize `docs/tests.md` sempre que adicionar casos.
