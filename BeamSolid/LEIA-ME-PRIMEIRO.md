# BeamSolid — atualização: diagramas (Fase 3, parte 1)

Você já tem o motor (BeamSolidEngine) e o app (BeamSolidApp-Fase2) funcionando. A única mudança
desta entrega é no arquivo `ContentView.swift`, que agora também desenha os diagramas de cortante,
momento e flecha.

## Como atualizar (mais rápido: copiar e colar)

Pelo que já vimos, arrastar arquivo por cima às vezes não substitui direito. Então, o jeito mais
seguro:

1. No Xcode, abra o `ContentView.swift` do SEU projeto (o que já está rodando).
2. Clique no código, **Cmd+A** (selecionar tudo), **Delete**.
3. Abra o arquivo `BeamSolidApp-Fase2/ContentView.swift` desta pasta num editor de texto, copie
   tudo, e cole no lugar, no Xcode.
4. **Cmd+S** para salvar.
5. **Cmd+R** para rodar.

Não precisa adicionar nenhuma dependência nova — os diagramas usam o framework **Charts**, que já
vem com o iOS, só precisa do `import Charts` (já está no arquivo).

## O que muda na tela

Depois de calcular, aparece uma nova seção **Diagramas**, com três gráficos: cortante, momento
fletor e flecha — cada um mostrando o valor de pico e em que posição x ele ocorre.

Se der algum erro ao compilar, me mande a mensagem exata (arquivo, linha, texto do erro), do jeito
que já vem funcionando bem até aqui.
