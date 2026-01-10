#!/usr/bin/env ruby

# Test script for IDF to epJSON converter
# Run from project root: ruby test_converter.rb

# Add source directories to load path for testing
$LOAD_PATH.unshift(File.expand_path('source', __dir__))
$LOAD_PATH.unshift(File.expand_path('source/legacy_openstudio/lib', __dir__))

require_relative 'source/legacy_openstudio/lib/inputfile/IdfToEpjsonConverter'

# Test 1: Load JSON Schema
puts "=" * 60
puts "Test 1: Loading EnergyPlus JSON Schema"
puts "=" * 60

schema = LegacyOpenStudio::IdfToEpjsonConverter.load_schema

if schema
  puts "✓ Schema loaded successfully"
  puts "  Object types: #{schema['properties'].keys.length}"
else
  puts "✗ Schema not found - will use FieldMapper fallback"
end

# Test 2: Check if file is IDF
puts "\n" + "=" * 60
puts "Test 2: IDF file detection"
puts "=" * 60

test_file = "source/legacy_openstudio/NewFileTemplate.idf"
if File.exist?(test_file)
  is_idf = LegacyOpenStudio::IdfToEpjsonConverter.is_idf_file?(test_file)
  puts "#{test_file}: #{is_idf ? '✓ Detected as IDF' : '✗ Not detected as IDF'}"
else
  puts "✗ Test file not found: #{test_file}"
end

# Test 3: Check field mapping
puts "\n" + "=" * 60
puts "Test 3: Field mapping from schema"
puts "=" * 60

# Test BuildingSurface:Detailed
field_order = LegacyOpenStudio::IdfToEpjsonConverter.get_field_order("BuildingSurface:Detailed")

if field_order
  puts "✓ BuildingSurface:Detailed field mapping:"
  if field_order.is_a?(Hash)
    puts "  Regular fields: #{field_order[:fields].join(', ')}"
    puts "  Extensions: #{field_order[:extensions].join(', ')}"
  else
    puts "  Fields: #{field_order.join(', ')}"
  end
else
  puts "✗ Could not get field mapping for BuildingSurface:Detailed"
end

# Test Zone
field_order = LegacyOpenStudio::IdfToEpjsonConverter.get_field_order("Zone")
if field_order
  puts "\n✓ Zone field mapping:"
  puts "  Fields: #{field_order.join(', ')}"
else
  puts "\n✗ Could not get field mapping for Zone"
end

puts "\n" + "=" * 60
puts "Schema tests complete!"
puts "=" * 60
puts "\nNote: Full IDF conversion will be tested inside SketchUp"
puts "      where all dependencies are available."
