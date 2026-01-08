# Phase 1 Implementation Complete: epJSON Support Core Files

## Files Created

### 1. EpJsonFile.rb
**Location:** `source/legacy_openstudio/lib/inputfile/EpJsonFile.rb`

**Purpose:** Handles reading and writing epJSON files (the JSON equivalent of IDF files)

**Key Features:**
- Uses Ruby's standard `JSON.parse()` and `JSON.pretty_generate()` - no custom parser needed!
- Mirrors the API of `InputFile.rb` for compatibility
- Supports progress callbacks during read/write operations
- Handles object reference resolution (e.g., zone_name references)
- Manages collections of objects, new objects, and deleted objects

**Key Methods:**
- `open(path)` - Read epJSON file
- `write(path)` - Write epJSON file with pretty formatting
- `add_object(object)` - Add new object
- `delete_object(object)` - Mark object as deleted
- `new_unique_object_name()` - Generate unique hex names (same as IDF)

### 2. JsonInputObject.rb
**Location:** `source/legacy_openstudio/lib/inputfile/JsonInputObject.rb`

**Purpose:** Represents a single epJSON object (equivalent to InputObject for IDF)

**Key Features:**
- Properties stored as hash instead of array (better for JSON)
- Name is separate from properties (in epJSON, name is the object key)
- Hash-like access: `object["zone_name"]` or `object.get("zone_name")`
- Automatic reference resolution for related objects
- Copy and equality methods

**Key Differences from InputObject:**
- IDF: `object.fields[4]` (positional access)
- epJSON: `object["zone_name"]` (named access)

### 3. FieldMapper.rb
**Location:** `source/legacy_openstudio/lib/inputfile/FieldMapper.rb`

**Purpose:** Maps between IDF field indices and epJSON property names

**Why Needed:**
- Interface classes currently use field indices: `@input_object.fields[4]`
- epJSON uses property names: `object["zone_name"]`
- This mapper provides the translation layer

**Example Mappings:**
```ruby
BUILDINGSURFACE:DETAILED:
  Field 1 => "name"
  Field 2 => "surface_type"
  Field 4 => "zone_name"
  Field 12+ => vertices (special handling)
```

**Key Methods:**
- `to_property(object_type, field_index)` - Convert index to property name
- `to_field_index(object_type, property_name)` - Convert property to index
- `is_vertices?(object_type, field_index)` - Check if field is vertex data
- `vertices_start_index(object_type)` - Get where vertices begin

### 4. InputObjectAdapter.rb
**Location:** `source/legacy_openstudio/lib/inputfile/InputObjectAdapter.rb`

**Purpose:** Provides unified interface to work with both IDF and epJSON objects

**Why This is Key:**
This allows interface classes to work with both formats without knowing which they're using!

**Usage Example:**
```ruby
# Old way (IDF only):
@input_object.fields[4] = zone_name

# New way (works with both):
adapter = InputObjectAdapter.new(@input_object)
adapter.set_field(4, zone_name)  # Works with both IDF and epJSON!
# or
adapter.set_field("zone_name", zone_name)  # Also works!
```

**Vertices Handling:**
The adapter handles the complex conversion between:
- IDF: Flat array `[x1, y1, z1, x2, y2, z2, ...]`
- epJSON: Array of objects `[{vertex_x_coordinate: x1, ...}, ...]`

**Key Methods:**
- `get_field(identifier)` - Get field by index or name
- `set_field(identifier, value)` - Set field by index or name
- `get_vertices()` - Get vertices as flat array
- `set_vertices(points_data)` - Set vertices from various formats
- `get_vertices_as_points()` - Get as array of Point3d objects

## Test File Created

**File:** `test_simple_zone.epJSON`

A simple test epJSON file with:
- 1 Zone
- 2 BuildingSurfaces (Wall and Floor)
- Proper vertex definitions
- Valid epJSON structure

## How It Works

### Reading an epJSON File:

```ruby
# 1. Parse JSON file
json_data = JSON.parse(File.read("model.epJSON"))

# 2. Iterate through object types
json_data.each do |object_type, instances|
  # 3. Create JsonInputObject for each instance
  instances.each do |name, properties|
    object = JsonInputObject.new(object_type, name, properties)
    objects.add(object)
  end
end

# 4. Resolve references (zone_name string => Zone object)
update_object_references()
```

### Writing an epJSON File:

```ruby
# 1. Build JSON structure
json_data = {}
objects.each do |object|
  json_data[object.class_name] ||= {}
  json_data[object.class_name][object.name] = object.to_json_hash
end

# 2. Write with pretty formatting
File.write(path, JSON.pretty_generate(json_data))
```

### Using the Adapter:

```ruby
# Interface class can now work with both formats:
adapter = InputObjectAdapter.new(@input_object)

# Set zone name (works whether @input_object is IDF or epJSON)
adapter.set_field(4, "Zone_1")  # Using field index
# OR
adapter.set_field("zone_name", "Zone_1")  # Using property name

# Set vertices (handles conversion automatically)
adapter.set_vertices(points_array)
```

## Next Steps (Phase 2)

1. **Update ModelManager** to detect file type and use appropriate handler
2. **Update CommandManager** to support .epJSON file extension in dialogs
3. **Update Interface Classes** to use InputObjectAdapter
4. **Test with SketchUp** - open test_simple_zone.epJSON

## Key Advantages of This Approach

✅ **Simple:** Uses standard Ruby JSON library - no custom parsing!
✅ **Clean:** Clear separation between IDF and epJSON code
✅ **Compatible:** Existing IDF code still works unchanged
✅ **Testable:** Easy to unit test each component
✅ **Maintainable:** Field mappings are centralized in one place
✅ **Extensible:** Easy to add more object types to FieldMapper
✅ **Robust:** Handles vertices conversion automatically

## Testing the Implementation

To test manually:

```ruby
# In Ruby console
require 'json'
require_relative 'source/legacy_openstudio/lib/Collection'
require_relative 'source/legacy_openstudio/lib/inputfile/JsonInputObject'
require_relative 'source/legacy_openstudio/lib/inputfile/EpJsonFile'

# Open test file
file = LegacyOpenStudio::EpJsonFile.open("test_simple_zone.epJSON")

# Check what was read
puts "Objects: #{file.objects.count}"
file.objects.each { |obj| puts "  #{obj.class_name}: #{obj.name}" }

# Get zone
zone = file.objects.find { |o| o.class_name == "Zone" }
puts "Zone origin: #{zone['x_origin']}, #{zone['y_origin']}, #{zone['z_origin']}"

# Get surface
surface = file.objects.find { |o| o.class_name == "BuildingSurface:Detailed" }
puts "Surface vertices: #{surface['vertices'].length}"
```

## Files Modified/Created Summary

**Created (4 new files):**
- `source/legacy_openstudio/lib/inputfile/EpJsonFile.rb`
- `source/legacy_openstudio/lib/inputfile/JsonInputObject.rb`
- `source/legacy_openstudio/lib/inputfile/FieldMapper.rb`
- `source/legacy_openstudio/lib/inputfile/InputObjectAdapter.rb`
- `test_simple_zone.epJSON` (test file)

**Next to Modify:**
- `source/legacy_openstudio/lib/ModelManager.rb`
- `source/legacy_openstudio/lib/CommandManager.rb`
- `source/legacy_openstudio/lib/interfaces/DrawingInterface.rb`
- `source/legacy_openstudio/lib/interfaces/Zone.rb`
- `source/legacy_openstudio/lib/interfaces/BaseSurface.rb`
- Other interface classes...
