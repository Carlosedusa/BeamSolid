# BeamSolidEngine (Swift) — Fase 1: motor de cálculo

Porte em Swift do motor de cálculo do **BeamSolid Pro** (o app web que já validamos). Esta é só a
**Fase 1**: o motor puro + os testes. Ainda não tem interface — isso vem na Fase 2.

## O que tem aqui

```
BeamSolidEngine/
├── Package.swift
├── Sources/BeamSolidEngine/
│   ├── Types.swift              ← tipos (LoadItem, SteelProfile, CalculationResults...)
│   ├── Profiles.swift           ← catálogo de 2 aços e 12 perfis (igual ao app web)
│   └── StructuralSolver.swift   ← o motor de cálculo em si (elementos finitos)
└── Tests/BeamSolidEngineTests/
    └── StructuralSolverTests.swift  ← casos de referência resolvidos à mão
```

`StructuralSolver.swift` é um porte **linha a linha** do `structuralSolver.ts` que já validamos no
app web (39/39 testes). A lógica é a mesma; só a sintaxe mudou de TypeScript para Swift.

**Importante:** eu escrevi este código sem conseguir compilá-lo (não tenho Mac/Xcode aqui). Revisei
à mão com cuidado, mas é você quem vai descobrir se há algum erro de digitação que escapou. Isso é
esperado — é para isso que serve o passo 3 abaixo.

## Passo 1 — instalar o Xcode

Se ainda não instalou:
1. Abra a **App Store** no seu Mac.
2. Procure por "Xcode" e instale (é grande, pode levar um tempo).
3. Abra o Xcode uma vez para ele terminar de configurar os componentes adicionais.

## Passo 2 — abrir o projeto

1. Descompacte o arquivo `BeamSolidEngine.zip` em alguma pasta do seu Mac.
2. Abra o Xcode.
3. **File → Open...** e escolha a pasta `BeamSolidEngine` (a que tem o `Package.swift` dentro).
4. O Xcode reconhece sozinho que é um Swift Package e monta o projeto. Pode levar uns segundos
   resolvendo o pacote na primeira vez.

## Passo 3 — rodar os testes

1. No menu do Xcode, vá em **Product → Test** (ou aperte **Cmd+U**).
2. Espere compilar. **Aqui é onde aparece qualquer erro de digitação meu** — se der erro de
   compilação, me mande a mensagem exata que o Xcode mostrar (ela aponta o arquivo e a linha) e eu
   corrijo.
3. Se compilar, o Xcode roda os testes e mostra ✅ ou ❌ ao lado de cada `func test...`. Clique na
   barra lateral esquerda (ícone de losango) para ver a lista de testes.

Os testes cobrem os mesmos casos do `verify.ts`: viga biapoiada (carga uniforme e pontual), balanço,
biengastada, contínua, momento aplicado, γf diferente de 1,4, entradas inválidas (devem sempre dar
`INVALID`, nunca `PASS`) e 300 configurações aleatórias conferindo equilíbrio de forças e
linearidade.

## Se algum teste falhar

- Falha de **compilação**: me mande a mensagem de erro — é provavelmente um erro meu de digitação
  no porte, fácil de corrigir.
- Falha de **asserção** (compila, mas o teste dá ❌): isso seria mais sério — indicaria que o porte
  introduziu uma diferença de comportamento em relação ao motor web. Me avise qual teste falhou e o
  que ele imprimiu; eu comparo com a versão TypeScript e corrijo.

## Próximos passos (Fase 2 e 3)

Com os testes passando no seu Xcode, me avise e eu sigo para:
- **Fase 2:** uma interface mínima em SwiftUI (escolher perfil/aço, lançar cargas, ver resultado).
- **Fase 3:** telas de projeto, memorial de cálculo, refinamento visual.
