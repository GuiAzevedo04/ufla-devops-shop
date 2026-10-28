# Pipeline DevSecOps (Atividade 8)

Workflow: [`.github/workflows/devsecops.yml`](../.github/workflows/devsecops.yml).

## Quando roda

- Em todo **Pull Request** para a `main`: ao abrir, a cada novo push na branch e
  ao reabrir (`opened`, `synchronize`, `reopened`).
- Em todo **push na `main`** (ou seja, depois de um merge).

## Jobs e ferramentas

| Job | Ferramenta | O que faz | Bloqueia? |
| --- | --- | --- | --- |
| `test` | ruff + pytest | Lint, testes e cobertura (`coverage.xml`) | Sim, se lint ou teste falhar |
| `gitleaks` | Gitleaks | Procura segredos em **todo o histórico** do Git (`fetch-depth: 0`) | Sim, qualquer segredo encontrado |
| `sonarcloud` | SonarCloud | SAST (bugs, vulnerabilidades, *code smells*) e cobertura | Sim, se o Quality Gate reprovar |
| `trivy` | Trivy | CVEs nas dependências (`fs`) e na imagem Docker (`image`) | Sim, CRITICAL/HIGH **com correção** |
| `sbom` | Syft | Gera o SBOM da imagem em SPDX JSON | Sim, se não conseguir gerar |
| `publish` | Docker + GHCR | Publica a imagem `ghcr.io/guiazevedo04/ufla-devops-shop` | Só roda em push na `main` |

## Regras de bloqueio

- **Gitleaks**: `gitleaks git --exit-code 1` varre todos os commits. Qualquer
  possível segredo reprova o job. O `--redact` evita imprimir o segredo no log.
- **SonarCloud**: o Quality Gate padrão *Sonar way* avalia o **código novo**
  (cobertura, duplicação, bugs, vulnerabilidades e *security hotspots*). Com
  `sonar.qualitygate.wait=true` em `sonar-project.properties`, o passo espera o
  resultado e falha se o gate reprovar.
- **Trivy**: dois scans bloqueantes, um no sistema de arquivos
  (`requirements.txt`) e outro na imagem construída, ambos com
  `severity: CRITICAL,HIGH`, `ignore-unfixed: true` (só vulnerabilidades que já
  têm versão corrigida) e `exit-code: 1`.
- **Só relatório**: o Trivy roda de novo com `severity: LOW,MEDIUM` e
  `exit-code: 0`. O resultado é gravado em arquivo e publicado como artefato,
  mas **nunca** reprova o pipeline.
- Nenhum passo bloqueante usa `continue-on-error` ou `|| true`.

## Publicação

O job `publish` tem `needs: [test, gitleaks, sonarcloud, trivy, sbom]` e
`if: github.event_name == 'push'` na `main`. Ou seja, a imagem só vai para o
GHCR depois que **todos** os checks passarem, e nunca a partir de um PR. As tags
são o SHA curto do commit e `latest`. A autenticação usa o `GITHUB_TOKEN`, e só
esse job tem `packages: write`; os outros só leem o repositório
(`contents: read`).

A `main` é protegida: o merge exige PR e os checks `test`, `gitleaks`,
`sonarcloud`, `trivy` e `sbom` verdes.

## Artefatos

Na página de cada execução (**Actions → DevSecOps → execução → Artifacts**):

- `sbom-ufla-devops-shop.spdx.json`: SBOM da imagem (componentes e versões).
- `trivy-relatorios`: relatórios LOW/MEDIUM do Trivy (`fs` e `image`).
- `coverage`: o `coverage.xml` usado pelo SonarCloud.

## Demonstração: bloqueio e correção

1. Na branch `demo/cve` foi adicionada a dependência vulnerável
   `urllib3==1.26.4` ao `requirements.txt`. O Trivy aponta, entre outras,
   **CVE-2021-33503** (HIGH, ReDoS, corrigida na 1.26.5):

   ```text
   │ urllib3 │ CVE-2021-33503 │ HIGH │ fixed │ 1.26.4 │ 1.26.5 │ python-urllib3: ReDoS in the parsing of authority part of
   ```

2. O PR para a `main` ficou com o check `trivy` vermelho e o merge **bloqueado**
   pela proteção de branch.
3. A dependência foi removida (a aplicação não a usa) com um novo push na mesma
   branch, e todos os checks ficaram verdes.
4. A versão vulnerável nunca foi publicada: o PR não roda o `publish`.

Evidências:

- PR bloqueado: _(link do PR)_
- Execução reprovada (Trivy): _(link da execução)_
- Execução aprovada após a correção: _(link da execução)_
