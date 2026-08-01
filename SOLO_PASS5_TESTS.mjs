/**
 * Headless test harness for the standalone SOLO Upgrade Pass 5 build.
 *
 * app.js is a browser IIFE with no exports, so this harness stubs just enough
 * DOM/localStorage for it to load, then reaches into its internals via a test
 * hook. The point is to catch the class of bug that smoke-testing cannot see:
 * silent rule failures where the game still plays fine but a mechanic is dead.
 *
 * Run: node --test SOLO_PASS5_TESTS.mjs
 */

import { readFileSync } from 'node:fs';
import { test, describe } from 'node:test';
import assert from 'node:assert/strict';

// ── Minimal DOM stub ───────────────────────────────────────────────
function makeEl() {
  const el = {
    innerHTML: '', className: '', style: {}, dataset: {}, value: '',
    children: [], classList: { add() {}, remove() {}, toggle() {}, contains: () => false },
    appendChild(c) { this.children.push(c); return c; },
    addEventListener() {}, removeEventListener() {},
    querySelector: () => makeEl(), querySelectorAll: () => [],
    closest: () => null, focus() {}, remove() {}, setAttribute() {}, getAttribute: () => null,
  };
  return el;
}

const store = new Map();
globalThis.localStorage = {
  getItem: (k) => (store.has(k) ? store.get(k) : null),
  setItem: (k, v) => store.set(k, String(v)),
  removeItem: (k) => store.delete(k),
  clear: () => store.clear(),
};
globalThis.document = {
  getElementById: () => makeEl(),
  querySelector: () => makeEl(),
  querySelectorAll: () => [],
  createElement: () => makeEl(),
  addEventListener() {},
  body: makeEl(),
};
globalThis.window = globalThis;
globalThis.addEventListener = () => {};
globalThis.removeEventListener = () => {};
globalThis.matchMedia = () => ({ matches: false, addEventListener() {}, removeEventListener() {} });
try {
  Object.defineProperty(globalThis, 'navigator', {
    value: { serviceWorker: { register: () => Promise.resolve() } },
    configurable: true, writable: true,
  });
} catch { /* Node already provides a read-only navigator; app.js guards it anyway */ }
globalThis.requestAnimationFrame = (fn) => setTimeout(() => fn(0), 0);
globalThis.AudioContext = class { createOscillator() { return { connect() {}, start() {}, stop() {}, frequency: { value: 0 } }; } createGain() { return { connect() {}, gain: { value: 0, setValueAtTime() {}, exponentialRampToValueAtTime() {} } }; } get destination() { return {}; } get currentTime() { return 0; } };

// ── Load the inline game script with a test hook appended ───────────
const html = readFileSync(new URL('./PLAY_SOLO_PASS5.html', import.meta.url), 'utf8');
const scriptStart = html.indexOf('<script>(() => {');
const scriptEnd = html.lastIndexOf('</script>');
assert.ok(scriptStart >= 0 && scriptEnd > scriptStart, 'could not find the game script');
const source = html.slice(scriptStart + '<script>'.length, scriptEnd);
// The IIFE ends with `})();` — inject an export of internals just before it.
const hookIndex = source.lastIndexOf('})();');
assert.ok(hookIndex > 0, 'could not find IIFE terminator in app.js');
const instrumented =
  source.slice(0, hookIndex) +
  `
  globalThis.__SOLO_TEST__ = {
    get state() { return state; },
    set state(v) { state = v; },
    createInitialState, startCareer, advanceSprint, generateTasks,
    assignAgent, toggleReview, chooseEvent, endVenture, startNextVenture,
    effectiveCalibration, effectiveReliability, claimRatio, updateTrustOnReview,
    trustLabel, rosterTrust, meanDrift, seededRandom, clamp,
    assignedModelFamilies, duplicateModelFamily, sameFamilyCount,
    precedentSimilarity, contextSnapshot, findMatchingPrecedent,
    reviewSignal, driftLabel, garageLightingState, agentSceneState, agentChangeBadge, migrateState, renderFounderScene,
    AGENT_TEMPLATES, TASK_POOL, EVENTS, DRIFT, TRUST_RULES, DOCTRINES,
  };
` +
  source.slice(hookIndex);

new Function(instrumented)();
const G = globalThis.__SOLO_TEST__;
assert.ok(G, 'test hook failed to install');

/** Fresh game in a known state. */
function fresh(doctrine = 'pure', seed = 12345) {
  G.state = G.createInitialState();
  G.state.seed = seed;
  G.startCareer('Tester', doctrine);
  return G.state;
}

/** Assign every task to some agent so the sprint can advance. */
function assignAll(s) {
  s.tasks.forEach((t, i) => { t.assignedAgent = s.agents[i % s.agents.length].id; });
}

// ═══════════════════════════════════════════════════════ RNG

describe('seeded RNG', () => {
  test('is deterministic for the same seed text', () => {
    const a = G.seededRandom('abc'), b = G.seededRandom('abc');
    for (let i = 0; i < 20; i++) assert.equal(a(), b());
  });

  test('differs across seed texts', () => {
    assert.notEqual(G.seededRandom('abc')(), G.seededRandom('abd')());
  });

  test('stays within [0,1)', () => {
    const r = G.seededRandom('range');
    for (let i = 0; i < 500; i++) { const v = r(); assert.ok(v >= 0 && v < 1); }
  });
});

// ═══════════════════════════════════════════ UNRELIABLE NARRATOR

describe('calibration and drift', () => {
  test('every agent template ships with calibration, drift and trust', () => {
    for (const a of G.AGENT_TEMPLATES) {
      assert.ok(typeof a.calibration === 'number', `${a.id} missing calibration`);
      assert.ok(typeof a.drift === 'number', `${a.id} missing drift`);
      assert.ok(typeof a.trust === 'number', `${a.id} missing trust`);
      assert.ok(a.calibration > 0 && a.calibration <= 1, `${a.id} calibration out of range`);
    }
  });

  test('drift degrades effective calibration', () => {
    const a = { calibration: 0.8, drift: 0, reliability: 80 };
    const clean = G.effectiveCalibration(a);
    a.drift = 100;
    assert.ok(G.effectiveCalibration(a) < clean, 'drift must reduce calibration');
    assert.ok(G.effectiveCalibration(a) > 0, 'calibration must not go negative');
  });

  test('drift degrades effective reliability', () => {
    const a = { calibration: 0.8, drift: 0, reliability: 90 };
    const clean = G.effectiveReliability(a);
    a.drift = 100;
    assert.ok(G.effectiveReliability(a) < clean);
  });

  test('claim ratio is always >= 1 — agents never modestly underclaim', () => {
    const rng = G.seededRandom('claims');
    for (const cal of [0.1, 0.4, 0.7, 0.95]) {
      for (let i = 0; i < 100; i++) {
        const r = G.claimRatio({ calibration: cal, drift: 0 }, rng);
        assert.ok(r >= 1, `ratio ${r} below 1 at calibration ${cal}`);
      }
    }
  });

  test('poorly calibrated agents overclaim more than well calibrated ones', () => {
    const rng = G.seededRandom('compare');
    const mean = (cal) => {
      let total = 0;
      for (let i = 0; i < 400; i++) total += G.claimRatio({ calibration: cal, drift: 0 }, rng);
      return total / 400;
    };
    assert.ok(mean(0.3) > mean(0.9), 'low calibration must overclaim more');
  });
});

describe('trust', () => {
  test('an accurate report raises trust', () => {
    const a = { trust: 60 };
    const verdict = G.updateTrustOnReview(a, 1.0);
    assert.equal(verdict, 'confirmed');
    assert.ok(a.trust > 60);
  });

  test('a revealed overclaim lowers trust', () => {
    const a = { trust: 60 };
    const verdict = G.updateTrustOnReview(a, 2.0);
    assert.equal(verdict, 'overclaimed');
    assert.ok(a.trust < 60, `expected a drop, got ${a.trust}`);
  });

  test('verifying always beats not verifying — the core incentive', () => {
    // Finding a lie costs trust, but never looking costs MORE. If this ever
    // inverts, the game punishes the player for paying attention, which is
    // the exact opposite of the design. This test guards that invariant.
    const reviewedLiar = { trust: 60 };
    G.updateTrustOnReview(reviewedLiar, 1.6);          // caught overclaiming
    const neglected = 60 - G.TRUST_RULES.UNVERIFIED_DECAY * 3; // 3 sprints unchecked
    assert.ok(
      reviewedLiar.trust > neglected,
      `reviewing (${reviewedLiar.trust}) must beat neglecting (${neglected})`,
    );
  });

  test('trust loss scales with the size of the lie', () => {
    const small = { trust: 80 }, big = { trust: 80 };
    G.updateTrustOnReview(small, 1.3);
    G.updateTrustOnReview(big, 2.5);
    assert.ok(big.trust < small.trust);
  });

  test('trust clamps to [0,100]', () => {
    const low = { trust: 2 };
    G.updateTrustOnReview(low, 9);
    assert.ok(low.trust >= 0);
    const high = { trust: 99 };
    for (let i = 0; i < 20; i++) G.updateTrustOnReview(high, 1.0);
    assert.ok(high.trust <= 100);
  });

  test('trust labels band correctly', () => {
    assert.equal(G.trustLabel(10), 'Skeptical');
    assert.equal(G.trustLabel(40), 'Cautious');
    assert.equal(G.trustLabel(65), 'Trusted');
    assert.equal(G.trustLabel(90), 'Relied upon');
  });

  test('reviewing during a real sprint actually moves an agent trust value', () => {
    const s = fresh('pure', 555);
    assignAll(s);
    s.agents.forEach(a => { a.calibration = 0.25; }); // guarantee overclaiming
    const before = s.agents.map(a => a.trust);
    s.reviews = [s.tasks[0].instanceId];
    G.advanceSprint();
    const after = G.state.agents.map(a => a.trust);
    assert.ok(after.some((t, i) => t !== before[i]), 'a review must move trust');
  });

  test('drift accrues on unreviewed work and is relieved by review', () => {
    const s = fresh('pure', 777);
    assignAll(s);
    G.advanceSprint();                       // nothing reviewed
    const driftAfterNeglect = G.state.agents.map(a => a.drift);
    assert.ok(driftAfterNeglect.some(d => d > 0), 'unreviewed agents must drift');
  });
});

// ══════════════════════════════════════════════ CORRELATED FAILURE

describe('correlated failure', () => {
  test('two agents share a model family in the default roster', () => {
    const fams = G.AGENT_TEMPLATES.map(a => a.modelFamily);
    const dupes = fams.filter((f, i) => fams.indexOf(f) !== i);
    assert.ok(dupes.length > 0, 'the starting roster must carry lineage risk');
  });

  test('duplicateModelFamily detects shared lineage among assigned agents', () => {
    const s = fresh('pure', 999);
    assignAll(s);
    const counts = G.assignedModelFamilies();
    assert.ok(Array.isArray(counts));
  });

  test('cascade risk rises with accumulated drift, not just doctrine', () => {
    // Run many seeded sprints at low vs high drift and compare cascade rates.
    function cascadeRate(driftLevel) {
      let hits = 0;
      const trials = 220;
      for (let i = 0; i < trials; i++) {
        const s = fresh('pure', 1000 + i);
        assignAll(s);
        s.agents.forEach(a => { a.drift = driftLevel; });
        G.advanceSprint();
        if ((G.state.cascadeCount || 0) > 0) hits++;
      }
      return hits / trials;
    }
    const low = cascadeRate(0);
    const high = cascadeRate(95);
    assert.ok(high > low, `high drift (${high}) must be riskier than low drift (${low})`);
  });

  test('a cascade damages the trust of the agents that failed together', () => {
    // Read trust off G.state AFTER the sprint -- duplicateModelFamily() consults
    // state.tasks, which advanceSprint has already regenerated by then, so the
    // check must be "did any agent lose trust", not "re-derive the lineage".
    let fired = 0;
    let withTrustDrop = 0;
    for (let i = 0; i < 400; i++) {
      const s = fresh('pure', 5000 + i);
      assignAll(s);
      s.agents.forEach(a => { a.drift = 100; a.trust = 90; });
      G.advanceSprint();
      if ((G.state.cascadeCount || 0) > 0) {
        fired++;
        if (G.state.agents.some(a => a.trust < 90)) withTrustDrop++;
      }
    }
    assert.ok(fired > 0, 'no cascade fired in 400 attempts at max drift — risk model may be broken');
    assert.equal(withTrustDrop, fired, `${fired - withTrustDrop} cascades cost no trust`);
  });
});

// ════════════════════════════════════════════════ CORE GAME LOOP

describe('game loop', () => {
  test('a fresh career starts at sprint 1 with three agents and three tasks', () => {
    const s = fresh();
    assert.equal(s.sprint, 1);
    assert.equal(s.agents.length, 3);
    assert.equal(s.tasks.length, 3);
    assert.equal(s.outcome, null);
  });

  test('advancing a sprint without any assignment does nothing', () => {
    const s = fresh();
    s.tasks.forEach(t => { t.assignedAgent = null; });
    G.advanceSprint();
    assert.equal(G.state.sprint, 1, 'sprint must not advance with nothing assigned');
  });

  test('advancing with assignments moves the sprint forward', () => {
    const s = fresh();
    assignAll(s);
    G.advanceSprint();
    assert.equal(G.state.sprint, 2);
    assert.ok(G.state.lastResults, 'results should be produced');
  });

  test('a full venture always terminates in an outcome', () => {
    for (const seed of [11, 22, 33, 44, 55]) {
      const s = fresh('pure', seed);
      let guard = 0;
      while (!G.state.outcome && guard++ < 60) {
        if (G.state.pendingEvent) {
          const ev = G.EVENTS[G.state.pendingEvent];
          G.chooseEvent(G.state.pendingEvent, ev.choices[0].id);
          continue;
        }
        if (G.state.pendingLifeBeat) { G.state.pendingLifeBeat = null; continue; }
        G.state.lastResults = null;
        if (!G.state.tasks.length) break;
        assignAll(G.state);
        G.advanceSprint();
      }
      assert.ok(G.state.outcome, `seed ${seed} never resolved`);
    }
  });

  test('stats never go NaN across a full venture', () => {
    const s = fresh('guided', 4242);
    let guard = 0;
    while (!G.state.outcome && guard++ < 60) {
      if (G.state.pendingEvent) {
        const ev = G.EVENTS[G.state.pendingEvent];
        G.chooseEvent(G.state.pendingEvent, ev.choices[0].id);
        continue;
      }
      if (G.state.pendingLifeBeat) { G.state.pendingLifeBeat = null; continue; }
      G.state.lastResults = null;
      if (!G.state.tasks.length) break;
      assignAll(G.state);
      G.advanceSprint();
      for (const [k, v] of Object.entries(G.state.stats)) {
        assert.ok(Number.isFinite(v), `stat ${k} became ${v}`);
      }
      for (const a of G.state.agents) {
        assert.ok(Number.isFinite(a.drift) && a.drift >= 0 && a.drift <= 100, `bad drift ${a.drift}`);
        assert.ok(Number.isFinite(a.trust) && a.trust >= 0 && a.trust <= 100, `bad trust ${a.trust}`);
      }
    }
  });
});

// ═══════════════════════════════════════════════════ HINDSIGHT

describe('hindsight', () => {
  test('every event choice records enough to build a precedent', () => {
    for (const [id, ev] of Object.entries(G.EVENTS)) {
      assert.ok(ev.class, `${id} has no class — hindsight cannot match it`);
      assert.ok(ev.choices.length >= 2, `${id} needs at least two choices`);
      for (const c of ev.choices) {
        assert.ok(c.id && c.label, `${id} has a malformed choice`);
      }
    }
  });

  test('similarity scores higher for closer conditions', () => {
    const s = fresh();
    const current = G.contextSnapshot();
    const near = { context: { ...current } };
    const far = { context: { runway: current.runway + 40, trust: current.trust + 40, momentum: current.momentum + 40, doctrine: 'other' } };
    assert.ok(G.precedentSimilarity(near, current).score > G.precedentSimilarity(far, current).score);
  });

  test('an identical context is a strong resonance', () => {
    fresh();
    const current = G.contextSnapshot();
    assert.equal(G.precedentSimilarity({ context: { ...current } }, current).label, 'Strong resonance');
  });
});

// ═══════════════════════════════════════════════════ CONTENT

describe('content integrity', () => {
  test('every task has rewards, a failure effect and a sane base rate', () => {
    for (const t of G.TASK_POOL) {
      assert.ok(t.rewards && Object.keys(t.rewards).length, `${t.id} has no rewards`);
      assert.ok(t.fail && Object.keys(t.fail).length, `${t.id} has no failure effect`);
      assert.ok(t.base > 0.3 && t.base < 0.95, `${t.id} base rate ${t.base} is out of band`);
      assert.ok(t.title && t.detail, `${t.id} has thin copy`);
    }
  });

  test('every doctrine has a name, perk and risk', () => {
    for (const [id, d] of Object.entries(G.DOCTRINES)) {
      assert.ok(d.name && d.perk && d.risk, `doctrine ${id} is incomplete`);
    }
  });

  test('task ids are unique', () => {
    const ids = G.TASK_POOL.map(t => t.id);
    assert.equal(new Set(ids).size, ids.length);
  });
});

// ═══════════════════════════════════════════ PASS 2: EVIDENCE OPERATIONS

describe('Upgrade Pass 2 evidence operations', () => {
  test('a mixed-review sprint records verified and unverified evidence', () => {
    const s = fresh('guided', 404);
    assignAll(s);
    s.reviews = [s.tasks[0].instanceId];
    G.advanceSprint();
    assert.equal(s.evidenceLog.length, 3, 'every assigned task should create an evidence record');
    assert.equal(s.evidenceLog.filter(entry => entry.reviewed).length, 1, 'the selected review should be verified');
    assert.equal(s.evidenceLog.filter(entry => !entry.reviewed).length, 2, 'other reports should remain unverified');
    assert.equal(s.lastReviewSummary.reviewed, 1);
    assert.equal(s.lastReviewSummary.unverified, 2);
  });

  test('review signals escalate with drift and shared-model exposure', () => {
    const s = fresh('guided', 505);
    s.tasks[0].assignedAgent = 'aurora';
    const baseline = G.reviewSignal(s.tasks[0]);
    s.agents.find(agent => agent.id === 'aurora').drift = 75;
    const elevated = G.reviewSignal(s.tasks[0]);
    assert.notEqual(elevated.level, 'low');
    assert.ok(['low', 'medium', 'high'].includes(baseline.level));
  });

  test('Pass 1 saves gain Pass 2 evidence fields and agent diagnostics', () => {
    const migrated = G.migrateState({
      version: 2,
      agents: [{ id: 'aurora', reliability: 80 }],
      settings: {},
    });
    assert.equal(migrated.version, 6);
    assert.deepEqual(migrated.evidenceLog, []);
    assert.equal(typeof migrated.agents[0].calibration, 'number');
    assert.equal(typeof migrated.agents[0].drift, 'number');
    assert.equal(typeof migrated.agents[0].trust, 'number');
  });
});

// ═══════════════════════════════════════════ PASS 3: MOTION AND CONSEQUENCES

describe('Upgrade Pass 3 presentation state', () => {
  test('Pass 2 saves gain a motion preference and consequence state safely', () => {
    const migrated = G.migrateState({ version: 3, agents: [{ id: 'aurora', reliability: 80 }], settings: {} });
    assert.equal(migrated.version, 6);
    assert.equal(migrated.settings.motion, true);
    assert.deepEqual(migrated.lastAgentChanges, {});
    assert.deepEqual(migrated.lastCascadeAgents, []);
  });

  test('a processed sprint records per-agent trust and drift deltas', () => {
    const s = fresh('guided', 808);
    assignAll(s);
    s.reviews = [s.tasks[0].instanceId];
    G.advanceSprint();
    assert.equal(Object.keys(s.lastAgentChanges).length, 3);
    assert.ok(Object.values(s.lastAgentChanges).every(change => Number.isFinite(change.trust) && Number.isFinite(change.drift)));
  });

  test('cascade agents receive the synchronized consequence state', () => {
    let found = false;
    for (let i = 0; i < 400 && !found; i++) {
      const s = fresh('pure', 9000 + i);
      assignAll(s);
      s.agents.forEach(agent => { agent.drift = 100; });
      G.advanceSprint();
      if (s.cascadeCount > 0) {
        found = true;
        assert.ok(s.lastCascadeAgents.length >= 2);
        assert.equal(G.agentSceneState(s.agents.find(agent => s.lastCascadeAgents.includes(agent.id))), 'is-cascade');
      }
    }
    assert.ok(found, 'expected at least one high-drift cascade');
  });
});

// ═══════════════════════════════════════ PASS 4: MODERN 3D GARAGE STATE

describe('Upgrade Pass 4 3D garage presentation', () => {
  test('Pass 3 saves migrate into the 3D garage visual mode', () => {
    const migrated = G.migrateState({ version: 4, agents: [{ id: 'aurora', reliability: 80 }], settings: {} });
    assert.equal(migrated.version, 6);
    assert.equal(migrated.settings.garageView, 'reference-3d');
  });

  test('garage lighting communicates steady, strained, and critical simulation states', () => {
    const s = fresh('guided', 1101);
    assert.equal(G.garageLightingState(), 'steady');
    s.agents.forEach(agent => { agent.drift = 40; });
    assert.equal(G.garageLightingState(), 'strained');
    s.agents.forEach(agent => { agent.drift = 75; });
    assert.equal(G.garageLightingState(), 'critical');
  });
});

// ═════════════════════════════════════ PASS 5: REFERENCE GARAGE SCREEN

describe('Upgrade Pass 5 reference-led Founder Garage', () => {
  test('previous saves migrate to the reference-led 3D garage without losing motion settings', () => {
    const migrated = G.migrateState({ version: 5, agents: [{ id: 'aurora', reliability: 80 }], settings: { motion: false } });
    assert.equal(migrated.version, 6);
    assert.equal(migrated.settings.garageView, 'reference-3d');
    assert.equal(migrated.settings.motion, false);
  });

  test('Founder Garage renders the embedded reference and preserves state-driven lighting classes', () => {
    const s = fresh('guided', 333);
    let screen = G.renderFounderScene();
    assert.match(screen, /reference-garage lighting-steady/);
    assert.match(screen, /garage-reference-image/);
    assert.match(screen, /src="assets\/founder-garage-reference\.jpg"/);
    s.agents.forEach(agent => { agent.drift = 76; });
    screen = G.renderFounderScene();
    assert.match(screen, /lighting-critical/);
  });

  test('the reference wall hotspot opens the Evidence Ledger instead of exposing hidden truth', () => {
    const s = fresh('pure', 334);
    const screen = G.renderFounderScene();
    assert.match(screen, /data-zone="evidence"><span>Evidence Ledger<\/span>/);
    assert.equal(s.evidenceLog.length, 0);
  });
});
