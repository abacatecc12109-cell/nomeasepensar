# 🌸 Parkour Vertical — O Mundo das Cerejeiras

Obby de dificuldade média para Roblox. O jogador começa num prado gramado, sobe
uma montanha de fantasia por cinco regiões ligadas entre si e, do Mirante do Céu,
continua por **ilhas de nuvem** até o Trono do Sol, a **798 m de altura**.
São **80 fases** (80 checkpoints) em 7 regiões.

## Como abrir no Roblox Studio

**Opção 1: arquivo pronto (mais fácil)**
1. Abra `build/MundoDasCerejeiras.rbxl` no Roblox Studio.
2. Clique em **Play** (F5). O mundo inteiro é gerado pelos scripts quando o jogo
   começa, então no modo de edição o mapa aparece vazio. Isso é esperado.
3. Para publicar: *File → Publish to Roblox*.

**Opção 2: Rojo (para editar o código)**
```bash
rojo serve          # e conecte pelo plugin do Rojo no Studio
rojo build -o build/MundoDasCerejeiras.rbxl   # gera o arquivo de novo
```

## O mundo

| # | Região | Altura | Destaques |
|---|--------|--------|-----------|
| 1 | Jardim das Cerejeiras | 0 → 44 m | prado, riacho com pedras, tocos e raízes, troncos sobre a ravina com rio, jangada no lago, primeira escalada de trepadeiras |
| 2 | Vila das Flores | 44 → 98 m | caixotes, saltos entre telhados-terraço, prancha entre casas, ponte que desaba, escada da torre do sino, ponte de corda, elevador do moinho |
| 3 | Penhascos Verdes | 98 → 188 m | trilhas estreitas na encosta, passagem pela cachoeira com rajadas, pontes suspensas, pedras que caem, tronco sobre o abismo, pilares crescentes, escaladas |
| 4 | Floresta das Nuvens | 188 → 291 m | raízes gigantes, espirais de cogumelos em volta de árvores enormes, casas na árvore, troncos balançando, elevador de cipó, tronco inclinado, névoa e vaga-lumes |
| 5 | Jardim Celestial | 291 → 312 m | ponte de pedra, jardim com cerejeiras gigantes, lago, templo, flores luminosas, pedras sobre a cascata de 140 m, santuário e pagode no Mirante do Céu |
| 6 | Ilhas de Nuvens | 312 → 562 m | 32 fases em nuvens brancas e fofas: saltos em zigue-zague, escadinhas, nuvens que levam o jogador, nuvens que se desfazem, elevadores de nuvem, pontes de arco-íris, pedras-estrela |
| 7 | Céu do Entardecer | 562 → 798 m | 32 fases em nuvens douradas e rosadas, plataformas menores e nuvens que somem mais rápido, até o Trono do Sol |

O percurso sobe em espiral em volta de um maciço central. Cada região é
fisicamente ligada à próxima. Do mirante, as ilhas de nuvem sobem numa espiral
larga sobre a montanha (cerca de 18 fases por volta), então dá para ver o mapa
inteiro lá embaixo. As regiões 1 a 5 têm 16 checkpoints; cada ilha de nuvem é
uma fase com checkpoint, totalizando **80 fases**.

Os desafios das nuvens seguem um ciclo de 9 tipos (saltos, nuvem-balsa,
escadinha, nuvens que se desfazem, arco-íris, elevador, nuvens que cruzam o
caminho, ponte que some e pedras-estrela), gerados em `Course/SkyPhases.luau`.

## Visual

- **Céu de pôr do sol:** degradê amarelo (horizonte) → laranja → rosa claro (alto),
  com um sol grande e brilhante e só algumas nuvens grandes flutuando ao longe.
  O céu é uma cúpula desenhada no cliente (`SkyController`); as cores ficam em
  `SkyController.Stops`.
- **Montanhas naturais:** os platôs ganharam bordas de grama arredondadas, encostas
  que alargam para baixo e cantos sem quina. Em volta há colinas suaves, serras e
  picos recortados no horizonte.
- **Árvores:** troncos que afinam e entortam, raízes, galhos em forquilha e copas de
  tufos de folhas achatados (nada de bolas). Pinheiros nos penhascos e na floresta.
- **Árvores gigantes (as "torres"):** tronco que afina, sulcos de casca, nós, musgo,
  cogumelos-orelha, raízes enormes, galhos no alto e copa de folhas.
- **Nuvens de verdade:** plataformas, ilhas, nuvens móveis e nuvens que se desfazem
  têm formato de nuvem (várias bolas fofas), com colisor invisível exato.
- **Vida:** bandos de pássaros voando em volta da montanha e borboletas nos jardins.

## Som

`SoundController` (cliente) cuida da ambientação sonora:
- fundo de cada região com dois loops (pássaros, vento nas folhas, riacho, insetos
  da floresta, sinos de vento, vento e brilho mágico nas nuvens), com troca suave;
- trilha calma em sequência, bem baixa;
- som 3D nas cachoeiras;
- efeitos de checkpoint, nova região, chegada, queda, tábua rangendo e nuvem se desfazendo;
- botão 🔊/🔇 no canto superior direito.

Todos os áudios são públicos do Roblox (Pro Sound Effects e APM Music), liberados
para qualquer experiência. Os números ficam em `Config.Sounds`.

## Mecânicas

- **Saltos justos:** cada salto é calculado com a física real do personagem
  (velocidade 16, pulo 7,2). Nenhum salto exige mais de 72% do alcance máximo;
  o mais difícil do mapa usa 52%.
- **Colisões exatas:** troncos redondos, cogumelos e pedras têm colisores
  invisíveis com as medidas do projeto do percurso. O que você vê é o que você pisa.
- **Plataformas móveis** (jangada, elevadores, pedras flutuantes): animadas no
  cliente pelo relógio do servidor. São suaves e carregam o jogador.
- **Ponte que desaba / pedras que caem:** tremem quando pisadas (aviso), caem e
  voltam após 3,5 s. Funcionam por jogador.
- **Troncos balançando e rajadas da cachoeira:** obstáculos com tempo. A
  cachoeira engrossa antes de cada rajada, avisando o jogador.
- **Checkpoints:** só uma estrela brilhante flutuando ao lado do caminho. No
  checkpoint atual a estrela fica rosa, gira e brilha; as já alcançadas ficam rosas.
- **Queda:** cair mais de 18 m abaixo do checkpoint, ou cair na água abaixo do
  percurso, leva o jogador de volta ao checkpoint. Morrer também.
- **Progresso da sessão:** checkpoint, tempo, recorde e altura máxima ficam
  guardados no servidor. Quem sai e volta ao mesmo servidor continua de onde parou.

## Interface

- Cartão: região atual, altura real (posição Y do jogador) e checkpoint atual.
- Cronômetro com o recorde da sessão.
- Medidor vertical de subida com as cores das 7 regiões, posição atual e altura máxima.
- Botão para ligar/desligar o som.
- Faixa de "nova região", avisos de checkpoint, anúncios de chegada.
- Tela de chegada com tempo, recorde e botões "Recomeçar" e "Ver a paisagem".
- Escala automática (celular e PC), áreas seguras do celular e tela deitada.

## Estrutura do código

```
src/
  shared/            (ReplicatedStorage.Shared)
    Config.luau        física, dificuldade, paleta, tags
    Fairness.luau      cálculo de salto justo
    Regions.luau       nome, cor e atmosfera de cada região
    Remotes.luau       eventos cliente/servidor
  server/            (ServerScriptService.Server)
    Main.server.luau   ordem de inicialização
    Course/            percurso
      CourseLayout       "tartaruga" que descreve o percurso como dados
      Stages/R1..R7      uma região por arquivo
      SkyPhases          gerador das fases nas nuvens (regiões 6 e 7)
      CourseBuilder      transforma dados em peças
      Pieces             visual + colisor de cada tipo de obstáculo
    World/             cenário
      TerrainBuilder     chão, platôs, maciço, rios, lagos, horizonte
      Nature             cerejeiras, folhosas e pinheiros (modelos-base clonados), árvores gigantes, flores...
      Clouds             nuvens fofas (plataformas, ilhas e nuvens do céu)
      Structures         casas, torre, moinho, templo, pagode, lanternas
      Water              cachoeiras e vitórias-régias
      Decorator          espalha decoração por tema
      Clearance          impede que a decoração invada o percurso
    Systems/           CheckpointService, ProgressService, LightingService, CourseInfo
  client/            (StarterPlayerScripts.Client)
    Main.client.luau
    Controllers/       ObstacleController, CheckpointVisuals, AmbientController, HUDController,
                       SkyController (céu e sol), SoundController (sons), LifeController (pássaros)
tests/               testes automatizados (veja abaixo)
```

## Otimização (celular)

- O mundo é feito de **Terrain** (leve) e cerca de 14.000 peças, com StreamingEnabled.
- Decoração sem colisão, sem toque e sem consulta de física.
- Árvores são clonadas de modelos-base, com variação de escala, rotação e cor.
  As árvores distantes usam versões mais leves (menos peças).
- Só **2 emissores de partículas** de ambiente, que seguem a câmera. Ficam com
  menos partículas no celular e em qualidade baixa.
- No máximo 40 luzes dinâmicas.
- Obstáculos só são animados perto do jogador, num único laço por quadro.
- O servidor verifica as quedas 4 vezes por segundo, num único laço.

## Testes

Os testes rodam fora do Roblox, com uma simulação da API. Eles constroem o mundo
inteiro, simulam um jogador e simulam o cliente quadro a quadro.

```bash
npm install @luau-rs/luau
node tests/run.mjs
```

São 34 testes, que verificam:
- justiça de todos os saltos;
- larguras mínimas;
- que nada enterra ou atravessa o percurso;
- espaço para a cabeça;
- checkpoints em todas as regiões;
- a regra de queda;
- construção do mundo sem erros nem avisos;
- orçamento de peças;
- nascimento, checkpoints, queda, morte, chegada, recorde, reinício e sessão;
- plataformas móveis, tábuas que caem e voltam, troncos que empurram;
- a interface, o visual dos checkpoints e a escala em telas de celular e PC;
- o céu em degradê, o sol e as poucas nuvens;
- a ambientação sonora (troca por região, cachoeiras, botão de som);
- pássaros e borboletas.

> Os testes simulam a API, mas não a física nem a renderização do Roblox.
> Antes de publicar, jogue uma vez no Studio e no emulador de celular
> (*Test → Device*).
