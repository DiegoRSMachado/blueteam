#!/bin/bash
# =====================================================================
# RECON UNIVERSAL — BLUE TEAM (SENAC-DF)
# Descobre o alvo seja qual for o nome do app ou a vulnerabilidade.
# Rode DENTRO do servidor do professor (via SSH), logo ao entrar.
#
# Autor: Diego Rodrigo dos S. Machado (github.com/DiegoRSMachado)
# Uso:   bash recon.sh        (nao precisa de argumento)
#
# NAO altera nada no servidor — so LE e mostra. Seguro rodar sempre.
# A saida inteira voce COLA pro Claude, que monta a defesa sob medida.
# =====================================================================

echo "############################################################"
echo "# RECON BLUE TEAM — $(date '+%Y-%m-%d %H:%M:%S')"
echo "# Host: $(hostname)  |  Usuario: $(whoami)"
echo "############################################################"

echo ""
echo "===== 1. QUEM SOU E QUE PODER TENHO ====="
id
echo "--- tenho sudo sem senha? ---"
sudo -n true 2>/dev/null && echo "SIM (sudo sem senha)" || echo "NAO (sudo pede senha ou nao tenho)"

echo ""
echo "===== 2. PORTAS ABERTAS E QUEM ESCUTA (acha o app web) ====="
# -t tcp, -l listening, -n numerico, -p processo
sudo ss -tlnp 2>/dev/null || ss -tlnp

echo ""
echo "===== 3. PROCESSOS E SEUS ARQUIVOS (qualquer nome de app) ====="
# Para cada PID que escuta porta, mostra o comando completo (revela o .py)
for pid in $(sudo ss -tlnp 2>/dev/null | grep -oP 'pid=\K[0-9]+' | sort -u); do
    echo "--- PID $pid ---"
    echo -n "  comando: "; sudo cat /proc/$pid/cmdline 2>/dev/null | tr '\0' ' '; echo
    echo -n "  pasta:   "; sudo readlink /proc/$pid/cwd 2>/dev/null; echo
done

echo ""
echo "===== 4. PROCESSOS PYTHON/NODE/PHP (apps web comuns) ====="
ps aux | grep -iE 'python|node|php|flask|gunicorn|ruby|java' | grep -v grep

echo ""
echo "===== 5. QUE FERRAMENTAS DE DEFESA O SERVIDOR TEM ====="
for t in fail2ban-client iptables python3 nano curl tcpdump ufw systemctl; do
    p=$(command -v $t 2>/dev/null)
    [ -n "$p" ] && echo "  [OK ] $t  -> $p" || echo "  [--] $t  (ausente)"
done

echo ""
echo "===== 6. FAIL2BAN: JA RODA? QUAIS JAILS? ====="
sudo fail2ban-client status 2>/dev/null || echo "  Fail2ban nao esta rodando ou nao instalado."

echo ""
echo "===== 7. REGRAS DE FIREWALL ATUAIS ====="
sudo iptables -L INPUT -n -v 2>/dev/null | head -20 || echo "  Sem acesso ao iptables."

echo ""
echo "############################################################"
echo "# FIM DO RECON."
echo "#"
echo "# PROXIMO PASSO: para ler o codigo do app (troque o caminho"
echo "# que apareceu na secao 3), rode:"
echo "#     sudo cat /CAMINHO/DO/app.py"
echo "# e cole o codigo pro Claude montar a defesa sob medida."
echo "############################################################"
