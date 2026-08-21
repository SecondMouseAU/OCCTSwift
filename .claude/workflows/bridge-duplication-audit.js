export const meta = {
  name: 'bridge-duplication-audit',
  description: 'Cross-reference/drift audit of the OCCT C++ bridge header pair (Pass 1b of #377, issue #381), bridge-specific angles, aware of what Pass 1a (#380) has already landed on refactor/377-segmented-audit',
  whenToUse: 'For issue #381 (Pass 1b: OCCTBridge.h + OCCTBridge_Internal.h). Sibling of duplication-audit.js but NOT a drop-in reuse: this header is a hand-written OCCT wrapper where per-function C-wrapper repetition is EXPECTED, not a finding, so the four Swift-app angles in duplication-audit.js do not apply. Looks instead for stale cross-reference-index entries, duplicate/inconsistent declarations, header/.mm split drift, and bridge-side duplication a Pass 1a Swift-side fix should have mirrored but did not. Defaults to issue 381 with no args; pass a different issue number or {files:[...]} to reuse this shape elsewhere.',
  phases: [
    { title: 'Scope' },
    { title: 'Context' },
    { title: 'Find' },
    { title: 'Sweep' },
    { title: 'Verify' },
    { title: 'Synthesize' },
  ],
}

// Purpose-built sibling of duplication-audit.js for #381 (Pass 1b) rather than a
// reuse of it: #381's own scope text says this header's per-function boilerplate
// is intentional, so the generic Swift-app angles (reimplemented helpers,
// copy-pasted math, drifted docs, parallel primitives) would misfire here. Two
// structural differences from duplication-audit.js:
//
// 1. OCCTBridge.h is 21,137 lines in ONE file with 598 "// MARK: -" lines (#381's
//    text says "~70", checked live via grep before writing this, that count is
//    off by ~8.5x, so this script measures structure at run time rather than
//    trusting either number). duplication-audit.js's file-clustering groups a
//    single large file into one unsplit group; that would hand one finder the
//    entire header. This script instead chunks OCCTBridge.h into line-range
//    groups along MARK boundaries, sized to GROUP_LOC_THRESHOLD.
// 2. A new Context phase fetches what Pass 1a (#380, the parallel foundation-layer
//    pass) has actually landed on refactor/377-segmented-audit. #381 is declared
//    to run in parallel with #380 with no dependency, but by the time this
//    executes 1a has usually landed real Swift-side fixes, some of which may
//    have left an unmirrored duplicate on the C side. That context feeds Angle 4
//    below and is fetched live (via gh), not hardcoded, so it stays current as
//    more Pass 1a PRs land.
//
// Branch note: this script only READS from refactor/377-segmented-audit (Pass
// 1a's landed work), it never files or targets anything there. Pass 1b's own
// findings get filed by bridge-duplication-triage.js against a separate branch,
// refactor/381-pass1b, kept apart from Pass 1a's branch while that branch is
// still under code review.

const REPO = 'SecondMouseAU/OCCTSwift'
const PASS_1A_BRANCH = 'refactor/377-segmented-audit'
const PASS_1A_ISSUE = 380
const GROUP_LOC_THRESHOLD = 2500
const GROUP_FINDER_CAP = 10
const CROSS_CAP = 10
const SWEEP_CAP = 10
const MAX_FINDINGS = 25

const NOT_FINDINGS_TEXT =
  'Do NOT flag as duplication: the ordinary one-C-function-per-exposed-operation pattern (every\n' +
  'wrapped OCCT op getting its own OCCTShape.../OCCTWire.../OCCTFace... declaration, its own Release\n' +
  'function, its own repeated error-handling shape). That repetition is this header\'s documented,\n' +
  'intended structure (CLAUDE.md\'s release process adds ~100 such declarations every release), not\n' +
  'accidental drift. Only report duplication that is genuinely accidental: declarations that used to\n' +
  'be one thing and diverged, or index/grouping metadata that fell out of sync with the code.\n'

const ANGLES_TEXT =
  '### Angle 1. Stale cross-reference index\n' +
  'OCCTBridge.h opens with an "OCCT Class Cross-Reference Index" (currently lines ~19-525) mapping\n' +
  'OCCT C++ classes to the bridge functions/files that wrap them. Find entries that no longer match\n' +
  'reality: a listed function that was renamed, removed, or moved to a different\n' +
  'OCCTBridge_<Domain>.mm file since the index entry was written; a class the index credits with a\n' +
  'wrapper that no longer calls it (or never did); or a class actually used by a shipped bridge\n' +
  'function with no index entry at all.\n\n' +
  '### Angle 2. Duplicate or inconsistent declarations\n' +
  'Find the same C function declared more than once, two declarations that should be one (near-\n' +
  'identical signatures wrapping the same OCCT operation under different names, not the expected\n' +
  'one-function-per-operation pattern, but a genuine accidental double), or a declaration whose\n' +
  'parameter list/return type/nullability annotation has drifted from its\n' +
  'OCCTBridge_<Domain>.mm implementation.\n\n' +
  '### Angle 3. Header/.mm split drift\n' +
  'The header\'s MARK sections and the 16-way OCCTBridge_<Domain>.mm split were meant to mirror each\n' +
  'other, but the header was never re-split to match as the .mm files evolved independently. Find a\n' +
  '`// MARK:` group whose declarations are actually implemented across more than one .mm file, or\n' +
  'implemented in a .mm file whose domain clearly does not match the MARK label.\n\n' +
  '### Angle 4. Bridge-side duplication a Pass 1a fix should have mirrored\n' +
  'Pass 1a (#' + PASS_1A_ISSUE + ', see the Context section you were given) found and in many cases\n' +
  'already fixed duplication/drift on the SWIFT side of this repo. For each Pass 1a finding listed as\n' +
  'landed, check whether the underlying bridge functions have the analogous problem: two C functions\n' +
  'still backing what is now a single unified Swift type/enum, a bridge-side tolerance/default\n' +
  'constant that still disagrees the way the pre-fix Swift-side ones did, or a bridge function\n' +
  'orphaned by a Pass 1a rename/removal that nothing calls anymore. Only report if you can name the\n' +
  'specific bridge function(s) AND the specific Pass 1a issue/PR whose Swift-side change this should\n' +
  'have mirrored.\n\n' +
  NOT_FINDINGS_TEXT

const ISSUE_SCOPE_SCHEMA = {
  type: 'object', required: ['files'],
  properties: {
    title: { type: 'string' },
    parentIssue: { type: 'number' },
    scopeNotes: { type: 'string', description: 'the issue\'s own "## Scope" text, verbatim, if present' },
    files: { type: 'array', items: {
      type: 'object', required: ['path'],
      properties: { path: { type: 'string' } },
    }},
    notes: { type: 'string', description: 'any listed file that turned out not to exist, or other discrepancies' },
  },
}
const FILE_STRUCTURE_SCHEMA = {
  type: 'object', required: ['files'],
  properties: {
    files: { type: 'array', items: {
      type: 'object', required: ['path', 'totalLines'],
      properties: {
        path: { type: 'string' },
        totalLines: { type: 'number', description: 'live `wc -l` result, not a number copied from anywhere else' },
        markLines: { type: 'array', items: { type: 'number' }, description: 'line numbers of every "// MARK: -" occurrence, in ascending order, via `grep -n', },
      },
    }},
  },
}
const PASS1A_SCHEMA = {
  type: 'object', required: ['landed', 'stillOpen'],
  properties: {
    landed: { type: 'array', items: {
      type: 'object', required: ['issue', 'title'],
      properties: {
        issue: { type: 'number' }, title: { type: 'string' }, pr: { type: 'number' },
        summary: { type: 'string', description: 'one line: what Swift-side code actually changed, read from the merged PR diff' },
      },
    }},
    stillOpen: { type: 'array', items: {
      type: 'object', required: ['issue', 'title'],
      properties: { issue: { type: 'number' }, title: { type: 'string' } },
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
        failure_scenario: { type: 'string', description: 'the concrete maintenance cost: what is duplicated/stale/drifted, or why it should be unified' },
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
if (args === undefined || args === null) ISSUE = 381
else if (typeof args === 'number') ISSUE = args
else if (typeof args === 'string' && /^\d+$/.test(args.trim())) ISSUE = parseInt(args.trim(), 10)
else if (args && typeof args === 'object') {
  if (args.issue) ISSUE = Number(args.issue)
  if (Array.isArray(args.files)) DIRECT_FILES = args.files.map(f => (typeof f === 'string' ? { path: f } : f))
}
if (!ISSUE && !DIRECT_FILES) {
  return { error: 'bridge-duplication-audit needs an issue number (defaults to 381 with no args) or {files:[...]}.' }
}

let files, issueTitle = null, parentIssue = null, scopeNotes = ''
if (DIRECT_FILES) {
  files = DIRECT_FILES
} else {
  const scoped = await agent(
    'Run `gh issue view ' + ISSUE + ' --repo ' + REPO + '` and read its body.\n\n' +
    'Extract:\n' +
    '1. title\n' +
    '2. parentIssue, the parent issue number if the issue has one (from a "Part of ... #<N>" ' +
    '   reference in the body), otherwise omit it.\n' +
    '3. scopeNotes, the issue\'s own "## Scope" section text, verbatim, if present.\n' +
    '4. files, every repo-relative, backtick-wrapped path listed under the "## Files" section.\n' +
    '   Do NOT extract any LOC number that may appear next to a path or in the section heading, it\n' +
    '   is frequently stale or absent; this script measures real sizes itself in the next phase.\n\n' +
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
log('Scope: ' + ALL_FILES.length + ' file(s)' + (issueTitle ? ', ' + issueTitle : '') + ': ' + ALL_FILES.join(', '))

const structure = await agent(
  'For EACH of these files, run `wc -l <path>` for its live total line count, and ' +
  '`grep -n \'^// MARK: -\' <path>` to list every MARK line\'s line number in ascending order (empty ' +
  'array if the file has none, e.g. a small internal header may have no MARK sections at all):\n\n' +
  ALL_FILES.map(f => '  - ' + f).join('\n') + '\n\n' +
  'Report real, freshly-measured numbers, do not estimate or reuse any figure you may recall from ' +
  'elsewhere. Structured output only.',
  { label: 'scope:structure', schema: FILE_STRUCTURE_SCHEMA }
)
const structByPath = Object.create(null)
for (const f of (structure && structure.files) || []) structByPath[f.path] = f
for (const p of ALL_FILES) {
  if (!structByPath[p]) { structByPath[p] = { path: p, totalLines: 0, markLines: [] } }
}
const totalLoc = ALL_FILES.reduce((s, p) => s + (structByPath[p].totalLines || 0), 0)
log('Measured: ' + totalLoc + ' LOC across ' + ALL_FILES.length + ' file(s), ' +
  ALL_FILES.map(p => p.split('/').pop() + '=' + (structByPath[p].markLines || []).length + ' MARKs').join(', '))

// ─── Chunk each file into line-range groups along MARK boundaries, sized to
// GROUP_LOC_THRESHOLD. A file under the threshold, or with no MARK lines at all,
// becomes one whole-file group (mirrors duplication-audit.js's "don't split a
// small cluster" rule, just applied within a file instead of across files).
const chunkFile = (path, totalLines, markLines) => {
  if (!totalLines) return []
  if (totalLines <= GROUP_LOC_THRESHOLD || !markLines || markLines.length === 0) {
    return [{ path, startLine: 1, endLine: totalLines }]
  }
  const chunks = []
  let chunkStart = 1
  let lastBoundary = 1
  for (const m of markLines) {
    if (m - chunkStart >= GROUP_LOC_THRESHOLD && lastBoundary > chunkStart) {
      chunks.push({ path, startLine: chunkStart, endLine: lastBoundary - 1 })
      chunkStart = lastBoundary
    }
    lastBoundary = m
  }
  chunks.push({ path, startLine: chunkStart, endLine: totalLines })
  return chunks
}
const FILE_GROUPS = ALL_FILES.flatMap(p => chunkFile(p, structByPath[p].totalLines, structByPath[p].markLines))
const marksIn = g => (structByPath[g.path].markLines || []).filter(m => m >= g.startLine && m <= g.endLine).length
const groupLabel = g => g.path.split('/').pop().replace(/\.h$/, '') + '_L' + g.startLine + '-' + g.endLine
log('Chunked into ' + FILE_GROUPS.length + ' finder group(s): ' + FILE_GROUPS.map(g => groupLabel(g) + '(' + marksIn(g) + ' MARKs)').join(', '))
const chunkBoundaries = FILE_GROUPS.filter((g, i) => i > 0 && FILE_GROUPS[i - 1].path === g.path).map(g => g.path + ':' + g.startLine)

const SCOPE_BLOCK =
  '## Audit scope, issue #' + (ISSUE || '?') + (parentIssue ? ' (sub-issue of #' + parentIssue + ')' : '') +
  (issueTitle ? ': ' + issueTitle : '') + '\n' +
  'This is a STATIC audit of the existing, already-committed OCCT C++ bridge header pair, there is\n' +
  'no diff or PR to review. It is a hand-written OCCT wrapper, not Swift application code: per-\n' +
  'function C-wrapper repetition is expected here, so the usual Swift-side duplication angles do not\n' +
  'apply (see below).\n' +
  (scopeNotes ? '\n' + scopeNotes + '\n' : '') +
  '\nFull scope (' + totalLoc + ' LOC across ' + ALL_FILES.length + ' file(s)):\n' +
  ALL_FILES.map(p => '  - ' + p + ' (' + structByPath[p].totalLines + ' lines, ' + (structByPath[p].markLines || []).length + ' MARK sections)').join('\n') + '\n'

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

// ─── Phase: Context, what Pass 1a has actually landed on the audit branch,
// fetched live (not a fixed snapshot) so this stays current as more Pass 1a PRs
// merge. Feeds Angle 4 above.
phase('Context')
const pass1a = await agent(
  'Compile what Pass 1a (issue #' + PASS_1A_ISSUE + ' of the #377 segmented duplication audit) has ' +
  'already landed on branch `' + PASS_1A_BRANCH + '` in repo ' + REPO + '.\n\n' +
  '1. Run `gh api repos/' + REPO + '/issues/' + PASS_1A_ISSUE + '/sub_issues --jq \'.[] | "\\(.number) [\\(.state)] \\(.title)"\'` ' +
  'to list every Pass 1a finding issue.\n' +
  '2. Run `gh pr list --repo ' + REPO + ' --base ' + PASS_1A_BRANCH + ' --state merged --json number,title,body --limit 200` ' +
  'to list merged PRs targeting the audit branch, and match each to a finding issue number from step 1 ' +
  '(PR title/body usually names it, e.g. "fix(#399): ..."; fall back to ' +
  '`git log ' + PASS_1A_BRANCH + ' --oneline --grep=\'#<n>\'` for any that don\'t match by title/body alone). ' +
  'A finding issue staying open on GitHub does NOT mean it is unfixed, these PRs target a non-default ' +
  'branch, so GitHub does not auto-close on merge; treat a matched merged PR as landed regardless of the ' +
  'issue\'s open/closed state.\n' +
  '3. For each finding confirmed landed, write a ONE-LINE summary of the actual Swift-side code change ' +
  '(run `gh pr diff <n>` if the PR title alone is not enough detail to summarize accurately).\n' +
  '4. List every remaining Pass 1a finding (no matching merged PR found) as stillOpen, issue + title only.\n\n' +
  'Structured output only.',
  { label: 'context:pass1a', schema: PASS1A_SCHEMA }
)
const landed = (pass1a && pass1a.landed) || []
const stillOpen = (pass1a && pass1a.stillOpen) || []
log('Pass 1a context: ' + landed.length + ' landed on ' + PASS_1A_BRANCH + ', ' + stillOpen.length + ' still open')

const PASS1A_BLOCK =
  '## Pass 1a (#' + PASS_1A_ISSUE + ') status on `' + PASS_1A_BRANCH + '`, fetched live this run, use for Angle 4\n' +
  (landed.length > 0
    ? 'Landed (' + landed.length + '):\n' + landed.map(l => '  - #' + l.issue + (l.pr ? ' (PR #' + l.pr + ')' : '') + ': ' + l.title + (l.summary ? ', ' + l.summary : '')).join('\n') + '\n'
    : '(nothing landed yet, Angle 4 will have nothing to check against this run)\n') +
  (stillOpen.length > 0
    ? 'Not yet landed (' + stillOpen.length + ', no bridge-side mirror check applies until these land):\n' +
      stillOpen.map(l => '  - #' + l.issue + ': ' + l.title).join('\n') + '\n'
    : '')

// ─── Find: one finder per line-range group (Angles 2-3, in-range duplication and
// MARK/.mm split drift; may Grep the rest of the repo to check cross-group/cross-
// file echoes) + 2 cross-cutting finders whose angles are inherently whole-scope.
phase('Find')
const groupFinders = FILE_GROUPS.map(g => () =>
  agent(
    '## Bridge duplication-audit finder, ' + groupLabel(g) + '\n\n' + SCOPE_BLOCK + '\n' + PASS1A_BLOCK + '\n' +
    'Your assigned range: lines ' + g.startLine + '-' + g.endLine + ' of ' + g.path +
    ' (' + marksIn(g) + ' MARK sections). Read exactly this range using your Read tool\'s offset/limit\n' +
    '(offset=' + g.startLine + ', limit=' + (g.endLine - g.startLine + 1) + ').\n\n' +
    'Review through Angles 2-4 below (Angle 1, the cross-reference index, is handled by a separate\n' +
    'whole-file finder, skip it unless something in your range obviously contradicts the index).\n' +
    'You may Grep the rest of the repo (not just your assigned range) to check whether a declaration\n' +
    'in your range duplicates something elsewhere, or to find the OCCTBridge_<Domain>.mm file backing\n' +
    'it, but only report a finding if its PRIMARY (worse-drifted, or newer/messier) location is\n' +
    'inside your assigned range.\n\n' + ANGLES_TEXT + '\n' +
    'Surface up to ' + GROUP_FINDER_CAP + ' candidates. Each needs a primary file+line, a one-line summary naming\n' +
    'both the primary location and its duplicate/stale counterpart (file:line, or the .mm file it should\n' +
    'match), and a failure_scenario stating the concrete cost. Pass every candidate through even if only\n' +
    'half-confident, an independent verifier judges them next. If nothing qualifies, return an empty list.\n\n' +
    'Structured output only.',
    { label: 'find:' + groupLabel(g), phase: 'Find', schema: CANDIDATES_SCHEMA }
  ).then(r => {
    if (!r) return []
    log('find:' + groupLabel(g) + ': ' + r.candidates.length + ' candidates')
    return ingest(r.candidates, GROUP_FINDER_CAP)
  })
)

const CROSS_CUTTING = [
  {
    label: 'cross-reference-index',
    focus:
      'Focus specifically on Angle 1 (stale cross-reference index). Read the full "OCCT Class Cross-\n' +
      'Reference Index" section at the top of OCCTBridge.h in one pass. For a representative sample of\n' +
      'its entries (do not exhaustively check all, sample broadly across domains, prioritize entries\n' +
      'that look old or reference less-common OCCT classes), grep Sources/OCCTBridge/src/OCCTBridge_*.mm\n' +
      'to confirm the listed function(s) still exist, still live in the file the index implies, and still\n' +
      'call the listed OCCT class. Report every mismatch found.\n',
  },
  {
    label: 'pass1a-mirror-gaps',
    focus:
      'Focus specifically on Angle 4 (bridge-side duplication a Pass 1a fix should have mirrored). You\n' +
      'were given the live Pass 1a landed/not-yet-landed list above. For each LANDED Pass 1a finding,\n' +
      'run `gh pr diff <pr>` on its PR to see exactly what Swift-side code changed, then grep\n' +
      'OCCTBridge.h/OCCTBridge_Internal.h and the relevant OCCTBridge_<Domain>.mm file(s) for the bridge\n' +
      'functions those Swift symbols call. Check whether the C side still has the pre-fix duplication\n' +
      '(e.g. still two C functions/constants where the Swift side is now unified) or has an orphaned\n' +
      'function nothing calls anymore post-fix.\n',
  },
]
const crossFinders = CROSS_CUTTING.map(c => () =>
  agent(
    '## Bridge duplication-audit finder, cross-cutting: ' + c.label + '\n\n' + SCOPE_BLOCK + '\n' + PASS1A_BLOCK + '\n' +
    c.focus + '\n' + NOT_FINDINGS_TEXT + '\n' +
    'Surface up to ' + CROSS_CAP + ' candidates. Each needs a primary file+line, a one-line summary naming\n' +
    'both locations involved (file:line for each, or the PR it should have mirrored for Angle 4), and a\n' +
    'failure_scenario stating the concrete cost or observed drift. If nothing qualifies, return an empty list.\n\n' +
    'Structured output only.',
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

// ─── Sweep: one fresh finder hunting only for gaps the group/cross-cutting
// finders above missed, including anything straddling a chunk boundary our own
// line-range split may have cut through.
phase('Sweep')
const knownBlock = allCandidates.length > 0
  ? allCandidates.map(c => '- ' + loc(c) + ', ' + c.summary).join('\n')
  : '(none)'
const sweep = await agent(
  '## Bridge duplication-audit sweep, gaps only\n\n' + SCOPE_BLOCK + '\n' + PASS1A_BLOCK + '\n' +
  '## Already-found candidates (do NOT re-derive or re-report these)\n' + knownBlock + '\n\n' +
  'Re-scan the full file scope (Grep across all of it together) looking ONLY for duplication/drift not\n' +
  'already listed above. Two things to check specifically: (1) OCCTBridge.h was split into line-range\n' +
  'groups for the Find pass at these boundaries: ' + (chunkBoundaries.length > 0 ? chunkBoundaries.join(', ') : '(none, whole file fit in one group)') +
  ', a MARK section or duplicated pair straddling one of these boundaries may have fallen through both\n' +
  'sides. (2) Angle 3 (header/.mm split drift) between groups that never directly compared their MARK\n' +
  'sections against each other.\n\n' +
  ANGLES_TEXT + '\n' +
  'Surface up to ' + SWEEP_CAP + ' additional candidates. If nothing new, return an empty list, do not pad.\n\n' +
  'Structured output only.',
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
  '- **CONFIRMED**, read both locations (and, for an Angle 4 claim, the cited Pass 1a PR diff) and\n' +
  '  confirm genuine, accidental duplication/drift; name the concrete cost or the actual point of drift.\n' +
  '- **PLAUSIBLE**, the duplication/drift is real but its cost or exact scope is uncertain. State\n' +
  '  what would confirm it.\n' +
  '- **REFUTED**, not actually duplicated/stale (different purpose despite surface similarity, the\n' +
  '  index entry is in fact still accurate, or this is the expected one-function-per-operation\n' +
  '  pattern misidentified as duplication). Quote the code that proves it.'

const byLoc = Object.create(null)
for (const c of allCandidates) (byLoc[loc(c)] ||= []).push(c)
const groups = Object.values(byLoc)
const verifierAgents = groups.length
const verifiedOut = await parallel(groups.map(g => async () => {
  const short = g[0].file.split('/').pop()
  const r = await agent(
    '## Bridge duplication-audit verifier\n\n' + SCOPE_BLOCK + '\n' + PASS1A_BLOCK + '\n' +
    '## Candidate findings at ' + loc(g[0]) + '\n' +
    g.map((c, i) => '[' + i + '] Summary: ' + c.summary + '\n    Cost claimed: ' + c.failure_scenario).join('\n') + '\n\n' +
    'Read the primary file and every duplicate-counterpart file/location named in each candidate\'s\n' +
    'summary (for an Angle 4 claim, also run `gh pr diff <pr>` on the cited Pass 1a PR). Return one\n' +
    'verdict per candidate, judged independently, candidates at the same location may describe\n' +
    'distinct issues, the same one, or a mix. Reference each by its [i] index.\n\n' +
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
  pass1aLanded: landed.length,
  pass1aStillOpen: stillOpen.length,
}

if (surviving.length === 0) {
  return {
    level: 'xhigh',
    target: 'issue #' + ISSUE + (parentIssue ? ' (sub-issue of #' + parentIssue + ')' : '') + (issueTitle ? ': ' + issueTitle : ''),
    summary: 'No duplication/drift findings survived verification.',
    findings: [],
    stats,
  }
}

// ─── Synthesize: rank, merge semantic dupes, cap the report.
phase('Synthesize')
const rank = c => (c.verdict === 'PLAUSIBLE' ? 1 : 0)
const ranked = surviving.slice().sort((a, b) => rank(a) - rank(b))
const block = ranked.map((c, i) =>
  '### [' + i + '] ' + loc(c) + ' (' + c.verdict + ')\n' +
  c.summary + '\nCost: ' + c.failure_scenario + '\nVerifier evidence: ' + c.evidence + '\n'
).join('\n')

const report = await agent(
  '## Synthesis: final bridge duplication-audit report (issue #' + ISSUE + ')\n\n' +
  ranked.length + ' findings survived independent verification. They are numbered [0]-[' + (ranked.length - 1) + '] below.\n\n' + block + '\n' +
  '## Instructions\n' +
  'Return decisions about findings BY INDEX, never re-emit finding text.\n' +
  '1. For each distinct duplication/drift, emit one decision with its index. When several findings\n' +
  '   describe the same root cause, keep one entry and list the others in its merge array.\n' +
  '2. Order decisions most-costly first: prefer CONFIRMED behavioral drift (the two copies already\n' +
  '   disagree, or the index is actively wrong) over duplication that is merely redundant but\n' +
  '   currently consistent.\n' +
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
  const also = merged.length > 0 ? ' [same issue also flagged at: ' + merged.map(loc).join(', ') + ']' : ''
  findings.push({ file: c.file, line: c.line, summary: c.summary + also, failure_scenario: c.failure_scenario, category: 'bridge-duplication', verdict })
}
const usedDecisions = findings.length > 0
let backfilled = 0
for (let i = 0; i < ranked.length && findings.length < MAX_FINDINGS; i++) {
  if (seen.has(i)) continue
  const c = ranked[i]
  findings.push({ file: c.file, line: c.line, summary: c.summary, failure_scenario: c.failure_scenario, category: 'bridge-duplication', verdict: c.verdict })
  backfilled++
}
const summary = usedDecisions && report
  ? report.summary + (backfilled > 0 ? ' (' + backfilled + ' additional verified finding' + (backfilled === 1 ? '' : 's') + ' appended unmerged.)' : '')
  : 'Synthesis step was skipped or its decisions were unusable, returning verified findings ranked, unmerged.'

return {
  level: 'xhigh',
  target: 'issue #' + ISSUE + (parentIssue ? ' (sub-issue of #' + parentIssue + ')' : '') + (issueTitle ? ': ' + issueTitle : ''),
  summary,
  findings,
  refuted: refuted.map(c => ({ file: c.file, line: c.line, summary: c.summary })),
  pass1aContext: { landed, stillOpen },
  stats: { ...stats, reported: findings.length },
}
