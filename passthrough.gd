## Static functions for creating "pasthrough" types
## use these to implement _get_property_list() _set() and _get()
##
## A passthrough type shows the sources of one or more sources as it's own
## These values of these members can be configured to either be
## - Read/Write 
## - Read only
## - Overridable (the source keeps its value, but this member will change)
##
## The order of lookup for members on a passthrough object in in this order:
## 1. Overrides
## 2. Members of self
## 3. Members of sources (in order) 
##
## Notes: 
## - To have a passthrough object export its members to the inspector it needs to be a @tool script
## - By default passthrough members are set to not save using
@tool
extends RefCounted
class_name Passthrough

## internal use: things in their list return default _get_property_list() 
## rather than the value normally provided by static_get_property_list if used
static var _use_default_properties:Dictionary = {}

## implementation for _get() 
## Note: To make a source read-only, don't provide it in the sources list for _get() but not _set() 
## @param property name of the property
## @param self_object a reference to self
## @param sources a list of source objects to pull members from
## @param overrides a dictionary used to contain the overrides in self
static func static_get(property:StringName, self_object:Variant, sources:Array, overrides:Variant) -> Variant:
	if not self_object in _use_default_properties:
		if overrides and property in overrides:
			return overrides[property]
		
		if not static_property_in_self(property, self_object):
			for i in range(len(sources)-1, -1, -1):
				var source = sources[i]
				if source and property in source:
					return source[property]
			
	return null


## implementation for _set() 
## Note: To make a source read-only, don't provide it in the sources list for _get() but not _set() 
## @param property name of the property
## @param value new value for the property
## @param self_object a reference to self
## @param sources a list of source objects to pull members from
## @param overrides a dictionary used to contain the overrides in self
static func static_set(property:StringName, value:Variant, self_object:Variant, sources:Array, overrides:Variant) -> bool:
	if overrides and property in overrides:
		overrides[property] = value
		return true

	if static_property_in_self(property, self_object):
		return false

	for source in sources:
		if source and property in source:
			source[property] = value
			return true
		
	return false


## Helper function to check if a property is provided by the passthrough object itself 
## rather than sources or overrides
## @param property name of the property
## @param self_object a reference to self
static func static_property_in_self(property:StringName, self_object:Object) -> bool:
	_use_default_properties.get_or_add(self_object)
	var result = property in self_object
	_use_default_properties.erase(self_object)
	return result


## Helper function to access get_property_list() for a passthrough object without
## any sources or overrides
## @param self_object a reference to self
static func static_get_self_property_list(self_object:Object) -> Array[Dictionary]:
	_use_default_properties.get_or_add(self_object)
	var result = self_object.get_property_list()
	_use_default_properties.erase(self_object)
	return result

## implementation for get_property_list() 
## @param property name of the property
## @param self_object a reference to self
## @param sources a list of source objects to pull members from
## @param source_usage_flag a dictionary containing {source: PropertyUsageFlag} items for additoinal usage flags to be added to properties
static func static_get_property_list(self_object:Object, sources:Array, source_usage_flags:Dictionary = {}) -> Array[Dictionary]:
	if self_object in _use_default_properties:
		return []

	var result:Array[Dictionary] = []
	var used_property_names:Dictionary = {}	
	for source in sources:
		var source_usage_flag = source_usage_flags.get(source, 0)
		if source is Object:
			for property in source.get_property_list():
				if property.name in used_property_names:
					continue
				used_property_names[property.name] = true
				
				if static_property_in_self(property.name, self_object):
					used_property_names[property.name] = true
					continue
					
				if property.usage & (PROPERTY_USAGE_CATEGORY|PROPERTY_USAGE_SUBGROUP) != 0:
					continue
				if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
					continue
				
				# prevent source properties being saved on the passthrough object 
				# (unless set by source_usage_flags)
				property.usage |= PROPERTY_USAGE_NO_INSTANCE_STATE | source_usage_flag
				result.append(property)
	
		elif source is Dictionary:
			for property_name in source: 
				var value = source[property_name]
				var hint_string = &""
				if value is Object:
					var script = value.get_script()
					hint_string = script.resource_path.get_file().get_basename().to_pascal_case() if script \
						else value.get_class() as StringName
				  
				result.append({
					"name": property_name,
					"type": typeof(value),
					"hint_string": hint_string,
					"usage": PROPERTY_USAGE_SCRIPT_VARIABLE|PROPERTY_USAGE_DEFAULT|source_usage_flag
				})
	return result
