export const meta = {
  name: 'bridge-duplication-triage',
  description: 'Investigate confirmed bridge duplication-audit findings (Pass 1b / #381) and draft one GitHub sub-issue body per finding (site, divergence, Swift call sites, tests, underlying OCCT functions)',
  whenToUse: 'After a bridge-duplication-audit workflow run (issue #381). Pass args as {parentIssue: <number>, findings: [{file, line, summary, failure_scenario}, ...]}, parentIssue defaults to 381 if omitted. Drafts only, does NOT create GitHub issues; the caller files the returned drafts (and links them as sub-issues) itself so each creation stays auditable. Drafted issue bodies target branch refactor/381-pass1b (a dedicated Pass 1b branch, separate from Pass 1a\'s refactor/377-segmented-audit while that one is under code review).',
  phases: [{ title: 'Triage' }],
}

// Sibling of duplication-triage.js, purpose-built for bridge-duplication-audit.js
// findings rather than a reuse of it. Differs in what "investigate this finding"
// means: duplication-triage.js's findings are Swift application code, so its
// interesting one-hop-DOWN question is "which OCCT C++ class does this call?".
// A bridge-header finding already IS that layer, so the interesting question
// runs one hop UP instead, "which Swift call sites in Sources/OCCTSwift reach
// this bridge function, and are they covered by any test?", plus, for an
// Angle-4 (Pass-1a-mirror-gap) finding, a direct cross-check against the Pass 1a
// PR diff the finding claims should have been mirrored.
//
// Branch note: drafted issues target refactor/381-pass1b, NOT Pass 1a's
// refactor/377-segmented-audit. #377's own convention is one shared audit branch
// for every child pass, but Pass 1a is still under code review as of this
// writing, a dedicated Pass 1b branch keeps its own child PRs from landing on
// top of 1a work that hasn't been reviewed yet. Where refactor/381-pass1b itself
// eventually merges (onto refactor/377-segmented-audit once 1a's review lands,
// or straight to main) is a later decision, not this script's concern.

const REPO = 'SecondMouseAU/OCCTSwift'
const PASS_1B_BRANCH = 'refactor/381-pass1b'
const PASS_1A_BRANCH = 'refactor/377-segmented-audit'
const PASS_1B_ISSUE = 381
const PASS_1A_ISSUE = 380

const DRAFT_SCHEMA = {
  type: 'object', required: ['title', 'duplicationSite', 'divergence', 'swiftCallSites', 'tests', 'occtFunctions'],
  properties: {
    title: { type: 'string', description: 'a standalone, specific issue title for this finding (not the auditor summary verbatim)' },
    duplicationSite: { type: 'string', description: 'markdown listing every file:line location involved in OCCTBridge.h/OCCTBridge_Internal.h/OCCTBridge_<Domain>.mm, with the specific declaration/symbol name at each' },
    divergence: { type: 'string', description: 'markdown: the concrete behavioral/index/split difference already observed, or the maintenance-cost rationale if currently consistent' },
    swiftCallSites: { type: 'string', description: 'markdown: every Sources/OCCTSwift/*.swift call site that invokes each implicated bridge function, found by grepping the C function name(s); explicitly say "no Swift call site found (orphaned)" per function with none' },
    tests: { type: 'string', description: 'markdown: test coverage found for each affected Swift call site (file + suite/test name, found by grepping the Swift symbol names in swiftCallSites), or an explicit "no coverage found" statement per site' },
    occtFunctions: { type: 'string', description: 'markdown: the specific OCCT C++ class/method each location\'s .mm implementation invokes (not just the C bridge function name)' },
    pass1aCrossCheck: { type: 'string', description: 'ONLY for an Angle-4 (Pass 1a mirror gap) finding: what the cited Pass 1a PR diff actually changed on the Swift side, confirmed by reading it, and exactly what bridge-side change would mirror it. Omit for non-Angle-4 findings.' },
  },
}

phase('Triage')
let PARENT_ISSUE = PASS_1B_ISSUE
let FINDINGS = null

if (args && typeof args === 'object' && Array.isArray(args.findings) && args.findings.length > 0) {
  FINDINGS = args.findings
  PARENT_ISSUE = args.parentIssue || PASS_1B_ISSUE
} else if (typeof args === 'string' && args.trim().length > 0) {
  // Large structured args objects have arrived here as an unparsed string in
  // this environment even when sent as valid JSON (observed directly: two
  // attempts, both landed as a raw string, args.findings undefined either
  // way) -- fall back to a plain file-path string instead, which passes
  // through untouched, and have an agent Read + structure its contents.
  const FINDINGS_FILE_SCHEMA = {
    type: 'object', required: ['findings'],
    properties: {
      parentIssue: { type: 'number' },
      findings: { type: 'array', items: {
        type: 'object', required: ['file', 'summary', 'failure_scenario'],
        properties: { file: { type: 'string' }, line: { type: 'number' }, summary: { type: 'string' }, failure_scenario: { type: 'string' } },
      }},
    },
  }
  const loaded = await agent(
    'Read the JSON file at ' + args.trim() + ' with your Read tool. It is either a bare JSON array of ' +
    'finding objects ({file, line, summary, failure_scenario}), or an object with a `findings` array and ' +
    'optionally a `parentIssue` number. Return its exact contents restructured to {parentIssue?, findings}. ' +
    'Do not alter, summarize, or truncate any finding\'s text.',
    { label: 'load-findings-file', schema: FINDINGS_FILE_SCHEMA }
  )
  if (loaded && Array.isArray(loaded.findings) && loaded.findings.length > 0) {
    FINDINGS = loaded.findings
    PARENT_ISSUE = loaded.parentIssue || PASS_1B_ISSUE
  }
}

if (!FINDINGS || FINDINGS.length === 0) {
  return { error: 'bridge-duplication-triage needs {parentIssue, findings: [...]} via args, or a JSON file path string as args, findings is empty or missing.' }
}
log('Triaging ' + FINDINGS.length + ' finding(s) for sub-issues of #' + PARENT_ISSUE)

const drafts = await parallel(FINDINGS.map((f, i) => async () => {
  const loc = f.file + (f.line != null ? ':' + f.line : '')
  const r = await agent(
    '## Bridge duplication finding to triage (Pass 1b, #' + PARENT_ISSUE + ')\n\n' +
    'Location: ' + loc + '\n' +
    'Summary: ' + f.summary + '\n' +
    'Cost/divergence noted by the auditor: ' + f.failure_scenario + '\n\n' +
    'Your job: investigate this finding thoroughly enough to write a complete, actionable GitHub issue\n' +
    'about the OCCT C++ bridge header pair (OCCTBridge.h / OCCTBridge_Internal.h), NOT Swift application\n' +
    'code, the finding IS in the bridge layer.\n\n' +
    '1. Read the primary file at the given location, and every OTHER file:line location this finding\'s\n' +
    '   summary/failure_scenario mentions (parse its file:line references out of the text above), this\n' +
    '   commonly includes the corresponding OCCTBridge_<Domain>.mm implementation file(s).\n' +
    '2. Grep Sources/OCCTSwift/*.swift for the specific C function name(s) involved at EACH location to\n' +
    '   find every Swift call site that invokes them. If a function has none, say so explicitly (an\n' +
    '   orphaned bridge declaration nothing calls is itself worth noting, not something to guess past).\n' +
    '3. For each Swift call site found in step 2, grep Tests/ (per-domain Swift Testing targets) for\n' +
    '   tests referencing that Swift symbol. List what you find (file + suite/test name); if none, say\n' +
    '   so explicitly per call site, do not guess or assume coverage exists.\n' +
    '4. For each location, identify the underlying OCCT bridge function\'s C++ implementation: read the\n' +
    '   matching OCCTBridge_<Domain>.mm body and name the actual OCCT C++ class(es)/method(s) invoked\n' +
    '   (e.g. GC_MakePlane, gce_MakePln, GeomLProp_SLProps), not just the C bridge function name.\n' +
    '5. If, and only if, the finding\'s summary references a Pass 1a issue/PR number (an "Angle 4"\n' +
    '   finding, i.e. a bridge-side gap a Pass 1a Swift-side fix should have mirrored): run\n' +
    '   `gh pr diff <pr> --repo ' + REPO + '` on that PR and confirm, from the actual diff, what the\n' +
    '   Swift side changed to. State exactly what bridge-side change would mirror it. If the finding does\n' +
    '   NOT reference a Pass 1a issue/PR, omit pass1aCrossCheck entirely, do not invent a cross-check.\n\n' +
    'Return:\n' +
    '- title: a concise, specific, standalone issue title for this finding\n' +
    '- duplicationSite: markdown listing every file:line location involved, with the specific\n' +
    '  declaration/symbol name at each\n' +
    '- divergence: markdown describing what has actually drifted/gone stale between the copies (a\n' +
    '  concrete difference you verified by reading both sides), or, if currently consistent, the\n' +
    '  concrete maintenance-cost rationale for why it should still be unified\n' +
    '- swiftCallSites: markdown listing every Swift call site per implicated function, or "orphaned"\n' +
    '- tests: markdown listing test coverage found per call site, or an explicit no-coverage statement\n' +
    '- occtFunctions: markdown listing the specific OCCT C++ class/method each location\'s .mm invokes\n' +
    '- pass1aCrossCheck: only if step 5 applied\n\n' +
    'Structured output only.',
    { label: 'triage:' + loc.split('/').pop(), schema: DRAFT_SCHEMA }
  )
  if (!r) { log('triage[' + i + '] (' + loc + '): agent returned no result, skipping'); return null }
  log('triage[' + i + '] (' + loc + '): drafted "' + r.title + '"')

  const body =
    'Part of the bridge duplication audit in #' + PARENT_ISSUE + ' (Pass 1b, itself a sub-issue of #377, ' +
    'parallel to Pass 1a / #' + PASS_1A_ISSUE + '). Per #377\'s ordering rule, triage or fix this before ' +
    'starting #395 (the OCCTBridge.h breakout, which depends on #381). Branch: `' + PASS_1B_BRANCH + '`, ' +
    'a dedicated branch for Pass 1b, separate from Pass 1a\'s `' + PASS_1A_BRANCH + '` while that branch is ' +
    'still under code review. PRs from this issue target `' + PASS_1B_BRANCH + '`, not `main`.\n\n' +
    '## Duplication site\n' + r.duplicationSite + '\n\n' +
    '## Divergence\n' + r.divergence + '\n\n' +
    '## Swift call sites\n' + r.swiftCallSites + '\n\n' +
    '## Associated tests\n' + r.tests + '\n\n' +
    '## Underlying OCCT functions\n' + r.occtFunctions + '\n\n' +
    (r.pass1aCrossCheck ? '## Pass 1a cross-check\n' + r.pass1aCrossCheck + '\n\n' : '') +
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
