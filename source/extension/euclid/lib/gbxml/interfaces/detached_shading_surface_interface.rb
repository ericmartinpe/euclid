# Copyright (c) 2017 Big Ladder Software LLC. All rights reserved.
# See the file "license.txt" for additional terms and conditions.

require("euclid/lib/gbxml/interfaces/surface_interface")
#require("euclid/lib/gbxml/interfaces/detached_shading_group_interface")

require("bemkit/shading")


module Euclid
  module GbXML

    class DetachedShadingSurfaceInterface < SurfaceInterface

      # Drawing interface is being created because an input object is being loaded.
      # Overridden to set 'surface_type' flag.
      def self.new_from_input_object(input_object)
        drawing_interface = self.new
        drawing_interface.input_object = input_object
        drawing_interface.surface_type = input_object.type
        return(drawing_interface)
      end


      def initialize
        super
        @container_class = DetachedShadingGroupInterface
        @surface_type = BEMkit::Shading::TYPE_BUILDING_SHADE
      end


  ##### Begin methods for the input object #####


      def create_input_object
        @input_object = BEMkit::Shading.new
        @input_object.name = ""
        @input_object.type = @surface_type

        LegacyOpenStudio::Plugin.model_manager.input_file.document.add_shading_surface(@input_object)

        # Don't call 'super' because the object is added to the document here manually.
        #super
      end


      # Updates the input object with the current state of the entity.
      def update_input_object
        super  # Surface superclass updates the vertices and parent
        self.surface_type = @parent.surface_type
      end


      def parent_from_input_object

        update_parent_from_entity  # This is really the wrong place...

        return(nil)
      end


  ##### Begin methods for the entity #####


      def create_entity
        super  # Creates the surface and parent group
        @parent.surface_type = @surface_type
      end


      def update_entity
        #super  # overridden here

        update_parent_from_entity  # This is key for getting the parent!
      end


  ##### Begin override methods for the interface #####


      # Deletes the input object and marks the drawing interface when the SketchUp entity is erased.
      def delete_input_object
        @deleted = true
        LegacyOpenStudio::Plugin.model_manager.input_file.document.remove_shading_surface(@input_object) if (@input_object)
        # Don't lose the input object so that it can be restored if it is undeleted.
      end


      def coordinate_transformation
        # Returns the general coordinate transformation from absolute to relative.
        # The 'inverse' method can be called on the resulting transformation to go from relative to absolute.

        #if (@parent.nil?)
        #  puts "DetachedShadingSurface.coordinate_transformation:  parent shading group is missing"
        #  return(Geom::Transformation.new)  # Identity transformation
        #else
        #  return(@parent.coordinate_transformation)
        #end

        # Kind of a kludge...parent surface_type was not being set correctly.
        # For now, ignore the parent coordinate transformation.  There's no extra data there anyway.
        #@parent.surface_type = @input_object.type

        if (@surface_type == BEMkit::Shading::TYPE_SITE_SHADE or @surface_type == BEMkit::Shading::TYPE_SITE_PHOTOVOLTAIC)
          return(Geom::Transformation.new)  # Identity transformation
        else
          azimuth = LegacyOpenStudio::Plugin.model_manager.location.input_object.azimuth

          origin = Geom::Point3d.new(0, 0, 0)   # Make these into plugin globals maybe
          z_axis = Geom::Vector3d.new(0, 0, 1)
          rotation_angle = (-azimuth.to_f).degrees
          return(Geom::Transformation.rotation(origin, z_axis, rotation_angle))
        end
      end


      def in_selection?(selection)
        return (selection.contains?(@entity) or selection.contains?(@parent.entity))
      end


      def paint_surface_type
        if (valid_entity?)
          if (@surface_type == BEMkit::Shading::TYPE_SITE_SHADE)
            @entity.material = LegacyOpenStudio::Plugin.model_manager.construction_manager.detached_fixed_shading
            @entity.back_material = LegacyOpenStudio::Plugin.model_manager.construction_manager.detached_fixed_shading_back
          elsif (@surface_type == BEMkit::Shading::TYPE_BUILDING_SHADE)
            @entity.material = LegacyOpenStudio::Plugin.model_manager.construction_manager.detached_building_shading
            @entity.back_material = LegacyOpenStudio::Plugin.model_manager.construction_manager.detached_building_shading_back
          elsif (@surface_type == BEMkit::Shading::TYPE_SITE_PHOTOVOLTAIC)
            @entity.material = LegacyOpenStudio::Plugin.model_manager.construction_manager.detached_photovoltaic_shading
            @entity.back_material = LegacyOpenStudio::Plugin.model_manager.construction_manager.detached_fixed_shading_back
          elsif (@surface_type == BEMkit::Shading::TYPE_BUILDING_PHOTOVOLTAIC)
            @entity.material = LegacyOpenStudio::Plugin.model_manager.construction_manager.detached_photovoltaic_shading
            @entity.back_material = LegacyOpenStudio::Plugin.model_manager.construction_manager.detached_building_shading_back
          end
        end
      end


  ##### Begin new methods for the interface #####


      attr_reader :surface_type


      def surface_type=(new_type)
        @surface_type = new_type
        @input_object.type = new_type
        paint_entity
      end


    end

  end
end
