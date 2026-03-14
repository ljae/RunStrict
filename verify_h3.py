import h3
hex_id = '892834705a7ffff'
parent_res5 = '85283473fffffff'
actual_parent = h3.cell_to_parent(hex_id, 5)
print(f"Hex: {hex_id} (Res {h3.get_resolution(hex_id)})")
print(f"Claimed Parent Res 5: {parent_res5}")
print(f"Actual Parent Res 5: {actual_parent}")
print(f"Match: {parent_res5 == actual_parent}")

district_parent = h3.cell_to_parent(hex_id, 6)
print(f"Actual District Parent Res 6: {district_parent}")
