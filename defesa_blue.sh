#!/bin/bash
# =====================================================================
# KIT DE DEFESA BLUE TEAM — SENAC-DF
# Blindagem estrutural de app Flask /login em segundos.
#
# Autor: Diego Rodrigo dos S. Machado  (github.com/DiegoRSMachado)
# Uso:   sudo bash defesa_blue.sh /caminho/do/app.py
#
# O que faz, em ordem:
#   1. Sobe o app ENDURECIDO (SQLi fechado + senha em hash)
#   2. Garante log persistente desde o primeiro request
#   3. Instala e ativa jail Fail2ban no /login (bane automatico)
#   4. Abre a tela de monitoramento
#
# Filosofia: defende o ATIVO, nao o IP. Trocar de IP nao vence isto.
# =====================================================================

set -euo pipefail

# --------- CONFIG (ajuste se o lab mudar) ----------------------------
APP_ORIGINAL="${1:-/home/blueteam/app.py}"   # app vulneravel do professor
APP_SEGURO="/home/blueteam/app_seguro.py"    # versao blindada (gerada abaixo)
LOG="/home/blueteam/login.log"               # log persistente
PORTA="5000"
USUARIO_HOME="/home/blueteam"
# Credencial PRESERVADA — mesma do app original, para nao derrubar devs.
ADMIN_USER="admin"
ADMIN_PASS="senha_super_secreta_123"
# Limiar de banimento
MAXRETRY=5          # falhas
FINDTIME=30         # em 30s
BANTIME=3600        # bane por 1h
# ---------------------------------------------------------------------

echo "[*] KIT DE DEFESA BLUE — iniciando blindagem..."

# --- PASSO 1: gerar o app endurecido ---------------------------------
echo "[1/4] Gerando app endurecido (SQLi fechado + senha em hash)..."
cat > "$APP_SEGURO" <<PYEOF
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""App Portal Senac ENDURECIDO. Credencial preservada; so a seguranca muda."""
import logging, sqlite3, time
from collections import defaultdict
from werkzeug.security import generate_password_hash, check_password_hash
from flask import Flask, request

app = Flask(__name__)
ADMIN_USER = "${ADMIN_USER}"
ADMIN_PASS = "${ADMIN_PASS}"

logging.basicConfig(filename="${LOG}", level=logging.INFO,
                    format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger("portal")

MAX_T, JANELA, LOCK = ${MAXRETRY}, ${FINDTIME}, 300
_tent = defaultdict(list); _bloq = {}

def ip_bloqueado(ip): return time.time() < _bloq.get(ip, 0)
def registra_falha(ip):
    a = time.time()
    _tent[ip] = [t for t in _tent[ip] if a - t < JANELA]
    _tent[ip].append(a)
    if len(_tent[ip]) >= MAX_T:
        _bloq[ip] = a + LOCK
        log.warning("LOCKOUT ip=%s", ip)

def init_db():
    h = generate_password_hash(ADMIN_PASS)
    c = sqlite3.connect(":memory:", check_same_thread=False)
    cur = c.cursor()
    cur.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, username TEXT, password TEXT)")
    cur.execute("INSERT INTO users (username,password) VALUES (?,?)", (ADMIN_USER, h))
    c.commit(); return c
conn = init_db()

@app.route("/login", methods=["GET","POST"])
def login():
    ip = request.remote_addr or "desconhecido"
    if request.method == "POST":
        if ip_bloqueado(ip):
            log.warning("ACESSO_BLOQUEADO ip=%s", ip)
            return "<h1>Muitas tentativas. Tente mais tarde.</h1>", 429
        u = request.form.get("username",""); p = request.form.get("password","")
        try:
            cur = conn.cursor()
            cur.execute("SELECT password FROM users WHERE username = ?", (u,))
            row = cur.fetchone()
            if row and check_password_hash(row[0], p):
                log.info("LOGIN_OK ip=%s user=%s", ip, u)
                return "<h1>Acesso Concedido! Bem-vindo ao painel do Senac.</h1>"
            registra_falha(ip)
            log.info("LOGIN_FALHA ip=%s user=%s", ip, u)
            return "<h1>Acesso Negado. Usuario ou senha incorretos.</h1>", 401
        except Exception:
            log.exception("ERRO_INTERNO ip=%s", ip)
            return "<h1>Erro interno.</h1>", 500
    return '''<h2>Portal Interno - Senac (DevSec)</h2>
        <form method="post">
        Usuario: <input type="text" name="username"><br><br>
        Senha: <input type="password" name="password"><br><br>
        <input type="submit" value="Entrar"></form>'''

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=${PORTA}, debug=False)
PYEOF
echo "    OK: $APP_SEGURO gerado."

# --- PASSO 2: derrubar app vulneravel e subir o seguro ---------------
echo "[2/4] Trocando app vulneravel pelo endurecido..."
pkill -f "$(basename "$APP_ORIGINAL")" 2>/dev/null || true
pkill -f "app_seguro" 2>/dev/null || true
sleep 1
nohup python3 "$APP_SEGURO" >> "$LOG" 2>&1 &
sleep 2
CODIGO=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${PORTA}/login" || echo "000")
if [ "$CODIGO" = "200" ]; then
    echo "    OK: app endurecido no ar (HTTP 200)."
else
    echo "    ERRO: app nao respondeu (HTTP $CODIGO). Verifique o caminho."
    exit 1
fi

# --- PASSO 3: jail Fail2ban automatica -------------------------------
echo "[3/4] Instalando jail Fail2ban no /login..."
cat > /etc/fail2ban/filter.d/flask-login.conf <<'F2BEOF'
[Definition]
failregex = ^<HOST> - - \[.*\] "POST /login HTTP/1\.[01]"
ignoreregex =
F2BEOF
cat > /etc/fail2ban/jail.d/flask-login.conf <<JAILEOF
[flask-login]
enabled  = true
port     = ${PORTA}
filter   = flask-login
logpath  = ${LOG}
maxretry = ${MAXRETRY}
findtime = ${FINDTIME}
bantime  = ${BANTIME}
action   = iptables[name=flask-login, port=${PORTA}, protocol=tcp]
JAILEOF
fail2ban-client reload >/dev/null 2>&1 || systemctl restart fail2ban
sleep 2
echo "    OK: jail ativa (bane $MAXRETRY falhas em ${FINDTIME}s, por ${BANTIME}s)."

# --- PASSO 4: validacao da blindagem ---------------------------------
echo "[4/4] Validando a blindagem..."
echo "  -> Teste SQLi (payload sqlmap):"
R1=$(curl -s "http://127.0.0.1:${PORTA}/login" -X POST \
     -d "username=admin' UNION SELECT NULL-- &password=x")
echo "     Resposta: $R1"
echo "  -> Teste login legitimo (senha preservada):"
R2=$(curl -s "http://127.0.0.1:${PORTA}/login" -X POST \
     -d "username=${ADMIN_USER}&password=${ADMIN_PASS}")
echo "     Resposta: $R2"

echo ""
echo "====================================================================="
echo " BLINDAGEM CONCLUIDA."
echo "   - SQLi: fechado (query parametrizada)"
echo "   - Senha: em hash (nao extraivel por SQLi)"
echo "   - Fail2ban: ativo (bane qualquer IP automaticamente)"
echo "   - Log: $LOG"
echo ""
echo " Abra a tela de monitoramento com:"
echo "   tail -f $LOG | grep -a --line-buffered --color=always -iE \"OR|--|UNION|SELECT|LOCKOUT|Concedido|\\\$\""
echo "====================================================================="
