# Lions Games — backend sandbox

Projeto exclusivo: `uzkmoeovdozgjzojfcdt` / `lions-games-sandbox` / São Paulo.
Nenhum projeto Supabase anterior foi alterado. REAL_MONEY_MODE=false é uma restrição no banco.

## Componentes
- Supabase Auth: usuários sintéticos de teste (`username@lions-sandbox.invalid`), sem envio de e-mail ou KYC. Confirmação interna automática significa apenas conta sandbox, não verificação de identidade.
- `sandbox-register`: Edge Function valida chave pública, nome, senha, origem e limite persistente de cadastro. A chave service_role existe somente no ambiente gerenciado da função.
- `lions_state`: estado da conta autenticada, extrato e administração condicional por papel.
- `lions_action`: movimentações transacionais, idempotência por usuário/UUID e comparação do payload.
- Schema privado: tabelas sem grants diretos, RLS default-deny; wrappers públicos SECURITY INVOKER; funções internas SECURITY DEFINER verificam auth.uid, sessão ativa e papel consultado no banco.

## Contabilidade de créditos DEMO
Cada carteira tem contas `available`, `reserved` (passivos), `clearing` e `gaming` (contrapartidas sandbox). Débito positivo, crédito negativo. Saldo de disponível/reservado = créditos menos débitos. Valores inteiros, sem ponto flutuante.

| Evento | Débito | Crédito |
|---|---|---|
| OPENING / DEPOSIT | clearing | available |
| RESERVE | available | reserved |
| BET | available | gaming |
| PAYOUT | gaming | available |
| RELEASE | reserved | available |
| WITHDRAWAL | reserved | clearing |
| REVERSAL de bilhete | gaming | available |

Triggers diferidos exigem soma zero e no mínimo duas linhas, com contas do mesmo dono. Lançamentos, linhas, contas, chaves idempotentes e auditoria recusam UPDATE/DELETE. Saldos são reconstruídos a partir das linhas. Lock de perfil serializa operações por usuário. Administrador não pode editar saldos ou resultados pela API.

## Arena
Resultado gerado com pgcrypto no servidor, amostragem por rejeição (bytes 0..254), três símbolos equiprováveis. Aposta, resultado e liquidação persistem na mesma transação. Repetir a mesma chave retorna o resultado original. Acerto paga 3×, incluindo stake. Sem certificação; algoritmo exclusivo sandbox, não jogo de produção.

## Permissões
- player: própria conta, créditos demo, apostas e cancelamento de seus bilhetes; nunca aprova saques.
- admin: lê painel e aprova/rejeita saques sandbox.
- auditor: painel somente leitura.
Papéis só podem ser provisionados por administração confiável do banco, nunca via user_metadata ou cadastro público. Credenciais administrativas entregues separadamente, nunca neste repositório.

## Limites conhecidos
- Não há PSP, KYC, AML, certificação, dinheiro real, recuperação por e-mail ou MFA obrigatório.
- Saldo/demo local anterior não é importado: não é fonte confiável para créditos do servidor.
- Snapshot limita extrato a 200 registros e listas a 100; totais financeiros consultam todo o ledger. A exportação atual contém os últimos 200 registros, não o ledger completo.
- Limite de operações bem-sucedidas: 60/minuto/usuário; depósitos demo até 50.000/dia. Cadastro até 5/hora/bucket de IP e 1.000 contas. Não substitui WAF/CAPTCHA.
- Tokens no sessionStorage; fechar a aba remove a sessão do navegador. A API revalida a sessão para cada ação.
- Erros de rede mantêm a chave idempotente para recuperação; não duplicar manualmente a requisição com outra chave.
- Auditoria registra operações concluídas; rejeições aparecem como erros de API e logs de autenticação, não como eventos persistidos no ledger.
- Triggers não protegem contra superusuário ou administrador da infraestrutura. Não há WORM ou cópia externa de auditoria.
- Proteção de senhas vazadas do Supabase permanece desativada no plano atual; use somente senhas exclusivas de teste. Referência: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

## Evolução
Certificação, jurídico/compliance, observabilidade, backup/restore exercitado, revisão independente, MFA administrativo, recuperação de conta, antifraude e gates de produção são etapas separadas. Este ambiente não é autorizado nem preparado para receber dinheiro real.
