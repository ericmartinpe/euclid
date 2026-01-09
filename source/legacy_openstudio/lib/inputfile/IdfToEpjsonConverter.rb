# OpenStudio
# Copyright (c) 2008-2015, Alliance for Sustainable Energy.  All rights reserved.
# Copyright (c) 2017-2020, Big Ladder Software LLC. All rights reserved.
# See the file "License.txt" for additional terms and conditions.

require 'fileutils'
require 'json'

module LegacyOpenStudio

  # Converts IDF files to epJSON format using Ruby parser and JSON schema
  class IdfToEpjsonConverter
    
    @@schema_cache = {}
    
    # Detect EnergyPlus version from epJSON file
    # @param epjson_data [Hash] Parsed epJSON data
    # @return [String] Version string like "25-1-0", or "25-1-0" as default
    def self.detect_version_from_epjson(epjson_data)
      # Check for Version object
      if epjson_data["Version"]
        version_obj = epjson_data["Version"].values.first
        if version_obj && version_obj["version_identifier"]
          version = version_obj["version_identifier"]
          # Convert "25.1.0" to "25-1-0"
          return version.gsub('.', '-')
        end
      end
      
      # Default to 25.1.0 if no version found
      "25-1-0"
    end
    
    # Detect EnergyPlus version from IDF file content
    # @param idf_path [String] Path to IDF file
    # @return [String] Version string like "25-1-0", or "25-1-0" as default
    def self.detect_version_from_idf(idf_path)
      # Read first 5000 chars to find Version object
      content = File.read(idf_path, 5000)
      
      # Look for Version object: Version,\n  25.1.0;
      if content.match(/Version,\s*[\r\n]+\s*([\d\.]+)\s*;/i)
        version = $1
        return version.gsub('.', '-')
      end
      
      # Default to 25.1.0 if no version found
      "25-1-0"
    rescue
      "25-1-0"
    end
    
    # Get the energyplus directory for a specific version
    # @param version [String] Version string like "25-1-0"
    # @return [String] Path to energyplus version directory
    def self.get_energyplus_dir(version)
      if defined?(Plugin) && Plugin.respond_to?(:dir)
        base_dir = File.join(Plugin.dir, "energyplus", version)
      else
        # For testing outside SketchUp
        base_dir = File.join(File.dirname(__FILE__), "..", "..", "energyplus", version)
      end
      
      File.expand_path(base_dir)
    end
    
    # Load the EnergyPlus JSON schema which contains IDD field mappings
    # @param version [String] Optional version string like "25-1-0" (defaults to 25-1-0)
    # @return [Hash, nil] Parsed schema or nil if not found
    def self.load_schema(version = "25-1-0")
      # Return cached schema if already loaded
      return @@schema_cache[version] if @@schema_cache[version]
      
      # Find schema file in version-specific directory
      energyplus_dir = get_energyplus_dir(version)
      schema_path = File.join(energyplus_dir, "Energy+.schema.epJSON")
      
      unless File.exist?(schema_path)
        puts "Warning: JSON schema not found at #{schema_path}"
        puts "         IDF conversion will use FieldMapper fallback"
        return nil
      end
      
      puts "Loading JSON schema from: #{schema_path}"
      schema_content = File.read(schema_path)
      @@schema_cache[version] = JSON.parse(schema_content)
      
      puts "Schema loaded: #{@@schema_cache[version]['properties'].keys.length} object types"
      @@schema_cache[version]
    end
    
    # Get field order for an object type from the schema
    # @param object_type [String] The EnergyPlus object type (e.g., "BuildingSurface:Detailed")
    # @param version [String] Optional EnergyPlus version (defaults to 25-1-0)
    # @return [Array<String>, nil] Array of field property names in IDF order
    def self.get_field_order(object_type, version = "25-1-0")
      schema = load_schema(version)
      return nil unless schema
      
      object_schema = schema.dig('properties', object_type)
      return nil unless object_schema
      
      # Get the field order from legacy_idd section
      field_order = object_schema.dig('legacy_idd', 'fields')
      
      # Handle extensible fields (like vertices)
      if extensions = object_schema.dig('legacy_idd', 'numerics', 'extensions')
        # For extensible objects, fields array doesn't include the repeated fields
        # We'll handle this specially during conversion
        return {fields: field_order || [], extensions: extensions}
      end
      
      field_order
    end
    
    # Convert an InputObject (IDF) to epJSON hash structure
    # @param input_object [InputObject] IDF object to convert
    # @param version [String] Optional EnergyPlus version (defaults to 25-1-0)
    # @return [Hash] epJSON representation
    def self.convert_object_to_epjson(input_object, version = "25-1-0")
      object_type = input_object.class_name
      epjson_obj = {}
      
      # Get field order from schema
      field_info = get_field_order(object_type, version)
      
      if field_info.is_a?(Hash) && field_info[:extensions]
        # Handle extensible objects (e.g., surfaces with vertices)
        field_order = field_info[:fields]
        extensions = field_info[:extensions]
        
        # Map regular fields
        field_order.each_with_index do |prop_name, index|
          next if prop_name == "name"  # Name is the key, not a property
          field_value = input_object.fields[index + 1]  # IDF fields are 1-indexed
          epjson_obj[prop_name] = field_value unless field_value.nil? || field_value.to_s.empty?
        end
        
        # Handle extensible fields (vertices)
        if extensions.include?("vertex_x_coordinate")
          # This is a surface with vertices
          vertices = []
          vertex_start = field_order.length + 1  # After regular fields
          
          i = vertex_start
          while i < input_object.fields.length
            x = input_object.fields[i]
            y = input_object.fields[i + 1]
            z = input_object.fields[i + 2]
            
            break if x.nil? && y.nil? && z.nil?
            
            vertices << {
              "vertex_x_coordinate" => x.to_f,
              "vertex_y_coordinate" => y.to_f,
              "vertex_z_coordinate" => z.to_f
            }
            
            i += 3
          end
          
          epjson_obj["vertices"] = vertices if vertices.any?
          epjson_obj["number_of_vertices"] = vertices.length
        end
        
      elsif field_info.is_a?(Array)
        # Regular object (non-extensible)
        field_info.each_with_index do |prop_name, index|
          next if prop_name == "name"  # Name is the key, not a property
          field_value = input_object.fields[index + 1]  # IDF fields are 1-indexed
          epjson_obj[prop_name] = field_value unless field_value.nil? || field_value.to_s.empty?
        end
        
      else
        # Schema not available - use FieldMapper as fallback
        require_relative 'FieldMapper'
        
        # This is the old adapter approach
        # Convert using best-effort field mapping
        input_object.fields.each_with_index do |value, index|
          next if index == 0  # Skip class name
          next if index == 1  # Skip name (it's the key)
          next if value.nil? || value.to_s.empty?
          
          prop_name = FieldMapper.to_property(object_type, index)
          if prop_name
            epjson_obj[prop_name] = value
          else
            # Unknown field - store with generic name
            epjson_obj["field_#{index}"] = value
          end
        end
      end
      
      epjson_obj
    end
    
    # Convert IDF file to epJSON
    # @param idf_path [String] Path to IDF file
    # @param epjson_path [String] Optional output path (defaults to same location with .epJSON extension)
    # @return [String, nil] Path to generated epJSON file, or nil on failure
    def self.convert(idf_path, epjson_path = nil)
      unless File.exist?(idf_path)
        puts "ERROR: IDF file not found: #{idf_path}"
        return nil
      end
      
      # Detect EnergyPlus version from IDF file
      version = detect_version_from_idf(idf_path)
      puts "Detected EnergyPlus version: #{version.gsub('-', '.')}"
      
      # Determine output path
      epjson_path ||= idf_path.sub(/\.idf$/i, '.epJSON')
      
      # Load the IDF file using existing InputFile parser
      require_relative 'InputFile'
      require_relative '../DataDictionary'
      
      puts "Parsing IDF file..."
      
      # Get data dictionary
      if defined?(Plugin) && Plugin.respond_to?(:data_dictionary)
        data_dict = Plugin.data_dictionary
      else
        # For testing: load dictionary from version-specific directory
        energyplus_dir = get_energyplus_dir(version)
        idd_path = File.join(energyplus_dir, "Energy+.idd")
        
        if File.exist?(idd_path)
          data_dict = DataDictionary.new
          data_dict.read_idd_file(idd_path)
        else
          puts "ERROR: Energy+.idd not found"
          return nil
        end
      end
      
      # Parse IDF
      input_file = InputFile.new(data_dict)
      input_file.open(idf_path)
      
      puts "Converting #{input_file.objects.length} objects to epJSON..."
      
      # Convert to epJSON structure
      epjson_data = {}
      
      input_file.objects.each do |obj|
        object_type = obj.class_name
        object_name = obj.name
        
        # Initialize object type hash if needed
        epjson_data[object_type] ||= {}
        
        # Convert object
        epjson_obj = convert_object_to_epjson(obj, version)
        
        # Add to epJSON structure
        epjson_data[object_type][object_name] = epjson_obj
      end
      
      # Write epJSON file
      puts "Writing epJSON file: #{epjson_path}"
      File.open(epjson_path, 'w') do |f|
        f.write(JSON.pretty_generate(epjson_data))
      end
      
      puts "Successfully converted #{File.basename(idf_path)} to epJSON"
      epjson_path
      
    rescue => e
      puts "ERROR during IDF conversion: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      nil
    end
    
    # Convert IDF file to epJSON and return the content as a hash
    # @param idf_path [String] Path to IDF file
    # @return [Hash, nil] Parsed epJSON data, or nil on failure
    def self.convert_to_hash(idf_path)
      require 'tmpdir'
      
      Dir.mktmpdir do |tmpdir|
        temp_epjson = File.join(tmpdir, "converted.epJSON")
        
        if convert(idf_path, temp_epjson)
          content = File.read(temp_epjson)
          return JSON.parse(content)
        end
      end
      
      nil
    end
    
    # Check if a file is IDF format (basic heuristic check)
    # @param file_path [String] Path to file
    # @return [Boolean] True if file appears to be IDF format
    def self.is_idf_file?(file_path)
      return false unless File.exist?(file_path)
      
      # Check file extension
      return true if file_path.match?(/\.idf$/i)
      
      # Check content - IDF files have object names followed by commas/semicolons
      # and use ! for comments
      content = File.read(file_path, 1000)  # Read first 1000 chars
      
      # Look for IDF patterns
      has_idf_comments = content.include?('!')
      has_idf_objects = content.match?(/^\s*[A-Z][A-Za-z:]+,/m)
      
      has_idf_comments && has_idf_objects
    rescue
      false
    end
  end

end
