@icon("./resource_library.svg")
@tool
class_name ResourceLibrary extends Resource

var _data:Dictionary

func get_data(property:StringName) -> Variant:
	if not _data:
		rescan()
	return _data.get(property)
			 

## override to change root folder to scan
func _get_scan_base_path() -> String: 
	return resource_path.get_base_dir()

## override to change key for file
func _scan_name(path:String) -> StringName:
	return path.get_basename().get_file()

## override to change stored data or return null to store no data for this file
func _scan_file(path:String) -> Variant:
	if not path.get_extension()=="tres":
		return null
		
	return ResourceLoader.load(path) as Resource

func rescan() -> void:
	#print("rescan: "+resource_path)
	var prev_data = _data
	_data = {}
	_scan_folder(_get_scan_base_path())
	notify_property_list_changed()
	if Engine.is_editor_hint() and not resource_path.is_empty() and _data!=prev_data:
		ResourceSaver.save(self)
	
func _get_property_list() -> Array[Dictionary]:
	if Engine.is_editor_hint():
		rescan()
	return Passthrough.static_get_property_list(self, [_data])

func _get(property:StringName) -> Variant:
	return Passthrough.static_get(property, self, [_data], null)

func _set(property:StringName, value:Variant) -> bool:
	return Passthrough.static_set(property, value, self, [_data], null)

func _scan_folder(path:String):
	#print("%s: scan_folder(%s)" % [resource_path, path])
	
	if path.is_empty():
		return	
		
	var dir = DirAccess.open(path)
	dir.list_dir_begin()
	while true:
		var file_name = dir.get_next()
		if file_name.is_empty(): 
			break
		
		var file_path = dir.get_current_dir().path_join(file_name)
		if file_path == resource_path:
			continue

		#print("%s: scan_folder(%s): %s" % [resource_path, path, file_path])

		if dir.current_is_dir():
			_scan_folder(file_path)
			continue
		
		var name = _scan_name(file_path)
		if name in _data or name.is_empty():
			continue
		
		var file_data = _scan_file(file_path)
		if file_data:
			_data[name] = file_data
