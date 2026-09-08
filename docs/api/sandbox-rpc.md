# Contrato RPC sandbox v1

Auth: `POST /auth/v1/token?grant_type=password`, email sintético derivado de username, senha. Cadastro: `POST /functions/v1/sandbox-register`, JSON `{username,password}` com chave publishable. Nome começa por letra, 4–24 letras minúsculas/números/underscore; senha 12–128 caracteres. Não enviar e-mail real.

`POST /rest/v1/rpc/lions_state` com `{}` e Bearer de usuário. Retorna role, available/reserved, paused, entries (últimos 200), withdrawals/tickets, bets. A propriedade admin só existe para admin/auditor. Estado inclui mode=sandbox, realMoney=false.

`POST /rest/v1/rpc/lions_action`:
```
{"p_key":"UUID gerado uma vez por intenção","p_action":"PLAY","p_data":{"amount":10,"choice":"Coroa"}}
```

Ações: DEPOSIT(amount), WITHDRAW(amount), PLAY(amount,choice), TICKET(amount,match,outcome), CANCEL(ref), PAUSE(paused boolean), APPROVE(ref), REJECT(ref). `match` e `outcome` são strings 0–2. APPROVE/REJECT exigem admin. Auditor só lê. Usuário não envia saldo, resultado, payout ou papel. PLAY computa tudo no servidor; valores extras do cliente não determinam resultado.

Idempotência: repetir chave + payload retorna resposta original; reutilizar chave com outro payload falha. Após timeout repetir a mesma chave. Não gerar uma nova aposta automaticamente. Falha de transação reverte todos os efeitos. Triggers diferidos de balanceamento executam com privilégio interno somente para ler e validar o ledger antes do commit; não concedem leitura de tabelas ao cliente.

Perda de conexão após o commit não perde a rodada: consultar lions_state ou repetir a chave original recupera resultado. Não há liquidação assíncrona pendente para Arena.

Não há endpoint de promoção a administrador nem de alteração livre de saldo. Concessões administrativas são feitas somente por operação confiável do banco, acompanhadas de evento de auditoria.
