# Contexto do Projeto — MinhaTurma

## O que é este projeto
App multiplataforma (iOS + Android) de localização e comunicação familiar em tempo real.
Iniciado como projeto de aprendizado de Flutter + Python, com potencial comercial.

## Stack escolhida
- **Mobile:** Flutter (Dart) + Google Maps
- **Backend:** Python + FastAPI (REST + WebSocket)
- **Banco:** PostgreSQL (AWS RDS)
- **Cache:** Redis (AWS ElastiCache)
- **Auth:** JWT próprio + OAuth social (Google, Facebook, Apple, Microsoft) via AWS Cognito
- **Storage:** AWS S3 + CloudFront CDN
- **Infra:** AWS ECS Fargate, Terraform, GitHub Actions CI/CD
- **Push:** Firebase FCM

## Funcionalidades do MVP (v1.0)
1. Localização em tempo real via WebSocket
2. Histórico de rotas (7 dias)
3. Alertas de entrada/saída de locais (Geofence)
4. Botão SOS com push notification
5. Chat com mensagens de texto, fotos e vídeos

## Estado atual do projeto
- Estrutura de pastas criada
- Arquivos base do backend criados (modelos, rotas, segurança, config)
- Arquivos base do Flutter criados (telas esqueleto, serviços de auth e localização)
- Infraestrutura Terraform esboçada (AWS: VPC, ECS, RDS, Redis, S3, Cognito, CloudFront)
- CI/CD com GitHub Actions configurado
- README.md completo com requisitos, arquitetura e documentação AWS

## Próximos passos sugeridos
1. [ ] Inicializar repositório Git e subir no GitHub
2. [ ] Configurar ambiente Python local (venv + requirements.txt)
3. [ ] Rodar docker-compose (banco + redis) e testar a API
4. [ ] Criar projeto Flutter e rodar no simulador
5. [ ] Implementar autenticação completa (RF01)
6. [ ] Implementar localização em tempo real (RF03)

## Decisões arquiteturais já tomadas
- Comunicação mobile ↔ backend: REST API + WebSocket
- Tokens: JWT (access 1h, refresh 30d com rotação)
- Storage de tokens no mobile: flutter_secure_storage (Keychain/Keystore)
- Gerenciamento de estado Flutter: Riverpod
- Padrão de commits: Conventional Commits

## Comandos úteis

### Backend
```bash
cd backend
docker-compose up -d db redis   # Subir dependências
pip install -r requirements.txt
alembic upgrade head            # Rodar migrations
uvicorn main:app --reload       # Iniciar API (http://localhost:8000/docs)
```

### Flutter
```bash
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8000/api/v1 \
            --dart-define=GOOGLE_MAPS_API_KEY=SUA_CHAVE
```

### Terraform (AWS)
```bash
cd infra/terraform
terraform init
terraform plan -var-file="staging.tfvars"
terraform apply
```
