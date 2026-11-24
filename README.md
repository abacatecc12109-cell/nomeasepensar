# 🌸 Parkour Vertical — O Mundo das Cerejeiras

Obby de dificuldade média para Roblox. O jogador começa num prado gramado e sobe
uma montanha de fantasia por cinco regiões ligadas entre si, até o Mirante do Céu,
a **312 m de altura**.

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
| 5 | Jardim Celestial | 291 → 312 m | ponte de pedra, jardim com cerejeiras gigantes, lago, templo, flores luminosas, pedras sobre a cascata de 140 m, santuário e pagode no mirante final |

O percurso sobe em espiral em volta de um maciço central. Cada região é
fisicamente ligada à próxima, e do topo dá para ver o mapa inteiro lá embaixo.
São 16 checkpoints (pelo menos um por região).

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
- **Checkpoints:** santuário com cristal. No checkpoint atual o cristal fica
  rosa, gira e brilha; os já alcançados ficam rosas.
- **Queda:** cair mais de 18 m abaixo do checkpoint, ou cair na água abaixo do
  percurso, leva o jogador de volta ao checkpoint. Morrer também.
- **Progresso da sessão:** checkpoint, tempo, recorde e altura máxima ficam
  guardados no servidor. Quem sai e volta ao mesmo servidor continua de onde parou.

## Interface

- Cartão: região atual, altura real (posição Y do jogador) e checkpoint atual.
- Cronômetro com o recorde da sessão.
- Medidor vertical de subida com as cores das 5 regiões, posição atual e altura máxima.
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
      Stages/R1..R5      uma região por arquivo
      CourseBuilder      transforma dados em peças
      Pieces             visual + colisor de cada tipo de obstáculo
    World/             cenário
      TerrainBuilder     chão, platôs, maciço, rios, lagos, horizonte
      Nature             cerejeiras (modelos-base clonados), árvores gigantes, flores...
      Structures         casas, torre, moinho, templo, pagode, lanternas
      Water              cachoeiras e vitórias-régias
      Decorator          espalha decoração por tema
      Clearance          impede que a decoração invada o percurso
    Systems/           CheckpointService, ProgressService, LightingService, CourseInfo
  client/            (StarterPlayerScripts.Client)
    Main.client.luau
    Controllers/       ObstacleController, CheckpointVisuals, AmbientController, HUDController
tests/               testes automatizados (veja abaixo)
```

## Otimização (celular)

- O mundo é feito de **Terrain** (leve) e cerca de 7.800 peças, com StreamingEnabled.
- Decoração sem colisão, sem toque e sem consulta de física.
- Árvores são clonadas de modelos-base, com variação de escala, rotação e cor.
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

São 31 testes, que verificam:
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
- a interface, o visual dos checkpoints e a escala em telas de celular e PC.

> Os testes simulam a API, mas não a física nem a renderização do Roblox.
> Antes de publicar, jogue uma vez no Studio e no emulador de celular
> (*Test → Device*).
