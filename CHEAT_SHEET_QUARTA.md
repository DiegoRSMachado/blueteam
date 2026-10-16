# CHEAT-SHEET BLUE TEAM — Procedimento de Quarta

**Objetivo:** chegar, descobrir o alvo, blindar em minutos. Seguir na ordem.
**Autor:** Diego Machado — github.com/DiegoRSMachado

---

## ⚠️ REGRA DE OURO (ler antes de começar)

1. **O hash sozinho NÃO salva.** O que impede o roubo da senha é **fechar o SQLi**.
   O hash é a 2ª linha, caso o SQLi escape. Aplicar os DOIS, nesta ordem.
2. **Manter login/senha do professor** — não mudar a credencial, só guardá-la em hash.
3. **A lista de IPs da equipe é para NÃO banir os nossos por engano** — não para
   bloquear o Red (o alvo precisa ficar acessível ao ataque, senão o lab é inválido).
4. Onde houver `CAMINHO` ou `SENHA_AQUI` em MAIÚSCULO, é para VOCÊ preencher.

---

## FASE 1 — DESCOBRIR O ALVO (não sei o nome do app)

Lógica: **a porta leva ao processo, o processo leva ao arquivo.**

```bash
# 1.1 — Que portas estão abertas e quem escuta (acha a porta web: 5000/8000/8080/80)
sudo ss -tlnp

# 1.2 — Isola o PID que escuta a porta web (troque 5000 pela porta real)
sudo ss -tlnp | grep ":5000"

# 1.3 — Descobre o comando e o arquivo .py exato que esse PID roda (troque PID)
sudo cat /proc/PID/cmdline | tr '\0' ' '; echo

# 1.4 — Mostra o código inteiro do app (troque pelo caminho que o 1.3 revelou)
sudo cat /CAMINHO/DO/app.py
```

**ATALHO (faz 1.1 a 1.3 de uma vez):**
```bash
for pid in $(sudo ss -tlnp | grep -oP 'pid=\K[0-9]+' | sort -u); do \
  echo "=== PID $pid ==="; sudo cat /proc/$pid/cmdline | tr '\0' ' '; echo; done
```

---

## FASE 2 — COLAR PARA O CLAUDE (análise)

Cola no chat, nesta ordem:

1. A saída do `cat /CAMINHO/app.py` (o código do alvo)  → ele vê a vuln e a senha real
2. A saída de `sudo ss -tlnp`                            → ele confirma a porta
3. Os IPs da sua equipe Blue (lista)                     → para a allowlist de proteção

**Frase para colar junto:** "Monta o defesa_blue.sh pra ESTE app, mantendo a senha real,
com hash, jail e allowlist da minha equipe."

→ O Claude devolve o `defesa_blue.sh` ajustado para o app real da quarta.

---

## FASE 3 — BLINDAR (um comando)

```bash
# 3.1 — Salva o script que o Claude devolveu
nano defesa_blue.sh      # cola o conteúdo, Ctrl+O, Enter, Ctrl+X

# 3.2 — Executa a blindagem
sudo bash defesa_blue.sh /CAMINHO/DO/app.py
```

O script faz sozinho:
- Sobe o app endurecido (SQLi fechado + senha em hash, senha preservada)
- Ativa log persistente
- Instala a jail Fail2ban
- Valida: mostra SQLi dando "Negado" e login real dando "Concedido"

---

## FASE 4 — PROTEGER A EQUIPE DO BAN (allowlist)

Para o Fail2ban NUNCA banir os IPs da sua equipe (evita falso-positivo):

```bash
# Troque pelos IPs reais da equipe, separados por espaço
sudo tee -a /etc/fail2ban/jail.d/flask-login.conf > /dev/null <<'EOF'
ignoreip = 127.0.0.1/8 192.168.1.XX 192.168.1.YY 192.168.1.ZZ
EOF
sudo fail2ban-client reload
```

---

## FASE 5 — MONITORAR (deixa rodando numa aba)

```bash
tail -f /home/blueteam/login.log | grep -a --line-buffered --color=always \
  -iE "OR|--|UNION|SELECT|LOCKOUT|Concedido|$"
```

- Vermelho em `UNION`/`--` = tentativa de SQLi (já barrada pelo app).
- `LOCKOUT` = Fail2ban/rate-limit banindo alguém.
- `Concedido` = login bem-sucedido — confere se foi a equipe ou intruso.

---

## FASE 6 — VERIFICAR SE HOUVE ACESSO INDEVIDO

```bash
# Alguém entrou? (deve ser só sua equipe)
grep -a "LOGIN_OK" /home/blueteam/login.log

# Ranking de quem mais bateu no alvo
grep -aoE "^[0-9.]+" /home/blueteam/login.log | sort | uniq -c | sort -rn | head

# Quem a jail baniu
sudo fail2ban-client status flask-login
```

---

## CHECKLIST RÁPIDO (marcar no dia)

```
[ ] 1. ss -tlnp → achei a porta e o PID
[ ] 2. cat /proc/PID/cmdline → achei o app.py
[ ] 3. colei o código pro Claude
[ ] 4. recebi e rodei o defesa_blue.sh
[ ] 5. teste SQLi deu "Negado" / login real deu "Concedido"
[ ] 6. allowlist da equipe aplicada
[ ] 7. monitor rodando
```

---

## SE NÃO PUDER MEXER NO APP (professor exige vulnerável)

Pergunte ao professor ANTES. Se a resposta for "não pode mexer no app":
- Pula a Fase 3 (não blinda o código).
- Usa só: Fail2ban (Fase 3 parcial) + allowlist (Fase 4) + monitor (Fase 5).
- Defesa menor, mas ainda melhor que reagir na mão.

---
*Guardar no GitHub junto com o laudo e o defesa_blue.sh.*
