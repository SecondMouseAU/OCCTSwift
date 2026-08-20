import {readFileSync} from 'fs'
const src = readFileSync('.claude/workflows/duplication-audit.js','utf8')
// Build the subject FROM the shipped source. An earlier version of this file extracted these
// three lines and then only printed them, while the logic under test was a hand-copy below, so
// gutting the real guard to `filter(p => false)` still reported 10/10 green. Nothing bound the
// test to the code it named. `new Function` over the extracted text is what binds it.
const mapLine = src.match(/const existsByPath = .*/)[0]
const filtLine = src.match(/const missingPaths = .*/)[0]
const guardLine = src.match(/if \(!verifyReport \|\| !Array\.isArray\(verifyReport\.results\)\) \{/)[0]
console.log('exercising:\n  ' + guardLine + '\n  ' + mapLine + '\n  ' + filtLine + '\n')
const run = new Function('ALL_FILES', 'verifyReport', `
  ${guardLine} return 'REJECTED (no verdict)' }
  ${mapLine}
  ${filtLine}
  return missingPaths.length ? 'REJECTED (' + missingPaths.join(', ') + ')' : 'ACCEPTED'
`)
const ok = (p) => ({path:p, exists:true})
const cases = [
  ['all present, should ACCEPT', ['a.swift','b.swift'], {results:[ok('a.swift'),ok('b.swift')]}, 'ACCEPTED'],
  ['one reported missing', ['a.swift','b.swift'], {results:[ok('a.swift'),{path:'b.swift',exists:false}]}, 'REJECTED'],
  ['one silently omitted from verdict', ['a.swift','b.swift'], {results:[ok('a.swift')]}, 'REJECTED'],
  ['verdict absent entirely', ['a.swift'], null, 'REJECTED'],
  ['verdict malformed', ['a.swift'], {results:'yes'}, 'REJECTED'],
  ['agent answers about a DIFFERENT path', ['a.swift'], {results:[ok('nearby.swift')]}, 'REJECTED'],
  ['exists is truthy-but-not-true', ['a.swift'], {results:[{path:'a.swift',exists:'yes'}]}, 'REJECTED'],
  ["#385's real fabricated scope",
    ['Sources/OCCTSwift/Topology.swift','Sources/OCCTSwift/XCAF.swift',
     'Sources/OCCTBridge/src/OCCTBridge_XDE.mm','Sources/OCCTSwift/Sketch.swift'],
    {results:[{path:'Sources/OCCTSwift/Topology.swift',exists:false},
              {path:'Sources/OCCTSwift/XCAF.swift',exists:false},
              {path:'Sources/OCCTBridge/src/OCCTBridge_XDE.mm',exists:false},
              ok('Sources/OCCTSwift/Sketch.swift')]}, 'REJECTED'],
  ["#385's corrected scope (bridge path fixed)",
    ['Sources/OCCTSwift/GDTInfo.swift','Sources/OCCTBridge/src/OCCTBridge_ProjLib_NLPlate.mm'],
    {results:[ok('Sources/OCCTSwift/GDTInfo.swift'),ok('Sources/OCCTBridge/src/OCCTBridge_ProjLib_NLPlate.mm')]}, 'ACCEPTED'],
  ['bare filename, the defect that reached main',
    ['OCCTBridge_ProjLib_NLPlate.mm'], {results:[{path:'OCCTBridge_ProjLib_NLPlate.mm',exists:false}]}, 'REJECTED'],
]
let pass=0
for (const [name, files, rep, want] of cases) {
  const got = run(files, rep)
  const good = got.startsWith(want)
  if (good) pass++
  console.log(`  ${good?'ok  ':'FAIL'} ${name}: ${got}`)
}
console.log(`\n${pass}/${cases.length} cases correct`)
process.exit(pass===cases.length?0:1)
