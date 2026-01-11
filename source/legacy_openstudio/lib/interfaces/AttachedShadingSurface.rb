# OpenStudio
# Copyright (c) 2008-2015, Alliance for Sustainable Energy.  All rights reserved.
# See the file "License.txt" for additional terms and conditions.

require("euclid/lib/legacy_openstudio/lib/interfaces/DrawingUtils")
require("euclid/lib/legacy_openstudio/lib/interfaces/Surface")
require("euclid/lib/legacy_openstudio/lib/inputfile/JsonInputObject")


module LegacyOpenStudio

  class AttachedShadingSurface < Surface

    def initialize
      super
    end


##### Begin methods for the input object #####


    def create_input_object
      @input_object = JsonInputObject.new("Shading:Zone:Detailed")
      @input_object.name = Plugin.model_manager.input_file.new_unique_object_name
      @input_object.set_property('base_surface_name', "")  # Base Surface
      @input_object.set_property('transmittance_schedule_name', "")  # Transmittance
      @input_object.set_property('vertices', [])  # Will be populated by update_input_object

      super
    end


    def check_input_object
      if (super)
        # Check the base surface.
        parent = parent_from_input_object
        if (parent.class != BaseSurface)
          Plugin.model_manager.add_error("Warning:  " + @input_object.name + "\n")
          Plugin.model_manager.add_error("This attached shading surface is missing its base surface: " + @input_object.get_property('base_surface_name').to_s + "\n")
          Plugin.model_manager.add_error("A new zone object has been automatically created for this surface.\n\n")
        end

        return(true)
      else
        return(false)
      end
    end


    # Updates the input object with the current state of the entity.
    def update_input_object
      super  # Surface superclass updates the vertices

      if (valid_entity?)
        if (@parent.class == BaseSurface)
          @input_object.set_property('base_surface_name', @parent.input_object.name)  # Parent should already have been updated.
        else
          @input_object.set_property('base_surface_name', "")
        end
      end
    end


    # Returns the parent drawing interface according to the input object.
    def parent_from_input_object
      parent = nil
      if (@input_object)
        base_surface_name = @input_object.get_property('base_surface_name', '')
        parent = Plugin.model_manager.base_surfaces.find { |object| object.input_object.name == base_surface_name }
      end
      return(parent)
    end


##### Begin override methods for the entity #####


    # Returns the parent drawing interface according to the entity.
    def parent_from_entity
      if (base_face = DrawingUtils.detect_base_face(@entity))
        return(base_face.drawing_interface)
      else

        zone_interface = super

        # try parent_from_input_object
        input_object_parent = parent_from_input_object
        if input_object_parent and zone_interface == input_object_parent.parent_from_entity
          return(input_object_parent)
        end

        # just grab the first base surface in the zone.
        for child in zone_interface.children
          if (child.class == BaseSurface)
            return(child)
          end
        end

        # Could not find any base surfaces
        return(zone_interface)
      end
    end


##### Begin override methods for the interface #####

    def in_selection?(selection)
      return (selection.contains?(@entity) or selection.contains?(@parent.entity) or (not @parent.parent.nil? and selection.contains?(@parent.parent.entity)))
    end

    def paint_surface_type
      if (valid_entity?)
        @entity.material = Plugin.model_manager.construction_manager.attached_shading
        @entity.back_material = Plugin.model_manager.construction_manager.attached_shading_back
      end
    end

  end


end
