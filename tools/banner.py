#!/usr/bin/env python3
"""tools/banner.py — gera docs/banner.svg a partir da mesma arte "LVL9" da tela do instalador.

Cada bloco da arte vira um retângulo (não depende de fonte instalada em quem abre o README),
com o degradê azul → roxo da marca e uma sombra deslocada para dar profundidade.
Uso: python3 tools/banner.py
"""
from pathlib import Path

ARTE = [
    "██╗     ██╗   ██╗██╗      █████╗ ",
    "██║     ██║   ██║██║     ██╔══██╗",
    "██║     ██║   ██║██║     ╚██████║",
    "██║     ╚██╗ ██╔╝██║      ╚═══██║",
    "███████╗ ╚████╔╝ ███████╗ █████╔╝",
    "╚══════╝  ╚═══╝  ╚══════╝ ╚════╝ ",
]
CW, CH = 15, 17          # célula: largura e altura (os blocos do terminal são mais altos que largos)
X0, Y0 = 72, 92          # posição da arte
W, H = 1280, 380

def blocos(ch):
    return [(c, l) for l, linha in enumerate(ARTE) for c, x in enumerate(linha) if x == ch]

cheios = blocos("█")

def rects(celulas, dx=0, dy=0, fill="url(#grad)"):
    """Junta blocos vizinhos da mesma linha num retângulo só (sem costura entre eles)."""
    corridas, atual = [], None
    for c, l in sorted(celulas, key=lambda p: (p[1], p[0])):
        if atual and atual[1] == l and atual[0] + atual[2] == c:
            atual[2] += 1
        else:
            atual = [c, l, 1]; corridas.append(atual)
    return "\n".join(
        f'    <rect x="{X0 + c * CW + dx}" y="{Y0 + l * CH + dy}" width="{n * CW}" height="{CH + 0.8}" fill="{fill}"/>'
        for c, l, n in corridas)

largura_arte = len(ARTE[0]) * CW
mono = "ui-monospace, SFMono-Regular, 'JetBrains Mono', Menlo, Consolas, monospace"
sans = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Inter, Helvetica, Arial, sans-serif"
tx = X0 + largura_arte + 70

svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" role="img" aria-label="lvl9 — pré-setup Debian/Ubuntu + XFCE + xrdp no estilo Omarchy">
  <defs>
    <linearGradient id="grad" gradientUnits="userSpaceOnUse" x1="{X0}" y1="{Y0}" x2="{X0 + largura_arte * 0.6}" y2="{Y0 + 6 * CH}">
      <stop offset="0" stop-color="#7aa2f7"/>
      <stop offset="1" stop-color="#bb9af7"/>
    </linearGradient>
    <linearGradient id="borda" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#7aa2f7"/>
      <stop offset="1" stop-color="#bb9af7"/>
    </linearGradient>
    <radialGradient id="brilho" cx="0.22" cy="0.45" r="0.6">
      <stop offset="0" stop-color="#7aa2f7" stop-opacity="0.16"/>
      <stop offset="1" stop-color="#7aa2f7" stop-opacity="0"/>
    </radialGradient>
    <pattern id="grade" width="24" height="24" patternUnits="userSpaceOnUse">
      <path d="M24 0H0V24" fill="none" stroke="#c0caf5" stroke-opacity="0.035"/>
    </pattern>
  </defs>

  <rect x="1" y="1" width="{W - 2}" height="{H - 2}" rx="22" fill="#1a1b26" stroke="url(#borda)" stroke-width="2"/>
  <rect x="1" y="1" width="{W - 2}" height="{H - 2}" rx="22" fill="url(#grade)"/>
  <rect x="1" y="1" width="{W - 2}" height="{H - 2}" rx="22" fill="url(#brilho)"/>

  <!-- arte LVL9: sombra deslocada + blocos com degradê -->
  <g opacity="0.55">
{rects(cheios, 6, 6, "#3b2f63")}
  </g>
  <g>
{rects(cheios)}
  </g>

  <text x="{X0}" y="{Y0 + 6 * CH + 52}" font-family="{mono}" font-size="17" fill="#565f89">
    <tspan fill="#bb9af7" font-weight="700">9LEVEL</tspan> · pré-setup Debian/Ubuntu · XFCE · xrdp
  </text>

  <text x="{tx}" y="118" font-family="{sans}" font-size="38" font-weight="700" fill="#c0caf5">Sua máquina no nível 9.</text>
  <text x="{tx}" y="160" font-family="{sans}" font-size="19" fill="#a9b1d6">Prompt powerline, CLI moderna, vim halcyon e</text>
  <text x="{tx}" y="187" font-family="{sans}" font-size="19" fill="#a9b1d6">Claude Code em uma linha, no estilo do Omarchy.</text>

  <rect x="{tx}" y="226" width="{W - tx - 60}" height="58" rx="12" fill="#16161e" stroke="#2f334d"/>
  <text x="{tx + 22}" y="262" font-family="{mono}" font-size="15.5" fill="#c0caf5">
    <tspan fill="#9ece6a">❯</tspan> curl -fsSL <tspan fill="#7aa2f7">…/julianol1berato/lvl9/main/boot.sh</tspan> <tspan fill="#bb9af7">|</tspan> bash<tspan fill="#c0caf5"> ▌<animate attributeName="opacity" values="1;1;0;0" keyTimes="0;0.5;0.5;1" dur="1.1s" repeatCount="indefinite"/></tspan>
  </text>

  <g font-family="{mono}" font-size="13.5" fill="#565f89">
    <text x="{tx}" y="322" xml:space="preserve">Debian 12 · 13    Ubuntu 24.04 · 26.04    x86_64 · arm64</text>
  </g>
</svg>
'''
destino = Path(__file__).resolve().parent.parent / "docs" / "banner.svg"
destino.write_text(svg, encoding="utf-8")
print(f"{destino} ({len(cheios)} blocos, {len(svg) // 1024} KB)")
