class_name QuakeMapReader

# Utility class for parsing a quake .map file into a QuakeMap instance
# Separate from the import code to allow for runtime usage

const OPEN_BRACKET = '('
const CLOSE_BRACKET = ')'

func read_map_file(file: File, valve_uvs: bool = false, bitmask_format: int = 0) -> QuakeMap:
	QodotUtil.debug_print('Reading map file')

	if(valve_uvs):
		QodotUtil.debug_print('Using Valve 220 UV format')

	match bitmask_format:
		QodotEnums.BitmaskFormat.QUAKE_2:
			QodotUtil.debug_print('Using Quake 2 bitmask format')
		QodotEnums.BitmaskFormat.HEXEN_2:
			QodotUtil.debug_print('Using Hexen 2 bitmask format')
		QodotEnums.BitmaskFormat.DAIKATANA:
			QodotUtil.debug_print('Using Daikatana bitmask format')

	var map_entities = []

	var parse = true
	while(parse):
		var line = read_line(file)

		if(line == null):
			parse = false
		elif(line.substr(0, 1) == '{'):
			map_entities.append(read_entity(file, valve_uvs, bitmask_format))

	return QuakeMap.new(map_entities)

func read_entity(file: File, valve_uvs: bool, bitmask_format: int) -> QuakeEntity:
	QodotUtil.debug_print('Reading entity section')
	var entity_properties = {}
	var entity_brushes = []

	var parse = true
	while(parse):
		var line = read_line(file)

		if(line == null):
			parse = false
		elif(line_is_property(line)):
			var key = line_property_key(line)
			var val = line_property_value(line)

			match key:
				'origin':
					var val_comps = val.split(' ')
					entity_properties[key] = parse_point(val)
				'angle':
					entity_properties[key] = float(val)
				_:
					entity_properties[key] = val

			QodotUtil.debug_print([key, ': ', entity_properties[key]])
		elif(line_starts_with(line, '{')):
			entity_brushes.append(read_brush(file, valve_uvs, bitmask_format))
		elif(line_starts_with(line, '}')):
			QodotUtil.debug_print('End of entity section')
			parse = false

	print(entity_properties)

	return QuakeEntity.new(entity_properties, entity_brushes)

func read_brush(file: File, valve_uvs: bool, bitmask_format: int) -> QuakeBrush:
	QodotUtil.debug_print('Reading brush section')
	var brush_planes = []

	var parse = true
	while(parse):
		var line = read_line(file)

		if(line == null):
			parse = false
		elif(line_starts_with(line, '(')):
			brush_planes.append(parse_plane(line, valve_uvs, bitmask_format))
		elif(line_starts_with(line, '}')):
			QodotUtil.debug_print('End of brush section')
			parse = false

	return QuakeBrush.new(brush_planes)

func parse_plane(line: String, valve_uvs: bool, bitmask_format: int) -> QuakePlane:
	QodotUtil.debug_print(['Plane: ', line])

	# Parse points
	var first_open_bracket = line.find(OPEN_BRACKET, 0)
	var second_open_bracket = line.find(OPEN_BRACKET, first_open_bracket + 1)
	var third_open_bracket = line.find(OPEN_BRACKET, second_open_bracket + 1)

	var first_close_bracket = line.find(CLOSE_BRACKET, 0)
	var second_close_bracket = line.find(CLOSE_BRACKET, first_close_bracket + 1)
	var third_close_bracket = line.find(CLOSE_BRACKET, second_close_bracket + 1)

	var first_point = parse_point(line.substr(first_open_bracket + 2, first_close_bracket - first_open_bracket - 2))
	var second_point = parse_point(line.substr(second_open_bracket + 2, second_close_bracket - second_open_bracket - 2))
	var third_point = parse_point(line.substr(third_open_bracket + 2, third_close_bracket - third_open_bracket - 2))

	var points = [first_point, second_point, third_point]
	QodotUtil.debug_print(['Points: ', points])

	# Parse other stuff
	var loose_params = Array(line.substr(third_close_bracket + 2, line.length()).split(' '))
	QodotUtil.debug_print(['Loose params: ', loose_params])

	var texture = String(loose_params.pop_front())
	QodotUtil.debug_print(['Texture: ', texture])

	var uv = null
	if(valve_uvs):
		loose_params.pop_front()
		var u = PoolRealArray([
			loose_params.pop_front(),
			loose_params.pop_front(),
			loose_params.pop_front(),
			loose_params.pop_front()
		])
		loose_params.pop_front()
		loose_params.pop_front()
		var v = PoolRealArray([
			loose_params.pop_front(),
			loose_params.pop_front(),
			loose_params.pop_front(),
			loose_params.pop_front()
		])
		loose_params.pop_front()

		uv = PoolRealArray([
			u[0], u[1], u[2], u[3],
			v[0], v[1], v[2], v[3]
		])
	else:
		uv = PoolRealArray([loose_params.pop_front(), loose_params.pop_front()])

	QodotUtil.debug_print(['UV: ', uv])

	var rotation = float(loose_params.pop_front())
	QodotUtil.debug_print(['Rotation: ', rotation])

	var scale = Vector2(loose_params.pop_front(), loose_params.pop_front())
	QodotUtil.debug_print(['Scale: ', scale])

	var surface = -1
	var content = -1
	var color = -1
	var hexen_2_param = -1

	match bitmask_format:
		QodotEnums.BitmaskFormat.HEXEN_2:
			hexen_2_param = int(loose_params.pop_front())
			QodotUtil.debug_print(['Unknown Hexen 2 Parameter: ', hexen_2_param])

		QodotEnums.BitmaskFormat.QUAKE_2:
			if(loose_params.size() > 0):
				surface = int(loose_params.pop_front())
				QodotUtil.debug_print(['Surface: ', surface])

			if(loose_params.size() > 0):
				content = int(loose_params.pop_front())
				QodotUtil.debug_print(['Content: ', content])

		QodotEnums.BitmaskFormat.DAIKATANA:
			if(loose_params.size() > 0):
				surface = int(loose_params.pop_front())
				QodotUtil.debug_print(['Surface: ', surface])

			if(loose_params.size() > 0):
				content = int(loose_params.pop_front())
				QodotUtil.debug_print(['Content: ', content])

			if(loose_params.size() > 0):
				color = int(loose_params.pop_front())
				QodotUtil.debug_print(['Color: ', color])

	return QuakePlane.new(points, texture, uv, rotation, scale, surface, content, color, hexen_2_param)

func parse_point(point_substr: String) -> Vector3:
	var comps = point_substr.split(' ')
	return Vector3(comps[1], comps[2], comps[0])

func read_line(file: File):
	if(file.eof_reached()):
		QodotUtil.debug_print('EOF Reached')
		return null

	var line = file.get_line()
	QodotUtil.debug_print(line)
	if(line.substr(0, 2) == '//'):
		return read_line(file)
	return line

func line_starts_with(line: String, prefix: String):
	return line.substr(0, prefix.length()) == prefix

func escape_property_name(property_name):
	return '"' + property_name + '"'

func line_is_property(line):
	return line_starts_with(line, '"')

func line_property_key(line):
	return line.substr(1, line.find('"', 1) - 1)

func line_property_value(line):
	var escaped_quote = '"'
	var first_quote = line.find(escaped_quote)
	var second_quote = line.find(escaped_quote, first_quote + 1)
	var third_quote = line.find(escaped_quote, second_quote + 1)
	var fourth_quote = line.find(escaped_quote, third_quote + 1)
	return line.substr(third_quote + 1, line.length() - (third_quote + 2))
