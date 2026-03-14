import h3
short_id = '89283472a9'
try:
    print(f"Is valid? {h3.is_valid_cell(short_id)}")
except:
    print("Parsing failed")

long_id = '89283472a93ffff'
print(f"Long ID: {long_id}")
print(f"Long ID valid? {h3.is_valid_cell(long_id)}")
