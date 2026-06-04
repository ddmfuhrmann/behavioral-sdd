# Workflow de Desenvolvimento — behavioral-sdd

> English version: `docs/workflow.md`

## Visão geral

Este workflow é **spec-driven e plan-first**: nenhum código é escrito sem um plano salvo. O contexto é preservado entre etapas via arquivos locais em `.plans/`, e as responsabilidades são distribuídas entre subagentes isolados para evitar que contexto de uma etapa contamine outra.

Decisões principais:

- **Prefixo `f-`** — evita colisão com skills nativas do Claude Code (`/plan`, `/review`, `/test`).
- **Grill-me como loop conversacional** — integrado ao `/bsdd-plan` via `AskUserQuestion`, uma pergunta por vez, sem comando separado.
- **`/bsdd-implement` orquestra implement + test + loop de correção** — sem necessidade de invocar `/test` separadamente.
- **`/bsdd-ship` unifica review + ADR check + handoff** — um único comando para fechar o ciclo.
- **Integrações isoladas em Haiku 4.5** — `git-agent` é barato e focado; domain agents nunca chamam git diretamente.
- **`caveman` e `karpathy-guidelines` sempre ativos** — todos os agentes carregam essas skills por padrão.

---

## Fluxo principal

```
[conversa livre / ticket / PRD]
         │
    /bsdd-prd  (opcional — features de maior escopo)
         │
    /bsdd-plan  ──→  [grill-me loop via AskUserQuestion]  ──→  plano salvo em .plans/
         │
    /bsdd-implement <título>
         ├──→  [feature-implementer]  (escreve código)
         ├──→  [test-implementer]     (escreve e roda testes)
         └──→  loop de correção automática (até 3x, depois checkpoint)
         │
    /bsdd-ship
         ├──→  [git-agent]    (obtém diff)
         ├──→  [reviewer]     (analisa diff vs plano)
         ├──→  grill-me das findings via AskUserQuestion
         ├──→  ADR check via AskUserQuestion
         ├──→  grill-me do handoff via AskUserQuestion
         ├──→  salva artefatos em .ship/YYYY-MM-DD-<título>/
         └──→  [git-agent]    (cria PR)
```

**Fluxo com optimize:**

```
    /bsdd-implement <título>
         │ (ao concluir: AskUserQuestion — rodar /bsdd-optimize?)
         ↓
    /bsdd-optimize <título>
         └──→  [optimizer]    (baseline → análise → loop)
              salva relatório em .plans/YYYY-MM-DD-<título>-optimization.md
         ↓
    /bsdd-ship
```

**Fluxo com PRD:**

```
    /bsdd-prd
         ├──→  grill-me via AskUserQuestion
         └──→  salva .prds/YYYY-MM-DD-<título>.md
         ↓
    /bsdd-plan  (lê o PRD como input)
```

---

## Comandos principais

### /bsdd-plan

Entry point do ciclo. Aceita qualquer input (conversa, ticket, PRD, ideia).

1. Usa o Plan agent nativo para explorar o codebase.
2. Produz plano estruturado com 10 seções: Understanding, Assumptions, Scope, Out of scope, Approach, Files likely to change, Tests needed, Risks, Performance criteria, Blocking questions.
3. Inicia grill-me automático — uma pergunta por vez via `AskUserQuestion`.
4. Salva plano refinado em `.plans/YYYY-MM-DD-<título>.md`.

### /bsdd-implement \<título\>

Orquestra implementação completa. O argumento é o título kebab-case do plano.

1. Lê `.plans/YYYY-MM-DD-<título>.md`.
2. Spawna `feature-implementer` (código de produção).
3. Spawna `test-implementer` (testes).
4. Se testes falham: loop automático de correção (até 3x), depois checkpoint via `AskUserQuestion`.
5. Ao concluir: pergunta se quer rodar `/bsdd-optimize`.

### /bsdd-ship

Fecha o ciclo. Pode ser usado fora do pipeline para revisitar entregas anteriores.

1. Spawna `git-agent` para obter o diff.
2. Spawna `reviewer` com plano + diff + summaries.
3. Grill-me interativo das findings (BLOCKER → corrigir, WARNING → deferir, SUGGESTION → issue).
4. ADR check: detecta decisões arquiteturais candidatas, pergunta se registrar.
5. Grill-me do handoff: próximo passo, decisões pendentes, riscos para produção.
6. Salva todos os artefatos localmente em `.ship/YYYY-MM-DD-<título>/`.
7. Spawna `git-agent` para criar PR.

**Integração com SonarQube (opt-in):** se `sonar-project.properties` existir na raiz do projeto, o `reviewer` executa análise estática completa via SonarQube antes de produzir o review summary. Veja [Integrações opcionais — SonarQube](#sonarqube-via-docker) abaixo.

---

## Comandos complementares

### /bsdd-optimize \<título\>

Otimização de performance baseada em plano. Comportamento determinado pelo campo **Performance criteria** do plano.

- **Com critério mensurável** (ex: `p95 < 200ms`): optimizer roda autonomamente — baseline → análise → mudança → re-medição → loop. Checkpoint a cada 3 tentativas.
- **Sem critério**: optimizer coleta baseline e produz findings sem aplicar mudanças.

Em ambos os casos, o relatório é salvo localmente em `.plans/YYYY-MM-DD-<título>-optimization.md`.

### /bsdd-prd

Cria PRD via grill-me conversacional. Use para features de maior escopo antes do `/bsdd-plan`. Uma pergunta por vez: nome, problema, objetivo mensurável, requisitos, fora do escopo, critérios de aceitação, bloqueadores.

### /bsdd-sync-patterns

Escaneia o código-fonte e reescreve `.skills/patterns.md` com snippets canônicos atualizados. Usar após implementar um padrão novo que outros agentes devem seguir.

---

## Referência rápida

| Comando | Quando usar |
|---|---|
| `/bsdd-prd` | Antes do plan, para features de maior escopo |
| `/bsdd-plan` | Sempre — entry point do ciclo |
| `/bsdd-implement <título>` | Após grill-me concluir e plano salvo |
| `/bsdd-ship` | Após implement completar com sucesso |
| `/bsdd-optimize <título>` | Performance — standalone ou pós-implement |
| `/bsdd-sync-patterns` | Após implementar padrão novo relevante |

---

## Estrutura de agentes

| Tipo | Agente | Modelo | Responsabilidade |
|---|---|---|---|
| Orchestrator | `/bsdd-plan`, `/bsdd-implement`, `/bsdd-ship`, `/bsdd-optimize`, `/bsdd-prd` | Sonnet 4.6 (inline) | Coordena fluxo, usa AskUserQuestion, nunca escreve código |
| Domain | `feature-implementer` | Sonnet 4.6 | Escreve código de produção |
| Domain | `test-implementer` | Sonnet 4.6 | Escreve e roda testes |
| Domain | `reviewer` | Opus 4.8 | Analisa diff vs plano |
| Optimizer | `optimizer` | Opus 4.8 | Loop de medição + otimização, evidence-based |
| Integration | `git-agent` | Haiku 4.5 | Branch, commit, PR |

**Princípio de isolamento:** domain agents nunca chamam git diretamente — delegam para `git-agent` via o orquestrador.

---

## Artefatos locais

| Caminho | Conteúdo |
|---|---|
| `.plans/YYYY-MM-DD-<título>.md` | Plano refinado com frontmatter (`date`, `title`) |
| `.prds/YYYY-MM-DD-<título>.md` | PRD com frontmatter |
| `.plans/YYYY-MM-DD-<título>-optimization.md` | Relatório de otimização |
| `.ship/YYYY-MM-DD-<título>/` | Review summary, ADRs, handoff doc |
| `.skills/patterns.md` | Snippets canônicos do codebase (atualizado via `/bsdd-sync-patterns`) |
| `docs/workflow.md` | Este documento (English) |
| `docs/workflow.pt-br.md` | Este documento (Português BR) |

`.plans/`, `.prds/` e `.ship/` são ignorados pelo git por padrão. Prática recomendada: remova-os do `.gitignore` em feature branches e inclua-os no PR. Eles funcionam como ADRs vivos — o registro de por que o código foi escrito, o que foi adiado e quais riscos foram aceitos.

---

## Integrações opcionais

### SonarQube via Docker *(experimental)*

> Ainda não validado em todos os stacks e configurações de CI. Trate os findings como sinal suplementar.

O agente `reviewer` suporta análise estática via SonarQube como integração opt-in. Quando ativa, os findings (code smells, bugs, vulnerabilidades) são incluídos no review summary com os mesmos rótulos de severidade `BLOCKER | WARNING | SUGGESTION`.

**Ativação:** crie `sonar-project.properties` na raiz do projeto. A presença do arquivo é o sinal de opt-in — o reviewer executa a análise automaticamente em todo `/bsdd-ship`.

**`sonar-project.properties` — apenas identidade do projeto (seguro de commitar):**

```properties
sonar.projectKey=meu-projeto
sonar.sources=src
sonar.exclusions=**/test/**,**/vendor/**
```

Não adicione `sonar.host.url` ou `sonar.token` neste arquivo. A skill os injeta como overrides de CLI em tempo de execução, mantendo o arquivo compatível com pipelines de CI que usam seu próprio host e token. Um step de SonarQube/SonarCloud no GitHub Actions passa seus próprios flags `-D` e não é afetado.

**Setup: apenas Docker.** Sem instalação de CLI, sem configuração manual de token.

No primeiro uso, a skill sobe o `bsdd-sonarqube`, gera um token automaticamente via API do SonarQube e salva em `.bsdd-sonar-token` (gitignored). Reviews seguintes reutilizam o token salvo. O scanner roda como container efêmero `sonarsource/sonar-scanner-cli` na network compartilhada `bsdd-sonar-net`. Se o SonarQube não ficar saudável em 120s, o review é bloqueado com mensagem de erro explícita.

**Mapeamento de severidade:**

| Severidade Sonar | Tipo Sonar | Label do reviewer |
|---|---|---|
| BLOCKER / CRITICAL | qualquer | `BLOCKER` |
| MAJOR | BUG / VULNERABILITY | `BLOCKER` |
| MAJOR | CODE_SMELL | `WARNING` |
| MINOR / INFO | qualquer | `SUGGESTION` |
| Security hotspot | qualquer | `WARNING` |

Apenas issues em arquivos presentes no diff atual são exibidos. Findings do projeto fora do changeset são ignorados.
