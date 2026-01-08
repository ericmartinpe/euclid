# OpenStudio
# Copyright (c) 2008-2015, Alliance for Sustainable Energy.  All rights reserved.
# Copyright (c) 2017-2020, Big Ladder Software LLC. All rights reserved.
# See the file "License.txt" for additional terms and conditions.


module LegacyOpenStudio

  # Container for epJSON objects
  class JsonInputObject
    attr_accessor :name, :properties, :deleted, :dependents
    
    def initialize(object_type, name, properties = {})
      @object_type = object_type
      @name = name
      @properties = properties || {}
      @deleted = false
      @dependents = []
    end
    
    def class_name
      @object_type
    end
    
    def deleted?
      @deleted
    end
    
    # Property access with hash-like syntax
    def [](property_name)
      @properties[property_name]
    end
    
    def []=(property_name, value)
      @properties[property_name] = value
    end
    
    # Alternative property access methods
    def get(property_name)
      @properties[property_name]
    end
    
    def set(property_name, value)
      @properties[property_name] = value
    end
    
    # Convert to JSON hash for writing
    def to_json_hash
      @properties.dup
    end
    
    # String conversion (for object references)
    def to_s
      @name
    end
    
    def inspect
      return to_s
    end
    
    # Create a copy of this object
    def copy
      object_copy = dup
      object_copy.properties = @properties.dup
      object_copy.dependents = []  # Don't copy dependents
      object_copy.name = @name  # Name will be changed by caller
      return object_copy
    end
    
    # Equality check
    def eql?(other_object)
      return(other_object.class == JsonInputObject && 
             @name == other_object.name && 
             @object_type == other_object.class_name &&
             @properties == other_object.properties)
    end
    
    def ==(other_object)
      return eql?(other_object)
    end
    
    # Get the object's key (name)
    def key
      @name
    end
    
    # Resolve object references
    # Replace name strings with object references where appropriate
    def resolve_references(object_lookup)
      # Define which properties reference other objects for each object type
      REFERENCE_PROPERTIES = {
        "BuildingSurface:Detailed" => {
          "zone_name" => ["Zone"],
          "space_name" => ["Space"],
          "construction_name" => ["Construction", "Construction:AirBoundary"],
          "outside_boundary_condition_object" => ["BuildingSurface:Detailed", "Zone", "Space", 
                                                   "SurfaceProperty:OtherSideCoefficients", 
                                                   "SurfaceProperty:OtherSideConditionsModel",
                                                   "Foundation:Kiva"]
        },
        
        "FenestrationSurface:Detailed" => {
          "building_surface_name" => ["BuildingSurface:Detailed"],
          "construction_name" => ["Construction"],
          "outside_boundary_condition_object" => ["FenestrationSurface:Detailed"],
          "frame_and_divider_name" => ["WindowProperty:FrameAndDivider"]
        },
        
        "Shading:Zone:Detailed" => {
          "base_surface_name" => ["BuildingSurface:Detailed"],
          "transmittance_schedule_name" => ["Schedule:Compact", "Schedule:File", "Schedule:Constant"]
        },
        
        "Shading:Site:Detailed" => {
          "transmittance_schedule_name" => ["Schedule:Compact", "Schedule:File", "Schedule:Constant"]
        },
        
        "Shading:Building:Detailed" => {
          "transmittance_schedule_name" => ["Schedule:Compact", "Schedule:File", "Schedule:Constant"]
        },
        
        "Daylighting:Controls" => {
          "zone_name" => ["Zone"],
          "availability_schedule_name" => ["Schedule:Compact", "Schedule:File", "Schedule:Constant"]
        },
        
        "Output:IlluminanceMap" => {
          "zone_name" => ["Zone"]
        }
      }
      
      ref_props = REFERENCE_PROPERTIES[@object_type]
      return unless ref_props
      
      ref_props.each do |prop_name, possible_object_types|
        value = @properties[prop_name]
        
        # Skip if value is nil, empty, or already an object reference
        next if value.nil? || value.to_s.empty? || value.is_a?(JsonInputObject) || value.is_a?(InputObject)
        
        # Try to find referenced object in any of the possible object types
        found = false
        possible_object_types.each do |obj_type|
          if object_lookup[obj_type] && (ref_obj = object_lookup[obj_type][value.to_s.upcase])
            @properties[prop_name] = ref_obj
            ref_obj.dependents << self
            found = true
            break
          end
        end
        
        # If reference not found, leave as string (will be flagged as error elsewhere)
      end
    end
  end

end
