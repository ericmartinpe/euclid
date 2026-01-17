# OpenStudio
# Copyright (c) 2008-2015, Alliance for Sustainable Energy.  All rights reserved.
# Copyright (c) 2017-2020, Big Ladder Software LLC. All rights reserved.
# See the file "License.txt" for additional terms and conditions.

require("euclid/lib/legacy_openstudio/lib/inputfile/FieldMapper")


module LegacyOpenStudio

  # Adapter to provide unified interface for both InputObject (IDF) and JsonInputObject (epJSON)
  # This allows interface classes to work with both file formats transparently
  class InputObjectAdapter
    
    def initialize(object)
      @object = object
      @is_json = object.is_a?(JsonInputObject)
    end
    
    # Get field value by index (IDF style) or property name (epJSON style)
    # @param identifier [Integer, String] Field index for IDF or property name for epJSON
    # @return [Object] Field value
    def get_field(identifier)
      if @is_json
        if identifier.is_a?(Integer)
          # Convert field index to property name using FieldMapper
          prop_name = FieldMapper.to_property(@object.class_name, identifier)
          if prop_name
            # Special case: "name" property maps to object key in epJSON
            return @object.key if prop_name == "name"
            return @object[prop_name]
          end
        else
          # Direct property access by name
          return @object[identifier]
        end
      else
        # IDF object - use fields array
        if identifier.is_a?(Integer)
          return @object.fields[identifier]
        else
          # Convert property name to field index
          field_idx = FieldMapper.to_field_index(@object.class_name, identifier)
          return @object.fields[field_idx] if field_idx
        end
      end
      nil
    end
    
    # Set field value
    # @param identifier [Integer, String] Field index for IDF or property name for epJSON
    # @param value [Object] Value to set
    def set_field(identifier, value)
      if @is_json
        if identifier.is_a?(Integer)
          prop_name = FieldMapper.to_property(@object.class_name, identifier)
          if prop_name
            # Can't change the object key (name) after creation
            return if prop_name == "name"
            @object[prop_name] = value
          end
        else
          # Direct property access by name
          @object[identifier] = value
        end
      else
        # IDF object
        if identifier.is_a?(Integer)
          @object.fields[identifier] = value
        else
          # Convert property name to field index
          field_idx = FieldMapper.to_field_index(@object.class_name, identifier)
          @object.fields[field_idx] = value if field_idx
        end
      end
    end
    
    # Get vertices as flat array of coordinates
    # @return [Array<Float>] Flat array [x1, y1, z1, x2, y2, z2, ...]
    def get_vertices
      if @is_json
        # Check if vertices are stored as an array (BuildingSurface:Detailed)
        vertices_array = @object["vertices"]
        if vertices_array && !vertices_array.empty?
          # Convert epJSON vertex objects to flat array for compatibility
          return vertices_array.flat_map do |v|
            [
              v["vertex_x_coordinate"] || 0.0,
              v["vertex_y_coordinate"] || 0.0,
              v["vertex_z_coordinate"] || 0.0
            ]
          end
        end
        
        # For FenestrationSurface:Detailed, vertices are stored as individual properties
        # vertex_1_x_coordinate, vertex_1_y_coordinate, vertex_1_z_coordinate, etc.
        num_vertices = (@object["number_of_vertices"] || 0).to_i
        result = []
        (1..num_vertices).each do |i|
          x = @object["vertex_#{i}_x_coordinate"]
          y = @object["vertex_#{i}_y_coordinate"]
          z = @object["vertex_#{i}_z_coordinate"]
          if x && y && z
            result << x.to_f << y.to_f << z.to_f
          end
        end
        result
      else
        # IDF: vertices start at different indices depending on object type
        start_idx = FieldMapper.vertices_start_index(@object.class_name)
        return [] unless start_idx
        @object.fields[start_idx..-1] || []
      end
    end
    
    # Get vertices as array of Point3d objects
    # @return [Array<Geom::Point3d>] Array of Point3d objects
    def get_vertices_as_points
      flat_vertices = get_vertices
      points = []
      
      (0...flat_vertices.length).step(3) do |i|
        x = flat_vertices[i] || 0.0
        y = flat_vertices[i+1] || 0.0
        z = flat_vertices[i+2] || 0.0
        points << Geom::Point3d.new(x.to_f, y.to_f, z.to_f)
      end
      
      points
    end
    
    # Set vertices from various input formats
    # @param points_data [Array] Can be:
    #   - Array of Point3d objects
    #   - Flat array of coordinates [x1, y1, z1, x2, y2, z2, ...]
    #   - Array of coordinate arrays [[x1, y1, z1], [x2, y2, z2], ...]
    def set_vertices(points_data)
      if @is_json
        # Check if this object uses vertex array format (BuildingSurface:Detailed)
        # or individual vertex properties (FenestrationSurface:Detailed)
        if @object.class_name.upcase.include?("BUILDINGSURFACE")
          # BuildingSurface:Detailed uses vertices array
          vertices = convert_to_epjson_vertices(points_data)
          @object["vertices"] = vertices
          @object["number_of_vertices"] = vertices.length
        else
          # FenestrationSurface:Detailed uses individual vertex_N_x/y/z_coordinate properties
          flat_coords = convert_to_flat_coordinates(points_data)
          num_vertices = flat_coords.length / 3
          @object["number_of_vertices"] = num_vertices
          
          (1..num_vertices).each do |i|
            idx = (i - 1) * 3
            @object["vertex_#{i}_x_coordinate"] = flat_coords[idx].to_f
            @object["vertex_#{i}_y_coordinate"] = flat_coords[idx + 1].to_f
            @object["vertex_#{i}_z_coordinate"] = flat_coords[idx + 2].to_f
          end
        end
      else
        # IDF: replace vertices in fields array
        start_idx = FieldMapper.vertices_start_index(@object.class_name)
        return unless start_idx
        
        # Remove old vertices
        @object.fields = @object.fields[0...start_idx]
        
        # Add new vertices
        flat_coords = convert_to_flat_coordinates(points_data)
        @object.fields.concat(flat_coords)
        
        # Update number of vertices field
        num_vertices_idx = start_idx - 1
        @object.fields[num_vertices_idx] = flat_coords.length / 3
      end
    end
    
    # Get the underlying object
    def object
      @object
    end
    
    # Check if this is a JSON object
    def is_json?
      @is_json
    end
    
    private
    
    # Convert various point formats to epJSON vertices format
    # @return [Array<Hash>] Array of vertex hashes
    def convert_to_epjson_vertices(points_data)
      vertices = []
      
      if points_data.empty?
        return vertices
      end
      
      if points_data.first.respond_to?(:x) && points_data.first.respond_to?(:y) && points_data.first.respond_to?(:z)
        # Array of Point3d objects
        points_data.each do |point|
          vertices << {
            "vertex_x_coordinate" => point.x.to_m.to_f,
            "vertex_y_coordinate" => point.y.to_m.to_f,
            "vertex_z_coordinate" => point.z.to_m.to_f
          }
        end
      elsif points_data.first.is_a?(Array)
        # Array of coordinate arrays
        points_data.each do |coords|
          vertices << {
            "vertex_x_coordinate" => coords[0].to_f,
            "vertex_y_coordinate" => coords[1].to_f,
            "vertex_z_coordinate" => coords[2].to_f
          }
        end
      else
        # Flat array of coordinates (Numeric or String)
        # Convert to float to handle both numbers and formatted strings
        (0...points_data.length).step(3) do |i|
          vertices << {
            "vertex_x_coordinate" => points_data[i].to_f,
            "vertex_y_coordinate" => points_data[i+1].to_f,
            "vertex_z_coordinate" => points_data[i+2].to_f
          }
        end
      end
      
      vertices
    end
    
    # Convert various point formats to flat coordinate array
    # @return [Array<Float>] Flat array of coordinates
    def convert_to_flat_coordinates(points_data)
      coords = []
      
      if points_data.empty?
        return coords
      end
      
      if points_data.first.respond_to?(:x) && points_data.first.respond_to?(:y) && points_data.first.respond_to?(:z)
        # Array of Point3d objects
        points_data.each do |point|
          coords << point.x.to_m.to_f
          coords << point.y.to_m.to_f
          coords << point.z.to_m.to_f
        end
      elsif points_data.first.is_a?(Array)
        # Array of coordinate arrays
        points_data.each do |coord_array|
          coords.concat(coord_array.map(&:to_f))
        end
      else
        # Flat array (Numeric or String) - convert all to float
        coords = points_data.map(&:to_f)
      end
      
      coords
    end
  end

end
