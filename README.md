# Plataforma de Jogos Online

Projeto proprietário para desenvolvimento de uma plataforma modular de jogos online.

Nome de trabalho: **Lions Games Sports Bet**.

STATUS INICIAL:
Arquitetura e documentação.

PRODUÇÃO:
DESATIVADA.

DINHEIRO REAL:
DESATIVADO.

Nenhuma funcionalidade de dinheiro real poderá ser colocada em produção sem validação jurídica, regulatória, compliance, segurança e certificação aplicáveis.

## Exclusividade e isolamento

Este repositório pertence exclusivamente ao projeto PLATAFORMA DE JOGOS ONLINE.
Repositório autorizado: https://github.com/marealtahostelbc-star/jogos-online
Visibilidade pública expressamente autorizada pelo proprietário.

Não reutilizar arquivos, código, configurações, variáveis de ambiente, credenciais,
integrações ou bancos de outros projetos, incluindo WOW MY HOUSE, MARÉ ALTA HOSTEL,
POUSADA CENTRAL, CENTRAL STAY, VÉRTICE IMÓVEIS, VOEE e PLANO DE NEGÓCIO DIGITAL.

Esta estrutura foi iniciada do zero, sem importar código ou configurações de outros projetos.

## Limites desta etapa

Somente estrutura base e documentação inicial. Nenhuma funcionalidade implementada.
Nenhum workflow de CI/CD, deploy ou integração está configurado nesta estrutura.
Vercel, Supabase, domínio, banco de dados e secrets externos não são configurados por este projeto.
Qualquer conexão, publicação ou próxima etapa depende de autorização posterior do proprietário.

A diretiva para o desenvolvimento futuro é `REAL_MONEY_MODE = FALSE`.
Ela é uma exigência documental nesta etapa; ainda não existe aplicação ou controle executável.
DEV e STAGING deverão utilizar moeda fictícia e adaptadores sandbox isolados.

## Arquitetura prevista

Monólito modular com contratos explícitos entre módulos.
Componentes críticos: Ledger, Game Engine, Audit e Identity/KYC.
Um único jogo de referência no futuro MVP sandbox.

## Estrutura

- `apps/web/`, `apps/admin/`, `apps/api/`: aplicações futuras.
- `modules/`: módulos de domínio isolados.
- `packages/`: contratos e componentes compartilhados exclusivamente neste projeto.
- `infrastructure/`: diretórios reservados, sem recursos provisionados.
- `docs/`: arquitetura, APIs, segurança, compliance e documentação mestre.
- `.github/`: diretório reservado, sem automações.

Arquivos `.gitkeep` preservam os diretórios vazios no Git.
A presença dos diretórios não significa que os componentes estejam implementados.

## Propriedade

Repositório público não implica concessão de licença de uso do código.
Nenhuma licença de código aberto foi adicionada nesta etapa.
