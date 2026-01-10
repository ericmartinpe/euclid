# OpenStudio
# Copyright (c) 2008-2015, Alliance for Sustainable Energy.  All rights reserved.
# See the file "License.txt" for additional terms and conditions.

require("euclid/lib/legacy_openstudio/lib/interfaces/DrawingInterface")
require("euclid/lib/legacy_openstudio/lib/interfaces/Zone")
require("euclid/lib/legacy_openstudio/lib/inputfile/JsonInputObject")
require("euclid/lib/legacy_openstudio/lib/observers/ComponentObserver")

module LegacyOpenStudio

  class DaylightingControls < DrawingInterface

    @@componentdefinition = nil

    attr_accessor :transform, :parent

    def initialize
      super
      @observer = ComponentObserver.new(self)
      @observer_child0 = ComponentObserver.new(self)
      @observer_child1 = ComponentObserver.new(self)
      @reference_point1 = nil
      @reference_point2 = nil
    end

##### Begin override methods for the input object #####

    def create_input_object
      # EnergyPlus 25.1+ uses separate ReferencePoint objects
      name = Plugin.model_manager.input_file.new_unique_object_name
      @input_object = JsonInputObject.new("Daylighting:Controls", name)
      
      # Create two reference point objects
      @reference_point1 = JsonInputObject.new("Daylighting:ReferencePoint", name + "_RefPt1")
      @reference_point2 = JsonInputObject.new("Daylighting:ReferencePoint", name + "_RefPt2")
      
      # Add reference points to input file
      Plugin.model_manager.input_file.add_object(@reference_point1)
      Plugin.model_manager.input_file.add_object(@reference_point2)
      
      # Set basic properties for controls object
      @input_object.set_property('zone_or_space_name', '')
      @input_object.set_property('daylighting_method', 'SplitFlux')
      @input_object.set_property('lighting_control_type', 'Continuous')
      @input_object.set_property('minimum_input_power_fraction_for_continuous_or_continuousoff_dimming_control', '0.3')
      @input_object.set_property('minimum_light_output_fraction_for_continuous_or_continuousoff_dimming_control', '0.2')
      @input_object.set_property('number_of_stepped_control_steps', '1')
      @input_object.set_property('probability_lighting_will_be_reset_when_needed_in_manual_stepped_control', '1')
      @input_object.set_property('glare_calculation_daylighting_reference_point_name', @reference_point1.name)
      @input_object.set_property('glare_calculation_azimuth_angle_of_view_direction_clockwise_from_zone_y_axis', '0')
      @input_object.set_property('maximum_allowable_discomfort_glare_index', '22')
      
      # Create control_data array with both reference points
      control_data = [
        {
          'daylighting_reference_point_name' => @reference_point1.name,
          'fraction_of_lights_controlled_by_reference_point' => 1.0,
          'illuminance_setpoint_at_reference_point' => 500
        },
        {
          'daylighting_reference_point_name' => @reference_point2.name,
          'fraction_of_lights_controlled_by_reference_point' => 0.0,
          'illuminance_setpoint_at_reference_point' => 500
        }
      ]
      @input_object.set_property('control_data', control_data)
      
      # Set reference point zone (will be updated when zone is assigned)
      @reference_point1.set_property('zone_or_space_name', '')
      @reference_point2.set_property('zone_or_space_name', '')
      
      # Initialize coordinates to empty (will be set when placed)
      @reference_point1.set_property('x_coordinate_of_reference_point', '')
      @reference_point1.set_property('y_coordinate_of_reference_point', '')
      @reference_point1.set_property('z_coordinate_of_reference_point', '')
      @reference_point2.set_property('x_coordinate_of_reference_point', '')
      @reference_point2.set_property('y_coordinate_of_reference_point', '')
      @reference_point2.set_property('z_coordinate_of_reference_point', '')

      super
    end

    def check_input_object
      # When loading from file, find and link existing reference points
      if @reference_point1.nil? && @reference_point2.nil?
        link_reference_points
      end
      return(super)
    end
    
    # Find and link existing reference points when loading from file
    def link_reference_points
      # Get control_data array to find reference point names
      control_data = @input_object.get_property('control_data', [])
      
      if control_data.is_a?(Array) && control_data.length > 0
        # Find first reference point
        ref_pt1_name = control_data[0]['daylighting_reference_point_name']
        if ref_pt1_name
          @reference_point1 = Plugin.model_manager.input_file.find_object_by_class_and_name("DAYLIGHTING:REFERENCEPOINT", ref_pt1_name)
        end
        
        # Find second reference point if exists
        if control_data.length > 1
          ref_pt2_name = control_data[1]['daylighting_reference_point_name']
          if ref_pt2_name
            @reference_point2 = Plugin.model_manager.input_file.find_object_by_class_and_name("DAYLIGHTING:REFERENCEPOINT", ref_pt2_name)
          end
        end
      end
    end


    # Updates the input object with the current state of the entity.
    def update_input_object

      super

      if (valid_entity?)

        #puts "Before DaylightingControls.update_input_object"
        #puts "input_object_sensor2 = #{input_object_sensor2}"
        #puts @input_object.to_idf

        if @parent.nil?
          puts "DaylightingControls.update_input_object: parent is nil"
          @parent = parent_from_input_object
        end

        # zone - update both controls and reference points
        @input_object.set_property('zone_or_space_name', @parent.input_object.name)
        if @reference_point1
          @reference_point1.set_property('zone_or_space_name', @parent.input_object.name)
        end
        if @reference_point2
          @reference_point2.set_property('zone_or_space_name', @parent.input_object.name)
        end

        # Update control_data array with current reference point names
        control_data = @input_object.get_property('control_data', [])
        if control_data.is_a?(Array)
          if control_data.length >= 1 && @reference_point1
            control_data[0]['daylighting_reference_point_name'] = @reference_point1.name
          end
          if control_data.length >= 2 && @reference_point2
            control_data[1]['daylighting_reference_point_name'] = @reference_point2.name
          end
          @input_object.set_property('control_data', control_data)
        end

        decimal_places = Plugin.model_manager.length_precision
        if (decimal_places < 6)
          decimal_places = 6
          # Always keep at least 6 places for now, until I figure out how to keep the actual saved in the idf from being reduced upon loading
          # There's nothing in the API that prevents from drawing at finer precision than the option settings.
          # Just have to figure out how to keep this routine from messing it up...
          # NOTE:  Comment above applies more for surfaces than zones.
        end
        format_string = "%0." + decimal_places.to_s + "f"  # This could be stored in a more central place

        # total_transformation = parent_transformation*entity_transformation*sensor_translation*sensor_rotation
        # sensor_position = parent_transformation*entity_transformation*sensor_translation*[0,0,0]

        # currently zone origin is separate from parent group's origin
        parent_transformation = @parent.entity.transformation
        entity_transformation = @entity.transformation
        sensor1_transformation = @entity.definition.entities[0].transformation
        sensor2_transformation = @entity.definition.entities[1].transformation

        # sensor 1, always have sensor one
        sensor1_position = (parent_transformation*entity_transformation*sensor1_transformation).origin
        self.sketchup_sensor1 = sensor1_position

        # sensor 2 - check if second reference point exists and has coordinates
        if @reference_point2
          x2 = @reference_point2.get_property('x_coordinate_of_reference_point', '').to_s
          y2 = @reference_point2.get_property('y_coordinate_of_reference_point', '').to_s
          z2 = @reference_point2.get_property('z_coordinate_of_reference_point', '').to_s
          
          if (x2.empty? or y2.empty? or z2.empty?)
            reset_lengths
            update_entity
          else
            sensor2_position = (parent_transformation*entity_transformation*sensor2_transformation).origin
            self.sketchup_sensor2 = sensor2_position
          end
        end

        #puts "After DaylightingControls.update_input_object"
        #puts "input_object_sensor2 = #{input_object_sensor2}"
        #puts @input_object.to_idf

      end
    end

    # Returns the parent drawing interface according to the input object.
    def parent_from_input_object
      parent = nil
      if (@input_object)
        zone_name = @input_object.get_property('zone_or_space_name', '')
        if zone_name && !zone_name.empty?
          parent = Plugin.model_manager.zones.find { |zone| zone.name.to_s.upcase == zone_name.to_s.upcase }
        end
      end
      return(parent)
    end

##### Begin override methods for the entity #####

    def create_entity
      if (@parent.nil?)
        puts "DaylightingControls parent is nil"

        # Create a new zone just for this DaylightingControls.
        @parent = Zone.new
        @parent.create_input_object
        @parent.draw_entity(false)
        @parent.add_child(self)  # Would be nice to not have to call this
      end

      # add the component definition
      path = Plugin.dir + "/lib/resources/components/OpenStudio_DaylightingControls.skp"
      definition = Sketchup.active_model.definitions.load(path)

      # parent entity is a Sketchup::Group
      @entity = @parent.entity.entities.add_instance(definition, Geom::Transformation.new)

      # make it unique as we will be messing with the definition
      @entity.make_unique
    end

    def valid_entity?
      return(super and @entity.valid?)
    end

    # Error checks, finalization, or cleanup needed after the entity is drawn.
    def confirm_entity
      return(super)
    end

    # change the entity to reflect the InputObject
    def update_entity

      # do not want to call super if just want to redraw
      super

      if(valid_entity?)

        #puts "Before DaylightingControls.update_entity"
        #puts "input_object_sensor2 = #{input_object_sensor2}"
        #puts @input_object.to_idf

        # do not want to trigger update_input_object in here
        had_observers = remove_observers

        # need to make unique
        @entity.make_unique

        # total_transformation = parent_transformation*entity_transformation*sensor_translation*sensor_rotation
        # sensor_position = parent_transformation*entity_transformation*sensor_translation*[0,0,0]

        # currently zone origin is separate from parent group's origin
        parent_transformation = @parent.entity.transformation
        entity_transformation = @entity.transformation

        # the fixed rotation angle
        glare_angle = -@input_object.get_property('glare_calculation_azimuth_angle_of_view_direction_clockwise_from_zone_y_axis', '0').to_f
        rotation_angle = 0
        if (Plugin.model_manager.relative_daylighting_coordinates?)
          # for some reason building azimuth is in EnergyPlus system and zone azimuth is in SketchUp system
          rotation_angle = -Plugin.model_manager.building.azimuth + @parent.azimuth.radians
        end
        sensor_rotation = Geom::Transformation.rotation([0, 0, 0], [0, 0, 1], rotation_angle.degrees+glare_angle.degrees)

        # move sensors, works because we have a unique definition
        sensor1_transformation = (parent_transformation*entity_transformation).inverse*Geom::Transformation.translation(sketchup_sensor1)*sensor_rotation
        #puts "sensor1_transformation = #{sensor1_transformation.origin}"
        @entity.definition.entities[0].transformation = sensor1_transformation

        if sketchup_sensor2
          sensor2_transformation = (parent_transformation*entity_transformation).inverse*Geom::Transformation.translation(sketchup_sensor2)*sensor_rotation
          #puts "not reset, sensor2_transformation = #{sensor2_transformation.origin}"
          @entity.definition.entities[1].transformation = sensor2_transformation
          @entity.definition.entities[1].hidden = false
        else
          sensor2_transformation = sensor1_transformation
          #puts "reset to sensor1, sensor2_transformation = #{sensor2_transformation.origin}"
          @entity.definition.entities[1].transformation = sensor2_transformation
          @entity.definition.entities[1].hidden = true
          if @reference_point2
            @reference_point2.set_property('x_coordinate_of_reference_point', '')
            @reference_point2.set_property('y_coordinate_of_reference_point', '')
            @reference_point2.set_property('z_coordinate_of_reference_point', '')
          end
        end

        add_observers if had_observers

        #puts "After DaylightingControls.update_entity"
        #puts "input_object_sensor2 = #{input_object_sensor2}"
        #puts @input_object.to_idf

      end

    end

    def paint_entity
      if (Plugin.model_manager.rendering_mode == 0)
        #paint
      elsif (Plugin.model_manager.rendering_mode == 1)
        #paint_data
      end
    end

    # Final cleanup of the entity.
    # This method is called by the model interface after the entire input file is drawn.
    def cleanup_entity
      super
    end

    # Returns the parent drawing interface according to the entity.
    def parent_from_entity
      parent = nil
      if (valid_entity?)
        if (@entity.parent.class == Sketchup::ComponentDefinition)
          parent = @entity.parent.instances.first.drawing_interface
        else
          # Somehow the surface got outside of a Group--maybe the Group was exploded.
        end
      end

      return(parent)
    end

##### Begin override methods for the interface #####

    # Attaches any Observer classes, usually called after all drawing is complete.
    # Also called to reattach an Observer when a drawing interface is restored via undo.
    # This method should be overriden by subclasses.
    def add_observers
      super # takes care of @observer only
      if (valid_entity?)

        # add observers for the children too
        @entity.definition.entities[0].add_observer(@observer_child0)
        @entity.definition.entities[1].add_observer(@observer_child1)
      end
    end

    # This method can be overriden by subclasses.
    def remove_observers
      super # takes care of @observer only
      if (valid_entity?)

        # remove observers for the children too
        @entity.definition.entities[0].remove_observer(@observer_child0)
        @entity.definition.entities[1].remove_observer(@observer_child1)
      end
    end

##### Begin new methods for the interface #####

    def zone
      zone_name = @input_object.get_property('zone_or_space_name', '')
      return Plugin.model_manager.zones.find { |z| z.name.to_s.upcase == zone_name.to_s.upcase }
    end

    def zone=(zone)
      @input_object.set_property('zone_or_space_name', zone.input_object.name)
      @parent = zone
    end

    # Gets the sensor1 point of the InputObject as it literally appears in the input fields.
    def input_object_sensor1
      return nil unless @reference_point1
      
      x = @reference_point1.get_property('x_coordinate_of_reference_point', '0').to_f.m
      y = @reference_point1.get_property('y_coordinate_of_reference_point', '0').to_f.m
      z = @reference_point1.get_property('z_coordinate_of_reference_point', '0').to_f.m

      return(Geom::Point3d.new(x, y, z))
    end

    # Sets the sensor1 point of the InputObject as it literally appears in the input fields.
    def input_object_sensor1=(point)
      return unless @reference_point1

      decimal_places = Plugin.model_manager.length_precision
      if (decimal_places < 6)
        decimal_places = 6
      end
      format_string = "%0." + decimal_places.to_s + "f"

      x = point.x.to_m.round_to(decimal_places)
      y = point.y.to_m.round_to(decimal_places)
      z = point.z.to_m.round_to(decimal_places)

      @reference_point1.set_property('x_coordinate_of_reference_point', format(format_string, x))
      @reference_point1.set_property('y_coordinate_of_reference_point', format(format_string, y))
      @reference_point1.set_property('z_coordinate_of_reference_point', format(format_string, z))
    end

    # Gets the sensor2 point of the InputObject as it literally appears in the input fields.
    def input_object_sensor2
      return nil unless @reference_point2

      x_str = @reference_point2.get_property('x_coordinate_of_reference_point', '').to_s
      y_str = @reference_point2.get_property('y_coordinate_of_reference_point', '').to_s
      z_str = @reference_point2.get_property('z_coordinate_of_reference_point', '').to_s
      
      if x_str.empty? or y_str.empty? or z_str.empty?
        return nil
      end
      
      x = x_str.to_f.m
      y = y_str.to_f.m
      z = z_str.to_f.m
      
      return Geom::Point3d.new(x, y, z)
    end

    # Sets the sensor2 point of the InputObject as it literally appears in the input fields.
    def input_object_sensor2=(point)
      return unless @reference_point2

      decimal_places = Plugin.model_manager.length_precision
      if (decimal_places < 6)
        decimal_places = 6
      end
      format_string = "%0." + decimal_places.to_s + "f"

      x = point.x.to_m.round_to(decimal_places)
      y = point.y.to_m.round_to(decimal_places)
      z = point.z.to_m.round_to(decimal_places)

      @reference_point2.set_property('x_coordinate_of_reference_point', format(format_string, x))
      @reference_point2.set_property('y_coordinate_of_reference_point', format(format_string, y))
      @reference_point2.set_property('z_coordinate_of_reference_point', format(format_string, z))
    end

    # Returns the general coordinate transformation from absolute to relative.
    # The 'inverse' method can be called on the resulting transformation to go from relative to absolute.
    def coordinate_transformation
      #puts "DaylightingControls.coordinate_transformation"

      if (@parent.nil?)
        puts "OutputIlluminanceMap.coordinate_transformation:  parent reference is missing"
        return(Plugin.model_manager.building.transformation)
      else
        return(@parent.coordinate_transformation)
      end
    end

    # Returns sensor1 of the InputObject as it should be drawn in the relative SketchUp coordinate system.
    def sketchup_sensor1

      result = nil
      if (Plugin.model_manager.relative_daylighting_coordinates?)
        result = input_object_sensor1.transform(coordinate_transformation)
      else
        result = input_object_sensor1
      end

      return(result)

    end

    # Sets the sensor1 of the InputObject from the relative SketchUp coordinate system.
    def sketchup_sensor1=(point)

      if (Plugin.model_manager.relative_daylighting_coordinates?)
        self.input_object_sensor1 = point.transform(coordinate_transformation.inverse)
      else
        self.input_object_sensor1 = point
      end
    end

    # Returns sensor2 of the InputObject as it should be drawn in the relative SketchUp coordinate system.
    def sketchup_sensor2

      result = nil
      if (Plugin.model_manager.relative_daylighting_coordinates?)
        if input_object_sensor2
          result = input_object_sensor2.transform(coordinate_transformation)
        end
      else
        result = input_object_sensor2
      end

      return(result)

    end

     # Sets the sensor2 of the InputObject from the relative SketchUp coordinate system.
     def sketchup_sensor2=(point)

       if (Plugin.model_manager.relative_daylighting_coordinates?)
         self.input_object_sensor2 = point.transform(coordinate_transformation.inverse)
       else
         self.input_object_sensor2 = point
       end
    end

    # set sensor2 somewhere reasonable once sensor1 is placed
    def reset_lengths
      # In EnergyPlus 25.1, just copy sensor1 position and offset by 1m in x
      if @reference_point1 && @reference_point2
        x1 = @reference_point1.get_property('x_coordinate_of_reference_point', '0').to_f
        y1 = @reference_point1.get_property('y_coordinate_of_reference_point', '0').to_s
        z1 = @reference_point1.get_property('z_coordinate_of_reference_point', '0').to_s
        
        @reference_point2.set_property('x_coordinate_of_reference_point', (x1 + 1).to_s)
        @reference_point2.set_property('y_coordinate_of_reference_point', y1)
        @reference_point2.set_property('z_coordinate_of_reference_point', z1)
      end
    end

  end

end
