// Barra propriedades que scripts de jogo não podem alterar (derrubam o servidor no Roblox real).
import fs from 'node:fs';
import path from 'node:path';

const rules = [
  [/\.Decoration\s*=(?!=)/, 'Terrain.Decoration não pode ser escrita por script de jogo'],
  [/\.Technology\s*=(?!=)/, 'Lighting.Technology não pode ser escrita por script de jogo'],
  [/\.Streaming(Enabled|TargetRadius|MinRadius)\s*=(?!=)/, 'propriedades de Streaming não podem ser escritas por script de jogo'],
  [/\.CollisionFidelity\s*=(?!=)/, 'CollisionFidelity não pode ser escrita por script de jogo'],
];
let bad = 0;
function scan(dir) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, e.name);
    if (e.isDirectory()) { scan(full); continue; }
    if (!e.name.endsWith('.luau')) continue;
    fs.readFileSync(full, 'utf8').split(/\r?\n/).forEach((line, i) => {
      const code = line.replace(/--.*$/, '');
      for (const [re, why] of rules) if (re.test(code)) { bad++; console.log(`${full}:${i + 1}: ${why}`); }
    });
  }
}
scan('src');
if (bad) process.exit(1);
console.log('✓ nenhuma propriedade proibida');