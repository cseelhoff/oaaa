package oaaa

check_positive_active_ships :: proc(gc: ^Game_Cache, sea: Sea_ID) {
  for ship, ship_idx in gc.active_ships[sea] {
    if ship < 0 {
      panic("Negative active ships")
    }
  }
}