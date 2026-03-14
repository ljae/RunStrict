import h3
district = '862834707ffffff'
child = '89283470003ffff'
print(f"District: {district} (Res {h3.get_resolution(district)})")
print(f"Child: {child} (Res {h3.get_resolution(child)})")
print(f"Parent of Child at Res 6: {h3.cell_to_parent(child, 6)}")
print(f"Match: {district == h3.cell_to_parent(child, 6)}")
