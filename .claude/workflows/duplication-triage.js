export const meta = {
  name: 'duplication-triage',
  description: 'Investigate confirmed duplication-audit findings and draft one GitHub sub-issue body per finding (site, divergence, tests, OCCT functions)',
  whenToUse: 'After a duplication-audit workflow run (e.g. issue #380). Pass args as {parentIssue: <number>, findings: [{file, line, summary, failure_scenario}, ...]}. Drafts only, does NOT create GitHub issues; the caller files the returned drafts (and links them as sub-issues) itself so each creation stays auditable.',
  phases: [{ title: 'Triage' }],
}

// Follow-up to duplication-audit.js: turns each CONFIRMED finding into a
// filing-ready GitHub issue draft. Per-finding investigation (which tests
// cover which side, which OCCT C++ API each bridge call wraps) needs real
// file reads grounded per location, so this stays one agent per finding
// rather than a batched prompt.

const DRAFT_SCHEMA = {
  type: 'object', required: ['title', 'duplicationSite', 'divergence', 'tests', 'occtFunctions'],
  properties: {
    title: { type: 'string', description: 'a standalone, specific issue title for this duplication (not the auditor summary verbatim)' },
    duplicationSite: { type: 'string', description: 'markdown listing every file:line location involved, with the specific symbol name at each' },
    divergence: { type: 'string', description: 'markdown: the concrete behavioral/doc difference already observed between the copies, or the maintenance-cost rationale if currently consistent' },
    tests: { type: 'string', description: 'markdown: test coverage found for each location (file + test/suite name), or an explicit "no coverage found" statement per location' },
    occtFunctions: { type: 'string', description: 'markdown: the specific OCCT C++ class/method each location\'s bridge call invokes (not just the C bridge function name)' },
  },
}

if (!args || !Array.isArray(args.findings) || args.findings.length === 0) {
  return { error: 'duplication-triage needs {parentIssue, findings: [...]}, findings is empty or missing.' }
}
const PARENT_ISSUE = args.parentIssue || null
const FINDINGS = args.findings

phase('Triage')
log('Triaging ' + FINDINGS.length + ' finding(s)' + (PARENT_ISSUE ? ' for sub-issues of #' + PARENT_ISSUE : ''))

const drafts = await parallel(FINDINGS.map((f, i) => async () => {
  const loc = f.file + (f.line != null ? ':' + f.line : '')
  const r = await agent(
    '## Duplication finding to triage\n\n' +
    'Location: ' + loc + '\n' +
    'Summary: ' + f.summary + '\n' +
    'Cost/divergence noted by the auditor: ' + f.failure_scenario + '\n\n' +
    'Your job: investigate this finding thoroughly enough to write a complete, actionable GitHub issue.\n\n' +
    '1. Read the primary file at the given location, and every OTHER file:line location this finding\'s\n' +
    '   summary/failure_scenario mentions (there is always at least one duplicate counterpart, parse its\n' +
    '   file:line references out of the text above).\n' +
    '2. Grep Tests/ (per-domain Swift Testing targets) for tests that reference the specific Swift symbols\n' +
    '   (method/type names) involved at EACH location. List what you find (file + suite/test name); if you\n' +
    '   find none for a given location, say so explicitly, do not guess or assume coverage exists.\n' +
    '3. For each location, find the underlying OCCT bridge function it calls: grep\n' +
    '   Sources/OCCTBridge/include/OCCTBridge.h for the C function declaration and Sources/OCCTBridge/src/*.mm\n' +
    '   for its implementation. Identify the actual OCCT C++ class(es)/method(s) invoked (e.g. GC_MakePlane,\n' +
    '   gce_MakePln, GeomLProp_SLProps), not just the C bridge function name.\n\n' +
    'Return:\n' +
    '- title: a concise, specific, standalone issue title for this duplication\n' +
    '- duplicationSite: markdown listing every file:line location involved, with the specific symbol name at each\n' +
    '- divergence: markdown describing what has actually drifted between the copies (a concrete behavioral or\n' +
    '  doc difference you verified by reading both sides), or, if currently consistent, the concrete\n' +
    '  maintenance-cost rationale for why it should still be unified\n' +
    '- tests: markdown listing test coverage found for each location, or an explicit "No existing test\n' +
    '  coverage found for <location>" statement per location with no coverage\n' +
    '- occtFunctions: markdown listing the specific OCCT C++ class/method each location\'s bridge call invokes\n\n' +
    'Structured output only.',
    { label: 'triage:' + loc.split('/').pop(), schema: DRAFT_SCHEMA }
  )
  if (!r) { log('triage[' + i + '] (' + loc + '): agent returned no result, skipping'); return null }
  log('triage[' + i + '] (' + loc + '): drafted "' + r.title + '"')

  const body =
    (PARENT_ISSUE
      ? 'Part of the duplication audit in #' + PARENT_ISSUE + ' (itself a sub-issue of #377). Per #377\'s ' +
        'ordering rule, triage or fix this before starting the next audit pass. Branch: ' +
        '`refactor/377-segmented-audit`, PRs from this issue target that branch, not `main`.\n\n'
      : '') +
    '## Duplication site\n' + r.duplicationSite + '\n\n' +
    '## Divergence\n' + r.divergence + '\n\n' +
    '## Associated tests\n' + r.tests + '\n\n' +
    '## Underlying OCCT functions\n' + r.occtFunctions + '\n\n' +
    '---\n<sub>Original audit finding: ' + f.summary + '</sub>\n'

  return { sourceIndex: i, file: f.file, line: f.line, title: r.title, body }
}))

const results = drafts.filter(Boolean)
log('Triage done: ' + results.length + '/' + FINDINGS.length + ' drafted')

return {
  parentIssue: PARENT_ISSUE,
  drafted: results.length,
  requested: FINDINGS.length,
  drafts: results,
}
