<p align="center">
  <img src="docs/banner.svg" alt="lvl9: sua máquina no nível 9" width="100%">
</p>

<p align="center">
  <a href="https://github.com/julianol1berato/lvl9/actions/workflows/test.yml"><img src="https://img.shields.io/github/actions/workflow/status/julianol1berato/lvl9/test.yml?branch=main&label=testes&style=flat-square&labelColor=1a1b26&color=9ece6a" alt="Testes"></a>
  <a href="https://github.com/julianol1berato/lvl9/releases"><img src="https://img.shields.io/github/v/tag/julianol1berato/lvl9?label=vers%C3%A3o&style=flat-square&labelColor=1a1b26&color=7aa2f7" alt="Versão"></a>
  <img src="https://img.shields.io/badge/Debian-12%20%C2%B7%2013-bb9af7?style=flat-square&labelColor=1a1b26&logo=debian&logoColor=c0caf5" alt="Debian 12 e 13">
  <img src="https://img.shields.io/badge/Ubuntu-24.04%20%C2%B7%2026.04-bb9af7?style=flat-square&labelColor=1a1b26&logo=ubuntu&logoColor=c0caf5" alt="Ubuntu 24.04 e 26.04">
  <a href="LICENSE"><img src="https://img.shields.io/badge/licen%C3%A7a-MIT-e0af68?style=flat-square&labelColor=1a1b26" alt="Licença MIT"></a>
</p>

<p align="center">
  <a href="#-instalar"><b>Instalar</b></a> ·
  <a href="#-o-prompt"><b>Prompt</b></a> ·
  <a href="#%EF%B8%8F-nada-para-decorar-alth"><b>Alt+H</b></a> ·
  <a href="#-o-que-vem-instalado"><b>O que vem</b></a> ·
  <a href="#-como-funciona"><b>Como funciona</b></a> ·
  <a href="#-perguntas-frequentes"><b>FAQ</b></a>
</p>

---

O **lvl9** pega um Debian ou Ubuntu recém-instalado, desktop com XFCE ou servidor sem interface
gráfica, e deixa a máquina pronta para trabalhar, no estilo do [Omarchy](https://github.com/basecamp/omarchy)
e do setup do [Fábio Akita](https://github.com/akitaonrails). Você ganha um prompt powerline com git,
IP e relógio, a CLI moderna escrita em Rust e Go, o vim com o tema halcyon, tmux e, se quiser,
Claude Code com statusbar e herdr. No desktop vêm também Nerd Fonts, flameshot no PrintScreen e
xrdp redondo.

São uma linha no terminal e uma tela de instalação. **Sem flags e sem nada para decorar.**

## ⚡ Instalar

```bash
curl -fsSL https://raw.githubusercontent.com/julianol1berato/lvl9/main/boot.sh | bash
```

Rode como **o seu usuário**, não como root. O lvl9 pede a senha do sudo uma vez e configura
**o seu usuário e o root**. Em uma máquina nova leva de 5 a 10 minutos, e pode rodar de novo
quando quiser: cada passo só mexe no que mudou e guarda backup do que substitui.

**O lvl9 respeita o host.** Numa máquina sem interface gráfica ele entra no **modo servidor** e não
instala nada gráfico: nem XFCE, nem xrdp, nem fontes. Onde já existe um desktop, ele configura
também o XFCE e o xrdp.

<p align="center">
  <img src="docs/img/instalador.gif" alt="O instalador: verificações, escolhas no gum, passos e resumo" width="100%">
</p>

<table>
  <tr>
    <td width="50%"><img src="docs/img/escolhas.png" alt="Escolha dos grupos de ferramentas"></td>
    <td width="50%"><img src="docs/img/instalado.png" alt="Resumo ao final da instalação"></td>
  </tr>
  <tr>
    <td align="center"><sub>Escolhas na tela: <code>x</code> marca, <code>Enter</code> confirma</sub></td>
    <td align="center"><sub>Cada passo com tempo, resumo e o terminal novo já pronto</sub></td>
  </tr>
</table>

## 🎨 O prompt

Duas linhas: à esquerda o que você está fazendo, à direita onde e quando.

<p align="center">
  <img src="docs/img/prompt.png" alt="O prompt com usuário@host, git, erro do último comando, duração, IPs e relógio" width="100%">
</p>

- **Máquina**: `usuário@host` no começo da linha, sempre (não só via SSH), para você nunca rodar um
  comando no servidor errado.
- **Git**: branch e estado (`!` modificado, `?` novo).
- **Erro e duração**: o código de saída aparece só quando o comando falha, e o tempo só quando passa de 2s.
- **IP da LAN e do Tailscale**: o da LAN vem da interface da rota padrão (nunca do `docker0`), e o do
  Tailscale da faixa `100.64.0.0/10`. A detecção roda 1x por dia, para não pesar no Enter. Mudou de
  rede? `atualiza-ip`.
- **Relógio** no fim da linha, para saber a hora em que cada comando rodou.

**Cinco temas.** Para ver todos com a sua pasta atual, rode `lvl9 tema`. Para trocar, `lvl9 tema <nome>`.

<p align="center">
  <img src="docs/img/temas.png" alt="Os temas gruvbox, omarchy, parrot, tokyo-night e bash-parrot" width="100%">
</p>

## 🖥️ Ao abrir o terminal

Um resumo do sistema com o fastfetch e uma dica de comando, diferente a cada terminal. Se cansar,
desligue com `lvl9 fastfetch off` ou `lvl9 dicas off`.

<p align="center">
  <img src="docs/img/terminal.png" alt="fastfetch com sistema, CPU, memória, disco e IPs, mais a dica do dia" width="100%">
</p>

## ⌨️ Nada para decorar: Alt+H

**`Alt+H`**, a qualquer momento, abre o catálogo de comandos com busca. O comando escolhido vai
para o prompt, pronto para você editar ou rodar.

<p align="center">
  <img src="docs/img/ajuda.gif" alt="Alt+H: busca por 'disco' e o comando vai para o prompt" width="100%">
</p>

Todo comando novo tem nome em **inglês e em pt-BR**:

| inglês | pt-BR | o que faz |
|---|---|---|
| `sys` | `sistema` | resumo do sistema (fastfetch) |
| `disk` | `disco` | espaço livre em cada disco (duf) |
| `usage` | `pasta` | o que está ocupando espaço aqui (dust) |
| `proc` | `processos` | processos com cores e busca (procs) |
| `ports` | `portas` | portas abertas e quem está ouvindo |
| `monitor` | `monitorar` | CPU, memória, disco e rede (btop) |
| `lg` · `lzd` | | git e Docker numa interface no terminal (lazygit, lazydocker) |
| `dns` | | consulta DNS moderna (doggo) |
| `pingg` | `pingar` | ping com gráfico, vários hosts (gping) |
| `route` · `bw` | `rota` · `banda` | traceroute visual (trippy) · banda por processo (bandwhich) |
| `scan` | `varrer` | nmap rápido das 100 portas mais comuns |
| `examples` | `exemplos` | exemplos práticos de um comando (tldr, em português) |
| `update` | `atualizar` | atualiza todos os pacotes do sistema |

Os comandos de sempre também ficam melhores, **sem mudar de nome**: `ls` (eza, com ícones e git),
`cat` (bat, com cores), `top` (btop), `cd` (zoxide, pula para a pasta mais usada) e `Ctrl+R` (fzf).

<p align="center">
  <img src="docs/img/comandos.gif" alt="ls com eza, cat com bat, pasta com dust, proc e exemplos tar" width="100%">
</p>

## 📝 Vim com halcyon

O [halcyon-vim](https://github.com/julianol1berato/halcyon-vim) com vim-plug, airline, NERDTree
(`Espaço f`), coc.nvim, ALE, fugitive e `:FZF` (`Ctrl+P`). Fica igual no seu usuário e no root.

<p align="center">
  <img src="docs/img/vim.png" alt="Vim com o tema halcyon, NERDTree e airline" width="100%">
</p>

## 🤖 Claude Code

Marque **Claude Code** na instalação e ele vem completo, no seu usuário e no root:

- **[Claude Code](https://docs.claude.com/en/docs/claude-code)** pelo instalador oficial, que se atualiza sozinho.
- **[statusbar-claude](https://github.com/9LEVEL/statusbar-claude)** mostra contexto usado, limites de 5h e da semana, custo e modelo.
- **[herdr](https://herdr.dev)** organiza vários agentes em painéis, já integrado ao Claude Code.

<p align="center">
  <img src="https://raw.githubusercontent.com/9LEVEL/statusbar-claude/main/docs/preview.svg" alt="statusbar-claude: contexto em 10%, 74% e 93%" width="100%">
</p>

## 📦 O que vem instalado

| | |
|---|---|
| **Sempre** | starship · eza · bat · fd · ripgrep · fzf · zoxide · jq · fastfetch · btop · gum · gh · mise com Node LTS |
| **Dev** | delta (diff do git lado a lado) · lazygit · tldr · yq |
| **Sysadmin** | Docker Engine · lazydocker · dust · duf · procs |
| **Rede** | nmap · doggo · gping · trippy · bandwhich · tcpdump · socat · mtr |
| **Shell** | bash no estilo do Akita, prompt com 5 temas, aliases em inglês e pt-BR, `Alt+H`, fastfetch e dica ao abrir |
| **Editor e terminal** | vim halcyon · tmux Tokyo Night (prefixo `Ctrl+a`) |
| **Desktop** ¹ | XFCE · xfce4-terminal com Nerd Font e Tokyo Night · JetBrainsMono e CaskaydiaMono Nerd Font · flameshot em `Print` e `Super+Shift+S` |
| **xrdp** ¹ | sessão XFCE · som pelo RDP · sem o pedido de senha do colord a cada login |
| **Sistema** | fuso America/Sao_Paulo com NTP · locale pt_BR.UTF-8 |
| **Opcional** | Tailscale · Claude Code + statusbar-claude + herdr |

¹ Só no modo desktop. Num servidor sem interface gráfica nada disso é instalado.

Os grupos **Dev**, **Sysadmin** e **Rede** vêm marcados. Desmarque na tela o que não quiser.

## 🩺 Depois de instalado

```
lvl9 update      busca a versão nova e reaplica, com as suas escolhas de antes
lvl9 diff        mostra o que mudou na máquina em relação ao lvl9
lvl9 doctor      confere cada ferramenta contra a versão fixada
lvl9 tema        mostra ou troca o tema do prompt
lvl9 dicas on|off · lvl9 fastfetch on|off
```

<details>
<summary><b>Ver o <code>lvl9 doctor</code></b></summary>
<br>
<p align="center"><img src="docs/img/doctor.png" alt="lvl9 doctor: todas as ferramentas na versão do lock" width="80%"></p>
</details>

## 🔒 Como funciona

- **Versões fixadas e conferidas.** Cada binário vem do GitHub na versão do
  [`versions.lock`](versions.lock), com sha256. Se o download não bater, a instalação para. Toda
  semana, um GitHub Action procura versões novas, confere com os checksums publicados pelos
  projetos e abre um pull request. Depois do merge, `lvl9 update` traz as novidades.
- **Auto-merge só do que é seu.** PRs do dono do repositório e do bot de versões entram sozinhos
  1 dia depois do último commit, com os testes verdes. Para segurar um, ponha o rótulo `segurar`.
  PRs de outras pessoas, vindos de fork, e os que mexem nos workflows esperam o merge manual.
  Claude Code, herdr e Tailscale usam os instaladores oficiais, que conferem o próprio download e
  se atualizam sozinhos.
- **O root nunca lê configuração de um home.** Temas do starship podem executar comandos, então o
  prompt, os temas e os aliases ficam em `/usr/local/share/lvl9`, que só o root altera.
- **Cópia com backup, não symlink.** Tudo o que é substituído vai antes para
  `~/.local/state/lvl9/backups/<data>/`. Os arquivos do root vão para `/root/.local/state/lvl9/backups/`.
- **O seu `~/.bashrc` é seu.** Ele só carrega `/usr/local/share/lvl9/bash/rc`. O `lvl9 update`
  atualiza o rc e não mexe mais no seu `~/.bashrc`. Segredos ficam em `~/.bashrc.local`.
- **XFCE na hora certa.** Instalou de dentro da sessão gráfica? Fonte, cores e atalhos são
  aplicados na hora. Instalou por SSH? São aplicados sozinhos no próximo login.
- **Testado.** A cada mudança, o GitHub roda o shellcheck e testes rápidos sem internet: detecção
  do modo, passos de cada modo, instalação sem terminal e o `versions.lock`. A instalação completa
  baixa as ferramentas, então roda local, em containers limpos de Debian 12 e 13 e Ubuntu 24.04 e
  26.04, nos dois modos, e confere mais de 80 itens em cada um.

## ❓ Perguntas frequentes

<details>
<summary><b>Posso rodar de novo?</b></summary>
<br>
Pode, quantas vezes quiser. A tela já vem com as suas escolhas anteriores, e cada passo só mexe no
que mudou. É o que o <code>lvl9 update</code> faz por baixo.
</details>

<details>
<summary><b>Terminei a instalação e o terminal continua igual.</b></summary>
<br>
O terminal de onde você rodou o <code>curl | bash</code> ainda está com a configuração antiga. No fim da
instalação o lvl9 pergunta se quer abrir um terminal novo, já com tudo. Se respondeu "Não", abra outra
janela do terminal ou digite <code>exec bash</code>.
</details>

<details>
<summary><b>Como desfaço uma mudança?</b></summary>
<br>
Tudo o que foi substituído está em <code>~/.local/state/lvl9/backups/&lt;data&gt;/</code>, com a mesma
árvore de pastas do original. Para voltar o <code>~/.bashrc</code> de antes:
<code>cp ~/.local/state/lvl9/backups/&lt;data&gt;/home/$USER/.bashrc ~/</code>.
</details>

<details>
<summary><b>Os ícones do prompt aparecem como quadrados.</b></summary>
<br>
O terminal precisa de uma Nerd Font. No xfce4-terminal o lvl9 já configura a JetBrainsMono. Se você
acessa por SSH a partir de outro computador (Windows Terminal, iTerm2…), instale uma
<a href="https://www.nerdfonts.com/font-downloads">Nerd Font</a> nesse computador e selecione-a no terminal dele.
</details>

<details>
<summary><b>O PrintScreen não abre o flameshot pelo RDP.</b></summary>
<br>
O Windows costuma segurar o PrintScreen, e a tecla nem chega à sessão. Use <code>Super+Shift+S</code>,
que o lvl9 também configura, ou desligue em <i>Configurações → Acessibilidade → Teclado → Usar a tecla
Print Screen para abrir a captura de tela</i>.
</details>

<details>
<summary><b>Funciona em servidor sem interface gráfica?</b></summary>
<br>
Sim. Sem interface gráfica instalada (nenhuma sessão X ou Wayland, nem display manager), o lvl9
entra sozinho no <b>modo servidor</b>: instala a parte de terminal (prompt, CLI, vim, tmux, Docker,
Claude Code…) e nada gráfico. Ficam de fora XFCE, xrdp, flameshot, Nerd Fonts e xclip. No tmux, o
que você copia vai para a área de transferência do seu computador pelo próprio terminal (OSC 52),
mesmo por SSH.
<br><br>
O modo fica salvo e vale para o <code>lvl9 update</code>. Para escolher na mão, use
<code>LVL9_MODO</code>: <code>curl -fsSL …/boot.sh | LVL9_MODO=desktop bash</code> instala XFCE e
xrdp num servidor, e <code>LVL9_MODO=servidor</code> faz o contrário.
</details>

<details>
<summary><b>Dá para instalar sem tela, por automação ou pelo Claude Code?</b></summary>
<br>
Dá. Sem terminal interativo (Claude Code, CI, <code>ssh</code> sem <code>-t</code>), o instalador
segue sem perguntas, com as escolhas da última instalação ou com os padrões. O sudo precisa
funcionar sem pedir senha (NOPASSWD), porque não há onde digitá-la. Para forçar esse modo mesmo
com terminal, use <code>LVL9_AUTO=1</code>.
</details>

<details>
<summary><b>Estrutura do repositório</b></summary>
<br>

```
boot.sh              alvo do curl | bash: valida, clona em ~/.local/share/lvl9 e abre o instalador
install.sh           a tela: verificações, escolhas, passos e resumo
install/NN-*.sh      passos idempotentes (sistema, ferramentas, fontes, shell, vim, docker, xrdp…)
lib/                 comum.sh (lock, downloads, cópia com backup) · ui.sh (gum) · desktop.sh (xfconf)
config/              rc do bash, prompt, temas, catálogo de comandos, tmux, fastfetch, xfce, xrdp
bin/lvl9             o comando lvl9
ferramentas.tsv      o que é instalado e de onde vem
versions.lock        versões e sha256 (gerado por tools/bump-versions.sh)
tests/               instalação completa em containers limpos: tests/docker.sh [imagem…]
docs/                banner, cenas das screenshots (docs/tapes) e imagens (docs/img)
tools/               bump-versions.sh · auto-merge.sh · screenshots.sh · banner.py
```
</details>

## 🤝 Contribuir

```bash
tests/rapidos.sh                # testes rápidos, sem internet (é o que o GitHub roda)
tests/docker.sh                 # instala nas 4 distros em containers limpos e confere tudo
tests/docker.sh ubuntu:24.04    # só uma
LVL9_MODO=desktop tests/docker.sh debian:13   # o container não tem interface: sem isso é servidor
tools/screenshots.sh            # regrava as imagens deste README (tudo em Docker)
tools/bump-versions.sh          # atualiza o versions.lock com as últimas versões
tools/auto-merge.sh --simula    # mostra o que o auto-merge faria com os PRs abertos
```

Issues e pull requests são bem-vindos.

## Créditos

Inspirado no [Omarchy](https://github.com/basecamp/omarchy) e no setup do
[Fábio Akita](https://github.com/akitaonrails). Interface do instalador feita com o
[gum](https://github.com/charmbracelet/gum). Tema do vim:
[halcyon-vim](https://github.com/julianol1berato/halcyon-vim). Statusbar do Claude Code:
[statusbar-claude](https://github.com/9LEVEL/statusbar-claude).

<p align="center">
  <sub>MIT · feito por <a href="https://github.com/9LEVEL">9LEVEL</a></sub>
</p>
