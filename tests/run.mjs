// Executor de testes: roda os specs Luau com a simulação da API do Roblox.
//
// Uso:  node tests/run.mjs            (todos os specs)
//       node tests/run.mjs course     (só specs cujo nome contém "course")
//
// Requer o pacote npm @luau-rs/luau (Luau compilado para WebAssembly).
// Veja tests/README.md.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..');

async function loadLuau() {
  const candidates = [
    path.join(root, 'node_modules'),
    path.join(here, 'node_modules'),
    process.env.LUAU_NODE_MODULES,
  ].filter(Boolean);
  for (const dir of candidates) {
    try {
      const req = createRequire(path.join(dir, 'x.js'));
      const resolved = req.resolve('@luau-rs/luau');
      return await import(resolved);
    } catch (_) {}
  }
  return await import('@luau-rs/luau');
}

const { Lua } = await loadLuau();

// Mapeamento igual ao default.project.json
const project = JSON.parse(fs.readFileSync(path.join(root, 'default.project.json'), 'utf8'));
const mounts = [];
function walkTree(node, instPath) {
  for (const [key, value] of Object.entries(node)) {
    if (key.startsWith('$')) continue;
    const childPath = [...instPath, key];
    if (value.$path) mounts.push({ inst: childPath, dir: path.join(root, value.$path) });
    walkTree(value, childPath);
  }
}
walkTree(project.tree, []);

const files = [];
function scan(dir, instPath) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push({ inst: [...instPath, entry.name], className: 'Folder' });
      scan(full, [...instPath, entry.name]);
      continue;
    }
    let m;
    if ((m = entry.name.match(/^(.*)\.server\.luau$/))) files.push({ inst: [...instPath, m[1]], className: 'Script', file: full });
    else if ((m = entry.name.match(/^(.*)\.client\.luau$/))) files.push({ inst: [...instPath, m[1]], className: 'LocalScript', file: full });
    else if ((m = entry.name.match(/^(.*)\.luau$/))) files.push({ inst: [...instPath, m[1]], className: 'ModuleScript', file: full });
  }
}
for (const mnt of mounts) {
  files.push({ inst: mnt.inst, className: 'Folder' });
  scan(mnt.dir, mnt.inst);
}

const filter = process.argv[2] || '';
const specs = fs.readdirSync(here).filter((f) => f.endsWith('_spec.luau') && f.includes(filter)).sort();

let failures = 0;
for (const spec of specs) {
  const lua = await Lua.create({ sandbox: false });
  lua.globals.set('__loadFile', lua.createFunction((p) => lua.load(fs.readFileSync(p, 'utf8'), { name: '@' + path.relative(root, p) }), { args: [String] }));
  lua.globals.set('__print', lua.createFunction((s) => { console.log(s); }, { args: [String] }));
  lua.globals.set('__testRoot', root);
  lua.globals.set('__filesList', files.map((f) => [f.className, f.file || '', f.inst.join('/')].join('\t')).join('\n'));
  const bootstrap = path.join(here, 'bootstrap.luau');
  try {
    const result = lua.execute(fs.readFileSync(bootstrap, 'utf8'), { name: '@tests/bootstrap.luau' }, path.join(here, spec));
    const [passed, failed] = result;
    console.log(`\n${spec}: ${passed} ok, ${failed} falhas`);
    if (failed > 0) failures += failed;
  } catch (err) {
    failures += 1;
    console.log(`\n${spec}: ERRO FATAL\n${err.message}`);
  }
}

if (failures > 0) {
  console.log(`\n✗ ${failures} falha(s)`);
  process.exit(1);
}
console.log('\n✓ todos os testes passaram');
