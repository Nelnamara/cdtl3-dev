// Lua 5.1 parse + global-write scan of the changed Lua files.
const fs = require('fs'), path = require('path');
const luaparse = require('luaparse');
const repo = process.argv[2];
const files = process.argv.slice(3);
let bad = 0;
for (const f of files) {
  const src = fs.readFileSync(path.join(repo, f), 'utf8');
  let ast;
  try {
    ast = luaparse.parse(src, { luaVersion: '5.1', scope: true, locations: true });
  } catch (e) { console.log(`PARSE FAIL ${f}: ${e.message}`); bad++; continue; }
  const writes = {};
  const visit = (n) => {
    if (!n || typeof n !== 'object') return;
    if (Array.isArray(n)) { n.forEach(visit); return; }
    if (n.type === 'AssignmentStatement') {
      for (const v of n.variables) if (v.type === 'Identifier' && !v.isLocal) (writes[v.name] = writes[v.name] || []).push(v.loc.start.line);
    }
    if (n.type === 'FunctionDeclaration' && n.identifier && n.identifier.type === 'Identifier' && !n.isLocal && !n.identifier.isLocal)
      (writes[n.identifier.name] = writes[n.identifier.name] || []).push(n.identifier.loc.start.line);
    for (const k in n) if (k !== 'loc' && k !== 'range') visit(n[k]);
  };
  visit(ast);
  const names = Object.keys(writes);
  const extra = names.filter(x => x !== 'CDTL3' && x !== 'CDTL3DB');
  console.log(`parse OK ${f}; global writes: ${names.map(x => x + '@' + writes[x].join(',')).join(' ') || 'none'}${extra.length ? '  <-- UNEXPECTED' : ''}`);
  if (extra.length) bad++;
}
process.exit(bad ? 1 : 0);
