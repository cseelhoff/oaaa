package oaaa

import "core:fmt"
import "core:math"

// EXPLORATION_CONSTANT :: 1.414
EXPLORATION_CONSTANT :: 0.5

Children :: [dynamic]^MCTSNode

MCTSNode :: struct {
	state:    Game_State,
	children: Children,
	parent:   ^MCTSNode,
	value:    f64,
	visits:   int,
	action:   u8,
}

check5 := false

create_node :: proc(state: ^Game_State, action: u8, parent: ^MCTSNode) -> ^MCTSNode {
	node := new(MCTSNode)
	node.state = state^ //memcopy
	node.action = action
	node.parent = parent
	node.visits = 0
	node.value = 0.0
	return node
}

// static void free_node(MCTSNode* node) {
//   free_state(&node->state);
//   free(node->children);
//   free(node);
// }

select_best_leaf :: proc(root_node: ^MCTSNode) -> (node: ^MCTSNode) {
	node = root_node
	for len(node.children) > 0 {
		best_value: f64 = -999999.0
		best_child: ^MCTSNode = nil
		children := node.children
		children_len := len(children)
		for child in node.children {
			uct_value: f64 =
				child.value / f64(child.visits + 1) +
				EXPLORATION_CONSTANT *
					math.sqrt(math.ln_f64(f64(node.visits + 1)) / f64(child.visits + 1))
			if uct_value > best_value {
				best_value = uct_value
				best_child = child
			}
		}
		node = best_child
	}
	return node
}

PRINT_INTERVAL :: 10000
//import "core:math/rand"
mcts_search :: proc(initial_state: ^Game_State, iterations: int) -> ^MCTSNode {
	root := create_node(initial_state, 0, nil)
	for MCTS_ITERATIONS in 0 ..< iterations {
		if MCTS_ITERATIONS % PRINT_INTERVAL == 0 {
			fmt.println("Iteration ", MCTS_ITERATIONS)
			print_mcts(root)
		}
		node := select_best_leaf(root)
		if !is_terminal_state(&node.state) {
			expand_node(node)
			children_len := len(node.children)
			node = node.children[RANDOM_NUMBERS[GLOBAL_RANDOM_SEED] % children_len]
			GLOBAL_RANDOM_SEED = (GLOBAL_RANDOM_SEED + 1) % RANDOM_MAX
		}
		result: f64 = random_play_until_terminal(&node.state)
		for node != nil {
			node.visits += 1
			if node.parent != nil && node.parent.state.cur_player % 2 == 0 { 	//test is Allies turn?
				node.value += result
			} else {
				node.value += 1 - result
			}
			node = node.parent
		}
	}
	return root
}
import sa "core:container/small_array"
expand_node :: proc(node: ^MCTSNode) {
	num_actions := 0
	actions := get_possible_actions(&node.state)
	for next_action in sa.slice(&actions) {
		if next_action > MAX_VALID_ACTIONS {
			fmt.eprintln("Invalid action ", next_action)
		}
		//new_state := clone_state(&node.state)
		new_node := create_node(&node.state, next_action, node)
		apply_action(&new_node.state, next_action)
		append(&node.children, new_node)
	}
}
MAX_ACTION_SEQUENCES :: 20
MAX_ACTIONS :: 1000
Action_Sequence :: [MAX_ACTIONS]u8
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

copy_full_array :: proc(src: ^[MAX_ACTIONS]u8, dest: ^[MAX_ACTIONS]u8) {
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
	VISITS_WIDTH := 8
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
		fmt.print(PLAYER_DATA[node.parent.state.cur_player].color)
		fmt.print("Action:")
		if node.action < LANDS_COUNT {
			fmt.print(LANDS_DATA[node.action].name)
		} else if node.action < TERRITORIES_COUNT {
			fmt.print(SEAS_DATA[node.action - LANDS_COUNT])
		} else {
			fmt.print(Buy_Action(node.action - TERRITORIES_COUNT))
		}
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
	for i in 0 ..< depth {
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
	//  current_sequence: Action_Sequence = {}
	// for i in 0..<MAX_ACTION_SEQUENCES {
	//   action_sequence_values[i] = 0;
	//   action_sequence_visits[i] = 0;
	// }
	// print_mcts_tree(root, 0, &current_sequence, 0);
	print_mcts_tree3(root, 0)
	// print_top_action_sequences();
}

select_best_action :: proc(root: ^MCTSNode) -> u8 {
	best_child: ^MCTSNode = nil
	best_value: f64 = -999999.0
	for child in root.children {
		if child.value > best_value {
			best_value = child.value
			best_child = child
		}
	}
	return best_child.action
}
