package oaaa

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "base:intrinsics"

save_json :: proc(game_state: ^Game_State, path: string = "game_state.json") {
	//fmt.printfln("%#v", game_state)
	json_data, err := json.marshal(game_state^, {pretty = true, use_enum_names = false})
	if err != nil {
		fmt.eprintfln("Unable to marshal JSON: %v", err)
		intrinsics.debug_trap()
		os.exit(1)
	}

	//fmt.printfln("%s", json_data)
	fmt.printfln("Writing: %s", path)
	success := os.write_entire_file(path, json_data)
	if success != true {
		fmt.eprintfln("Unable to write file: %v", success)
		intrinsics.debug_trap()
		os.exit(1)
	}

	fmt.println("Done")
}

load_game_data :: proc(game_state: ^Game_State, path: string = "game_state.json") -> (ok: bool) {
	data, read_ok := os.read_entire_file_from_filename(path)
	defer delete(data)
	if !read_ok {
		fmt.eprintln("Failed to load the file!")
		intrinsics.debug_trap()
		return false
	}
	// Parse the json file.
	json_data, err := json.parse(data)
	defer json.destroy_value(json_data)
	if err != .None {
		fmt.eprintln("Failed to parse the json file.")
		fmt.eprintln("Error:", err)
		intrinsics.debug_trap()
		return false
	}
	// local_game_state := game_state
	json.unmarshal(data, game_state)
	return true
}
