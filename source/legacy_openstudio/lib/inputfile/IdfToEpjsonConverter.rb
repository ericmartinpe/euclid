require 'tmpdir'
require 'fileutils'
require 'json'

module LegacyOpenStudio

  # Utility class for converting between IDF and epJSON formats using EnergyPlus
  class IdfToEpjsonConverter
    
    # Convert epJSON file to IDF using EnergyPlus --convert-only
    # @param epjson_path [String] Path to epJSON file
    # @param idf_path [String] Output path for IDF file
    # @param add_comments [Boolean] Whether to add field definition comments (default: true)
    # @return [String, nil] Path to created IDF file, or nil on failure
    def self.convert_to_idf(epjson_path, idf_path, add_comments = true)
      return nil unless File.exist?(epjson_path)
      
      # Get EnergyPlus executable path
      energyplus_exe = Plugin.energyplus_path
      unless energyplus_exe && File.exist?(energyplus_exe)
        puts "ERROR: EnergyPlus executable not found"
        return nil
      end
      
      puts "Converting epJSON to IDF using EnergyPlus..."
      puts "  Input: #{epjson_path}"
      puts "  Output: #{idf_path}"
      
      # Create temp directory for conversion
      temp_dir = Dir.mktmpdir
      temp_epjson = File.join(temp_dir, File.basename(epjson_path))
      FileUtils.cp(epjson_path, temp_epjson)
      
      # Run EnergyPlus converter in temp directory
      original_dir = Dir.pwd
      begin
        Dir.chdir(temp_dir)
        
        # Run: energyplus --convert-only input.epjson
        cmd = "\"#{energyplus_exe}\" --convert-only \"#{File.basename(temp_epjson)}\""
        output = `#{cmd} 2>&1`
        exit_status = $?.exitstatus
        
        if exit_status != 0
          puts "ERROR: EnergyPlus conversion failed with exit code #{exit_status}"
          puts output
          return nil
        end
        
        # Find the IDF file created by EnergyPlus
        # Look for any .idf file in the temp directory
        temp_idf = nil
        Dir.entries(temp_dir).each do |file|
          if file =~ /\.idf$/i
            temp_idf = File.join(temp_dir, file)
            break
          end
        end
        
        unless temp_idf
          # No IDF file found - list what files are in the directory
          puts "ERROR: EnergyPlus did not create IDF file"
          puts "Files in temp directory:"
          Dir.entries(temp_dir).each { |f| puts "  #{f}" }
          puts "\nEnergyPlus output:"
          puts output
          return nil
        end
        
        # Copy to final destination
        FileUtils.cp(temp_idf, idf_path)
        puts "Successfully converted to: #{idf_path}"
        
        # Add field definition comments and sort if requested
        if add_comments
          format_and_sort_idf(idf_path, epjson_path)
        end
        
        return idf_path
        
      ensure
        Dir.chdir(original_dir)
        FileUtils.rm_rf(temp_dir)
      end
      
    rescue => e
      puts "ERROR during epJSON to IDF conversion: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      nil
    end
    
    # Format and sort IDF file using epJSON schema
    # @param idf_path [String] Path to IDF file
    # @param epjson_path [String] Path to source epJSON file (to detect version)
    # @return [Boolean] True if successful, false otherwise
    def self.format_and_sort_idf(idf_path, epjson_path = nil)
      return false unless File.exist?(idf_path)
      
      puts "Formatting and sorting IDF file..."
      
      # Get schema file path
      schema_path = get_schema_path(idf_path, epjson_path)
      unless schema_path
        puts "WARNING: epJSON schema not found, skipping formatting"
        return false
      end
      
      # Load schema
      schema = JSON.parse(File.read(schema_path))
      
      # Parse IDF
      idf_objects = parse_idf_file(idf_path)
      
      # Get object order from schema
      object_order = get_object_order_from_schema(schema)
      
      # Sort objects
      sorted_objects = sort_idf_objects(idf_objects, object_order)
      
      # Format and write IDF with proper comments and line endings
      formatted_text = format_idf_objects(sorted_objects, schema)
      
      # Write with proper line endings (CRLF on Windows, LF on Unix)
      File.open(idf_path, 'wb') do |file|
        file.write(formatted_text)
      end
      
      puts "IDF formatted and sorted successfully"
      true
      
    rescue => e
      puts "ERROR formatting IDF: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      false
    end
    
    private
    
    # Get path to epJSON schema file
    # @param idf_path [String] Path to IDF file
    # @param epjson_path [String] Optional path to epJSON file to detect version
    # @return [String, nil] Path to schema file
    def self.get_schema_path(idf_path, epjson_path = nil)
      # Try to detect version from IDF or epJSON
      version = detect_version_from_idf(idf_path)
      
      unless version
        # Try epJSON if provided
        if epjson_path && File.exist?(epjson_path)
          epjson_data = JSON.parse(File.read(epjson_path))
          if epjson_data["Version"]
            version_obj = epjson_data["Version"].values.first
            if version_obj && version_obj["version_identifier"]
              version_str = version_obj["version_identifier"].to_s
              parts = version_str.split('.')
              parts[2] ||= '0'
              version = parts.join('-')
            end
          end
        end
      end
      
      # Default to latest version if not found
      version ||= "25-1-0"
      
      # Construct path to schema in plugin directory
      schema_path = File.join(Plugin.dir, "energyplus", version, "Energy+.schema.epJSON")
      
      # Fall back to latest if specific version not found
      unless File.exist?(schema_path)
        schema_path = File.join(Plugin.dir, "energyplus", "25-1-0", "Energy+.schema.epJSON")
      end
      
      File.exist?(schema_path) ? schema_path : nil
    end
    
    # Detect EnergyPlus version from IDF file
    # @param idf_path [String] Path to IDF file
    # @return [String, nil] Version string like "25-1-0"
    def self.detect_version_from_idf(idf_path)
      content = File.read(idf_path, encoding: 'UTF-8')
      
      # Look for Version object
      if content.match(/Version\s*,\s*[\r\n]*\s*([\d\.]+)\s*;/i)
        version = $1
        parts = version.split('.')
        parts[2] ||= '0'
        return parts.join('-')
      end
      
      nil
    end
    
    # Parse IDF file into array of object hashes
    # @param idf_path [String] Path to IDF file
    # @return [Array<Hash>] Array of objects with :class and :fields
    def self.parse_idf_file(idf_path)
      content = File.read(idf_path, encoding: 'UTF-8')
      objects = []
      
      # Remove full-line comments but keep inline comments for now
      lines = []
      content.each_line do |line|
        # Skip full-line comments (lines starting with !)
        next if line.strip.start_with?('!')
        lines << line
      end
      content = lines.join
      
      # Split by semicolons to get objects
      raw_objects = content.split(';')
      
      raw_objects.each do |obj_text|
        obj_text = obj_text.strip
        next if obj_text.empty?
        
        # Split by commas and remove inline comments
        fields = obj_text.split(',').map do |field|
          # Remove inline comments
          field = field.split('!')[0] if field.include?('!')
          field.strip
        end
        
        next if fields.empty?
        
        class_name = fields[0]
        objects << {
          class: class_name,
          fields: fields
        }
      end
      
      objects
    end
    
    # Get object type ordering from schema
    # @param schema [Hash] Parsed epJSON schema
    # @return [Hash] Map of object type to sort index
    def self.get_object_order_from_schema(schema)
      order = {}
      index = 0
      
      # schema["properties"] contains all object types
      if schema["properties"]
        schema["properties"].keys.each do |object_type|
          order[object_type.upcase] = index
          index += 1
        end
      end
      
      order
    end
    
    # Sort IDF objects by class and optionally by name
    # @param objects [Array<Hash>] Array of IDF objects
    # @param object_order [Hash] Map of object type to sort index
    # @return [Array<Hash>] Sorted array of IDF objects
    def self.sort_idf_objects(objects, object_order)
      objects.sort_by do |obj|
        class_name = obj[:class].upcase
        obj_name = obj[:fields].length > 1 ? obj[:fields][1] : ""
        
        # Get order index, use large number if not in schema
        order_index = object_order[class_name] || 9999
        
        # Sort by: 1) schema order, 2) object name, 3) all fields (for uniqueness)
        [order_index, obj_name.to_s.upcase, obj[:fields].join('|')]
      end
    end
    
    # Format IDF objects with field comments
    # @param objects [Array<Hash>] Array of IDF objects
    # @param schema [Hash] Parsed epJSON schema
    # @return [String] Formatted IDF text
    def self.format_idf_objects(objects, schema)
      text = ""
      indent = "  "
      rjust_col = 29  # Column where field comments start
      
      objects.each do |obj|
        class_name = obj[:class]
        fields = obj[:fields]
        
        # Get field definitions from schema
        field_defs = get_field_definitions(schema, class_name)
        min_fields = get_min_fields(schema, class_name)
        
        # Find last non-blank field beyond min_fields
        last_field_num = nil
        if fields.length > min_fields
          (min_fields...fields.length).reverse_each do |i|
            if fields[i] && !fields[i].strip.empty?
              last_field_num = i
              break
            end
          end
        end
        
        # Write object
        fields.each_with_index do |field, idx|
          if idx == 0
            # Class name
            text << "#{field},\n"
          else
            # Data field
            field_value = fix_number(field)
            
            # Determine if this is the last field
            is_last = (idx == fields.length - 1) || (last_field_num && idx == last_field_num)
            field_end = is_last ? ";" : ","
            
            # Get field name
            field_name = field_defs[idx - 1] if idx - 1 < field_defs.length
            field_name ||= "Extended Field"
            
            # Format with proper spacing
            padding = [0, rjust_col - field_value.length].max
            comment = padding > 0 ? "!-".rjust(padding) : " !-"
            
            text << "#{indent}#{field_value}#{field_end}#{comment} #{field_name}\n"
            
            # Stop if we hit last meaningful field
            break if last_field_num && idx == last_field_num
          end
        end
        
        text << "\n"  # Blank line after each object
      end
      
      text
    end
    
    # Get field definitions for an object type from schema
    # @param schema [Hash] Parsed epJSON schema
    # @param class_name [String] Object class name
    # @return [Array<String>] Array of field names
    def self.get_field_definitions(schema, class_name)
      return [] unless schema["properties"] && schema["properties"][class_name]
      
      obj_def = schema["properties"][class_name]
      
      # Check for legacy_idd field information
      if obj_def["legacy_idd"] && obj_def["legacy_idd"]["fields"]
        fields = obj_def["legacy_idd"]["fields"]
        field_info = obj_def["legacy_idd"]["field_info"] || {}
        
        # Map field IDs to field names
        return fields.map do |field_id|
          if field_info[field_id] && field_info[field_id]["field_name"]
            field_info[field_id]["field_name"]
          else
            # Convert field_id to readable name
            field_id.to_s.split('_').map(&:capitalize).join(' ')
          end
        end
      end
      
      []
    end
    
    # Get minimum fields for an object type
    # @param schema [Hash] Parsed epJSON schema
    # @param class_name [String] Object class name
    # @return [Integer] Minimum number of fields
    def self.get_min_fields(schema, class_name)
      return 999 unless schema["properties"] && schema["properties"][class_name]
      
      obj_def = schema["properties"][class_name]
      min_fields = obj_def["min_fields"] || obj_def["minFields"]
      
      return min_fields.to_i if min_fields
      
      # Default to large number to include all fields
      999
    end
    
    # Check if string represents a number
    # @param value [String] Value to check
    # @return [Boolean] True if value is a number
    def self.is_number?(value)
      return false unless value.is_a?(String)
      return false if value.strip.empty?
      
      # Use regex to check if it looks like a number
      # Matches: integers, decimals, scientific notation, negative numbers
      value.strip =~ /^-?\d+\.?\d*([eE][+-]?\d+)?$/
    end
    
    # Fix number formatting - convert to cleanest representation
    # @param value [String] Field value
    # @return [String] Fixed value
    def self.fix_number(value)
      return value unless value.is_a?(String)
      return value unless is_number?(value)
      
      # Parse as number
      num = Float(value)
      
      # Check if it's essentially an integer
      if num == num.to_i
        return num.to_i.to_s
      end
      
      # Format with appropriate precision (remove trailing zeros)
      formatted = sprintf("%.12g", num)
      return formatted
    end
    
  end

end
