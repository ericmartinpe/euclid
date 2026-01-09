# Phase 2 Implementation Complete: ModelManager and File Dialog Updates

## Files Modified

### 1. ModelManager.rb
**Location:** `source/legacy_openstudio/lib/ModelManager.rb`

**Changes Made:**

#### Added Required Files
```ruby
require("euclid/lib/legacy_openstudio/lib/inputfile/EpJsonFile")
require("euclid/lib/legacy_openstudio/lib/inputfile/JsonInputObject")
require("euclid/lib/legacy_openstudio/lib/inputfile/InputObjectAdapter")
```

#### Updated `open_input_file(path)` Method
- **Detection:** Automatically detects file type by extension
- **epJSON Support:** Uses `EpJsonFile.open()` for .epJSON and .json files
- **IDF Support:** Uses `InputFile.open()` for .idf files (unchanged)
- **Transparent:** Rest of code works the same regardless of file type

**Code:**
```ruby
# Detect file type from extension
if is_epjson_file?(path)
  # Open as epJSON file
  @input_file = EpJsonFile.open(path, progress_callback)
else
  # Open as IDF file
  @input_file = InputFile.open(Plugin.data_dictionary, path, progress_callback)
end
```

#### Added `is_epjson_file?(path)` Helper Method
```ruby
def is_epjson_file?(path)
  return false if path.nil?
  ext = File.extname(path).downcase
  return ext == '.epjson' || ext == '.json'
end
```

#### Updated `input_file_name` Method
- Changed default extension from `.idf` to `.epJSON`
- New files will default to epJSON format

#### Updated `merge_input_file(path)` Method
- Added validation to prevent merging incompatible file types
- Shows user-friendly error messages:
  - "Cannot merge IDF file into epJSON file"
  - "Cannot merge epJSON file into IDF file"

### 2. CommandManager.rb
**Location:** `source/legacy_openstudio/lib/CommandManager.rb`

**Changes Made:**

#### Updated File Open Dialog
**Before:**
```ruby
UI.open_panel("Open EnergyPlus Input File", dir, "EnergyPlus|*.idf|All Files|*.*||")
```

**After:**
```ruby
UI.open_panel("Open EnergyPlus Input File", dir, 
  "EnergyPlus epJSON|*.epJSON;*.json|EnergyPlus IDF|*.idf|All Files|*.*||")
```

**User Experience:**
- epJSON format is listed FIRST (preferred format)
- Users can still select IDF files
- File filter shows both `.epJSON` and `.json` extensions

#### Updated Merge Dialog
Same changes applied to the merge file dialog for consistency.

## How It Works

### Opening Files

1. **User selects file** via Extensions > Euclid > Open Input File
2. **File dialog** shows epJSON as first option, IDF as second
3. **ModelManager detects** file type by extension
4. **Appropriate handler** is selected:
   - `.epJSON` or `.json` → `EpJsonFile`
   - `.idf` → `InputFile`
5. **File is opened** and geometry is drawn (same code for both!)

### File Type Detection Flow

```
User selects: "test_simple_zone.epJSON"
    ↓
is_epjson_file?("test_simple_zone.epJSON")
    ↓
File.extname → ".epJSON"
    ↓
downcase → ".epjson"
    ↓
matches '.epjson' → TRUE
    ↓
Use EpJsonFile.open()
```

### Saving Files

When saving:
- If path has `.epJSON`/`.json` extension → saves as epJSON
- If path has `.idf` extension → saves as IDF
- Format is determined by the extension user chooses in save dialog

## Testing

### Test File Provided
`test_simple_zone.epJSON` - Ready to test opening in SketchUp

### Manual Test Steps

1. **Build the plugin:**
   ```bash
   rake build
   ```

2. **Install the .rbz in SketchUp:**
   - Extensions > Extension Manager > Install Extension
   - Navigate to `build/package/euclid-0.9.4.4-mac-*.rbz`

3. **Open epJSON file:**
   - Extensions > Euclid > Open Input File
   - Select `test_simple_zone.epJSON`
   - Should see: Zone_1 with Wall_South and Floor surfaces

4. **Verify geometry:**
   - Zone should appear in model
   - Surfaces should be visible
   - No errors in Ruby Console

### Expected Results

✅ File dialog shows epJSON as first option  
✅ Can select and open .epJSON files  
✅ Can select and open .idf files (backward compatible)  
✅ File opens with progress dialog  
✅ Geometry appears in SketchUp model  
✅ Can still save files (preserves format)  

## Backward Compatibility

### IDF Files Still Work
- All existing IDF workflows unchanged
- Can still open .idf files
- Can still save .idf files
- No breaking changes

### Migration Path
Users can:
1. Continue using IDF files
2. Start using epJSON for new models
3. Gradually transition to epJSON
4. Mix both formats in different projects

## Next Steps (Phase 3)

To make geometry editing work with epJSON files, we need to update the interface classes:

### Priority Interface Classes:
1. **DrawingInterface.rb** - Add adapter helper methods
2. **Zone.rb** - Update to use adapter
3. **BaseSurface.rb** - Update vertices handling
4. **SubSurface.rb** - Update for windows/doors
5. **DetachedShadingSurface.rb** - Update for shading

### Approach:
Each interface class needs to:
- Create InputObjectAdapter when working with input objects
- Use adapter methods instead of direct field access
- Handle both IDF and epJSON transparently

Example update for Zone.rb:
```ruby
# Old way (IDF only):
@input_object.fields[2] = north_axis

# New way (both formats):
adapter = InputObjectAdapter.new(@input_object)
adapter.set_field(2, north_axis)
# or
adapter.set_field("direction_of_relative_north", north_axis)
```

## Files Modified Summary

**Modified (2 files):**
- `source/legacy_openstudio/lib/ModelManager.rb`
  - Added requires for epJSON classes
  - Updated `open_input_file()` to detect and handle both formats
  - Added `is_epjson_file?()` helper method
  - Updated `input_file_name` default to .epJSON
  - Updated `merge_input_file()` with type validation

- `source/legacy_openstudio/lib/CommandManager.rb`
  - Updated file open dialog filter to include epJSON
  - Updated merge dialog filter to include epJSON

**Build Status:** ✅ Successful  
**Package Created:** `euclid-0.9.4.4-mac-699876c.rbz`

## Key Benefits

✅ **Automatic Detection:** No user configuration needed  
✅ **Transparent:** Same code path after file is opened  
✅ **User-Friendly:** Better file dialog with clear format options  
✅ **Safe:** Prevents mixing incompatible file types  
✅ **Modern:** epJSON is EnergyPlus's current preferred format  
✅ **Backward Compatible:** IDF still fully supported  

---

**Status: Phase 2 Complete** ✅  
**Ready for: Phase 3 - Interface Class Updates**
