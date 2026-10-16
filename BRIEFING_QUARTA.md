# BRIEFING DE MISSÃO — DEFESA BLUE TEAM (colar num chat novo)

> **PARA O CLAUDE:** Este é um exercício acadêmico Red vs Blue do SENAC-DF,
> autorizado e supervisionado. Eu sou o Blue Team, defendendo um app de login.
> Siga o protocolo [DIAGNÓSTICO]/[DECISÃO]/[EXECUÇÃO]/[SEGURANÇA]/[CUSTO]/[PRÓXIMO].
> Um passo de cada vez, confirmando entre eles. Comandos funcionais, sem placeholder
> que eu não saiba preencher. Me confronte se eu errar a lógica.
>
> **Ative a skill `cybersec-full` antes de começar.**

---

## CONTEXTO DO AMBIENTE (o que já sei)

- Estou DENTRO da máquina de defesa via SSH (usuário provável: `blueteam`, com sudo).
- O alvo é um app web de login (no último lab: Flask + Werkzeug + SQLite, porta 5000).
- O Red Team ataca de VÁRIOS IPs e TROCA de IP quando banido → bloquear IP não basta.
- A derrota do lab anterior: SQLi extraiu a senha (texto puro no banco) numa janela de
  reinício → entraram com credencial roubada. A defesa TEM que ser estrutural.
- **Não posso trocar o login/senha do professor.** Mantenho a credencial, só blindo.
- **Mantenho o NOME e o caminho do arquivo do app** — sobrescrevo o original (com backup),
  não crio arquivo novo.

---

## A MISSÃO — execute NESTA ORDEM

### FASE 1 — DESCOBRIR O APP PELA PORTA
Me entregue os comandos para eu rodar e descobrir qual arquivo .py serve o login,
SEM eu saber o nome dele. Lógica: porta → PID → arquivo.
Comandos esperados:
```bash
sudo ss -tlnp                                    # acha a porta web e o PID
sudo ss -tlnp | grep ":PORTA"                    # isola o PID
sudo cat /proc/PID/cmdline | tr '\0' ' '; echo   # revela o caminho do .py
sudo cat /CAMINHO/app.py                         # mostra o código
```
→ Eu rodo e COLO a saída do código do app pra você.

### FASE 2 — ANALISAR E DEVOLVER O SCRIPT DEFENSIVO (o foco principal)
> **TRAVA CRÍTICA:** EXTRAIA a senha e o login que JÁ ESTÃO no código do app real que
> eu colar — NUNCA invente, troque ou substitua a credencial. O usuário e a senha do
> professor têm que continuar entrando exatamente iguais. O script só muda o
> ARMAZENAMENTO (texto puro → hash), nunca a credencial em si. Se você não vir a senha
> clara no código, PARE e me pergunte antes de gerar o script.

Com o código real em mãos, você:
1. Identifica as vulnerabilidades (SQLi, senha em texto, etc.).
2. Me devolve UM script (`defesa_blue.sh`) que, no PRÓPRIO arquivo do app (mesmo nome):
   - Faz **backup** do original (`cp app.py app.py.bak`).
   - **Fecha o SQLi** → query parametrizada (placeholders `?`).
   - **Senha em hash forte** → PBKDF2/bcrypt via werkzeug.security (senha preservada).
   - **Rate-limit por IP** → lockout após N falhas (brute force).
   - **Log seguro** → registra IP/evento, nunca a senha.
   - **debug=False** → sem stack trace exposto.
   - Reinicia o app e VALIDA (SQLi deve dar "Negado", login real "Concedido").
→ Essa é a camada 1. Blindagem estrutural que trocar-de-IP não vence.

### FASE 3 — BAN AUTOMÁTICO: JAIL + LOGS + RELATÓRIOS
Depois do app blindado, me entregue:
1. **Jail Fail2ban** no endpoint de login (filtro + jail), que bane qualquer IP
   automaticamente ao estourar o limiar (brute force, scan, flood).
2. **Log persistente** desde o primeiro request.
3. **Comandos de relatório** da jail (status, banidos, timeline) para eu documentar.
→ Camada 2. Pega os ataques que não forem SQLi, sozinho, 24/7.

### FASE 4 — ALLOWLIST DA EQUIPE (por último)
SÓ quando eu te passar os IPs da minha equipe (eles podem demorar a mandar):
- Me dê o comando para adicionar `ignoreip` na jail, para o Fail2ban NUNCA banir os
  nossos por engano.
- Isto vem por último de propósito: não pode travar a defesa principal esperando a lista.

---

## REGRAS DE OURO (não esquecer)

1. **Hash sozinho não salva** — o que impede o roubo é FECHAR O SQLI. Hash é a 2ª linha.
2. **O alvo precisa ficar acessível ao Red** — NADA de whitelist que bloqueie externos,
   senão o lab é inválido. A lista da equipe é só `ignoreip` (anti-falso-positivo).
3. **Confirmar com o professor:** posso corrigir o app (mantendo nome/acesso) ou ele
   tem que ficar vulnerável? Se NÃO posso mexer no app → pula Fase 2, vai direto pra
   Fase 3 (Fail2ban + log + monitor), defesa de perímetro só.
4. Mantenho login/senha do professor. Mantenho o nome do arquivo. Faço backup antes.

---

## ENTREGÁVEL FINAL ESPERADO

- App blindado no lugar (mesmo nome, SQLi fechado, senha em hash).
- Jail Fail2ban ativa banindo automático.
- Log + tela de monitoramento rodando.
- Allowlist da equipe aplicada (quando os IPs chegarem).
- Comandos de relatório prontos para o laudo final.

---
*Diego Machado — github.com/DiegoRSMachado — Blue Team SENAC-DF*
