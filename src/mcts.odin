package oaaa

import "core:fmt"
import "core:math"

/*
AI NOTE: Monte Carlo Tree Search Implementation

Key Components:
1. Node Selection (UCT):
   - Balances exploration vs exploitation
   - Uses standard √2 exploration constant
   - Visits+1 prevents division by zero

2. State Evaluation:
   - Random playouts until decisive advantage
   - Score based on money and military assets
   - Perspective adjusted for current team

3. Search Optimization:
   - Tracks rejected moves to prune search space
   - Prevents re-exploring known bad paths
   - Helps focus on promising strategies
*/

// Standard UCT exploration constant of √2 for balanced exploration vs exploitation
EXPLORATION_CONSTANT :: 1.4142135623730950488 // math.sqrt(2)

Children :: [dynamic]^MCTSNode

MCTSNode :: struct {
	state:    Game_State,
	children: Children,
	parent:   ^MCTSNode,
	value:    f64,
	visits:   int,
	action:   Action_ID,
}

check5 := false

create_node :: proc(state: ^Game_State, action: Action_ID, parent: ^MCTSNode) -> ^MCTSNode {
	node := new(MCTSNode)
	node.state = state^ //memcopy
	node.action = action
	node.parent = parent
	node.visits = 0
	node.value = 0.0
	return node
}

select_best_leaf :: proc(root_node: ^MCTSNode) -> (node: ^MCTSNode) {
	node = root_node
	for len(node.children) > 0 {
		best_value: f64 = -999999.0
		best_child: ^MCTSNode = nil
		for child in node.children {
			// Add 1 to visits to avoid division by zero when a node is newly created (visits = 0)
			// UCT formula: exploitation_term + exploration_constant * sqrt(ln(parent_visits) / child_visits)
			uct_value: f64 =
				child.value / f64(child.visits + 1) +
				EXPLORATION_CONSTANT *// exploitation term
					math.sqrt(math.ln_f64(f64(node.visits + 1)) / f64(child.visits + 1)) // exploration term
			if uct_value > best_value {
				best_value = uct_value
				best_child = child
			}
		}
		node = best_child
	}
	return node
}

PRINT_INTERVAL :: 1000
mcts_search :: proc(initial_state: ^Game_State, iterations: int) -> ^MCTSNode {
	/*
    AI NOTE: Main MCTS Loop
    
    For each iteration:
    1. Selection: Find most promising leaf using UCT
    2. Expansion: Generate children for chosen leaf
    3. Simulation: Random playout from new state
    4. Backpropagation: Update values up the tree
    
    Key Optimizations:
    - Rejected moves tracked in gc.rejected_moves_from
    - Deterministic random numbers for reproducibility
    - Progress updates every PRINT_INTERVAL iterations
    
    Random Number Usage:
    - Child Selection: node.children[RANDOM_NUMBERS[seed] % len]
    - Seed Updates: (seed + 1) % RANDOM_MAX
    - Ensures consistent behavior across runs
    */
	root := create_node(initial_state, .Skip_Action, nil)
	for MCTS_ITERATIONS in 0 ..< iterations {
		if MCTS_ITERATIONS % PRINT_INTERVAL == 0 {
			fmt.println("Iteration ", MCTS_ITERATIONS)
			print_mcts(root)
		}
		node := select_best_leaf(root)
		if !is_terminal_state(&node.state) {
			expand_node(node)
			children_len := len(node.children)
			node = node.children[int(RANDOM_NUMBERS[GLOBAL_RANDOM_SEED]) % children_len]
			GLOBAL_RANDOM_SEED = (GLOBAL_RANDOM_SEED + 1) % RANDOM_MAX
		}
		result: f64 = random_play_until_terminal(&node.state)
		for node != nil {
			node.visits += 1
			if node.parent != nil && mm.team[node.parent.state.cur_player] == .Allies { 	//test is Allies turn?
				node.value += result
			} else {
				node.value += 1 - result
			}
			node = node.parent
		}
	}
	return root
}
expand_node :: proc(node: ^MCTSNode) {
	/*
    AI NOTE: Node Expansion with Deterministic Randomness
    
    Uses fixed random number array for reproducibility:
    1. Random Selection:
       - RANDOM_NUMBERS: Pre-generated array of values
       - GLOBAL_RANDOM_SEED: Current index into array
       - RANDOM_MAX: Array size for wrapping
    
    2. Usage:
       - Child selection during tree expansion
       - Move selection during random playouts
       - Consistent behavior for debugging
    
    3. Benefits:
       - Reproducible search behavior
       - Easier to debug and test
       - Still provides good exploration
    */
	actions := get_possible_actions(&node.state)
	for next_action in actions {
		new_node := create_node(&node.state, next_action, node)
		apply_action(&new_node.state, next_action)
		append(&node.children, new_node)
	}
}
MAX_ACTION_SEQUENCES :: 20
MAX_ACTIONS :: 1000
Action_Sequence :: [MAX_ACTIONS]Action_ID
action_sequences := [MAX_ACTION_SEQUENCES]Action_Sequence{}
action_sequence_lengths := [MAX_ACTION_SEQUENCES]int{}
action_sequence_visits := [MAX_ACTION_SEQUENCES]int{}
action_sequence_values := [MAX_ACTION_SEQUENCES]f64{}
update_top_action_sequences :: proc(
	current_sequence: ^Action_Sequence,
	length: int,
	value: f64,
	visits: int,
) {
	/*
    AI NOTE: Best Sequence Management
    
    Maintains sorted list of best action sequences:
    1. Sequence Storage:
       - Fixed-size array of top sequences
       - Each sequence includes:
         - List of actions
         - Value/visit statistics
         - Sequence length
    
    2. Update Rules:
       - New sequence must improve on existing
       - Maintains descending value order
       - Limited to MAX_ACTION_SEQUENCES
    */
	for i in 0 ..< MAX_ACTION_SEQUENCES {
		if visits > action_sequence_visits[i] {
			// Shift lower value sequences down
			for j := MAX_ACTION_SEQUENCES - 1; j > i; j -= 1 {
				action_sequence_values[j] = action_sequence_values[j - 1]
				action_sequence_lengths[j] = action_sequence_lengths[j - 1]
				copy_full_array(&action_sequences[j - 1], &action_sequences[j])
			}
			action_sequence_values[i] = value
			action_sequence_lengths[i] = length
			copy_full_array(current_sequence, &action_sequences[i])
			break
		}
	}
}

copy_full_array :: proc(src: ^[MAX_ACTIONS]Action_ID, dest: ^[MAX_ACTIONS]Action_ID) {
	for i in 0 ..< MAX_ACTIONS {
		dest[i] = src[i]
	}
}

MAX_DEPTH :: 40
MIN_VISITS :: 10000

print_mcts_tree :: proc(
	node: ^MCTSNode,
	depth: uint,
	current_sequence: ^Action_Sequence,
	length: int,
) {
	/*
    AI NOTE: Action Sequence Analysis
    
    Tracks and analyzes complete paths through MCTS tree:
    1. Sequence Building:
       - Follows most visited paths
       - Limited by MAX_DEPTH to control complexity
       - Records both actions and their values
    
    2. Sequence Selection:
       - Requires MIN_VISITS to filter noise
       - Sorted by value/visit ratio
       - Top sequences represent best strategies
    
    3. Usage:
       - Provides move suggestions to player
       - Shows alternative strategic options
       - Helps explain AI decision making
    */
	if node == nil do return
	new_length := length
	current_sequence[new_length] = node.action
	new_length += 1
	if len(node.children) == 0 || depth == MAX_DEPTH {
		update_top_action_sequences(
			current_sequence,
			new_length,
			node.value / f64(node.visits),
			node.visits,
		)
		return
	}
	has_mature_child := false
	for child in node.children {
		if child.visits > MIN_VISITS {
			has_mature_child = true
			print_mcts_tree(child, depth + 1, current_sequence, new_length)
		}
	}
	if !has_mature_child {
		update_top_action_sequences(
			current_sequence,
			new_length,
			node.value / f64(node.visits),
			node.visits,
		)
	}
}

// Function to print the top 20 action sequences
print_top_action_sequences :: proc() {
	// VISITS_WIDTH := 8
	for i in 0 ..< MAX_ACTION_SEQUENCES {
		if action_sequence_values[i] > 0 {
			fmt.print(" value:", action_sequence_values[i])
			fmt.print(" visits:", action_sequence_visits[i])
			fmt.print(" Actions:")
			for j in 1 ..< action_sequence_lengths[i] {
				fmt.print(" ", action_sequences[i][j])
			}
			fmt.println()
		}
	}
}
MAX_PRINT_DEPTH :: 40

print_mcts_tree3 :: proc(node: ^MCTSNode, depth: int) {
	if node == nil do return
	if depth > MAX_PRINT_DEPTH || len(node.children) == 0 do return
	if node.parent != nil {
		fmt.print(mm.color[node.parent.state.cur_player])
		fmt.print("Action:", node.action)
		fmt.print(", Money:", node.state.money[node.parent.state.cur_player])
		fmt.print(", Visits:", node.visits)
		fmt.print(", Value:", node.value)
		fmt.print(", Avg:", node.value / f64(node.visits))
		fmt.println(DEF_COLOR)
	}
	best_index := 0
	best_value: f64 = 0.0
	for child, i in node.children {
		new_value := child.value / f64(child.visits)
		if new_value > best_value {
			best_value = new_value
			best_index = i
		}
	}
	print_mcts_tree3(node.children[best_index], depth + 1)
}

print_mcts_tree2 :: proc(node: ^MCTSNode, depth: uint) {
	if node == nil do return
	if depth > 3 {
		return
	}
	for _ in 0 ..< depth {
		fmt.print("  ")
	}
	fmt.print("Action:", node.action)
	fmt.print(", Money:", node.state.money[node.parent.state.cur_player])
	fmt.print(", Visits:", node.visits)
	fmt.print(", Value:", node.value)
	fmt.print(", Avg:", node.value / f64(node.visits))
	fmt.println()
	for child in node.children {
		print_mcts_tree2(child, depth + 1)
	}
}

// Public function to print the MCTS tree starting from the root
print_mcts :: proc(root: ^MCTSNode) {
	print_mcts_tree3(root, 0)
}

select_best_action :: proc(root: ^MCTSNode) -> Action_ID {
	/*
    AI NOTE: Final Move Selection
    
    Standard MCTS approach:
    - Select most visited child at root
    - Visit count is most reliable metric
    - More robust than using raw value
    - Naturally balances exploration/exploitation
    */
	best_child: ^MCTSNode = nil
	most_visits: int = -1
	// 	best_value: f64 = -999999.0
	for child in root.children {
		if child.visits > most_visits {
			// 		if child.value > best_value {
			// best_value = child.value
			most_visits = child.visits
			best_child = child
		}
	}
	return best_child.action
}
