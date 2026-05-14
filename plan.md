# Axis & Allies Reinforcement Learning Agent — Implementation Plan

> **Audience**: A fresh Claude (Opus) Copilot session with no prior context on this project. Read this end-to-end before writing code. Cross-references to the existing Odin engine assume the workspace layout described in **§2**.

---

## 1. Project goal

Build a reinforcement-learning agent that plays Axis & Allies at or above the strength of TripleA's hand-coded **ProAI**, using:

- The user's **Odin** port of the TripleA game engine as the simulator (perfect-fidelity port of the Java engine).
- A **Sampled AlphaZero**-family algorithm (Hubert et al., 2021) with a **graph neural network** encoder and an **autoregressive plan decoder**.
- **ProAI** as a bootstrap teacher (behavioral cloning, value pretraining, MCTS leaf rollouts, opponent pool, candidate-plan injection).

This is a **custom training stack** of roughly 2k LOC of Python on top of PyTorch + PyG + Ray, using LightZero and OpenSpiel as **reference implementations**, not as runtime dependencies. See **§9** for the rationale against forking an existing framework.

---

## 2. Workspace layout (assumed)

The Odin engine lives in `~/todin`:

- `~/todin/triplea/game-app/game-core/src/main/java/...` — original Java source of truth.
- `~/todin/odin_flat/...` — Odin port.
- `~/todin/triplea/conversion/odin_tests/...` — Odin test harness.
- `~/todin/triplea/game-app/smoke-testing/src/test/java/` — Java parity-test harness.

This RL project lives in `~/todin/rl-agent/`. All paths in this document are relative to that directory unless prefixed with `~/todin/`.

**Java-fidelity rule**: when porting any Java behavior to Odin, read the Java first (see `/memories/java-fidelity-rule.md` in user memory). The same rule applies to any new engine functionality this RL project requires (e.g., `clone`, `apply`/`undo`, `proai_plan_for(state)`).

---

## 3. Why this architecture (one-paragraph each)

### 3.1 Why not vanilla AlphaZero / `alpha-zero-general`
A&A has stochastic combat, a per-turn factored action space in the thousands, ~30-round game length, multiple powers per side, and a large economic sub-game. Vanilla AZ assumes a small discrete action set and deterministic transitions. It will not work.

### 3.2 Why AlphaZero-family, not MuZero-family
The user has a perfect, fast simulator (the Odin engine) and a strong heuristic (ProAI). MuZero's main advantages — learning dynamics when no simulator exists, planning in latent space — are wasted here, and MuZero's leaf evaluation runs in latent space, which is **incompatible with ProAI rollouts at MCTS leaves**. AlphaZero-style search on real states with real combat resolution is strictly the better fit. Stochastic MuZero can be revisited later if AlphaZero plateaus.

### 3.3 Why Sampled AlphaZero specifically
Even with phase-level macro-actions, the per-phase action space is far too large to enumerate at MCTS nodes. Sampled AlphaZero (Hubert et al., 2021, *Learning and Planning in Complex Action Spaces*) handles this by sampling K candidate actions from the policy at each node and running PUCT only over those K, with an importance-weighting correction in the policy loss. K = 20–30 is typical.

### 3.4 Why a GNN encoder
The A&A map is literally a graph (territories + sea zones as nodes, adjacency as edges, with heterogeneous edge types: land-land, sea-sea, amphibious, canal). A GNN gives:

- Correct topological inductive bias (Suez/Panama, island ferries).
- Permutation equivariance over territories (the game's actual symmetry).
- Map-size invariance (same weights for 1942.2, Global 1940, custom maps).
- Message passing radius ≈ strategic reasoning radius (k layers ≈ "k territories of foresight").
- Edge-scoring and node-scoring action heads map directly onto the action space.

This is the same architectural choice DeepMind made for **DipNet** (Diplomacy). Port DipNet's encoder/decoder shape — it is the closest published analogue.

### 3.5 Why phase-level macro-actions
Per-unit MCTS would have tree depth 50+ and branching factor in the thousands per node — unsearchable. Treating each phase as **one MCTS edge** (whose action is a complete phase plan generated autoregressively by the policy net) collapses tree depth to ~5 per power-turn with branching factor K. Phase collapsing further reduces this:

- **Decision 1**: Purchase + CombatMove (combined plan).
- **Chance node**: Combat resolution (engine resolves all battles + casualty selection via ProAI).
- **Decision 2**: NCM + Place (combined plan).

Two decision nodes + one chance node per power-turn. With 5–6 powers per round, ~10–12 decision nodes per game round. Casualties, retreats, sub-submerge, AA fire targeting, etc. are handled by ProAI/engine heuristics inside the chance node — they are tactical micro and almost never strategically pivotal.

### 3.6 Why this is a 2-player, not multi-agent, problem
A&A is a two-team zero-sum game. Allies share a reward; Axis share a reward. Standard reduction: `current_player ∈ {Allies=0, Axis=1}`, value is from the current team's POV, and **the currently-acting power is a feature in the observation, not a separate agent**. No MARL machinery is needed.

### 3.7 Why canonical-form per-power feature rotation
AlphaZero canonicalizes Go to "always white to move". The same trick applies to A&A's 5–6 powers: per-power feature planes are rotated so plane 0 is always the mover, plane 1 the next opponent, etc. Geography stays fixed (Moscow is always Moscow). This lets the network share parameters across "I am USSR thinking" / "I am Germany thinking" / etc. instead of learning five disjoint sub-policies. Add a small `acting_power` one-hot for power-specific quirks (war declarations, mobilization rules).

### 3.8 Why ProAI bootstrap is critical
A randomly-initialized policy will produce thousands of nonsense games before MCTS finds anything. ProAI bootstrap reduces cold-start cost from "infeasible on a workstation" to "feasible on a workstation". Four independent uses of ProAI, all stacked: see **§7**.

---

## 4. Odin engine FFI requirements

The Odin engine must expose a stable C ABI shared library (`-build-mode:shared` → `libtriplea_odin.so`). Python calls it via `ctypes`. Out-of-process subprocess + IPC is an alternative if process isolation matters (worth it for crash containment); start with in-process FFI.

### 4.1 Required C-ABI surface

```c
// Lifecycle
GameState* ts_new(int seed, const char* map_name, const char* ruleset);
GameState* ts_clone(const GameState*);                  // MUST be cheap; see §4.3
void       ts_free(GameState*);
int        ts_serialize(const GameState*, uint8_t* buf, int cap);
GameState* ts_deserialize(const uint8_t* buf, int len);

// Game state queries
int        ts_current_player(const GameState*);          // 0=Allies team, 1=Axis team
int        ts_acting_power(const GameState*);            // 0..5 (RUS, GER, UK, JPN, USA, ITA)
int        ts_current_phase(const GameState*);           // enum: PURCHASE_COMBATMOVE, COMBAT, NCM_PLACE, END_TURN, GAME_OVER
int        ts_round_number(const GameState*);
int        ts_is_terminal(const GameState*);
double     ts_team_reward(const GameState*, int team);   // +1/-1 at terminal, 0 otherwise

// Sub-action interface (autoregressive plan execution)
int        ts_legal_subactions(const GameState*, int32_t* out_buf, int cap);
int        ts_apply_subaction(GameState*, int32_t subaction);  // returns 0=ok, nonzero=illegal
int        ts_can_finalize_phase(const GameState*);            // can current plan be ended?
int        ts_finalize_phase(GameState*);                       // close current decision phase

// Chance node
int        ts_resolve_combat(GameState*, uint64_t rng_seed);    // resolves all battles deterministically given seed; uses ProAI for casualties
int        ts_combat_outcome_distribution(const GameState*, double* out_probs, int cap);  // optional, for stratified sampling later

// Graph observation (zero-copy into preallocated NumPy buffers)
int        ts_observe_node_count(const GameState*);
int        ts_observe_edge_count(const GameState*);
void       ts_observe_node_features(const GameState*, float* out, int rows, int cols);
void       ts_observe_edge_index(const GameState*, int32_t* out, int rows /* =2 */, int cols);
void       ts_observe_edge_features(const GameState*, float* out, int rows, int cols);
void       ts_observe_edge_types(const GameState*, int32_t* out, int n);
void       ts_observe_global_features(const GameState*, float* out, int n);

// ProAI integration (see §7)
int        ts_proai_plan_for_phase(const GameState*, int32_t* out_subactions, int cap);  // returns plan length; fills out_buf with sub-actions ProAI would take
double     ts_proai_rollout(const GameState*, int max_turns, uint64_t seed);             // play with ProAI on both sides for ≤max_turns turns; returns team-0 win prob estimate (0/1 if game ends, else heuristic eval at horizon)
double     ts_proai_value_estimate(const GameState*);                                      // optional: ProAI's static eval (TUV+IPC heuristic); cheap fallback for rollout horizon
```

### 4.2 Sub-action vocabulary

A plan = ordered sequence of sub-actions, terminated by `FINALIZE`. Sub-action IDs are encoded in a single `int32`. Suggested encoding (32 bits):

```
bits 28–31: opcode (4 bits, 16 ops)
bits 0–27 : opcode-specific payload (territory ids, unit type, count, edge id, etc.)
```

Opcodes:

| Op | Name | Payload | Used in phase |
|---|---|---|---|
| 0 | `BUY_UNIT` | unit_type (8b), count (8b), factory_node (12b) | Purchase+CM |
| 1 | `MOVE_STACK` | from_node (12b), to_node (12b), unit_mask (4b) | Purchase+CM, NCM+Place |
| 2 | `MOVE_UNIT` | from_node (12b), to_node (12b), unit_type (4b) | Purchase+CM, NCM+Place |
| 3 | `LOAD_TRANSPORT` | unit_node (12b), transport_node (12b), unit_type (4b) | Purchase+CM, NCM+Place |
| 4 | `UNLOAD_TRANSPORT` | transport_node (12b), to_node (12b), unit_type (4b) | Purchase+CM, NCM+Place |
| 5 | `PLACE_UNIT` | unit_type (8b), count (8b), node (12b) | NCM+Place |
| 6 | `TECH_ROLL` | tech_token_count (8b) | Purchase+CM |
| 15 | `FINALIZE` | 0 | any |

The exact set of opcodes will evolve. The contract is: **`ts_legal_subactions(state)` is the ground truth** for what is legal at any moment, and **`ts_apply_subaction` is a no-op-or-fail** if an illegal sub-action is passed.

### 4.3 Critical: clone / apply / undo performance

MCTS does ~hundreds of `clone` operations per move. Cloning a Global 1940 `GameState` naïvely is the single biggest performance bottleneck.

**Required**: `ts_clone` must be O(state size) with a small constant. Use:

- Arena allocator per `GameState` so clone = `memcpy` of a contiguous arena.
- Or copy-on-write for unit lists with refcounted tiles.
- Or, even better, an **`apply` + `undo` stack** so MCTS does `apply(action)` → recurse → `undo()` instead of cloning at every node. This is the biggest perf win available in the entire project.

If the engine cannot easily support undo, prioritize fast clone first; revisit undo later if profiling shows clone dominating.

### 4.4 Determinism

`ts_resolve_combat` and `ts_proai_rollout` must be fully deterministic given their seed argument. This is required for debugging, replay, and Common-Random-Numbers variance reduction in MCTS.

---

## 5. Python project layout

```
~/todin/rl-agent/
├── plan.md                          # this file
├── pyproject.toml                   # uv / hatch / poetry — your call
├── configs/
│   ├── default.yaml                 # Hydra config root
│   ├── env/
│   │   ├── tictactoe.yaml
│   │   ├── aa_toy.yaml              # 5-territory toy map
│   │   ├── aa_1942.yaml
│   │   └── aa_global1940.yaml
│   ├── model/
│   │   ├── tiny_mlp.yaml
│   │   └── hgnn_dipnet.yaml
│   └── train/
│       ├── bc_pretrain.yaml
│       ├── value_pretrain.yaml
│       └── alphazero.yaml
├── triplea_odin/                    # Python FFI wrapper
│   ├── __init__.py
│   ├── ffi.py                       # ctypes bindings
│   ├── env.py                       # AAEnv class (the env contract)
│   └── proai.py                     # ProAI helper functions
├── model/
│   ├── __init__.py
│   ├── encoder.py                   # HeteroGNN (PyG)
│   ├── decoder.py                   # autoregressive plan decoder
│   ├── heads.py                     # value head, sub-action heads
│   └── model.py                     # composes encoder + decoder + heads
├── mcts/
│   ├── __init__.py
│   ├── node.py                      # DecisionNode, ChanceNode, TerminalNode
│   ├── puct.py                      # PUCT formula, Dirichlet noise, virtual loss
│   ├── search.py                    # main search loop
│   ├── sampling.py                  # K-plan sampling with diversity + ProAI injection
│   └── chance.py                    # chance-node single-sample / stratified expansion
├── train/
│   ├── __init__.py
│   ├── replay.py                    # replay buffer (state, plan_visits, outcome)
│   ├── losses.py                    # policy CE + value MSE + importance correction
│   ├── self_play.py                 # collection workers (Ray actors)
│   ├── trainer.py                   # main training loop
│   ├── bc_pretrain.py               # standalone: behavioral cloning on ProAI games
│   ├── value_pretrain.py            # standalone: value MSE on ProAI rollout outcomes
│   └── eval.py                      # vs ProAI evaluation harness
├── tests/
│   ├── test_ffi.py
│   ├── test_env_contract.py
│   ├── test_mcts_tictactoe.py       # smoke test against OpenSpiel TTT
│   ├── test_chance_nodes.py
│   └── test_sampling_diversity.py
└── tools/
    ├── generate_proai_games.py       # dataset for BC + value pretraining
    ├── visualize_game.py             # render game state + MCTS tree
    └── benchmark_clone.py            # measure clone/apply/undo cost
```

---

## 6. Component specifications

### 6.1 `triplea_odin.env.AAEnv`

The single env contract used everywhere. **Not** PettingZoo — we don't need its overhead since we're not using a stock framework.

```python
class AAEnv:
    def reset(self, seed: int = 0) -> Observation: ...
    def clone(self) -> "AAEnv": ...
    def current_player(self) -> int: ...                # 0 or 1 (team)
    def acting_power(self) -> int: ...                  # 0..5
    def current_phase(self) -> Phase: ...
    def round_number(self) -> int: ...
    def is_terminal(self) -> bool: ...
    def team_reward(self, team: int) -> float: ...

    def legal_subactions(self) -> np.ndarray: ...        # int32[N]
    def apply_subaction(self, sub: int) -> None: ...
    def can_finalize_phase(self) -> bool: ...
    def finalize_phase(self) -> None: ...

    def resolve_combat(self, seed: int) -> None: ...

    def observation(self) -> Observation: ...            # PyG HeteroData

    # ProAI hooks
    def proai_plan(self) -> list[int]: ...
    def proai_rollout(self, max_turns: int, seed: int) -> float: ...
    def proai_value(self) -> float: ...
```

`Observation` is a `torch_geometric.data.HeteroData` with:

- Node types: `LandTerritory`, `SeaZone`. (Optionally `Factory`, `UnitStack` later — start simple.)
- Edge types: `land_to_land`, `sea_to_sea`, `land_to_sea_amphib`, `sea_to_land_amphib`, `canal`.
- Node features: see **§6.2**.
- Edge features: see **§6.2**.
- Global tensor: round, phase, current_player, acting_power one-hot, money per power, IPC income per power, war-declaration bits.

Apply per-power feature rotation (canonical form, **§3.7**) here at observation construction time.

### 6.2 Feature schemas (initial)

**Node features** (per territory/sea zone, ~40 floats):

- One-hot owner per "rotated power slot" (6 floats: mover, +1, +2, ..., +5).
- IPC value (1 float).
- Per-unit-type counts per rotated power slot (6 powers × ~10 unit types = 60 floats; trim to active unit types per ruleset).
- Factory present + factory damage (2 floats).
- AA gun present (1 float).
- Capital flag (1 float).
- Original-owner-of-rotated-mover flag (1 float).
- Victory city flag (1 float).
- Sea zone flag (1 float).
- Convoy zone IPC value (1 float).

**Edge features** (per edge, ~5 floats):

- Edge-type one-hot.
- Distance (always 1 in A&A, but useful for unified API).
- Canal-controlled-by-mover flag (for canal edges).

**Global features** (~30 floats):

- Round number (normalized).
- Phase one-hot.
- Money on hand per rotated power slot.
- IPC income per rotated power slot.
- Tech tokens per rotated power slot.
- War-declaration matrix bits.

These are starting points. Iterate based on what ProAI consults; ProAI's heuristics are themselves a feature-engineering hint sheet.

### 6.3 `model.encoder.HeteroGNN`

- 4–8 layers of **HGT** (Heterogeneous Graph Transformer) or **R-GCN** via `torch_geometric.nn`. HGT is preferred — it handles heterogeneous edges and global attention naturally.
- Hidden dim: 128 → 256 → 512 as you scale.
- Add a global **readout** token: virtual node connected to all real nodes, OR a global mean+max+attention pool over node embeddings, concatenated with the global feature MLP output.
- Output: per-node embeddings `h_v` + global embedding `h_global`.

### 6.4 `model.decoder.PlanDecoder`

Autoregressive plan generator. **DipNet-shaped**: at each step, condition on (encoder output, sub-actions emitted so far) and produce one sub-action.

```
class PlanDecoder(nn.Module):
    def step(
        self,
        node_emb: Tensor,        # [N_nodes, D]
        global_emb: Tensor,      # [D]
        prefix: list[int],       # sub-actions emitted so far (autoregressive context)
        legal_mask: Tensor,      # [N_legal_subactions], bool
        legal_subactions: Tensor # [N_legal_subactions], int32 — what each logit slot maps to
    ) -> Categorical:
        ...
```

Internally:

- A small **transformer** over `[global_emb] + [emb of each prefix sub-action]`. Sub-action embedding = (opcode_emb + node_emb_of_referenced_nodes + unit_type_emb).
- Final hidden state attends over **legal sub-actions** (each represented by its corresponding node/edge embeddings + opcode embedding) to produce logits.
- **Mask invalid sub-actions to −∞** before softmax. This is non-negotiable.

`sample_plan(state, temperature, max_len)`:

1. Encode state once → `(node_emb, global_emb)`.
2. Loop: sample next sub-action from `step(...).distribution`, apply via `env.apply_subaction`, append to prefix, recompute legal mask.
3. Stop on `FINALIZE` or `max_len`.
4. Return `(plan, log_prob_sum)`.

`sample_K_plans(state, K, temperature)`:

- Naïve: K independent samples. Diversity via temperature.
- Better: **stochastic beam search** (Kool et al., 2019) — proper unbiased sampling without replacement, gives diverse plans cheaply.
- Always include in the candidate set:
  - The ProAI plan (1 slot).
  - The previous root's best plan if iterating (1 slot).
  - Up to K−2 sampled plans from the policy.

### 6.5 `model.heads.ValueHead`

MLP `global_emb → scalar`, tanh-bounded to [−1, +1], trained with MSE against terminal team outcome.

### 6.6 `mcts.search` — Sampled AlphaZero with chance nodes

Three node types:

- `DecisionNode`: state, list of (plan, prior, visits, total_value, child_node).
- `ChanceNode`: state, list of (sampled_outcome_state, visits, total_value).
- `TerminalNode`: state, terminal value.

**Decision node expansion**:

1. Call `sample_K_plans(state, K)` → K plans + log-probs + ProAI plan (always included).
2. Convert log-probs to priors via softmax over the K candidates (note: this is a sampled distribution; the importance-correction in the policy loss handles the bias).
3. Initialize each child with `prior=π(plan)`, `visits=0`, `value=0`.

**Chance node expansion** (after `Purchase+CM` decision):

- **Single-sample mode** (start here): pick a fresh seed, call `clone() + resolve_combat(seed)`, recurse on the resulting decision node. The same chance node may have many child outcomes over many visits — store them in a dict keyed by outcome hash, or just keep the most recent + accumulate value.
- **Stratified mode** (later optimization): sample N=8–16 outcomes upfront, weight by `ts_combat_outcome_distribution`.

**Selection**: standard PUCT.

```
PUCT(plan) = Q(plan) + c_puct * π(plan) * sqrt(N_parent) / (1 + N_plan)
```

with `c_puct ≈ 1.25 * log((N_parent + c_base + 1) / c_base) + c_init`, `c_base=19652`, `c_init=1.25` (AlphaZero defaults).

**Dirichlet noise**: at the root only, mix `0.75 * π + 0.25 * Dirichlet(α)` with `α ≈ 0.3 / K`. Crucial for exploration.

**Virtual loss** (for parallel MCTS): subtract a virtual visit count from in-flight branches to discourage worker collisions. Crib the formula from LightZero `ptree_az.py`.

**Leaf evaluation**:

```
v_leaf = λ * v_net(state) + (1 - λ) * proai_rollout(state, K_turns=4..8)
```

with `λ` annealed linearly from 0.0 (early training) to 1.0 (when v_net surpasses ProAI). Use `proai_value(state)` as a cheap fallback for rollout truncation horizon.

**Reference math sources** (read these before writing the file):

- LightZero `lzero/mcts/ptree/ptree_az.py` — PUCT, Dirichlet, virtual loss details.
- OpenSpiel `open_spiel/python/algorithms/mcts.py` — clean reference, chance-node handling.
- Hubert et al. 2021 §4 — Sampled AlphaZero importance correction in the policy loss.

### 6.7 `train.losses`

```python
def alphazero_loss(
    pred_plan_logits: Tensor,       # [B, K] over the K sampled plans at root
    target_visits: Tensor,           # [B, K] visit counts from MCTS
    sample_log_probs: Tensor,        # [B, K] log-prob each plan was sampled with (for IS correction)
    pred_value: Tensor,              # [B]
    target_outcome: Tensor,          # [B] in {-1, +1}
) -> dict[str, Tensor]:
    # Importance-weighted policy CE (Hubert §4)
    target_policy = target_visits / target_visits.sum(-1, keepdim=True)
    is_weights = (target_policy.detach() / sample_log_probs.exp()).clamp(max=10.0)
    policy_loss = -(is_weights * target_policy * F.log_softmax(pred_plan_logits, -1)).sum(-1).mean()

    value_loss = F.mse_loss(pred_value, target_outcome)

    return {"policy": policy_loss, "value": value_loss, "total": policy_loss + value_loss}
```

The exact IS formulation should be cross-checked against Hubert §4 before relying on it; this is the part where it's easiest to be subtly wrong.

### 6.8 `train.self_play` (Ray-based)

- N self-play actors, each holding their own `AAEnv` (independent Odin `GameState` via FFI).
- Each actor runs MCTS-driven games, writes `(state, root_plan_distribution, sample_log_probs, eventual_outcome, acting_power)` tuples to the central replay buffer.
- Opponent-pool ε-mixing: with probability ε, the opposing team's moves come from `env.proai_plan()` instead of from MCTS+net. **Mark these transitions and exclude them from the policy target** — we don't want to imitate ProAI here, we want to beat it. Anneal ε from 0.5 → 0.1 over training.

### 6.9 `train.trainer`

Standard AZ loop:

```
loop:
    collect_games(N_games)              # via Ray
    for _ in range(train_steps_per_iter):
        batch = replay.sample(batch_size)
        loss = alphazero_loss(model(batch), batch.targets)
        loss.backward(); optimizer.step()
    if iter % checkpoint_every == 0:
        save_checkpoint()
        eval_vs_proai(N_games=20)
```

### 6.10 `train.bc_pretrain` (run once, before RL)

- Generate 10–50k ProAI-vs-ProAI games via `tools/generate_proai_games.py`.
- For each `(state, proai_plan)`, train the policy decoder supervised with teacher-forcing on the plan sequence (token-by-token cross-entropy on sub-actions, masked to legal).
- Save checkpoint → consumed by RL trainer as `model.init_checkpoint`.

### 6.11 `train.value_pretrain` (run once, before RL)

- For each state in the BC dataset, also store the eventual game outcome (already known from the ProAI-vs-ProAI rollout that produced the state).
- Train value head supervised with MSE: `v_net(state) ≈ outcome`.
- Can be combined into one pretraining pass with BC since both heads share the encoder.

### 6.12 `train.eval`

- Round-robin tournament: `current_checkpoint` vs `ProAI` (both sides), N games.
- Report: win rate, avg game length, avg TUV margin.
- This is the **primary** progress metric — Elo within self-play is unreliable, vs-ProAI win rate is ground truth.

---

## 7. ProAI integration (the four uses, summarized)

| Use | When | What it touches | Cost |
|---|---|---|---|
| **BC pretraining** | Once, before RL | Policy decoder | One weekend of game generation |
| **Value pretraining** | Once, before RL | Value head | Same dataset as BC |
| **Opponent pool** | During RL collection | Self-play data distribution | Cheap, one ProAI plan per ε-sampled turn |
| **MCTS leaf rollouts** | Online, during search | MCTS leaf value estimates | **Expensive**: K_turns rollout per leaf; truncate to 4–8 turns; anneal weight λ → 1 |
| **MCTS prior mixing** *(optional)* | Online, during expansion | Plan candidate set | One ProAI plan per decision node — cheap if ProAI plan generation is cheap |

ProAI plan injection into the K candidate set at every decision node is **the cheapest and most robust** of these. Implement it from day one. Leaf rollouts are the most expensive but the most powerful for cold-start; gate behind a config flag and benchmark.

---

## 8. Build & validation order

Do these in order. **Do not skip ahead.** Each step validates assumptions for the next.

### Step 1: Tic-Tac-Toe smoke test
- Implement custom MCTS (`mcts/`) + tiny MLP model + minimal `AAEnv`-compatible TTT env.
- No GNN, no plan decoder, no chance nodes, no ProAI.
- Train to perfect play (achievable in minutes on CPU).
- Cross-check value estimates against OpenSpiel's TTT solver.
- **Goal**: validates PUCT, Dirichlet, replay buffer, training loop, checkpointing.

### Step 2: Connect Four or 9×9 Go (optional but recommended)
- Same code, different env.
- Validates that the MCTS framework generalizes beyond TTT before adding A&A complexity.

### Step 3: Odin FFI shell
- Implement `ts_new`, `ts_clone`, `ts_free`, `ts_current_player`, `ts_is_terminal`, `ts_team_reward` only.
- `tools/benchmark_clone.py`: measure clone cost on Global 1940 state. **If >100µs, stop and optimize the Odin engine first** — clone cost dominates everything else.

### Step 4: Toy A&A env
- 5 land territories + 2 sea zones, 2 powers (1 vs 1), infantry + tank only, deterministic combat (use `seed=0` and treat combat as deterministic), no purchase phase.
- Implement remaining FFI: sub-actions, observation, finalize.
- Build `model/encoder.py` (small HGT) and `model/decoder.py` (small autoregressive head, ~5 sub-actions per plan max).
- Run Sampled AlphaZero. Verify it learns to beat random.

### Step 5: Add chance nodes
- Enable stochastic combat on the toy env.
- Implement `mcts/chance.py` single-sample expansion.
- Verify training is still stable. Variance may require larger batch / more sims.

### Step 6: ProAI integration on a real ruleset
- Switch to **1942.2** (smaller than Global 1940, real ruleset, ProAI works well on it).
- Implement `ts_proai_plan_for_phase`, `ts_proai_rollout`, `ts_proai_value_estimate`.
- Generate 5k ProAI-vs-ProAI games. Run BC + value pretraining.
- Run RL with ProAI in opponent pool + ProAI plan injection. Measure vs-ProAI win rate.
- **Success criterion**: pretrained-only (no RL) checkpoint plays at ProAI strength; after RL, checkpoint exceeds ProAI by ≥10% win rate.

### Step 7: Scale to Global 1940
- Add ITA as 6th power. Verify per-power rotation handles 6 powers cleanly.
- Generate larger ProAI dataset (30k+ games).
- Add MCTS leaf rollouts (with annealing schedule).
- Train. Periodically eval vs ProAI.

### Step 8: Iterate on architecture
Only after step 7 is stable, consider:
- Larger encoder (more layers, larger hidden dim).
- Stochastic MuZero variant for combat (in LightZero, separate experiment).
- Stratified chance-node sampling.
- Player-of-Games-style CFR layer if hidden-info aspects of the ruleset matter.

---

## 9. Why custom code, not a framework fork

Inventoried code reuse from the most attractive candidate (LightZero):

| Component | Reusable from LightZero? |
|---|---|
| Env wrapper | No — A&A's HeteroData graph + plan-as-action doesn't fit |
| GNN encoder | No — it's our model |
| Autoregressive plan decoder | No — no framework ships this |
| Sampled AlphaZero MCTS | Partial — LightZero's Sampled AZ assumes flat discrete actions; we'd modify substantially |
| Chance nodes for AlphaZero | No — LightZero has chance nodes only in the MuZero family |
| ProAI hooks (BC, opponent pool, leaf rollouts, prior mixing) | No — frameworks have no concept of "external expert" |
| Replay buffer / checkpoint / orchestration | Yes — but standard library code, easy to write |
| Training loop / optimizer / mixed precision | Yes — but PyTorch directly is fine |

**Net**: forking LightZero saves ~20% of the code and costs ~50% in adapter-fighting. Custom code (~2k LOC) using LightZero and OpenSpiel as **reference implementations** is the right balance. See §6.6 for which specific files to read for reference math.

---

## 10. Dependencies

```toml
# pyproject.toml — minimal set
[project]
dependencies = [
  "torch>=2.4",
  "torch_geometric>=2.5",
  "ray[default]>=2.9",
  "hydra-core>=1.3",
  "wandb>=0.16",
  "numpy>=1.26",
  "pytest>=8.0",
  "tqdm",
]
```

Optional / later:

- `lightzero` — install only as a reference; not imported in production code.
- `open_spiel` — install for the Tic-Tac-Toe oracle in tests.

---

## 11. Performance targets (rough, for sanity-checking)

These are guesses to calibrate against, not requirements. Measure and iterate.

| Operation | Target |
|---|---|
| `ts_clone` on Global 1940 state | < 50 µs |
| `ts_apply_subaction` | < 10 µs |
| `ts_proai_plan_for_phase` (Global 1940 turn) | < 50 ms |
| `ts_proai_rollout(K_turns=6)` | < 500 ms |
| GNN forward pass (HGT, ~1000 nodes, batch=64) on RTX 3090 | < 20 ms |
| MCTS sims/sec per worker | > 50 |
| Self-play games/hour (16 workers, 200 sims/move) | > 50 |

If clone or ProAI rollout is much slower than this, the bottleneck is in the Odin engine and that's where to spend effort.

---

## 12. Things that are easy to get wrong (read before debugging)

1. **Dirichlet noise must be added at the root only**, after softmax over the K sampled plans (not over the full action space). Α scales with 1/K.
2. **Per-power feature rotation must rotate every per-power feature plane** — missing one (e.g., money) leaks identity and breaks parameter sharing.
3. **Value targets must be from the perspective of the player at that state**, not always from team-0's perspective. Standard AZ bug.
4. **Importance correction in the policy loss** (Sampled AZ) is the part most likely to be subtly wrong. Cross-check against Hubert et al. §4 explicitly.
5. **Legal-action mask must be applied at every autoregressive step**, not just at the end. An illegal sub-action mid-plan corrupts the rest.
6. **`ts_apply_subaction` must reject illegal actions**, not crash or produce undefined behavior. The Python side trusts the legal-mask; the engine side must enforce it as defense in depth.
7. **MCTS must use `clone()` then `apply()`**, not `apply()` then `undo()`, **unless** the engine has a bullet-proof undo stack. Half-implemented undo is a debugging nightmare.
8. **Random seeds**: per-rollout, per-combat, per-MCTS-search. Log them. Make every stochastic step replayable from a seed.
9. **ProAI in opponent pool data must be excluded from policy targets** but **included in value targets** (the outcome is still the outcome). This is easy to mess up.
10. **Java fidelity**: the Odin engine is a port. If the engine produces a result that disagrees with the Java engine, the Odin code is wrong. See `/memories/java-fidelity-rule.md`.

---

## 13. Open questions to resolve with the user

These were not nailed down in the design conversation. Surface them before committing to the affected component:

- **Which ruleset to target first?** Plan assumes 1942.2 → Global 1940. Confirm.
- **Is ITA always present?** Plan rotates 6 powers; if some rulesets have 5, the rotation logic must handle variable N.
- **Bid handling?** Bids are pre-game decisions. Plan ignores them initially; treat bids as a separate, optional outer decision later.
- **Tech rolls?** Plan includes `TECH_ROLL` opcode but treats tech as low priority. Confirm.
- **Editor / political actions?** Out of scope unless explicitly added.
- **Training hardware target?** Plan assumes single workstation (1× RTX 3090/4090, 16+ CPU cores). Multi-GPU is straightforward later but changes nothing architecturally.

---

## 14. Reference reading list

Before writing each component, the implementing agent should read:

- **Sampled AlphaZero**: Hubert et al., 2021, *Learning and Planning in Complex Action Spaces* (arXiv:2104.06303).
- **DipNet** (architecture template for plan decoder): Paquette et al., 2019, *No-Press Diplomacy: Modeling Multi-Agent Gameplay* (NeurIPS 2019).
- **Cicero** (more recent Diplomacy work, supplementary materials show updated GNN+decoder): Bakhtin et al., 2022, *Human-level play in Diplomacy* (Science).
- **AlphaZero**: Silver et al., 2017, *Mastering Chess and Shogi by Self-Play with a General Reinforcement Learning Algorithm* (arXiv:1712.01815).
- **Stochastic beam search** (for diverse plan sampling): Kool, van Hoof, Welling, 2019.
- **HGT**: Hu et al., 2020, *Heterogeneous Graph Transformer*.
- **LightZero source**: `lzero/mcts/ptree/ptree_az.py`, `lzero/policy/sampled_alphazero.py` — read for PUCT / virtual loss / Dirichlet implementation details.
- **OpenSpiel source**: `open_spiel/python/algorithms/mcts.py` — read for chance-node handling.
- **TripleA ProAI source**: `~/todin/triplea/game-app/game-core/src/main/java/games/strategy/triplea/ai/pro/...` — read to understand what ProAI considers, which informs feature engineering and reward shaping.

---

## 15. First commit — what the implementing agent should produce

The first commit should establish the skeleton, not deliver a working trainer. Specifically:

1. `pyproject.toml` with the dependency list from §10.
2. Empty package skeletons matching §5.
3. `triplea_odin/ffi.py` with `ctypes` declarations matching §4.1 (functions can return `NotImplementedError` if the Odin side isn't ready).
4. `triplea_odin/env.py` with the `AAEnv` class **interface** from §6.1, all methods stubbed.
5. A working **Tic-Tac-Toe** env implementing the same `AAEnv` interface (no Odin, pure Python — for validating MCTS).
6. `mcts/` skeleton with type signatures.
7. `tests/test_mcts_tictactoe.py` that's expected to fail until step 1 of §8 is complete.
8. This `plan.md` checked in.

After the skeleton, follow §8 step by step.

---

## 16. Out of scope for v1

- Bidding, political actions, editor actions.
- Custom maps beyond the standard rulesets.
- Distributed multi-machine training (single-workstation only).
- Web UI or visualization beyond a basic game-replay tool.
- Imperfect-information handling (tech rolls treated as fully observed; opponent purchases revealed at place phase as in TripleA).
- Online play against humans (post-v1 deployment concern).

---

End of plan.
