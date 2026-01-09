# OpenStudio
# Copyright (c) 2008-2015, Alliance for Sustainable Energy.  All rights reserved.
# Copyright (c) 2017-2020, Big Ladder Software LLC. All rights reserved.
# See the file "License.txt" for additional terms and conditions.

require 'json'
require("euclid/lib/legacy_openstudio/lib/Collection")
require("euclid/lib/legacy_openstudio/lib/inputfile/JsonInputObject")


module LegacyOpenStudio

  class EpJsonFile
    attr_accessor :path, :modified, :objects, :deleted_objects, :new_objects, :context, :original_idf_path, :energyplus_version
    
    def self.open(path, update_progress = nil)
      file = new(update_progress)
      file.open(path)
      return file
    end
    
    def initialize(update_progress = nil)
      @path = nil
      @modified = false
      @objects = Collection.new
      @new_objects = Collection.new
      @deleted_objects = Collection.new
      @update_progress = update_progress
      @context = ""  # For compatibility with InputFile
      @original_idf_path = nil  # Track original IDF file if converted
      @energyplus_version = "25-1-0"  # Default to 25.1.0
    end
    
    def open(path)
      @path = path
      if File.exist?(path)
        read_json_file(path)
        @modified = false
      else
        puts "EpJsonFile.open: bad path"
      end
    end
    
    def copy
      new_file = dup
      new_file.objects = @objects.dup
      new_file.new_objects = @new_objects.dup
      new_file.deleted_objects = @deleted_objects.dup
      return new_file
    end
    
    def merge(path)
      if File.exist?(path)
        read_json_file(path)
        update_object_references
        @modified = true
      else
        puts "EpJsonFile.merge: bad path"
      end
    end
    
    def write(path = nil, update_progress = nil)
      path ||= @path
      success = write_json_file(path, update_progress)
      @modified = false if success
      return success
    end
    
    def writable?
      if @path && File.exist?(@path)
        return File.writable?(@path)
      else
        return false
      end
    end
    
    def modified?
      @modified
    end
    
    def add_object(object, set_modified = true)
      @objects.add(object)
      @new_objects.add(object)
      @modified = true if set_modified
    end
    
    def copy_object(object, set_modified = true)
      object_copy = object.copy
      object_copy.name = new_unique_object_name
      add_object(object_copy)
      @modified = true if set_modified
      return object_copy
    end
    
    def new_object(class_name, properties = nil)
      object = JsonInputObject.new(class_name, new_unique_object_name, properties)
      add_object(object)
      return object
    end
    
    def delete_object(object)
      object.deleted = true
      @deleted_objects.add(object)
      @objects.remove(object)
      @modified = true
    end
    
    def undelete_object(object)
      object.deleted = false
      @objects.add(object)
      @deleted_objects.remove(object)
      @modified = true
    end
    
    def new_unique_object_name
      # Generate a random 6 digit hex number (same as InputFile)
      loop do
        new_name = (rand(15728640) + 1048576).to_s(16).upcase
        
        # Check to make sure the name is not already in use
        return new_name unless @objects.any? { |obj| obj.name == new_name }
      end
    end
    
    def find_object_by_name(class_name, name)
      @objects.find { |obj| obj.class_name == class_name && obj.name == name }
    end
    
    def find_objects_by_class_name(*args)
      found_objects = Collection.new
      for arg in args
        found_objects += @objects.find_all { |object| object.is_class_name?(arg) }
      end
      return found_objects
    end
    
    def find_object_by_class_and_name(class_name, object_name)
      return @objects.find { |object| object.is_class_name?(class_name) && object.name == object_name }
    end
    
    def object_exists?(this_object)
      return @objects.contains?(this_object)
    end
    
    def find_object_by_id(object_id)
      @objects.find { |obj| obj.object_id == object_id }
    end
    
    def inspect
      # Prevent Ruby Console from getting bogged down
      return to_s
    end
    
    private
    
    def read_json_file(path)
      # Read and parse JSON file
      json_string = File.read(path)
      json_data = JSON.parse(json_string)
      
      # Detect EnergyPlus version from file
      require_relative 'IdfToEpjsonConverter'
      @energyplus_version = IdfToEpjsonConverter.detect_version_from_epjson(json_data)
      puts "Detected EnergyPlus version: #{@energyplus_version.gsub('-', '.')}"
      
      # Track object counts for progress reporting (Ruby 2.2 compatible)
      total_objects = 0
      json_data.values.each { |instances| total_objects += instances.size if instances.is_a?(Hash) }
      count = 0
      
      # Iterate through object types
      json_data.each do |object_type, instances|
        next unless instances.is_a?(Hash)
        
        # Iterate through named instances
        instances.each do |name, properties|
          object = JsonInputObject.new(object_type, name, properties)
          @objects.add(object)
          
          count += 1
          if @update_progress
            continue = @update_progress.call((100 * count / total_objects), "Reading epJSON Objects")
            break unless continue
          end
        end
      end
      
      update_object_references
      
    rescue JSON::ParserError => e
      Plugin.model_manager.add_error("Error parsing epJSON file: #{e.message}\n")
      Plugin.model_manager.add_error("The file may be corrupt or not a valid epJSON file.\n\n")
      return false
    rescue => e
      Plugin.model_manager.add_error("Error reading epJSON file: #{e.message}\n\n")
      return false
    end
    
    def write_json_file(path, update_progress = nil)
      # Merge new objects into main collection
      @new_objects.each { |obj| @objects.add(obj) unless @objects.include?(obj) }
      @new_objects.clear
      
      # Build JSON structure
      json_data = {}
      count = 0
      total = @objects.count
      
      @objects.each do |object|
        next if object.deleted?
        
        object_type = object.class_name
        json_data[object_type] ||= {}
        json_data[object_type][object.name] = object.to_json_hash
        
        count += 1
        if update_progress
          continue = update_progress.call((100 * count / total), "Writing epJSON Objects")
          break unless continue
        end
      end
      
      # Write with pretty formatting (4 space indent, sorted keys for readability)
      File.write(path, JSON.pretty_generate(json_data, indent: '    ', space: ' ', object_nl: "\n"))
      return true
      
    rescue => e
      Plugin.model_manager.add_error("Error writing epJSON file: #{e.message}\n\n")
      return false
    end
    
    def update_object_references
      # Build lookup hash by object type and name
      # This allows quick lookup when resolving references
      object_lookup = {}
      
      total_objects = @objects.count
      count = 0
      
      @objects.each do |object|
        object_lookup[object.class_name] ||= {}
        object_lookup[object.class_name][object.name.upcase] = object
        
        count += 1
        if @update_progress
          continue = @update_progress.call((100 * count / total_objects), "Updating Object References, First Pass")
          break unless continue
        end
      end
      
      # Second pass: replace name strings with object references
      count = 0
      @objects.each do |object|
        object.resolve_references(object_lookup)
        
        count += 1
        if @update_progress
          continue = @update_progress.call((100 * count / total_objects), "Updating Object References, Second Pass")
          break unless continue
        end
      end
    end
  end

end
