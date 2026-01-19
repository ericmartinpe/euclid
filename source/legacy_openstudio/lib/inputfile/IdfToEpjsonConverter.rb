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
          # Convert "25.1.0" to "25-1-0" or "25.1" to "25-1-0"
          parts = version.split('.')
          # Ensure we have major, minor, and patch (default patch to 0)
          parts[2] ||= '0'
          return parts.join('-')
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
        # Convert "25.1.0" to "25-1-0" or "25.1" to "25-1-0"
        parts = version.split('.')
        # Ensure we have major, minor, and patch (default patch to 0)
        parts[2] ||= '0'
        return parts.join('-')
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
      
      # Ruby 2.2 compatible - no dig method
      object_schema = schema['properties'] && schema['properties'][object_type]
      return nil unless object_schema
      
      # Get the field order from legacy_idd section
      legacy_idd = object_schema['legacy_idd']
      field_order = legacy_idd && legacy_idd['fields']
      
      # Handle extensible fields (like vertices)
      numerics = legacy_idd && legacy_idd['numerics']
      if numerics && (extensions = numerics['extensions'])
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
        require("euclid/lib/legacy_openstudio/lib/inputfile/FieldMapper")
        
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
      
      # Use EnergyPlus's built-in converter to convert IDF to epJSON
      # This avoids needing IDD files since EnergyPlus has the schema built-in
      puts "Converting IDF to epJSON using EnergyPlus converter..."
      
      # Find EnergyPlus installation for this version
      if (RUBY_PLATFORM =~ /mswin|mingw/)
        energyplus_exe = "C:/EnergyPlusV#{version}/energyplus.exe"
      elsif (RUBY_PLATFORM =~ /darwin/)
        energyplus_exe = "/Applications/EnergyPlus-#{version}/energyplus"
      else
        energyplus_exe = "/usr/local/EnergyPlus-#{version}/energyplus"
      end
      
      # Check if EnergyPlus exists for this version
      unless File.exist?(energyplus_exe)
        puts "ERROR: EnergyPlus #{version.gsub('-', '.')} not found at #{energyplus_exe}"
        puts "Please install EnergyPlus #{version.gsub('-', '.')} to convert IDF files"
        return nil
      end
      
      # Run EnergyPlus converter in a temp directory
      require 'tmpdir'
      temp_dir = Dir.mktmpdir
      temp_idf = File.join(temp_dir, File.basename(idf_path))
      FileUtils.cp(idf_path, temp_idf)
      
      # Run converter - EnergyPlus writes output files in the current directory
      # So we need to run it from the temp directory
      original_dir = Dir.pwd
      begin
        Dir.chdir(temp_dir)
        
        # Run: energyplus --convert-only input.idf
        # Capture both stdout and stderr
        cmd = "\"#{energyplus_exe}\" --convert-only \"#{File.basename(temp_idf)}\" 2>&1"
        puts "Running: #{cmd}"
        output = `#{cmd}`
        exit_status = $?.exitstatus
        
        puts "EnergyPlus output:"
        puts output
        
        if exit_status != 0
          puts "ERROR: EnergyPlus command failed with exit code #{exit_status}"
          Dir.chdir(original_dir)
          FileUtils.rm_rf(temp_dir)
          return nil
        end
        
        # EnergyPlus creates the epJSON with the same base name
        temp_epjson = temp_idf.sub(/\.idf$/i, '.epJSON')
        
        # Check for generated epJSON
        unless File.exist?(temp_epjson)
          puts "ERROR: EnergyPlus did not create epJSON file"
          puts "Expected: #{temp_epjson}"
          puts "Files in temp dir:"
          Dir.entries(temp_dir).each { |f| puts "  #{f}" }
          Dir.chdir(original_dir)
          FileUtils.rm_rf(temp_dir)
          return nil
        end
        
        # Copy to final destination
        FileUtils.cp(temp_epjson, epjson_path)
        puts "Successfully converted to: #{epjson_path}"
        
      ensure
        Dir.chdir(original_dir)
        FileUtils.rm_rf(temp_dir)
      end
      
      puts "Successfully converted #{File.basename(idf_path)} to epJSON"
      epjson_path
      
    rescue => e
      puts "ERROR during IDF conversion: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      nil
    end
    
    # Convert epJSON file to IDF format using EnergyPlus converter
    # @param epjson_path [String] Path to source epJSON file
    # @param idf_path [String] Path where IDF file should be saved
    # @return [String, nil] Path to created IDF file, or nil on failure
    def self.convert_to_idf(epjson_path, idf_path)
      return nil unless File.exist?(epjson_path)
      
      # Get EnergyPlus path from plugin
      energyplus_exe = nil
      if defined?(Plugin) && Plugin.respond_to?(:energyplus_path)
        energyplus_exe = Plugin.energyplus_path
      end
      
      unless energyplus_exe && File.exist?(energyplus_exe)
        puts "ERROR: EnergyPlus executable not found at: #{energyplus_exe}"
        return nil
      end
      
      puts "Converting epJSON to IDF using EnergyPlus..."
      puts "  Input: #{epjson_path}"
      puts "  Output: #{idf_path}"
      
      # Create temp directory for conversion
      require 'tmpdir'
      Dir.mktmpdir do |tmpdir|
        # Copy epJSON to temp directory with standard name
        temp_input = File.join(tmpdir, "in.epJSON")
        FileUtils.cp(epjson_path, temp_input)
        
        # Run EnergyPlus with --convert-only flag
        # This converts the file without running simulation
        original_dir = Dir.pwd
        begin
          Dir.chdir(tmpdir)
          
          # Use --convert-only to just convert format
          cmd = "\"#{energyplus_exe}\" --convert-only in.epJSON"
          puts "Running: #{cmd}"
          
          result = system(cmd)
          
          # EnergyPlus creates in.idf in the same directory
          converted_file = File.join(tmpdir, "in.idf")
          
          if result && File.exist?(converted_file)
            # Copy to destination
            FileUtils.cp(converted_file, idf_path)
            puts "Successfully converted to IDF format"
            return idf_path
          else
            puts "ERROR: Conversion failed or output file not created"
            return nil
          end
          
        ensure
          Dir.chdir(original_dir)
        end
      end
      
    rescue => e
      puts "ERROR during epJSON to IDF conversion: #{e.message}"
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
    
    # Sort and format IDF file using IDD field definitions
    # Alphabetizes objects by name within each class and cleans up number formatting
    # @param idf_path [String] Path to IDF file to sort
    # @param version [String] EnergyPlus version (e.g., "25-1-0")
    # @return [Boolean] True if successful
    def self.sort_idf_file(idf_path, version = nil)
      return false unless File.exist?(idf_path)
      
      # Detect version if not provided
      version ||= detect_version_from_idf(idf_path)
      
      # Get IDD path from repo
      energyplus_dir = get_energyplus_dir(version)
      idd_path = File.join(energyplus_dir, "Energy+.idd")
      
      unless File.exist?(idd_path)
        puts "Warning: IDD not found at #{idd_path}, skipping sort"
        return false
      end
      
      # Parse IDD and IDF
      idd_classes = parse_idd_for_sorting(idd_path)
      idf_objects = parse_idf_for_sorting(idf_path)
      
      # Sort and format
      sorted_content = format_sorted_idf(idf_objects, idd_classes)
      
      # Write back to file
      File.write(idf_path, sorted_content, encoding: 'utf-8')
      
      true
    rescue => e
      puts "Error sorting IDF: #{e.message}"
      false
    end
    
    private
    
    # Parse IDD file to extract class definitions and field names
    # @param idd_path [String] Path to IDD file
    # @return [Hash] Hash of class definitions with field info
    def self.parse_idd_for_sorting(idd_path)
      content = File.read(idd_path, encoding: 'utf-8')
      
      # Remove full-line comments
      lines = content.split("\n").reject { |line| line.strip.start_with?('!') }
      content = lines.join("\n")
      
      # Split into class blocks
      class_blocks = content.split(/\n(?=[A-Za-z])/)
      
      classes = {}
      class_blocks.each do |block|
        next if block.strip.empty?
        
        # Extract class name
        first_line_match = block.match(/^([A-Za-z][A-Za-z0-9:_-]*)/)
        next unless first_line_match
        
        class_name = first_line_match[1].strip
        
        # Extract field names
        fields = []
        block.scan(/\\field\s+([^\n]+)/i).each do |field_match|
          fields << field_match[0].strip
        end
        
        # Extract min-fields
        min_fields_match = block.match(/\\min-fields\s+(\d+)/i)
        min_fields = min_fields_match ? min_fields_match[1].to_i : fields.length + 1
        
        classes[class_name] = {
          fields: fields,
          min_fields: min_fields
        }
      end
      
      classes
    end
    
    # Parse IDF file to extract objects
    # @param idf_path [String] Path to IDF file
    # @return [Hash] Hash of objects grouped by class
    def self.parse_idf_for_sorting(idf_path)
      content = File.read(idf_path, encoding: 'utf-8')
      
      # Remove comments
      lines = content.split("\n").map do |line|
        line.include?('!') ? line.split('!')[0] : line
      end
      content = lines.join("\n")
      
      # Split into objects (separated by semicolons)
      object_blocks = content.split(';')
      
      objects_by_class = Hash.new { |hash, key| hash[key] = [] }
      
      object_blocks.each do |block|
        block = block.strip
        next if block.empty?
        
        # Split by commas to get fields
        fields = block.split(',').map(&:strip)
        next if fields.empty?
        
        class_name = fields[0]
        objects_by_class[class_name] << fields
      end
      
      objects_by_class
    end
    
    # Format sorted IDF content
    # @param objects_by_class [Hash] Objects grouped by class
    # @param idd_classes [Hash] IDD class definitions
    # @return [String] Formatted IDF content
    def self.format_sorted_idf(objects_by_class, idd_classes)
      text = "\n" # blank line at top
      indent = "  "
      rjust_col = 27
      
      # Process each class in IDD order (to maintain consistent ordering)
      idd_classes.keys.each do |class_name|
        objects = objects_by_class[class_name]
        next unless objects && !objects.empty?
        
        class_def = idd_classes[class_name]
        field_defs = class_def[:fields]
        min_fields = class_def[:min_fields]
        
        # Alphabetize objects by name (second field)
        objects.sort_by! { |fields| [fields[1] || '', fields] }
        
        objects.each do |fields|
          # Find last non-blank field
          last_field_num = nil
          if fields.length > min_fields
            (min_fields...fields.length).each do |i|
              if i < fields.length && !fields[i].strip.empty?
                last_field_num = i
              end
            end
          end
          
          # Write each field
          fields.each_with_index do |field, num|
            if num.zero? # class name
              text += "#{field},\n"
              next
            end
            
            # Clean up number formatting
            field = fix_number_string(field)
            
            # Determine if last field
            is_last = (num == fields.length - 1) || (last_field_num && num == last_field_num)
            field_end = is_last ? ';' : ','
            line_end = is_last ? "\n\n" : "\n"
            
            spaces = field.length < rjust_col - 2 ? '' : '  '
            
            # Get field name from IDD
            field_name = if num - 1 < field_defs.length
                           field_defs[num - 1]
                         else
                           'Extended Field'
                         end
            
            # Format with comment
            padding = [0, rjust_col - field.length].max
            comment = padding > 0 ? '!-'.rjust(padding) : ' !-'
            
            text += "#{indent}#{field}#{field_end}#{spaces}#{comment} #{field_name}#{line_end}"
            
            break if last_field_num && num == last_field_num
          end
        end
      end
      
      text
    end
    
    # Convert number string to cleanest representation
    # @param str [String] String to check and convert
    # @return [String] Cleaned number string or original string
    def self.fix_number_string(str)
      return str if str.nil? || str.empty?
      
      # Quick check if it looks like a number before trying to parse
      # Match optional sign, digits, optional decimal point and more digits, optional scientific notation
      # Using =~ instead of match? for Ruby 2.2 compatibility
      return str unless str =~ /^\s*[+-]?(\d+\.?\d*|\d*\.\d+)([eE][+-]?\d+)?\s*$/
      
      # Try to parse as float
      num = Float(str)
      
      # Check if it's essentially an integer
      return num.to_i.to_s if num == num.to_i
      
      # Format with up to 12 significant figures, removing trailing zeros
      format('%.12g', num)
    rescue ArgumentError, TypeError
      # Not a number, return as-is
      str
    end
  end

end
