---
date: 2026-06-05
title: bsdd-plugins
---

## Understanding

Generalizar o mecanismo opt-in hardcoded do SonarQube em um sistema de plugins de primeira classe. Hoje o `reviewer.md` carrega `sonar-analysis.md` diretamente via sentinel file (`sonar-project.properties`). A proposta cria um `.bsdd-plugins.yml` no projeto-alvo que declara plugins por sub-agente; cada plugin vive em `.skills/plugins/<nome>.md`; o `reviewer.md` itera os plugins declarados dinamicamente em vez de hardcode.

## Assumptions

- Plugins são executados por sub-agentes, não pelo orquestrador
- Por ora, apenas o `reviewer` terá plugins — os demais são extensão futura
- `.bsdd-plugins.yml` fica no **projeto-alvo** (como `sonar-project.properties` hoje), não no behavioral-sdd em si
- `sonar-analysis.md` será desmembrado e deletado — substituído pelos 3 arquivos de plugin
- O mecanismo `auto` (detecção por sentinel file) deve ser preservado como valor possível

## Scope

| Arquivo | Ação |
|---|---|
| `.skills/sonar-analysis.md` | Deletar |
| `.skills/plugins/sonar.md` | Criar — contém os steps 1–8 do sonar-analysis.md atual |
| `.skills/plugins/xlint-removal.md` | Criar — Java only, -Xlint:removal via Gradle init script ou Maven |
| `.skills/plugins/trivy.md` | Criar — CVE scan via Docker, HIGH/CRITICAL |
| `.claude/agents/reviewer.md` | Step 7 → loop de plugins via .bsdd-plugins.yml |
| `CLAUDE.md` | "Optional integrations (experimental)" → seção "Plugins" |
| `README.md` | idem |
| `docs/workflow.md` | idem |
| `docs/workflow.pt-br.md` | idem (PT-BR atualizado em paralelo) |

## Out of scope

- Plugins para `implementer`, `ship`, `optimizer` — futuro
- Opções extras por plugin no YAML (ex: `severity: MAJOR`) — futuro; documentar a possibilidade
- Registry central ou validação de schema do `.bsdd-plugins.yml`
- Interface além de YAML simples

## Approach

### 1. Formato `.bsdd-plugins.yml`

```yaml
# .bsdd-plugins.yml
plugins:
  reviewer:
    sonar:
      enabled: auto        # auto = só roda se sonar-project.properties existir
    xlint-removal:
      enabled: true        # força habilitado
    trivy:
      enabled: false       # força desabilitado
```

Valores de `enabled`:
- `auto` — usa detecção por sentinel file (comportamento atual preservado)
- `true` — força habilitado independente de detecção
- `false` — força desabilitado, omite seção do output

Arquivo ausente → todos os plugins em `auto` (backward compatible).

Documentar que suporte a opções extras por plugin (ex: `sonar: { enabled: auto, severity: MAJOR }`) está reservado para versão futura.

### 2. Criar `.skills/plugins/sonar.md`

Extrair steps 1–8 do `sonar-analysis.md` atual (SonarQube server, token, scanner, CE queue, fetch issues, severity mapping, output format). Atualizar opt-in: `enabled: auto` detecta `sonar-project.properties`; `enabled: true` força mesmo sem o arquivo.

### 3. Criar `.skills/plugins/xlint-removal.md`

Extrair seção "Compiler Removal Warnings" do `sonar-analysis.md` atual. Java only. Gradle via init script temporário; Maven via `-Dmaven.compiler.compilerArgument=-Xlint:removal`. Skip graceful para projetos não-Java.

### 4. Criar `.skills/plugins/trivy.md`

Extrair seção "Dependency Vulnerability Scan" do `sonar-analysis.md` atual. Docker required. CRITICAL → BLOCKER, HIGH → WARNING.

### 5. Deletar `.skills/sonar-analysis.md`

### 6. Atualizar `reviewer.md` — step 7

Substituir lógica hardcoded do Sonar por:

```
Step 7 — Run plugins
  a. If .bsdd-plugins.yml exists at project root: parse plugins.reviewer
     Else: treat all known plugins as enabled: auto
  b. For each plugin in declaration order:
     - Resolve enabled value (auto | true | false)
     - If false: skip (no output)
     - If auto: apply plugin's own opt-in detection
     - If true or auto+detected: load .skills/plugins/<name>.md and execute
     - If .skills/plugins/<name>.md not found: emit
       [WARN] Plugin '<name>' declared but .skills/plugins/<name>.md not found — skipping
  c. Append all plugin findings to review output under their respective sections
```

### 7. Atualizar documentação (5 arquivos)

Substituir "Optional integrations *(experimental)*" / "SonarQube via Docker *(experimental)*" por seção "Plugins" com:
- Explicação do mecanismo `.bsdd-plugins.yml`
- Tabela de plugins disponíveis (sonar, xlint-removal, trivy)
- Exemplo de configuração
- Nota de extensão futura (opções por plugin, plugins para outros sub-agentes)

### 8. Pré-implementação

```bash
cd /Users/fuhrmann/git/behavioral-sdd
git pull origin main          # origin/main está em fbece47
git rebase origin/main        # aplica eb6f99a (xlint+trivy) em cima
git checkout -b feat/bsdd-plugins
```

## Files likely to change

```
.skills/sonar-analysis.md              ← deletar
.skills/plugins/sonar.md              ← criar
.skills/plugins/xlint-removal.md      ← criar
.skills/plugins/trivy.md              ← criar
.claude/agents/reviewer.md
CLAUDE.md
README.md
docs/workflow.md
docs/workflow.pt-br.md
```

## Tests needed

N/A — framework de instruções para LLM. Validação é comportamental:
- Sem `.bsdd-plugins.yml` → comportamento idêntico ao atual
- `sonar: enabled: false` → Sonar não roda, seção ausente do output
- Plugin declarado sem arquivo `.skills/plugins/` → `[WARN]` e review continua
- `xlint-removal: enabled: true` em projeto não-Java → skip graceful com mensagem

## Risks

- `reviewer.md` referencia `sonar-analysis.md` explicitamente — se não atualizado em conjunto com a deleção do arquivo, o reviewer quebra silenciosamente. Mitigação: deleção e atualização do reviewer no mesmo commit.
- `origin/main` está à frente do local (`fbece47` > `eb6f99a`) — rebase obrigatório antes de criar a feature branch.

## Performance criteria

Nenhum — não há código de produção.

## API tests

N/A
