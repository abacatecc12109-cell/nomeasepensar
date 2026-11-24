# Obby das Cerejeiras (Roblox, Luau + Rojo)

Responda em português.

## Ao terminar cada mudança
1. `npm ci` (se preciso) e `npm test`: todos os testes têm que passar.
2. Faça commit e **push**. Sem push nada chega ao jogo.
3. Parta sempre da branch mais nova (`git fetch` antes). Um agente no PC pega o commit mais novo de qualquer branch, testa, monta com Rojo e abre no Roblox Studio; a publicação é feita lá, pelo Studio.

## Regras
- O código do jogo fica em `src/`. Não edite `build/*.rbxl`: o agente monta de novo.
- Scripts de jogo não podem escrever `Terrain.Decoration`, `Lighting.Technology`, propriedades de Streaming nem `CollisionFidelity` (o servidor quebra no Roblox real, embora os testes simulados passem). Ponha isso no `default.project.json`.
- Nunca coloque chaves, cookies ou senhas no repositório: ele é público.