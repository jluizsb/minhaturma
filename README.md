# 📍 MinhaTurma

> App multiplataforma de localização e comunicação familiar em tempo real.

![Status](https://img.shields.io/badge/status-em%20desenvolvimento-yellow)
![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)
![Python](https://img.shields.io/badge/Python-3.11+-green?logo=python)
![AWS](https://img.shields.io/badge/AWS-Cloud-orange?logo=amazonaws)
![License](https://img.shields.io/badge/licença-MIT-lightgrey)

---

## 📋 Índice

- [Sobre o Projeto](#sobre-o-projeto)
- [Funcionalidades](#funcionalidades)
- [Arquitetura](#arquitetura)
- [Stack Tecnológica](#stack-tecnológica)
- [Autenticação Unificada](#autenticação-unificada)
- [Infraestrutura AWS](#infraestrutura-aws)
- [Segurança](#segurança)
- [Requisitos](#requisitos)
- [Instalação e Configuração](#instalação-e-configuração)
- [Estrutura do Projeto](#estrutura-do-projeto)
- [Roadmap](#roadmap)
- [Contribuição](#contribuição)
- [Licença](#licença)

---

## 📖 Sobre o Projeto

O **MinhaTurma** é um aplicativo multiplataforma (iOS e Android) voltado para grupos familiares e amigos próximos. Ele permite acompanhar a localização de todos os membros em tempo real, comunicar-se por mensagens e mídias, e acionar alertas de emergência — tudo em um único lugar, com privacidade e segurança hospedados na AWS.

> **Origem:** Projeto iniciado como laboratório de aprendizado das plataformas Flutter e Python, com potencial de evolução para produto comercial.

---

## ✅ Funcionalidades

### MVP — Versão 1.0

| # | Funcionalidade | Descrição | Status |
|---|---|---|---|
| 1 | 📍 Localização em tempo real | Ver no mapa onde cada membro do grupo está agora | 🔲 Planejado |
| 2 | 🗺️ Histórico de rotas | Consultar o trajeto percorrido por cada membro durante o dia | 🔲 Planejado |
| 3 | 🔔 Alertas de entrada/saída | Notificação automática ao chegar ou sair de locais definidos (casa, escola, trabalho) | 🔲 Planejado |
| 4 | 🆘 Botão SOS | Alerta de emergência que notifica todos os membros do grupo com localização atual | 🔲 Planejado |
| 5 | 💬 Mensagens e mídia | Chat interno com suporte a mensagens de texto, fotos e vídeos | 🔲 Planejado |

### Versões Futuras (Backlog)

- 🔋 Exibição do nível de bateria dos membros
- 🚗 Detecção de modo de transporte (dirigindo, a pé, etc.)
- 👶 Modo controle parental com restrições de horário
- 📊 Relatórios de deslocamento semanais
- 🌙 Modo silencioso programado (não perturbe)
- 🗓️ Integração com calendário familiar

---

## 🏗️ Arquitetura

```
┌──────────────────────────────────────────────────────────────┐
│                    APP FLUTTER (iOS / Android)               │
│                                                              │
│  ┌────────────┐  ┌──────────────┐  ┌────────────────────┐   │
│  │ Telas/UI   │  │ Google Maps  │  │  Chat (msgs/mídia) │   │
│  └─────┬──────┘  └──────┬───────┘  └──────────┬─────────┘   │
│        └────────────────┼───────────────────────┘            │
└─────────────────────────┼────────────────────────────────────┘
                          │ HTTPS + WSS (TLS 1.3)
                          ▼
┌──────────────────────────────────────────────────────────────┐
│                    AWS — Cloud                               │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  AWS Cognito (Autenticação Unificada)                │    │
│  │  Google · Facebook · Apple · Microsoft · E-mail      │    │
│  └──────────────────────┬───────────────────────────────┘    │
│                         │ JWT / OAuth2                        │
│  ┌──────────────────────▼───────────────────────────────┐    │
│  │  Application Load Balancer (ALB)                     │    │
│  │  HTTPS · Rate Limiting · WAF                         │    │
│  └──────────────────────┬───────────────────────────────┘    │
│                         │                                     │
│  ┌──────────────────────▼───────────────────────────────┐    │
│  │  ECS Fargate — Backend Python FastAPI                │    │
│  │                                                      │    │
│  │  ┌──────────┐  ┌────────────┐  ┌──────────────────┐ │    │
│  │  │ REST API │  │ WebSocket  │  │  Celery Workers  │ │    │
│  │  │ (rotas)  │  │ (localiz.) │  │  (notificações)  │ │    │
│  │  └──────────┘  └────────────┘  └──────────────────┘ │    │
│  └──────────────┬───────────────────────────────────────┘    │
│                 │                                             │
│  ┌──────────────▼──────────┐  ┌─────────────────────────┐   │
│  │  RDS PostgreSQL         │  │  ElastiCache Redis      │   │
│  │  (Multi-AZ, encrypted)  │  │  (cache + websocket hub)│   │
│  └─────────────────────────┘  └─────────────────────────┘   │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  S3 + CloudFront CDN (fotos e vídeos)                │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  Serviços de Suporte                                 │    │
│  │  CloudWatch · Secrets Manager · WAF · Route 53       │    │
│  └──────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────┘
          │                      │
  ┌───────▼───────┐    ┌─────────▼─────────┐
  │ Google Maps   │    │ Firebase FCM       │
  │ Platform API  │    │ (Push Notifications│
  └───────────────┘    └───────────────────┘
```

---

## 🛠️ Stack Tecnológica

### 📱 Mobile — Flutter
| Tecnologia | Uso |
|---|---|
| Flutter 3.x | Framework principal (iOS + Android) |
| Dart | Linguagem de programação |
| google_maps_flutter | Integração com Google Maps |
| riverpod | Gerenciamento de estado |
| dio | Requisições HTTP |
| web_socket_channel | Comunicação WebSocket em tempo real |
| firebase_messaging | Notificações push |
| image_picker | Seleção de fotos e vídeos |
| geolocator | Acesso à geolocalização do dispositivo |
| google_sign_in | Login com Google |
| flutter_facebook_auth | Login com Facebook |
| sign_in_with_apple | Login com Apple |
| msal_flutter | Login com Microsoft |
| flutter_secure_storage | Armazenamento seguro de tokens |
| go_router | Navegação entre telas |

### 🔧 Backend — Python
| Tecnologia | Uso |
|---|---|
| Python 3.11+ | Linguagem principal |
| FastAPI | Framework web (REST + WebSocket) |
| SQLAlchemy (async) | ORM assíncrono |
| PostgreSQL | Banco de dados relacional |
| Redis | Cache, sessões e hub de WebSocket |
| Alembic | Migrations do banco de dados |
| PyJWT | Tokens JWT locais |
| Celery | Tarefas assíncronas (alertas, notificações) |
| httpx | Cliente HTTP assíncrono (verificação OAuth) |
| boto3 | SDK AWS (S3, Cognito, SES) |
| firebase-admin | Push notifications via FCM |
| Docker | Containerização |

### ☁️ Infraestrutura AWS
| Serviço | Uso |
|---|---|
| **AWS Cognito** | Autenticação unificada e provedores sociais |
| **ECS Fargate** | Execução dos containers do backend |
| **RDS PostgreSQL** | Banco de dados gerenciado e criptografado |
| **ElastiCache Redis** | Cache e hub de WebSocket |
| **S3** | Armazenamento de fotos e vídeos |
| **CloudFront** | CDN para entrega rápida de mídia |
| **ALB** | Load balancer com HTTPS e WAF |
| **AWS WAF** | Proteção contra ataques web |
| **Secrets Manager** | Armazenamento seguro de credenciais |
| **CloudWatch** | Logs, métricas e alertas |
| **Route 53** | DNS gerenciado |
| **AWS SES** | Envio de e-mails transacionais |
| **ECR** | Registro de imagens Docker |
| **GitHub Actions** | CI/CD automatizado |

---

## 🔐 Autenticação Unificada

O MinhaTurma utiliza **AWS Cognito** como hub central de autenticação, suportando múltiplos provedores de identidade sem a necessidade de gerenciar credenciais diretamente.

### Provedores Suportados

| Provedor | Tipo | Status |
|---|---|---|
| 📧 E-mail + Senha | Nativo Cognito | ✅ MVP |
| 🔵 Google | OAuth 2.0 / OpenID | ✅ MVP |
| 🔷 Facebook | OAuth 2.0 | ✅ MVP |
| 🍎 Apple | Sign in with Apple | ✅ MVP |
| 🟦 Microsoft / Azure AD | OAuth 2.0 | ✅ MVP |
| 🟠 AWS (IAM Identity) | SAML / Federated | 🔲 Futuro |

### Fluxo de Autenticação

```
MOBILE APP
    │
    │  1. Usuário toca "Entrar com Google"
    ▼
SDK Google Sign In
    │
    │  2. Google retorna ID Token
    ▼
FastAPI /auth/social-login
    │
    │  3. Backend valida token com Google
    │  4. Busca ou cria usuário no banco
    │  5. Emite JWT próprio (access + refresh)
    ▼
APP recebe JWT e armazena no Secure Storage
    │
    │  6. Usa JWT em todas as requisições
    ▼
Backend valida JWT a cada requisição
```

### Tokens e Segurança
- **Access Token:** JWT válido por **1 hora**
- **Refresh Token:** JWT válido por **30 dias** (rotacionado a cada uso)
- **Armazenamento:** `flutter_secure_storage` (Keychain no iOS, Keystore no Android)
- **Transmissão:** Apenas via HTTPS/TLS 1.3
- **MFA:** Suportado via AWS Cognito (TOTP)

---

## ☁️ Infraestrutura AWS

### Visão Geral dos Serviços

```
Internet
    │
    ▼
Route 53 (DNS)
    │
    ▼
CloudFront (CDN + HTTPS)
    │
    ├──► S3 (mídia estática)
    │
    ▼
ALB — Application Load Balancer
    │
    ├── WAF (proteção web)
    │
    ▼
ECS Fargate (containers)
    │
    ├── RDS PostgreSQL (Multi-AZ)
    ├── ElastiCache Redis
    ├── S3 (upload de mídia)
    ├── Cognito (auth)
    ├── SES (e-mails)
    └── CloudWatch (logs)
```

### Ambientes

| Ambiente | Propósito | Configuração |
|---|---|---|
| **development** | Local, com Docker Compose | SQLite ou Postgres local |
| **staging** | Testes antes de produção | ECS t3.micro, RDS t3.micro |
| **production** | Usuários reais | ECS Auto Scaling, RDS Multi-AZ |

### Estimativa de Custo Inicial (staging)

| Serviço | Estimativa/mês |
|---|---|
| ECS Fargate (1 task) | ~$15 |
| RDS PostgreSQL t3.micro | ~$15 |
| ElastiCache t3.micro | ~$15 |
| S3 + CloudFront (10GB) | ~$3 |
| ALB | ~$16 |
| Route 53 | ~$1 |
| **Total estimado** | **~$65/mês** |

> Valores aproximados para us-east-1. Use o [AWS Pricing Calculator](https://calculator.aws/) para estimativas precisas.

### Provisionamento com Terraform

```bash
cd infra/terraform
terraform init
terraform plan -var-file="staging.tfvars"
terraform apply -var-file="staging.tfvars"
```

---

## 🔒 Segurança

### Camadas de Segurança

```
Camada 1 — Rede
├── HTTPS/TLS 1.3 obrigatório em todas as comunicações
├── WSS (WebSocket Secure) para localização em tempo real
├── AWS WAF — proteção contra SQLi, XSS, DDoS
└── VPC privada — banco e cache sem acesso público

Camada 2 — Autenticação
├── JWT com expiração curta (1h access, 30d refresh)
├── Tokens armazenados em Keychain/Keystore (nunca em localStorage)
├── MFA opcional via AWS Cognito (TOTP)
└── Refresh token rotation (rotaciona a cada uso)

Camada 3 — Dados
├── RDS com criptografia em repouso (AES-256)
├── S3 com criptografia server-side (SSE-S3)
├── AWS Secrets Manager para todas as credenciais
├── Backups automáticos do RDS (7 dias de retenção)
└── Dados de localização com TTL de 7 dias

Camada 4 — Aplicação
├── Rate limiting no ALB e FastAPI
├── Validação de entrada com Pydantic
├── Sanitização de uploads (tipo + tamanho)
├── Usuário não-root nos containers Docker
└── Security headers no FastAPI (CORS, TrustedHost)

Camada 5 — Monitoramento
├── CloudWatch Logs para todos os serviços
├── Alertas de erro e latência no CloudWatch
├── Auditoria de acesso ao S3
└── CloudTrail para ações na conta AWS
```

### Boas Práticas Implementadas

| Prática | Implementação |
|---|---|
| Secrets fora do código | AWS Secrets Manager + variáveis de ambiente |
| Princípio do menor privilégio | IAM roles específicas por serviço |
| Imutabilidade de containers | Imagens Docker com tag de commit |
| Zero trust na rede | Security groups restritivos |
| Backups automáticos | RDS + S3 versioning |
| Logs centralizados | CloudWatch com retenção de 90 dias |

### Checklist de Segurança antes do Deploy

- [ ] Rotacionar todas as chaves do `.env.example` com valores reais
- [ ] Habilitar MFA na conta AWS raiz
- [ ] Configurar AWS Budgets para evitar gastos inesperados
- [ ] Revisar Security Groups (nunca `0.0.0.0/0` no banco)
- [ ] Habilitar AWS GuardDuty (detecção de ameaças)
- [ ] Configurar alertas no CloudWatch para erros 5xx
- [ ] Testar restore do backup do RDS
- [ ] Verificar CORS e allowed hosts

---

## 📐 Requisitos

### Funcionais

#### RF01 — Autenticação
- O usuário deve poder se cadastrar com nome, e-mail e senha
- O usuário deve poder fazer login com Google, Facebook, Apple ou Microsoft
- O sistema deve emitir tokens JWT com expiração e rotação automática
- O usuário deve poder recuperar senha via e-mail (AWS SES)

#### RF02 — Grupos Familiares
- O usuário deve poder criar um grupo e convidar membros via link ou código
- O administrador do grupo pode remover membros
- Cada usuário pode pertencer a múltiplos grupos

#### RF03 — Localização em Tempo Real
- O app deve enviar a localização do usuário a cada 30 segundos (quando em uso)
- Todos os membros do grupo devem visualizar as localizações no mapa simultaneamente
- O usuário pode pausar o compartilhamento de localização a qualquer momento

#### RF04 — Histórico de Rotas
- O sistema deve armazenar o histórico de localização por até 7 dias
- O usuário pode consultar o trajeto de qualquer membro do seu grupo
- O histórico deve ser exibido como linha no mapa

#### RF05 — Alertas de Entrada/Saída (Geofence)
- O usuário pode cadastrar locais com nome e raio de alcance (ex: "Casa — 200m")
- O sistema deve notificar todos do grupo quando um membro entra ou sai de um local cadastrado

#### RF06 — Botão SOS
- O app deve ter um botão de emergência de fácil acesso
- Ao acionar, todos os membros do grupo recebem uma notificação push com a localização atual
- O evento SOS deve ser registrado no histórico

#### RF07 — Mensagens e Mídia
- Os membros do grupo devem poder trocar mensagens de texto em tempo real
- O app deve suportar envio de fotos e vídeos (até 50MB por arquivo)
- As mensagens devem ser armazenadas por até 30 dias

### Não Funcionais

| Código | Requisito | Critério |
|---|---|---|
| RNF01 | Performance | Atualização de localização com latência máxima de 3 segundos |
| RNF02 | Disponibilidade | Uptime mínimo de 99% (SLA AWS ECS + RDS Multi-AZ) |
| RNF03 | Segurança | Todas as comunicações via HTTPS/WSS (TLS 1.3) |
| RNF04 | Privacidade | Dados de localização nunca compartilhados com terceiros |
| RNF05 | Escalabilidade | Suporte a até 1.000 usuários simultâneos na v1 |
| RNF06 | Usabilidade | Interface em português, acessível e intuitiva |
| RNF07 | Compatibilidade | iOS 13+ e Android 8+ |
| RNF08 | Conformidade | LGPD — consentimento explícito para coleta de localização |
| RNF09 | Backup | RDS com backup automático diário, retenção de 7 dias |
| RNF10 | Observabilidade | Logs estruturados no CloudWatch, alertas de erro configurados |
| RNF11 | Usabilidade | Interface também em ingles e espanhol, acessível e intuitiva |

---

## 🚀 Instalação e Configuração

> **Pré-requisitos:** Flutter SDK 3.x, Python 3.11+, Docker, Git, AWS CLI (para deploy)

### 1. Clonar o repositório

```bash
git clone https://github.com/seu-usuario/minhaturma.git
cd minhaturma
```

### 2. Configurar o Backend (desenvolvimento local)

```bash
cd backend

# Copiar e editar variáveis de ambiente
cp .env.example .env
# Edite o .env com suas chaves

# Subir banco e redis com Docker
docker-compose up -d db redis

# Instalar dependências Python
pip install -r requirements.txt

# Rodar migrations
alembic upgrade head

# Iniciar servidor
uvicorn main:app --reload
# API disponível em http://localhost:8000
# Documentação em http://localhost:8000/docs
```

### 3. Configurar o App Flutter

```bash
cd mobile

# Instalar dependências
flutter pub get

# Configurar chaves (editar lib/config/app_config.dart)
# ou usar --dart-define:
flutter run \
  --dart-define=API_BASE_URL=http://localhost:8000/api/v1 \
  --dart-define=GOOGLE_MAPS_API_KEY=sua-chave-aqui
```

### 4. Configurar provedores OAuth

#### Google
1. Acesse [console.cloud.google.com](https://console.cloud.google.com)
2. Crie um projeto → APIs & Services → Credentials
3. Crie credenciais OAuth 2.0 para Android e iOS
4. Adicione `google-services.json` (Android) e `GoogleService-Info.plist` (iOS)

#### Facebook
1. Acesse [developers.facebook.com](https://developers.facebook.com)
2. Crie um app → Adicione "Facebook Login"
3. Configure os Bundle IDs do iOS e Android

#### Apple
1. Acesse [developer.apple.com](https://developer.apple.com)
2. Certificates → Identifiers → Enable "Sign in with Apple"
3. Configure o Service ID

#### Microsoft
1. Acesse [portal.azure.com](https://portal.azure.com)
2. Azure Active Directory → App registrations
3. Configure Redirect URI: `minhaturma://callback`

### 5. Deploy na AWS

```bash
# Configurar AWS CLI
aws configure

# Provisionar infraestrutura
cd infra/terraform
terraform init
terraform apply -var-file="production.tfvars"

# Build e push da imagem
docker build -t minhaturma-api ./backend
# (o CI/CD via GitHub Actions faz isso automaticamente no push para main)
```

---

## 📁 Estrutura do Projeto

```
minhaturma/
│
├── 📱 mobile/                      # App Flutter
│   ├── lib/
│   │   ├── config/
│   │   │   ├── app_config.dart     # Configurações e constantes
│   │   │   ├── router.dart         # Rotas de navegação (GoRouter)
│   │   │   └── theme.dart          # Tema visual do app
│   │   ├── data/
│   │   │   ├── models/             # Modelos de dados (User, Group, Location...)
│   │   │   ├── repositories/       # Acesso a dados (API, local)
│   │   │   └── services/
│   │   │       ├── auth_service.dart      # Autenticação (todos os provedores)
│   │   │       └── location_service.dart  # Geolocalização e WebSocket
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   │   ├── auth/           # Login e cadastro
│   │   │   │   ├── map/            # Mapa principal com membros
│   │   │   │   ├── chat/           # Chat e mídia
│   │   │   │   ├── sos/            # Botão de emergência
│   │   │   │   ├── group/          # Gerenciar grupo
│   │   │   │   └── profile/        # Perfil do usuário
│   │   │   ├── widgets/            # Componentes reutilizáveis
│   │   │   └── providers/          # Riverpod providers
│   │   └── main.dart
│   └── pubspec.yaml
│
├── 🔧 backend/                     # API Python FastAPI
│   ├── app/
│   │   ├── api/v1/
│   │   │   ├── auth.py             # Login, registro, OAuth social
│   │   │   ├── groups.py           # CRUD de grupos
│   │   │   ├── locations.py        # WebSocket + histórico
│   │   │   ├── messages.py         # Chat + upload de mídia
│   │   │   └── sos.py              # Emergência
│   │   ├── core/
│   │   │   ├── config.py           # Configurações (Pydantic Settings)
│   │   │   ├── database.py         # Conexão async PostgreSQL
│   │   │   └── security.py         # JWT + verificação OAuth
│   │   ├── models/                 # Modelos SQLAlchemy
│   │   │   ├── user.py
│   │   │   ├── group.py
│   │   │   ├── location.py
│   │   │   └── message.py
│   │   ├── schemas/                # Schemas Pydantic (request/response)
│   │   ├── services/               # Lógica de negócio
│   │   └── workers/                # Celery tasks
│   ├── alembic/                    # Migrations do banco
│   ├── tests/                      # Testes automatizados
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── requirements.txt
│   ├── .env.example
│   └── main.py
│
├── ☁️ infra/
│   ├── terraform/
│   │   ├── main.tf                 # VPC, ECS, RDS, Redis, S3, Cognito, CDN
│   │   └── variables.tf
│   ├── docker/                     # Configs adicionais Docker
│   └── .github/
│       └── workflows/
│           └── deploy.yml          # CI/CD GitHub Actions
│
├── 📄 docs/                        # Documentação adicional
├── .gitignore
└── README.md
```

---

## 🗺️ Roadmap

### 🔵 Fase 1 — Fundação (MVP)
- [ ] Configuração do projeto Flutter e FastAPI
- [ ] Autenticação com e-mail/senha e provedores sociais (Google, Facebook, Apple)
- [ ] Criação e gerenciamento de grupos
- [ ] Integração com Google Maps
- [ ] Localização em tempo real via WebSocket
- [ ] Tela principal com mapa e membros

### 🟡 Fase 2 — Funcionalidades Principais
- [ ] Histórico de rotas (7 dias)
- [ ] Geofence — alertas de entrada/saída
- [ ] Botão SOS com push notification
- [ ] Chat com mensagens de texto

### 🟠 Fase 3 — Mídia e Notificações
- [ ] Envio de fotos e vídeos no chat (S3 + CloudFront)
- [ ] Integração com Firebase FCM (push notifications)
- [ ] Login com Microsoft

### 🟢 Fase 4 — AWS e Produção
- [ ] Provisionamento com Terraform
- [ ] CI/CD com GitHub Actions → ECS Fargate
- [ ] Monitoramento com CloudWatch
- [ ] Publicação na App Store e Google Play

---

## 🤝 Contribuição

1. Faça um **fork** do projeto
2. Crie uma branch: `git checkout -b feature/minha-feature`
3. Commit: `git commit -m 'feat: adiciona minha feature'`
4. Push: `git push origin feature/minha-feature`
5. Abra um **Pull Request**

### Padrão de Commits (Conventional Commits)
```
feat:     nova funcionalidade
fix:      correção de bug
docs:     documentação
style:    formatação (sem mudança de lógica)
refactor: refatoração de código
test:     adição ou correção de testes
chore:    tarefas de build, configs, infra
```

---

## 📄 Licença

Este projeto está sob a licença **MIT**. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.

---

<div align="center">

Feito com ❤️ para aprender e evoluir

**Flutter + Python + AWS**

</div>
