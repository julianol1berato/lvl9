# A instalação de verdade: curl | bash do GitHub, escolhas no gum, passos e resumo
Output "docs/img/instalador.gif"
Source docs/tapes/_base.tape
Set Width 1280
Set Height 980
Set FontSize 16
Set Framerate 20
Set TypingSpeed 35ms
Source docs/tapes/_inicio.tape
Sleep 800ms
Type "curl -fsSL https://raw.githubusercontent.com/julianol1berato/lvl9/main/boot.sh | bash"
Sleep 600ms
Enter
Wait+Screen@90s /Grupos extras/
Sleep 1.5s
Down Sleep 400ms Down Sleep 500ms Type "x" Sleep 700ms Type "x" Sleep 600ms Up Sleep 400ms Up Sleep 600ms
Screenshot docs/img/escolhas.png
Sleep 1.5s
Enter
Wait+Screen@20s /Tema do prompt/
Sleep 1.2s
Down Sleep 400ms Up Sleep 700ms
Enter
# confirmações do gum: o rodapé "y Sim · n Não" fica na última linha
Sleep 1.5s
Wait@20s /n Não/
Sleep 1.2s
Enter
Sleep 1.5s
Wait@20s /n Não/
Sleep 1.2s
Enter
Sleep 1.5s
Wait@20s /n Não/
Sleep 2.5s
Enter
# fim: resumo e a pergunta para abrir o terminal com o lvl9
Sleep 5s
Wait@600s /n Não/
Sleep 1.5s
Screenshot docs/img/instalado.png
Sleep 1.5s
Enter
# o terminal novo: fastfetch, dica e o prompt
Wait@30s /❯/
Sleep 4s
