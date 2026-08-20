export const meta = {
  name: 'duplication-audit',
  description: 'Static duplication audit of an existing file scope (reimplemented helpers, copy-pasted math, drifted docs, parallel primitives)',
  whenToUse: 'For a #377-style segmented duplication-audit sub-issue (e.g. #380-#392): pass the issue number as args, or {files:[...]} directly for an ad hoc scope. This is NOT a diff/PR review — it reads existing, already-committed files rather than a git diff, and its finder angles are duplication-specific rather than correctness-bug angles. Use the plain "code-review" workflow instead for reviewing an actual diff/PR.',
  phases: [
    { title: 'Scope' },
    { title: 'Find' },
    { title: 'Sweep' },
    { title: 'Verify' },
    { title: 'Synthesize' },
  ],
}

// Generalized from the issue #380 (Pass 1a of #377) duplication audit. #377
// segments a repo-wide duplication sweep into per-layer sub-issues, each
// listing a fixed "## Files" scope in its body (path + LOC per line) — this
// script fetches that scope from the issue, bin-packs it into finder-sized
// groups, then mirrors the stock code-review workflow's Find -> group-verify
// -> Sweep -> Synthesize shape with duplication-specific angles instead of
// correctness-bug angles, since there's no diff for a static audit like this.

const REPO = 'SecondMouseAU/OCCTSwift'
const GROUP_LOC_THRESHOLD = 2000
const GROUP_FINDER_CAP = 10
const CROSS_CAP = 10
const SWEEP_CAP = 10
const MAX_FINDINGS = 25

const ANGLES_TEXT =
  '### Angle 1 — Reimplemented helpers\n' +
  'Find functions/methods that duplicate logic already implemented elsewhere in scope: the same\n' +
  'algorithm/computation expressed twice under different names, a private helper that reimplements\n' +
  'a public utility, or an inline computation that duplicates an existing static/instance method.\n\n' +
  '### Angle 2 — Copy-pasted math\n' +
  'Find near-duplicate mathematical formulas/algorithms that appear more than once with only\n' +
  'superficial variation (renamed variables, minor rearrangement): distance/length calculations,\n' +
  'dot/cross products, angle normalization, tolerance/epsilon comparisons, parametric interpolation,\n' +
  'coordinate conversions. Flag each duplicate pair/group and note anywhere they diverge even\n' +
  'slightly — a correctness bug can hide inside an otherwise-cosmetic duplication.\n\n' +
  '### Angle 3 — Drifted doc comments\n' +
  'Find /// doc comments that no longer accurately describe the implementation below them (stale\n' +
  'parameter descriptions, wrong return-value claims, outdated behavioral guarantees), or two\n' +
  'similar/parallel APIs whose doc comments make inconsistent or contradictory claims about\n' +
  'equivalent behavior.\n\n' +
  '### Angle 4 — Parallel primitives that should be one\n' +
  'Find types, structs, or families of methods that overlap in responsibility and represent the\n' +
  'same underlying concept through two different code paths (e.g. two ways to express the same\n' +
  'kind of value, or two overlapping validation/conversion helpers). Name the concrete cost: the\n' +
  'maintenance burden of keeping both in sync, or a place where they have already drifted apart.\n'

const ISSUE_SCOPE_SCHEMA = {
  type: 'object', required: ['files'],
  properties: {
    title: { type: 'string' },
    parentIssue: { type: 'number' },
    scopeNotes: { type: 'string', description: 'the issue\'s own "## Scope" text, verbatim, if present' },
    files: { type: 'array', items: {
      type: 'object', required: ['path'],
      properties: { path: { type: 'string' }, loc: { type: 'number' } },
    }},
    notes: { type: 'string', description: 'any listed file that turned out not to exist, or other discrepancies' },
  },
}
const SCOPE_VERIFY_SCHEMA = {
  type: 'object', required: ['results'],
  properties: {
    results: { type: 'array', description: 'one entry per path handed to you, in the same order', items: {
      type: 'object', required: ['path', 'exists'],
      properties: {
        path: { type: 'string', description: 'the path exactly as given, not corrected or normalised' },
        exists: { type: 'boolean', description: 'true only if `test -f` on that exact path succeeded' },
      },
    }},
  },
}
const CANDIDATES_SCHEMA = {
  type: 'object', required: ['candidates'],
  properties: {
    candidates: { type: 'array', items: {
      type: 'object', required: ['file', 'summary', 'failure_scenario'],
      properties: {
        file: { type: 'string', description: 'repo-relative path of the primary/worse-drifted location to fix' },
        line: { type: 'number' },
        summary: { type: 'string', description: 'one line naming both the primary location and its duplicate counterpart (file:line)' },
        failure_scenario: { type: 'string', description: 'the concrete maintenance cost: what is duplicated, where it has drifted, or why it should be unified' },
      },
    }},
  },
}
const GROUP_VERDICT_SCHEMA = {
  type: 'object', required: ['verdicts'],
  properties: {
    verdicts: { type: 'array', items: {
      type: 'object', required: ['index', 'verdict', 'evidence'],
      properties: {
        index: { type: 'number', description: 'the [i] label of the candidate this verdict is for' },
        verdict: { enum: ['CONFIRMED', 'PLAUSIBLE', 'REFUTED'] },
        evidence: { type: 'string' },
      },
    }},
  },
}
const REPORT_SCHEMA = {
  type: 'object', required: ['summary', 'decisions'],
  properties: {
    summary: { type: 'string' },
    decisions: { type: 'array', items: {
      type: 'object', required: ['index'],
      properties: {
        index: { type: 'number' },
        merge: { type: 'array', items: { type: 'number' } },
      },
    }},
  },
}

// ─── Phase 0: Scope ───
phase('Scope')
let ISSUE = null, DIRECT_FILES = null
if (typeof args === 'number') ISSUE = args
else if (typeof args === 'string' && /^\d+$/.test(args.trim())) ISSUE = parseInt(args.trim(), 10)
else if (args && typeof args === 'object') {
  if (args.issue) ISSUE = Number(args.issue)
  if (Array.isArray(args.files)) DIRECT_FILES = args.files.map(f => (typeof f === 'string' ? { path: f } : f))
}
if (!ISSUE && !DIRECT_FILES) {
  return { error: 'duplication-audit needs an issue number (e.g. Workflow({name:"duplication-audit", args: 380})) or {files:[...]}.' }
}

let files, issueTitle = null, parentIssue = null, scopeNotes = ''
if (DIRECT_FILES) {
  files = DIRECT_FILES
} else {
  const scoped = await agent(
    'Run `gh issue view ' + ISSUE + ' --repo ' + REPO + '` and read its body.\n\n' +
    'Extract:\n' +
    '1. title\n' +
    '2. parentIssue — the parent issue number if the issue has one (from the "parent:" field or a\n' +
    '   "Part of ... #<N>" reference in the body), otherwise omit it.\n' +
    '3. scopeNotes — the issue\'s own "## Scope" section text, verbatim, if present.\n' +
    '4. files — the "## Files" section: a markdown list of backtick-wrapped repo-relative paths,\n' +
    '   each followed by a LOC count in parentheses, e.g. "- `Sources/Foo.swift` (123)". Return each\n' +
    '   file\'s path and loc exactly as listed.\n\n' +
    'Then verify every listed file actually exists in the repo (e.g. `test -f <path>`) from the ' +
    'current working directory. Drop any that do not exist and note the discrepancy in `notes`.\n\n' +
    'Structured output only.',
    { label: 'scope:issue' + ISSUE, schema: ISSUE_SCOPE_SCHEMA }
  )
  if (!scoped || !scoped.files || scoped.files.length === 0) {
    return { error: 'Could not resolve a file scope from issue #' + ISSUE + ' (empty or missing "## Files" section).' }
  }
  files = scoped.files
  issueTitle = scoped.title || null
  parentIssue = scoped.parentIssue || null
  scopeNotes = scoped.scopeNotes || ''
  if (scoped.notes) log('Scope notes: ' + scoped.notes)
}

const ALL_FILES = files.map(f => f.path)
const totalLoc = files.reduce((s, f) => s + (f.loc || 0), 0)
log('Scope: ' + ALL_FILES.length + ' files' + (totalLoc > 0 ? ', ' + totalLoc + ' LOC' : '') + (issueTitle ? ' — ' + issueTitle : ''))

// ─── Scope guard ───
// Every resolved path must exist before any finder runs. This cannot be a plain
// existsSync: workflow scripts have no filesystem access, so it is an independent
// agent, and deliberately not the one that produced the list. #385 shipped an audit
// whose recorded scope named four files that do not exist in the repo; the scope
// resolver is *told* to drop those, which is a soft instruction to a model, so a
// fabricated scope ran to completion and its closing summary read as coverage.
// A path is treated as missing unless it is affirmatively reported as existing,
// so an incomplete verdict fails the same way a false one does.
const verifyReport = await agent(
  'Verify these repo-relative paths exist. For each one, run `test -f "<path>"` from the repo root ' +
  'and report the result.\n\n' +
  'Report exactly what the shell returns. Do not correct spellings, do not substitute a similar or ' +
  'nearby path, do not infer that a file "should" be there, and do not omit any path from your ' +
  'answer. Return one entry per path below, in the same order.\n\n' +
  ALL_FILES.map(f => '  - ' + f).join('\n') + '\n\nStructured output only.',
  { label: 'scope:verify', schema: SCOPE_VERIFY_SCHEMA }
)
if (!verifyReport || !Array.isArray(verifyReport.results)) {
  return { error: 'Scope verification did not return a verdict; refusing to audit an unverified file scope.' }
}
const existsByPath = new Map(verifyReport.results.map(r => [r.path, r.exists === true]))
const missingPaths = ALL_FILES.filter(p => existsByPath.get(p) !== true)
if (missingPaths.length > 0) {
  return {
    error: 'Scope verification failed: ' + missingPaths.length + ' of ' + ALL_FILES.length +
      ' path(s) do not exist in the repo (or were not verified): ' + missingPaths.join(', ') +
      '. Fix the source of the scope before re-running. If it came from an issue, its "## Files" ' +
      'section needs one backtick-wrapped repo-relative path per line; a bare filename resolves ' +
      'nowhere from the repo root.',
  }
}
log('Scope verified: ' + ALL_FILES.length + ' path(s) exist')

// ─── Group files into finder-sized clusters. A "Name+Suffix.swift" file
// (this repo's extension-file naming convention) stays paired with its
// "Name.swift" base file; otherwise each file is its own cluster. Clusters
// are then greedily bin-packed in listed order up to GROUP_LOC_THRESHOLD —
// a file/cluster already at or over the threshold becomes its own
// single-cluster group rather than being split.
const baseName = p => {
  const stem = p.split('/').pop().replace(/\.swift$/, '')
  return stem.split('+')[0]
}
const clusterMap = new Map()
const clusterOrder = []
for (const f of files) {
  const key = baseName(f.path)
  if (!clusterMap.has(key)) { clusterMap.set(key, []); clusterOrder.push(key) }
  clusterMap.get(key).push(f)
}
const clusters = clusterOrder.map(k => clusterMap.get(k))

const FILE_GROUPS = []
let current = []
let currentLoc = 0
for (const cluster of clusters) {
  const clusterLoc = cluster.reduce((s, f) => s + (f.loc || 0), 0)
  if (current.length > 0 && currentLoc + clusterLoc > GROUP_LOC_THRESHOLD) {
    FILE_GROUPS.push(current)
    current = []
    currentLoc = 0
  }
  current = current.concat(cluster)
  currentLoc += clusterLoc
  if (currentLoc >= GROUP_LOC_THRESHOLD) {
    FILE_GROUPS.push(current)
    current = []
    currentLoc = 0
  }
}
if (current.length > 0) FILE_GROUPS.push(current)
const groupLabel = g => g[0].path.split('/').pop().replace(/\.swift$/, '')
log('Grouped into ' + FILE_GROUPS.length + ' finder group(s): ' + FILE_GROUPS.map(g => groupLabel(g) + '(' + g.length + ')').join(', '))

const SCOPE_BLOCK =
  '## Audit scope' + (ISSUE ? ' — issue #' + ISSUE + (parentIssue ? ' (sub-issue of #' + parentIssue + ')' : '') : '') +
  (issueTitle ? ': ' + issueTitle : '') + '\n' +
  'This is a STATIC duplication audit of existing, already-committed code — there is no diff or\n' +
  'PR to review. Read the file contents directly.\n' +
  (scopeNotes ? '\n' + scopeNotes + '\n' : '') +
  '\nFull scope (' + ALL_FILES.length + ' files' + (totalLoc > 0 ? ', ' + totalLoc + ' LOC' : '') + '):\n' +
  ALL_FILES.map(f => '  - ' + f).join('\n') + '\n'

const canonFile = raw => {
  if (!raw) return ''
  const p = raw.replace(/\\/g, '/')
  let best = ''
  for (const sf of ALL_FILES) {
    if ((p === sf || p.endsWith('/' + sf)) && sf.length > best.length) best = sf
  }
  return best || p
}
const ingest = (cs, cap) => cs.slice(0, cap).map(c => ({ ...c, file: canonFile(c.file) }))
const loc = c => c.file + (c.line != null ? ':' + c.line : '')
const inBounds = (i, n) => Number.isInteger(i) && i >= 0 && i < n

// ─── Find: one finder per file group (in-group duplication, may Grep the
// rest of the repo to check for cross-group echoes) + 2 cross-cutting
// finders (duplication that spans group boundaries, which a single-group
// reviewer can't see on its own).
phase('Find')
const groupFinders = FILE_GROUPS.map(g => () =>
  agent(
    '## Duplication-audit finder — file group: ' + groupLabel(g) + '\n\n' + SCOPE_BLOCK +
    '\nYour assigned files for this pass:\n' + g.map(f => '  - ' + f.path).join('\n') + '\n\n' +
    'Read every assigned file in full. Review through EACH of the following angles. You may Grep\n' +
    'the rest of the repo (not just the files above) to check whether something in your assigned\n' +
    'files duplicates code elsewhere — but only report a finding if its PRIMARY (worse-drifted, or\n' +
    'newer/messier) location is inside your assigned files.\n\n' + ANGLES_TEXT + '\n' +
    'Surface up to ' + GROUP_FINDER_CAP + ' candidates. Each needs a primary file+line, a one-line summary naming\n' +
    'both the primary location and its duplicate counterpart (file:line), and a failure_scenario stating the\n' +
    'concrete maintenance cost. Pass every candidate through even if only half-confident — an independent\n' +
    'verifier judges them next. If nothing qualifies, return an empty list.\n\nStructured output only.',
    { label: 'find:' + groupLabel(g), phase: 'Find', schema: CANDIDATES_SCHEMA }
  ).then(r => {
    if (!r) return []
    log('find:' + groupLabel(g) + ': ' + r.candidates.length + ' candidates')
    return ingest(r.candidates, GROUP_FINDER_CAP)
  })
)

const CROSS_CUTTING = [
  {
    label: 'cross-parallel-types',
    focus:
      'Focus specifically on Angle 4 (parallel primitives that should be one) ACROSS the whole file\n' +
      'scope: look for any pair or family of types/files that overlap in responsibility and represent\n' +
      'the same underlying concept through two different code paths. For each pair, check whether the\n' +
      'overlap is a genuine, documented design split or accidental duplication that has already\n' +
      'drifted (inconsistent docs, a fix applied to one side but not the other, differing edge-case\n' +
      'handling for what should be the same operation).\n',
  },
  {
    label: 'cross-math-formulas',
    focus:
      'Focus specifically on Angle 2 (copy-pasted math) ACROSS the whole file scope: Grep for\n' +
      'repeated formula shapes — distance/length, dot/cross product, angle normalization\n' +
      '(degrees<->radians, periodic wraparound), tolerance/epsilon comparisons, linear/parametric\n' +
      'interpolation — that recur in more than one file with only superficial variation. Report every\n' +
      'recurring formula family found, even across files that are not in the same file group, and\n' +
      'flag any place the duplicated copies use a DIFFERENT tolerance/epsilon constant or a subtly\n' +
      'different formula for what should be the same computation.\n',
  },
]
const crossFinders = CROSS_CUTTING.map(c => () =>
  agent(
    '## Duplication-audit finder — cross-cutting: ' + c.label + '\n\n' + SCOPE_BLOCK + '\n' +
    'Read all files listed above (Grep first to locate candidate patterns, then Read the specific\n' +
    'functions/sections you find, in full, before reporting).\n\n' + c.focus + '\n' +
    'Surface up to ' + CROSS_CAP + ' candidates. Each needs a primary file+line, a one-line summary naming\n' +
    'both locations involved (file:line for each), and a failure_scenario stating the concrete\n' +
    'maintenance cost or observed drift. If nothing qualifies, return an empty list.\n\nStructured output only.',
    { label: 'find:' + c.label, phase: 'Find', schema: CANDIDATES_SCHEMA }
  ).then(r => {
    if (!r) return []
    log('find:' + c.label + ': ' + r.candidates.length + ' candidates')
    return ingest(r.candidates, CROSS_CAP)
  })
)

const findOuts = await parallel([...groupFinders, ...crossFinders])
let allCandidates = findOuts.filter(Boolean).flat()
let candidatesSeen = allCandidates.length
log('Find done: ' + candidatesSeen + ' total candidates')

// ─── Sweep: one fresh finder hunting only for cross-boundary gaps the
// group/cross-cutting finders above missed.
phase('Sweep')
const knownBlock = allCandidates.length > 0
  ? allCandidates.map(c => '- ' + loc(c) + ' — ' + c.summary).join('\n')
  : '(none)'
const sweep = await agent(
  '## Duplication-audit sweep — gaps only\n\n' + SCOPE_BLOCK + '\n' +
  '## Already-found candidates (do NOT re-derive or re-report these)\n' + knownBlock + '\n\n' +
  'Re-scan the full file scope (Grep across all of them together) looking ONLY for duplication not\n' +
  'already listed above. Focus on what a per-group/per-lens split tends to miss: duplication between\n' +
  'files in DIFFERENT groups that neither group finder nor either cross-cutting finder happened to\n' +
  'compare directly, and doc-comment drift between two files that are rarely read side-by-side.\n\n' +
  ANGLES_TEXT + '\n' +
  'Surface up to ' + SWEEP_CAP + ' additional candidates. If nothing new, return an empty list — do not pad.\n\nStructured output only.',
  { label: 'sweep', phase: 'Sweep', schema: CANDIDATES_SCHEMA }
)
if (sweep && sweep.candidates.length > 0) {
  const sliced = ingest(sweep.candidates, SWEEP_CAP)
  candidatesSeen += sliced.length
  log('sweep: ' + sliced.length + ' candidates')
  allCandidates = allCandidates.concat(sliced)
}

// ─── Verify: one verifier agent per distinct (file, line) location, judging
// every candidate reported at that location independently.
phase('Verify')
const VERDICT_LADDER =
  '- **CONFIRMED** — read both locations and confirm genuine, substantive duplication (not just\n' +
  '  superficial similarity); name the concrete maintenance cost or an actual point of drift.\n' +
  '- **PLAUSIBLE** — the duplication is real but its cost is uncertain (e.g. unclear which side is\n' +
  '  "correct", or the drift is cosmetic rather than behavioral). State what would confirm it.\n' +
  '- **REFUTED** — not actually duplicated (different algorithm/purpose despite surface similarity),\n' +
  '  or the parallel structure is a deliberate, already-documented design split. Quote the code that\n' +
  '  proves it.'

const byLoc = Object.create(null)
for (const c of allCandidates) (byLoc[loc(c)] ||= []).push(c)
const groups = Object.values(byLoc)
const verifierAgents = groups.length
const verifiedOut = await parallel(groups.map(g => async () => {
  const short = g[0].file.split('/').pop()
  const r = await agent(
    '## Duplication-audit verifier\n\n' + SCOPE_BLOCK + '\n' +
    '## Candidate findings at ' + loc(g[0]) + '\n' +
    g.map((c, i) => '[' + i + '] Summary: ' + c.summary + '\n    Cost claimed: ' + c.failure_scenario).join('\n') + '\n\n' +
    'Read the primary file and every duplicate-counterpart file/location named in each candidate\'s\n' +
    'summary. Return one verdict per candidate, judged independently — candidates at the same\n' +
    'location may describe distinct duplications, the same one, or a mix. Reference each by its [i] index.\n\n' +
    VERDICT_LADDER + '\n\nStructured output only. Evidence must quote or cite the relevant line(s) from BOTH locations.',
    { label: 'verify:' + short + '(' + g.length + ')', phase: 'Verify', schema: GROUP_VERDICT_SCHEMA }
  )
  if (!r) return []
  const byIdx = {}
  for (const v of r.verdicts) if (inBounds(v.index, g.length)) byIdx[v.index] = v
  return g.flatMap((c, i) => byIdx[i] ? [{ ...c, verdict: byIdx[i].verdict, evidence: byIdx[i].evidence }] : [])
}))
const verified = verifiedOut.filter(Boolean).flat()
const surviving = verified.filter(c => c.verdict !== 'REFUTED')
const refuted = verified.filter(c => c.verdict === 'REFUTED')
log('Verify done: ' + verified.length + ' verified -> ' + surviving.length + ' kept, ' + refuted.length + ' refuted')

const stats = {
  issue: ISSUE || undefined,
  fileGroups: FILE_GROUPS.length,
  crossCuttingFinders: CROSS_CUTTING.length,
  finders: FILE_GROUPS.length + CROSS_CUTTING.length + 1,
  candidates: candidatesSeen,
  verifierAgents,
  verified: verified.length,
  refuted: refuted.length,
}

if (surviving.length === 0) {
  return {
    level: 'xhigh',
    target: (ISSUE ? 'issue #' + ISSUE + (parentIssue ? ' (sub-issue of #' + parentIssue + ')' : '') : 'ad hoc scope') + (issueTitle ? ': ' + issueTitle : ''),
    summary: 'No duplication findings survived verification.',
    findings: [],
    stats,
  }
}

// ─── Synthesize: rank, merge semantic dupes (same pair found by more than
// one finder), cap the report.
phase('Synthesize')
const rank = c => (c.verdict === 'PLAUSIBLE' ? 1 : 0)
const ranked = surviving.slice().sort((a, b) => rank(a) - rank(b))
const block = ranked.map((c, i) =>
  '### [' + i + '] ' + loc(c) + ' (' + c.verdict + ')\n' +
  c.summary + '\nCost: ' + c.failure_scenario + '\nVerifier evidence: ' + c.evidence + '\n'
).join('\n')

const report = await agent(
  '## Synthesis: final duplication-audit report' + (ISSUE ? ' (issue #' + ISSUE + ')' : '') + '\n\n' +
  ranked.length + ' findings survived independent verification. They are numbered [0]-[' + (ranked.length - 1) + '] below.\n\n' + block + '\n' +
  '## Instructions\n' +
  'Return decisions about findings BY INDEX — never re-emit finding text.\n' +
  '1. For each distinct duplication, emit one decision with its index. When several findings describe\n' +
  '   the same duplicate pair/group (same root cause), keep one entry and list the others in its merge array.\n' +
  '2. Order decisions most-costly first: prefer duplications with CONFIRMED behavioral drift (the two\n' +
  '   copies already disagree) over duplications that are merely redundant but currently consistent.\n' +
  '3. Keep at most ' + MAX_FINDINGS + ' decisions; omit the least severe beyond the cap.\n' +
  '4. Write a 2-3 sentence summary of the audit.\n\nStructured output only.',
  { label: 'synthesize', schema: REPORT_SCHEMA }
)

const decisions = report && Array.isArray(report.decisions) ? report.decisions : []
const seen = new Set()
const claim = i => (inBounds(i, ranked.length) && !seen.has(i) ? (seen.add(i), true) : false)
const findings = []
for (const d of decisions) {
  if (findings.length >= MAX_FINDINGS) break
  if (!claim(d.index)) continue
  const c = ranked[d.index]
  const merged = (Array.isArray(d.merge) ? d.merge : []).filter(claim).map(i => ranked[i])
  const verdict = merged.some(m => m.verdict === 'CONFIRMED') ? 'CONFIRMED' : c.verdict
  const also = merged.length > 0 ? ' [same duplication also flagged at: ' + merged.map(loc).join(', ') + ']' : ''
  findings.push({ file: c.file, line: c.line, summary: c.summary + also, failure_scenario: c.failure_scenario, category: 'duplication', verdict })
}
const usedDecisions = findings.length > 0
let backfilled = 0
for (let i = 0; i < ranked.length && findings.length < MAX_FINDINGS; i++) {
  if (seen.has(i)) continue
  const c = ranked[i]
  findings.push({ file: c.file, line: c.line, summary: c.summary, failure_scenario: c.failure_scenario, category: 'duplication', verdict: c.verdict })
  backfilled++
}
const summary = usedDecisions && report
  ? report.summary + (backfilled > 0 ? ' (' + backfilled + ' additional verified finding' + (backfilled === 1 ? '' : 's') + ' appended unmerged.)' : '')
  : 'Synthesis step was skipped or its decisions were unusable — returning verified findings ranked, unmerged.'

return {
  level: 'xhigh',
  target: (ISSUE ? 'issue #' + ISSUE + (parentIssue ? ' (sub-issue of #' + parentIssue + ')' : '') : 'ad hoc scope') + (issueTitle ? ': ' + issueTitle : ''),
  summary,
  findings,
  refuted: refuted.map(c => ({ file: c.file, line: c.line, summary: c.summary })),
  stats: { ...stats, reported: findings.length },
}
