
## Appendix D: Turn Overview

1. Purchase Phase
- g_purchased_units: [dynamic]Purchased_Units
- AND g_purchased_factories: [dynamic]Land_ID
2. Combat Move Phase
- options: ^[dynamic]Attack_Option
- bitset of air_id of territories to attack (1 of 2)
- inf[src_air_id][dst_land_id]count
- art[src_air_id][dst_land_id]count
- tank[src_air_id][dst_land_id]count
- fighter[src_air_id][dst_air_id]count
- bomber[src_land_id][dst_air_id]count
- sub[src_sea_id][dst_sea_id]count
- destroyer[src_sea_id][dst_sea_id]count
- cruiser[src_sea_id][dst_sea_id]count
- battleship[src_sea_id][dst_sea_id]count
- damaged_bs[src_sea_id][dst_sea_id]count
- carrier[src_sea_id][dst_sea_id]count
- (TODO - how do 2 step load/unload transport amphibious assaults work?)
3. Non-Combat Move Phase
- [src_air_id][dst_air_id][idle_unit_type]count
