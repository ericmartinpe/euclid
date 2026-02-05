# OpenStudio
# Copyright (c) 2008-2015, Alliance for Sustainable Energy.  All rights reserved.
# See the file "License.txt" for additional terms and conditions.

require("euclid/lib/legacy_openstudio/lib/interfaces/DrawingInterface")


module LegacyOpenStudio

  class Material < DrawingInterface

    def initialize(input_object)
      super
      #Plugin.model_manager.drawing_manager.materials << self
      return(self)
    end

  end


  class Construction < DrawingInterface

    def initialize(input_object)
      super
      #Plugin.model_manager.drawing_manager.constructions << self
      return(self)
    end

  end


  class DaylightingDetailed < DrawingInterface
  # makes me wonder if there should be a common ancestor shared with Surface to do simple point manipulations/transformations.
  #  Zone would inherit from that because it also does point transformations (I think).

    def initialize(obj)
      super

      @first_vertex_field = 3
      @zone = nil   # really only the BaseSurface that needs this zone ref---take that back, subs and attached shading need it too.

      @input_object = nil
      @entity = nil  # Reference to the native SketchUp entity:  group, face, material, etc.
      @zone = nil

      @points = []

      if (object.class == InputObject)
        new_from_input_object(object)
      elsif (object.class == Sketchup::Face)
        new_from_entity(object)
      end

      #Plugin.model_manager.drawing_manager.daylighting_detailed_points << self

      return(self)
    end


    def new_from_input_object(input_object)

      # Drawing interface is being created because an input object is being loaded
      # Can either create/draw a new entity, or relink to an existing entity.
      # This method might be pretty similar across drawing classes.

      @input_object = input_object  # Reference to the EnergyPlus input object:  ZONE, SURFACE, MATERIAL, etc.

      zone_name_property = @input_object.get_property('zone_or_zonelist_or_space_or_spacelist_name', '')
      zone_name = zone_name_property.to_s
      
      # For epJSON, zone references are strings, not objects
      # Look up zone by name if we have one

      if (@zone.nil?)
        Plugin.model_manager.add_error("Error:  " + @input_object.key + "\n")
        Plugin.model_manager.add_error("The zone referenced by this daylighting point does not exist.\n")
        Plugin.model_manager.add_error("NO ZONE WAS ADDED.\n\n")
      end

      #@zone.daylighting_detailed_points << self

    end


    def read_input_object_vertices
      number_of_points = @input_object.get_property('number_of_control_points', '1').to_i

      points = []
      for i in 0...number_of_points

        # need some error checking here:
        #   what if field had bogus content and could not be converted to float?
        #   what if some fields are missing?
        x = @input_object.get_property("control_point_#{i+1}_x_coordinate", '0').to_f.m
        y = @input_object.get_property("control_point_#{i+1}_y_coordinate", '0').to_f.m
        z = @input_object.get_property("control_point_#{i+1}_z_coordinate", '0').to_f.m

        if (false) #not x || not y || not z)
          error += 1
          next
        else
          points[i] = Geom::Point3d.new(x, y, z)
        end
      end

      # This is where all the error checking should happen

      @points = points
    end


    def draw_entity
      # create its own group

      # create the construction points
      for point in @points
        @entity = group_entity.entities.add_cpoint(point)
      end

      @entity.input_object_key = key  # persistent link
      @entity.drawing_interface = self

      # Tricky because there are 2 entities (cpoints) for each input object...how to do?
    end

  end

end
