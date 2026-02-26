"""
Simula um segundo usuário dentro de um grupo MinhaTurma.

Uso:
  # Opção A — O usuário principal faz login e informa o invite_code:
  python scripts/simulate_user.py --invite-code ABCD1234

  # Opção B — Informa o invite_code e credenciais do usuário principal:
  python scripts/simulate_user.py \\
      --invite-code ABCD1234 \\
      --sim-email fake@test.com \\
      --sim-password Test@1234

  # Ver invite_code do seu grupo:
  python scripts/simulate_user.py --show-invite \\
      --main-email joaoluiz.barbosa@gmail.com \\
      --main-password "SuaSenha"
"""

import argparse
import asyncio
import json
import math
import time
import urllib.parse
import urllib.request
import urllib.error

# ── Configuração ─────────────────────────────────────────────────────────────
BASE_URL  = "http://localhost:8000/api/v1"
WS_URL    = "ws://localhost:8000/api/v1/locations/ws"

SIM_EMAIL    = "simulador@minhaturma.com"
SIM_PASSWORD = "Simulador@123"
SIM_NAME     = "Usuário Simulado"

# Posição inicial: Parque Ibirapuera, São Paulo
START_LAT = -23.5874
START_LNG = -46.6576

# Raio do círculo simulado (em graus, ~500 m)
RADIUS_DEG = 0.005
INTERVAL_S = 4  # segundos entre cada envio


# ── Helpers HTTP (síncrono, sem dependências extras) ─────────────────────────

def _post(path: str, body: dict, token: str | None = None,
          form: bool = False) -> dict:
    if form:
        data = urllib.parse.urlencode(body).encode()
        content_type = "application/x-www-form-urlencoded"
    else:
        data = json.dumps(body).encode()
        content_type = "application/json"

    req = urllib.request.Request(
        f"{BASE_URL}{path}",
        data=data,
        headers={
            "Content-Type": content_type,
            **({"Authorization": f"Bearer {token}"} if token else {}),
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        body_txt = e.read().decode()
        raise RuntimeError(f"HTTP {e.code} em {path}: {body_txt}") from e


def _get(path: str, token: str) -> dict | list:
    req = urllib.request.Request(
        f"{BASE_URL}{path}",
        headers={"Authorization": f"Bearer {token}"},
        method="GET",
    )
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())


# ── Autenticação ─────────────────────────────────────────────────────────────

def login(email: str, password: str) -> str:
    """Faz login e retorna o access_token."""
    # O endpoint usa OAuth2PasswordRequestForm (form-data com campo 'username')
    resp = _post("/auth/login", {"username": email, "password": password}, form=True)
    return resp["access_token"]


def register_or_login(email: str, password: str, name: str) -> str:
    """Registra o usuário simulado (ignora erro se já existe) e faz login."""
    try:
        _post("/auth/register", {"email": email, "password": password, "name": name})
        print(f"  [+] Usuário simulado criado: {email}")
    except RuntimeError as e:
        if "400" in str(e) or "409" in str(e):
            print(f"  [~] Usuário já existe, fazendo login...")
        else:
            raise
    return login(email, password)


# ── Grupo ────────────────────────────────────────────────────────────────────

def get_invite_code(main_token: str) -> str:
    """Busca o invite_code do primeiro grupo do usuário principal."""
    groups = _get("/groups/", main_token)
    if not groups:
        raise RuntimeError("Usuário principal não tem nenhum grupo. Crie um no app.")
    code = groups[0]["invite_code"]
    name = groups[0]["name"]
    print(f"  [i] Grupo: '{name}'  |  Invite code: {code}")
    return code


def join_group(invite_code: str, sim_token: str) -> str:
    """Entra no grupo (ignora se já for membro) e retorna o group_id."""
    try:
        resp = _post("/groups/join", {"invite_code": invite_code}, token=sim_token)
        print(f"  [+] Entrou no grupo: {resp['name']}")
        return resp["id"]
    except RuntimeError as e:
        if "já é membro" in str(e) or "400" in str(e):
            print("  [~] Usuário simulado já é membro do grupo")
            groups = _get("/groups/", sim_token)
            # Pega o grupo cujo invite_code bate
            for g in groups:
                if g["invite_code"] == invite_code:
                    return g["id"]
            # Se não achou pelo código, retorna o primeiro
            return groups[0]["id"]
        raise


# ── WebSocket ─────────────────────────────────────────────────────────────────

async def stream_location(sim_token: str, group_id: str):
    """Conecta ao WebSocket e envia posições em círculo indefinidamente."""
    import websockets  # noqa: PLC0415 (só importa se realmente for usar)

    uri = f"{WS_URL}?token={sim_token}&group_id={group_id}"
    print(f"\n  [WS] Conectando a {WS_URL} ...")

    async with websockets.connect(uri) as ws:
        print("  [WS] Conectado! Enviando posições a cada "
              f"{INTERVAL_S}s. Ctrl+C para parar.\n")
        step = 0
        try:
            while True:
                angle = (step * 15) % 360  # avança 15° por passo
                rad   = math.radians(angle)
                lat   = START_LAT + RADIUS_DEG * math.sin(rad)
                lng   = START_LNG + RADIUS_DEG * math.cos(rad)
                ts    = int(time.time())

                msg = json.dumps({"lat": lat, "lng": lng, "ts": ts})
                await ws.send(msg)
                print(f"  → lat={lat:.6f}  lng={lng:.6f}  "
                      f"ângulo={angle}°  ts={ts}")

                step += 1
                await asyncio.sleep(INTERVAL_S)
        except KeyboardInterrupt:
            print("\n  [WS] Encerrado pelo usuário.")


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Simula um segundo usuário no MinhaTurma."
    )
    parser.add_argument("--invite-code",
        help="Código de convite do grupo (obtido no app ou com --show-invite)")
    parser.add_argument("--show-invite",  action="store_true",
        help="Apenas mostra o invite_code do grupo do usuário principal e sai")
    parser.add_argument("--main-email",   default="joaoluiz.barbosa@gmail.com",
        help="E-mail do usuário principal (para buscar o invite_code)")
    parser.add_argument("--main-password", default="",
        help="Senha do usuário principal")
    parser.add_argument("--sim-email",    default=SIM_EMAIL)
    parser.add_argument("--sim-password", default=SIM_PASSWORD)
    parser.add_argument("--sim-name",     default=SIM_NAME)
    args = parser.parse_args()

    print("=== MinhaTurma — Simulador de Usuário ===\n")

    # ── Modo: só mostrar invite_code ──────────────────────────────────────────
    if args.show_invite:
        if not args.main_password:
            args.main_password = input(f"Senha de {args.main_email}: ")
        print("Fazendo login com usuário principal...")
        main_token = login(args.main_email, args.main_password)
        get_invite_code(main_token)
        return

    # ── Obter invite_code ─────────────────────────────────────────────────────
    invite_code = args.invite_code
    if not invite_code:
        if not args.main_password:
            args.main_password = input(f"Senha de {args.main_email} (para buscar invite_code): ")
        print("Buscando invite_code do grupo...")
        main_token = login(args.main_email, args.main_password)
        invite_code = get_invite_code(main_token)

    # ── Login do simulado ──────────────────────────────────────────────────────
    print(f"\nPreparando usuário simulado ({args.sim_email})...")
    sim_token = register_or_login(args.sim_email, args.sim_password, args.sim_name)

    # ── Entrar no grupo ────────────────────────────────────────────────────────
    print(f"\nEntrando no grupo (invite_code={invite_code})...")
    group_id = join_group(invite_code, sim_token)

    # ── Stream de localização ──────────────────────────────────────────────────
    print(f"\nIniciando stream de localização (group_id={group_id})...")
    asyncio.run(stream_location(sim_token, group_id))


if __name__ == "__main__":
    main()
