# agent-sandbox

Painel de controle compartilhado para o Claude Code e o Codex CLI, rodando
dentro de um container Docker, exposto via terminal web (ttyd sobre tmux) e
um painel de status ao lado.

## O que é

- Uma sessão `tmux` (`agents`) com uma janela `main` dividida em 2 panes:
  esquerda roda `claude`, direita roda `codex` — ambos autoiniciados. Os dois
  abrem com `~/Projects` como diretório de trabalho.
- `ttyd` expõe essa sessão tmux inteira como um terminal no navegador, com
  autenticação básica (usuário/senha do `.env`), na porta `7681`.
- Um mini status-server (Node) faz `tmux capture-pane` em todas as panes a
  cada 2s e serve um JSON (`/status.json`) consumido por um painel HTML
  (`/`, porta `8080`) que mostra as últimas linhas de cada pane ao lado de um
  terminal embutido (iframe do ttyd).

## Como criar novos agentes/tarefas específicas

De dentro de qualquer pane do tmux:

```
tmux new-window -n nome-da-tarefa -c /home/ayo/Projects/algum-projeto
```

A nova janela aparece automaticamente no painel de status (auto-descoberta
via `tmux list-panes`) e é acessível pelo mesmo terminal ttyd (troque de
janela com o prefixo do tmux, `Ctrl-b` + número da janela).

## Setup

```bash
cp .env.example .env
sed -i "s/^TTYD_PASS=.*/TTYD_PASS=$(openssl rand -base64 32 | tr -d '=+/\n')/" .env
sed -i "s/^HOST_UID=.*/HOST_UID=$(id -u)/" .env
sed -i "s/^HOST_GID=.*/HOST_GID=$(id -g)/" .env

docker compose build
docker compose up -d
```

## Verificação

1. `docker compose ps` — container `agent-sandbox` up.
2. `docker exec -it agent-sandbox claude --version` e `codex --version`.
3. `docker exec -it agent-sandbox claude` não deve pedir login (credenciais
   montadas de `~/.claude` / `~/.claude.json`); mesmo teste pro `codex`
   (`~/.codex/auth.json`).
4. `docker exec -it agent-sandbox tmux list-panes -a -t agents` — 2 panes na
   janela `main`.
5. No navegador (mesma rede): `http://<ip-da-maquina>:7681` — pede usuário/
   senha do `.env`, mostra as duas panes lado a lado, dá pra digitar em
   ambas.
6. `http://<ip-da-maquina>:8080` — painel de status com as últimas linhas de
   cada pane, timestamp `updatedAt` avançando a cada ~2s, terminal embutido
   abaixo.
7. Criar uma janela nova via tmux (seção acima) e confirmar que ela aparece
   no painel sem precisar reiniciar nada.
8. `docker compose restart` — sessão tmux recriada, credenciais continuam
   válidas sem novo login, histórico do bash preservado (`agent_state`
   volume).
9. Rodar uma tarefa real no `codex` que precise executar comando de shell e
   observar se o sandbox interno dele (bubblewrap/seccomp) funciona rodando
   aninhado dentro do Docker. Se falhar, ajustar `sandbox_mode` em
   `~/.codex/config.toml` (ex: `danger-full-access`), já que o próprio
   container Docker já é a fronteira de isolamento.

## Riscos / segurança

- O terminal fica exposto na rede local, mesmo com autenticação básica.
  Qualquer dispositivo na LAN que descobrir a senha ganha acesso de shell
  com os arquivos do usuário e as credenciais de ambos os CLIs. Use uma
  senha longa e aleatória (já gerada pelo setup acima) e nunca a commite.
- Autenticação básica em HTTP simples envia a senha em base64, não
  criptografada. Numa LAN doméstica é um risco limitado, mas se isso
  importar, `ttyd -S` (TLS com certificado autoassinado) é um endurecimento
  futuro documentado, não implementado nesta v1.
- Endurecimento futuro recomendado: já que a máquina roda Tailscale, vincular
  a porta publicada do ttyd só ao IP do Tailscale (`"100.x.y.z:7681:7681"`
  no compose) em vez de `0.0.0.0`, restringindo o acesso aos seus próprios
  dispositivos em vez de toda a LAN.
- Rodar o `claude` no host e dentro do container ao mesmo tempo, apontando
  para o mesmo `~/.claude`, tem baixa chance de contenção de estado
  (sqlite/lock). Se notar comportamento estranho, checar
  `~/.claude/daemon.log` primeiro.
