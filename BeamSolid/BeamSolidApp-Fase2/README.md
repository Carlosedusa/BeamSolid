# BeamSolid — Fase 2: interface em SwiftUI

Esta fase precisa de um projeto de **App** de verdade no Xcode (com ícone, tela de abertura etc.),
que é diferente do Swift Package da Fase 1. Por isso tem alguns passos manuais — o Xcode faz a
parte difícil, você só clica em alguns botões.

## Passo 1 — criar o projeto de App

1. No Xcode: **File → New → Project...**
2. Escolha **iOS → App** e clique em Next.
3. Nome do produto: `BeamSolidApp` (ou o nome que preferir).
4. Interface: **SwiftUI**. Linguagem: **Swift**.
5. Salve numa pasta à sua escolha (pode ser ao lado da pasta `BeamSolidEngine`, fora do OneDrive,
   para evitar os problemas de sincronização que tivemos na Fase 1).

## Passo 2 — adicionar o motor (BeamSolidEngine) como dependência

1. Com o novo projeto aberto: **File → Add Package Dependencies...**
2. No canto inferior esquerdo da janela que abre, clique em **Add Local...**
3. Navegue até a pasta `BeamSolidEngine` (a mesma da Fase 1, com o `Package.swift` dentro) e
   selecione-a.
4. Confirme adicionando o pacote ao target do app.

## Passo 3 — colocar a tela

1. No Xcode, clique com o botão direito em `ContentView.swift` (o arquivo que o próprio Xcode já
   criou) → **Delete** → **Move to Trash**.
2. Arraste o `ContentView.swift` que está nesta pasta para dentro do projeto, na mesma posição
   (dentro da pasta do app, ao lado de `BeamSolidApp.swift`/`BeamSolidAppApp.swift`). Marque a
   opção "Copy items if needed" se ela aparecer.

Não precisa mexer em mais nenhum arquivo — o `App.swift` que o Xcode gerou sozinho já abre a
`ContentView` automaticamente.

## Passo 4 — rodar

1. No topo do Xcode, escolha um simulador de iPhone (ex.: "iPhone 16") no lugar de "My Mac".
2. Aperte **Cmd+R** (ou o botão ▶️).
3. O simulador abre e mostra a tela: tipo de apoio, vão, perfil, aço, lista de cargas e um botão
   **Calcular**.

## Atualização — diagramas

O `ContentView.swift` agora também desenha os diagramas de cortante, momento fletor e flecha,
logo abaixo dos resultados numéricos, usando o framework **Charts** da própria Apple (não precisa
adicionar nenhuma dependência nova — é só `import Charts`, parte do iOS). Os dados dos gráficos já
vêm prontos do motor (`shearCurve`, `momentCurve`, `deflectionCurve`); a tela só desenha.

A flecha é mostrada com o sinal invertido visualmente (a curva "afunda" na tela), para parecer com
uma viga fletida de verdade — o motor continua calculando com a mesma convenção de sempre
(positivo = para baixo); só a exibição no gráfico é que inverte.

## O que já dá para fazer

- Escolher o tipo de apoio (biapoiada, balanço, biengastada, contínua de 2 vãos).
- Escolher perfil (os 12 do catálogo) e aço (A36 ou A572 Gr 50).
- Adicionar/remover cargas (distribuída, pontual ou momento), com posição, valor, γf e direção.
- Calcular e ver: reações, momento, cortante, flecha, flecha admissível e as 3 utilizações (%),
  com uma cor indicando o status (verde = OK, laranja = atenção, vermelho = reprovado ou entrada
  inválida).

## O que NÃO tem ainda

- Memorial de cálculo, diagramas (cortante/momento/flecha desenhados), projetos salvos — isso é
  conteúdo da Fase 3, que fazemos depois que esta tela estiver rodando certinho no seu simulador.
- Se o Xcode acusar algum erro de compilação ao tentar rodar, me manda a mensagem exata (igual
  fizemos na Fase 1) — mesma lógica: eu escrevi isso sem poder compilar, então essa é a hora de
  pegar qualquer erro de digitação que tenha escapado da minha revisão.
