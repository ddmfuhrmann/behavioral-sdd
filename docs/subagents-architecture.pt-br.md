# Arquitetura de Subagents

Como o behavioral-sdd divide o trabalho entre subagents isolados do Claude Code, e
as regras de design que mantêm cada um no seu papel.

> A versão canônica (inglês) deste documento é [`subagents-architecture.md`](subagents-architecture.md).

---

## Modelo: orquestrador + especialistas

Os slash commands `bsdd-*` (`.claude/commands/`) são **orquestradores**. Rodam na
sessão principal, seguram a conversa e dão `Spawn` em **subagents** especialistas
(`.claude/agents/`) para o trabalho que se beneficia de contexto isolado e de um
conjunto restrito de ferramentas.

```
/bsdd-implement ──▶ feature-implementer ──▶ test-implementer
                         │ (loop de correção em caso de falha de teste)
/bsdd-ship ─────▶ reviewer ──▶ (fix via feature-implementer) ──▶ git-agent
/bsdd-optimize ─▶ optimizer
ops de git ─────▶ git-agent  (branches, commits, diffs, PRs)
```

O planejamento (`/bsdd-prd`, `/bsdd-plan`) roda deliberadamente na **thread
principal**, não num subagent — planejar precisa do contexto completo da conversa,
que o isolamento removeria. Veja [Lacunas conhecidas](#lacunas-conhecidas).

> **Restrição — subagents não conseguem invocar slash commands.** Um subagent roda
> num contexto isolado com um conjunto fixo de ferramentas; ele não tem como disparar
> `/bsdd-ship` nem qualquer outro comando, não importa o que o prompt dele diga. Slash
> commands são um construto da sessão principal. É por isso que o `feature-implementer`
> não consegue "chamar o ship" — é estrutural, não um bug. **O encadeamento de fases
> tem que morar num orquestrador da thread principal** (o `/bsdd-run` proposto, veja
> [`brainstorm.md`](brainstorm.md) #6), nunca dentro de um subagent.

---

## O elenco

| Subagent | Modelo | Ferramentas | Papel | Invocado por |
|---|---|---|---|---|
| `feature-implementer` | Sonnet 4.6 | Read, Write, Edit, Bash | Escreve código de produção exatamente como o plano descreve | `/bsdd-implement`, `/bsdd-ship` (fixes) |
| `test-implementer` | Sonnet 4.6 | Read, Write, Edit, Bash | Escreve e roda testes que verificam o plano | `/bsdd-implement` |
| `reviewer` | Opus 4.8 | Read, Bash | Audita o diff contra o plano; quality gate | `/bsdd-ship` |
| `optimizer` | Opus 4.8 | Read, Write, Edit, Bash | Performance baseada em evidência (medir → mudar → medir) | `/bsdd-optimize` |
| `git-agent` | Haiku 4.5 | Bash | Operações de git: branches, commits, diffs, PRs | só orquestradores |

---

## Princípios de design

### 1. Responsabilidade única
Cada subagent faz uma coisa. O implementer não escreve testes; o test-implementer
não corrige código de produção; o reviewer não reescreve código — ele aponta
achados e o orquestrador re-spawna o implementer para corrigir.

### 2. Escopo de ferramentas
Ferramentas concedidas por necessidade, do mais estrito primeiro. O `reviewer` **não
tem `Write`/`Edit`** — ele fisicamente não consegue alterar a árvore, e é isso que o
torna um gate confiável. O `git-agent` só tem `Bash`.

> **Ressalva:** o escopo é grosso. `Bash` não dá pra restringir a "só git", e
> `Write`/`Edit` não dá pra restringir a "só arquivos de teste". Então alguns
> invariantes ("não corrigir código de produção", "nunca force-push") são
> **garantidos por prosa**, não por ferramenta. Endurecer isso em hooks
> `PreToolUse` está anotado em [`brainstorm.md`](brainstorm.md) (ideia #1).

### 3. Tiering de modelo (consciente de custo)
Trabalho mecânico roda barato, julgamento roda caro:
- **Haiku** — `git-agent` (ops de shell determinísticas)
- **Sonnet** — `feature-implementer`, `test-implementer` (execução)
- **Opus** — `reviewer`, `optimizer` (julgamento, raciocínio de trade-off)

### 4. Isolamento de contexto
Cada subagent recebe só o que precisa — o plano, o resumo anterior, o diff. O
reviewer vê o diff e os resumos, não a cadeia de raciocínio do implementer. Essa é a
razão central de usar subagents em vez de uma thread longa única.

### 5. Handoff por contrato
Subagents não compartilham memória. Eles se comunicam através de **blocos de Output
estruturados** que o orquestrador repassa:

- `feature-implementer` → **Implementation Summary** (arquivos mudados, cobertura do
  plano, desvios, sinalizado-para-optimizer, fora de escopo)
- `test-implementer` → **Test Summary** (tipos de teste, casos, resultados, lacunas,
  bugs encontrados)
- `reviewer` → **Review Summary** (cobertura do plano, veredito, achados com rótulo
  de severidade)
- `optimizer` → **Optimization Report** (baseline, mudança, depois, trade-offs,
  recomendação)

O plano em si é passado **inline no prompt do spawn** — não há arquivo de plano
compartilhado que os subagents leiam. (O plano salvo canônico fica em
`.plans/YYYY-MM-DD-<title>.md`, escrito pelo `/bsdd-plan`.)

---

## Fluxos de orquestração

### Implement (com loop de correção)
`/bsdd-implement` spawna o `feature-implementer`, depois o `test-implementer`. Em
caso de falha de teste, registra a assinatura do erro, re-spawna o implementer com o
output da falha e re-testa. Um **circuit breaker** aborta se a nova assinatura de
erro for igual à da tentativa anterior — evitando um loop de thrash. Após falhas
repetidas, faz checkpoint via `AskUserQuestion` (tentar de novo / intervir /
abandonar).

### Ship (quality gate → handoff)
`/bsdd-ship` spawna o `git-agent` para o diff, avisa em PRs grandes (600–900 / >900
linhas), spawna o `reviewer`, percorre os achados com `AskUserQuestion` (corrigir /
adiar / abrir issue), roda uma checagem de ADR, coleta contexto de handoff e então
spawna o `git-agent` para abrir o PR. Artefatos de review/ADR/handoff são salvos em
`.ship/` e são **gitignored** — nunca commitados.

### Optimize
`/bsdd-optimize` spawna o `optimizer` só quando há uma preocupação mensurável.
Estabelece baseline antes de qualquer mudança, aplica uma mudança por vez e reporta
trade-offs.

---

## Invariantes de segurança do git-agent

O `git-agent` centraliza o git para que as regras de segurança morem num lugar só:

- Nunca force-push.
- Nunca `--no-verify` (nunca pular hooks).
- Nunca commitar em `main` diretamente.
- Nunca `git add -f` / `--force`; se o git recusar um arquivo ignorado, reportar em
  vez de sobrepor.
- Nunca commitar `.env` ou arquivos de credencial; checar cada arquivo contra o
  `.gitignore` antes de stage.

Hoje são **invariantes de prosa** (o agente tem `Bash` completo). Promovê-los a hooks
forçados está anotado em [`brainstorm.md`](brainstorm.md) (ideia #1).

---

## Lacunas conhecidas

- **Sem subagent de planner/PRD.** `/bsdd-prd` e `/bsdd-plan` rodam na thread
  principal. É intencional (planejar precisa de contexto completo), mas significa que
  a qualidade do plano depende do orquestrador, não de um especialista isolado.
- **Enforcement só por prosa** de várias regras de segurança — veja princípio #2.
- **Sobreposição na criação de branch.** O `feature-implementer` cria sua própria
  branch (`git checkout -b`) mesmo o `git-agent` oferecendo uma operação
  `create-branch`. Um dono só deveria ser escolhido.
