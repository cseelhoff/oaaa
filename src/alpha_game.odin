/*
python code for calling this odin game functions

from __future__ import print_function
import sys
sys.path.append('..')
from Game import Game
import numpy as np
import ctypes
from ctypes import c_int, c_float, c_void_p, c_bool, POINTER

class OAAAGame(Game):
    def __init__(self):
        # Load the compiled Odin library
        self.lib = ctypes.CDLL('./liboaaa.so')  # or .dll on Windows
        
        # Set up function signatures
        self.lib.get_init_board.restype = c_void_p

        self.lib.get_board.restype = POINTER(c_float)

        self.lib.get_board_size.restype = (c_int, c_int)

        self.lib.get_action_size.restype = c_int

        self.lib.get_next_state.argtypes = [c_void_p, c_int, c_int]
        self.lib.get_next_state.restype = (c_void_p, c_int)

        self.lib.get_valid_moves.argtypes = [c_void_p, c_int]
        self.lib.get_valid_moves.restype = POINTER(c_bool)

        self.lib.get_game_ended.argtypes = [c_void_p, c_int]
        self.lib.get_game_ended.restype = c_float

        self.lib.get_canonical_form.argtypes = [c_void_p, c_int]
        self.lib.get_canonical_form.restype = POINTER(c_float)

        self.lib.get_string_representation.argtypes = [c_void_p]
        self.lib.get_string_representation.restype = c_char_p
        
    def getInitBoard(self):
        return self.lib.get_init_board()
        
    def getBoardSize(self):
        return self.lib.get_board_size()
        
    def getActionSize(self) -> c_int:
        return self.lib.get_action_size()
        
    def getNextState(self, board, player, action):
        return self.lib.get_next_state(board, player, action)
        
    def getGameEnded(self, board, player) -> c_float:
        return self.lib.get_game_ended(board, player)
        
    def getValidMoves(self, board, player) -> np.ndarray:
        moves_ptr = self.lib.get_valid_moves(board, player)
        size = self.getActionSize()
        # Convert the C boolean array to numpy array of bools
        return np.ctypeslib.as_array(moves_ptr, shape=(size,)).astype(bool)
        
    def getCanonicalForm(self, board, player)-> np.ndarray:
        canonicalBoard_ptr = self.lib.get_canonical_form(board, player)
        x, y = self.getBoardSize()
        # Convert the C array to numpy array
        return np.ctypeslib.as_array(canonicalBoard_ptr, shape=(x, y))
        
    def getSymmetries(self, board, pi):
        # mirror, rotational
        # If no meaningful symmetries exist in OAAA
        return [(board, pi)]
        
    def stringRepresentation(self, board) -> string:
        return self.lib.get_string_representation(board).decode('utf-8')
*/

package oaaa

import "base:runtime"
import "core:fmt"

// Export these functions with C calling convention for Python interop
@(export)
get_init_board :: proc "c" () -> rawptr {
	context = runtime.default_context()
	// fmt.println("get_init_board")
	gs := new(Game_State)
	load_default_game_state(gs)
	return gs
}

GAME_STATE_SIZE :: 13712

@(export)
get_board_size :: proc "c" () -> (x: i32, y: i32) {
	context = runtime.default_context()
	// fmt.println("get_board_size")
	// Return the dimensions of the board representation
	// This could be based on number of territories + state variables
	return i32(GAME_STATE_SIZE), i32(1)
}

@(export)
get_action_size :: proc "c" () -> i32 {
	context = runtime.default_context()
	// fmt.println("get_action_size")
	// Return total number of possible actions
	// This includes all possible moves for all unit types
	return i32(len(Action_ID)) // You'll need to define this constant based on your game rules
}

@(export)
get_next_state :: proc "c" (board: rawptr, player: i32, action: i32) -> (rawptr, i32) {
	context = runtime.default_context()
	// fmt.println("get_next_state")
	// Apply action and return new state
	gs := (^Game_State)(board)
	new_gs := new(Game_State) // todo maybe not needed?
	new_gs^ = gs^
	action_id := (Action_ID)(action)
	apply_action(new_gs, action_id)
    player := mm.team[new_gs.cur_player] == .Allies ? 1:-1
	return new_gs, i32(player)
}

@(export)
get_valid_moves :: proc "c" (board: rawptr, player: i32) -> [^]bool {
	context = runtime.default_context()
	// fmt.println("get_valid_moves")
	// Return binary vector of valid moves
	gs := (^Game_State)(board)
	new_gs := new(Game_State) // todo maybe not needed?
	defer free(new_gs)
	new_gs^ = gs^
    actions := get_possible_actions(new_gs)^

    //convert bitset of bool to new([dynamic]bool)
    moves := new([MAX_ACTIONS]bool)
    for action in actions {
        moves[action] = true
    }
	return raw_data(moves)
}

@(export)
get_game_ended :: proc "c" (board: rawptr, player: i32) -> f32 {
	context = runtime.default_context()
	// fmt.println("get_game_ended")
	// Check win/loss/draw state
	// Return 0 for ongoing, 1 for win, -1 for loss, small value for draw
	gs := (^Game_State)(board)
    score := evaluate_state(gs)
	team := (1 - player) / 2 // player = -1 -> team = Axis, player = 1 -> team = Allies
    if mm.team[gs.cur_player] == Team_ID(team) {
		// if score > 0.99 {
		// 	return 1
		// } else if score < 0.01 {
		// 	return -1
		// }
		// return 0
        return f32(score)
    }
	// if score > 0.99 {
	// 	return -1
	// } else if score < 0.01 {
	// 	return 1
	// }
	// return 0
	return f32(score * -1)
}

@(export)

get_canonical_form :: proc "c" (board: rawptr, player: i32) -> rawptr {
	context = runtime.default_context()
	// fmt.println("get_canonical_form")
	return board
}

@(export)
board_ptr_to_f32_array :: proc "c" (board: rawptr, player: i32) -> [^]f32 {
	context = runtime.default_context()
	// fmt.println("board_ptr_to_f32_array")
	// Return canonical form of board state as float array
	gs := (^Game_State)(board)
	canon_board := new([GAME_STATE_SIZE]f32) // Explicitly size the array
	
	// Convert game state to float array representation
	idx := 0
	
	// Convert active armies to floats
	for location in Land_ID {
		for army in Active_Army {
			canon_board[idx] = f32(gs.active_armies[location][army])
			idx += 1
		}
	}
	
	// Convert active ships to floats
	for location in Sea_ID {
		for ship in Active_Ship {
			canon_board[idx] = f32(gs.active_ships[location][ship])
			idx += 1
		}
	}
	
	// Convert active land planes to floats
	for location in Land_ID {
		for plane in Active_Plane {
			canon_board[idx] = f32(gs.active_land_planes[location][plane])
			idx += 1
		}
	}
	
	// Convert active sea planes to floats
	for location in Sea_ID {
		for plane in Active_Plane {
			canon_board[idx] = f32(gs.active_sea_planes[location][plane])
			idx += 1
		}
	}

	// Convert idle armies to floats
	for location in Land_ID {
		for player in Player_ID {
			for army in Idle_Army {
				canon_board[idx] = f32(gs.idle_armies[location][player][army])
				idx += 1
			}
		}
	}

	// Convert idle land planes to floats
	for location in Land_ID {
		for player in Player_ID {
			for plane in Idle_Plane {
				canon_board[idx] = f32(gs.idle_land_planes[location][player][plane])
				idx += 1
			}
		}
	}

	// Convert idle sea planes to floats
	for location in Sea_ID {
		for player in Player_ID {
			for plane in Idle_Plane {
				canon_board[idx] = f32(gs.idle_sea_planes[location][player][plane])
				idx += 1
			}
		}
	}

	// Convert idle ships to floats
	for location in Sea_ID {
		for player in Player_ID {
			for ship in Idle_Ship {
				canon_board[idx] = f32(gs.idle_ships[location][player][ship])
				idx += 1
			}
		}
	}

	// Convert rejected_moves_from bitsets
	for location in Air_ID {	
		canon_board[idx] = f32(gs.smallest_allowable_action[location])
		idx += 1
	}

	// Convert territory ownership
	for location in Land_ID {
		canon_board[idx] = f32(gs.owner[location])
		idx += 1
	}

	// Convert player money
	for player in Player_ID {
		canon_board[idx] = f32(gs.money[player])
		idx += 1
	}

	// Convert max_bombards
	for location in Land_ID {
		canon_board[idx] = f32(gs.max_bombards[location])
		idx += 1
	}

	// Convert factory damage
	for location in Land_ID {
		canon_board[idx] = f32(gs.factory_dmg[location])
		idx += 1
	}

	// Convert factory production
	for location in Land_ID {
		canon_board[idx] = f32(gs.factory_prod[location])
		idx += 1
	}

	// Convert builds left
	for location in Land_ID {
		canon_board[idx] = f32(gs.builds_left[location])
		idx += 1
	}

	// Convert random seed
	canon_board[idx] = f32(gs.seed)
	idx += 1

	// Convert combat state bitsets
	for land in Land_ID {
		canon_board[idx] = land in gs.more_land_combat_needed ? 1.0 : 0.0
		idx += 1
	}
	for sea in Sea_ID {
		canon_board[idx] = sea in gs.more_sea_combat_needed ? 1.0 : 0.0
		idx += 1
	}
	for land in Land_ID {
		canon_board[idx] = land in gs.land_combat_started ? 1.0 : 0.0
		idx += 1
	}
	for sea in Sea_ID {
		canon_board[idx] = sea in gs.sea_combat_started ? 1.0 : 0.0
		idx += 1
	}

	// Convert current player
	canon_board[idx] = f32(gs.cur_player)
	idx += 1

	// fmt.println(idx)
	
	return raw_data(canon_board)
}

@(export)
get_symmetries :: proc "c" (board: rawptr, pi: rawptr) -> rawptr {
	context = runtime.default_context()
	// fmt.println("get_symmetries")
	// Return list of symmetric positions and corresponding policies
	// For OAAA, this might just return the original position if no meaningful symmetries exist
	gs := (^Game_State)(board)
	return gs
}

@(export)
get_string_representation :: proc "c" (board: rawptr) -> cstring {
	context = runtime.default_context()
	// fmt.println("get_string_representation")
	// Convert game state to string for MCTS hashing
	gs := (^Game_State)(board)
	gc : Game_Cache = {}
    load_cache_from_state(&gc, gs)
	str := game_state_to_string(&gc)
	return cstring(raw_data(transmute([]u8)str))
}
