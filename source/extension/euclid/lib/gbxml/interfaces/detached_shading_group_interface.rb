# Copyright (c) 2017 Big Ladder Software LLC. All rights reserved.
# See the file "license.txt" for additional terms and conditions.

#require("euclid/lib/legacy_openstudio/lib/interfaces/SurfaceGroup")
require("bemkit/shading")


module Euclid
  module GbXML

    class DetachedShadingGroupInterface < LegacyOpenStudio::SurfaceGroup

      attr_accessor :surface_type, :origin


      def initialize
        super
        @surface_type = BEMkit::Shading::TYPE_BUILDING_SHADE
        @origin = nil
      end


  ##### Begin override methods for the input object #####


      # Creates new defaulted input object and adds it to the input file.
      # ShadingGroup does not have an input object so this method is empty.
      def create_input_object
      end


      # ShadingGroup does not have an input object so this method is always true.
      def check_input_object
        return(true)
      end


      # Called by the plugin GUI (currently triggered by user action in the Object Info dialog).
      # ShadingGroup does not have an input object, but child input objects do need to be updated.
      def on_change_input_object
        @children.each { |child| child.on_change_input_object }
      end


  ##### Begin override methods for the entity #####


      # Called from DetachedShadingGroup.new_from_entity(entity).
      # Needed for recreating the Group when a shading surface is reassociated.
      def create_from_entity(entity)
        @entity = entity
        @entity.drawing_interface = self

        if (check_entity)
          #create_input_object
          #update_input_object

          #@entity.input_object_key = @input_object.key

          update_entity
          update_parent_from_entity  # kludge...this is out of place here, but works:  it adds itself as a child of model interface
          #paint_entity

          #add_observers  # should be added ModelInterface
        else
          puts "DrawingInterface.create_from_entity:  check_entity failed"
        end

        return(self)
      end


      # Updates the SketchUp entity with new information from the EnergyPlus object.
      # ShadingGroup does not have an input object so this method is empty.
      def update_entity
      end


      def clean_entity
        super
        @entity.name = "Euclid Shading Group"
      end


  ##### Begin override methods for the interface #####


      # Returns the general coordinate transformation from absolute to relative.
      # The 'inverse' method can be called on the resulting transformation to go from relative to absolute.
      def coordinate_transformation
        if (@surface_type == BEMkit::Shading::TYPE_SITE_SHADE or @surface_type == BEMkit::Shading::TYPE_SITE_PHOTOVOLTAIC)
          transformation = Geom::Transformation.new
        else
          azimuth = LegacyOpenStudio::Plugin.model_manager.location.input_object.azimuth

          origin = Geom::Point3d.new(0, 0, 0)   # Make these into plugin globals maybe
          z_axis = Geom::Vector3d.new(0, 0, 1)
          rotation_angle = (-azimuth.to_f).degrees
          transformation = Geom::Transformation.rotation(origin, z_axis, rotation_angle)
        end
        return(transformation)
      end


  ##### Begin new methods for the interface #####


      def set_entity_name
        @entity.name = "Euclid Shading Group"
      end


      def area
        area = 0.0
        for child in @children
          area += child.area
        end
        return(area)
      end


      def surface_type=(new_type)
        @surface_type = new_type
        @children.each { |child| child.surface_type = new_type }
      end

    end

  end
end
