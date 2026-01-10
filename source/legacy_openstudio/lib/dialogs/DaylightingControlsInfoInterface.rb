# OpenStudio
# Copyright (c) 2008-2015, Alliance for Sustainable Energy.  All rights reserved.
# See the file "License.txt" for additional terms and conditions.

require("euclid/lib/legacy_openstudio/lib/dialogs/DialogInterface")


module LegacyOpenStudio

  class DaylightingControlsInfoInterface < DialogInterface

    def populate_hash

      @drawing_interface = Plugin.model_manager.selected_drawing_interface

      if (not @drawing_interface.nil?)
        @input_object = @drawing_interface.input_object

        # Get control_data array
        control_data = @input_object.get_property('control_data', [])
        
        # Determine number of points based on control_data
        num_points = control_data.is_a?(Array) ? control_data.length : 0
        @hash['NUMPOINTS'] = num_points.to_s
        
        # Get fractions and setpoints from control_data
        if num_points >= 1
          @hash['FRAC1'] = control_data[0]['fraction_of_lights_controlled_by_reference_point'].to_f
          @hash['SETPOINT1'] = control_data[0]['illuminance_setpoint_at_reference_point'].to_f
        else
          @hash['FRAC1'] = 1.0
          @hash['SETPOINT1'] = 500.0
        end
        
        if num_points >= 2
          @hash['FRAC2'] = control_data[1]['fraction_of_lights_controlled_by_reference_point'].to_f
          @hash['SETPOINT2'] = control_data[1]['illuminance_setpoint_at_reference_point'].to_f
        else
          @hash['FRAC2'] = 0.0
          @hash['SETPOINT2'] = 500.0
        end
        
        # Get other properties
        lighting_type_map = {'Continuous' => 1, 'Stepped' => 2, 'ContinuousOff' => 3}
        control_type_str = @input_object.get_property('lighting_control_type', 'Continuous')
        @hash['CONTROL_TYPE'] = lighting_type_map[control_type_str] || 1
        
        @hash['GLARE_ANGLE'] = @input_object.get_property('glare_calculation_azimuth_angle_of_view_direction_clockwise_from_zone_y_axis', '0').to_f
        @hash['MAX_GLARE'] = @input_object.get_property('maximum_allowable_discomfort_glare_index', '22').to_f
        @hash['INPUT_POWER_FRACTION'] = @input_object.get_property('minimum_input_power_fraction_for_continuous_or_continuousoff_dimming_control', '0.3').to_f
        @hash['OUTPUT_LIGHT_FRACTION'] = @input_object.get_property('minimum_light_output_fraction_for_continuous_or_continuousoff_dimming_control', '0.2').to_f
        @hash['NUM_STEPS'] = @input_object.get_property('number_of_stepped_control_steps', '1').to_i
        @hash['PROB_RESET'] = @input_object.get_property('probability_lighting_will_be_reset_when_needed_in_manual_stepped_control', '1').to_f

        # Get reference point coordinates
        ref_pt1 = @drawing_interface.instance_variable_get(:@reference_point1)
        ref_pt2 = @drawing_interface.instance_variable_get(:@reference_point2)
        
        # Need better method here
        if (Plugin.model_manager.units_system == "SI")
          i = 0
          if ref_pt1
            @hash['X1'] = ref_pt1.get_property('x_coordinate_of_reference_point', '0').to_f
            @hash['Y1'] = ref_pt1.get_property('y_coordinate_of_reference_point', '0').to_f
            @hash['Z1'] = ref_pt1.get_property('z_coordinate_of_reference_point', '0').to_f
          else
            @hash['X1'] = 0.0
            @hash['Y1'] = 0.0
            @hash['Z1'] = 0.0
          end

          if num_points >= 2 && ref_pt2
            @hash['X2'] = ref_pt2.get_property('x_coordinate_of_reference_point', '0').to_f
            @hash['Y2'] = ref_pt2.get_property('y_coordinate_of_reference_point', '0').to_f
            @hash['Z2'] = ref_pt2.get_property('z_coordinate_of_reference_point', '0').to_f
          else
            @hash['X2'] = ""
            @hash['Y2'] = ""
            @hash['Z2'] = ""
          end
        else
          i = 1
          m_to_ft = 3.2808399
          if ref_pt1
            @hash['X1'] = (m_to_ft*ref_pt1.get_property('x_coordinate_of_reference_point', '0').to_f).round_to(Plugin.model_manager.length_precision)
            @hash['Y1'] = (m_to_ft*ref_pt1.get_property('y_coordinate_of_reference_point', '0').to_f).round_to(Plugin.model_manager.length_precision)
            @hash['Z1'] = (m_to_ft*ref_pt1.get_property('z_coordinate_of_reference_point', '0').to_f).round_to(Plugin.model_manager.length_precision)
          else
            @hash['X1'] = 0.0
            @hash['Y1'] = 0.0
            @hash['Z1'] = 0.0
          end

          if num_points >= 2 && ref_pt2
            @hash['X2'] = (m_to_ft*ref_pt2.get_property('x_coordinate_of_reference_point', '0').to_f).round_to(Plugin.model_manager.length_precision)
            @hash['Y2'] = (m_to_ft*ref_pt2.get_property('y_coordinate_of_reference_point', '0').to_f).round_to(Plugin.model_manager.length_precision)
            @hash['Z2'] = (m_to_ft*ref_pt2.get_property('z_coordinate_of_reference_point', '0').to_f).round_to(Plugin.model_manager.length_precision)
          else
            @hash['X2'] = ""
            @hash['Y2'] = ""
            @hash['Z2'] = ""
          end
        end

        @hash['X_LABEL'] = "X-Coordinate of Reference Point " + Plugin.model_manager.units_hash['m'][i] + ":"
        @hash['Y_LABEL'] = "Y-Coordinate of Reference Point " + Plugin.model_manager.units_hash['m'][i] + ":"
        @hash['Z_LABEL'] = "Z-Coordinate of Reference Point " + Plugin.model_manager.units_hash['m'][i] + ":"
        @hash['OBJECT_TEXT'] = @input_object.to_idf
      end

    end


    def report

      input_object_copy = @input_object.copy

      # Get current reference points
      ref_pt1 = @drawing_interface.instance_variable_get(:@reference_point1)
      ref_pt2 = @drawing_interface.instance_variable_get(:@reference_point2)
      
      # Get number of points from the form
      num_points = @hash['NUMPOINTS'].to_i
      
      # Update control_data array
      control_data = []
      
      if num_points >= 1 && ref_pt1
        control_data << {
          'daylighting_reference_point_name' => ref_pt1.get_property('name'),
          'fraction_of_lights_controlled_by_reference_point' => @hash['FRAC1'].to_f,
          'illuminance_setpoint_at_reference_point' => @hash['SETPOINT1'].to_f
        }
      end
      
      if num_points >= 2 && ref_pt2
        control_data << {
          'daylighting_reference_point_name' => ref_pt2.get_property('name'),
          'fraction_of_lights_controlled_by_reference_point' => @hash['FRAC2'].to_f,
          'illuminance_setpoint_at_reference_point' => @hash['SETPOINT2'].to_f
        }
      end
      
      @input_object.set_property('control_data', control_data)
      
      # Update lighting control type
      control_type_map = {1 => 'Continuous', 2 => 'Stepped', 3 => 'ContinuousOff'}
      control_type_val = @hash['CONTROL_TYPE'].to_i
      @input_object.set_property('lighting_control_type', control_type_map[control_type_val] || 'Continuous')
      
      # Update other properties
      @input_object.set_property('glare_calculation_azimuth_angle_of_view_direction_clockwise_from_zone_y_axis', @hash['GLARE_ANGLE'].to_f.to_s)
      @input_object.set_property('maximum_allowable_discomfort_glare_index', @hash['MAX_GLARE'].to_f.to_s)
      @input_object.set_property('minimum_input_power_fraction_for_continuous_or_continuousoff_dimming_control', @hash['INPUT_POWER_FRACTION'].to_f.to_s)
      @input_object.set_property('minimum_light_output_fraction_for_continuous_or_continuousoff_dimming_control', @hash['OUTPUT_LIGHT_FRACTION'].to_f.to_s)
      @input_object.set_property('number_of_stepped_control_steps', @hash['NUM_STEPS'].to_i.to_s)
      @input_object.set_property('probability_lighting_will_be_reset_when_needed_in_manual_stepped_control', @hash['PROB_RESET'].to_f.to_s)

      # Need better method here
      if (Plugin.model_manager.units_system == "SI")
        i = 0
        if ref_pt1
          ref_pt1.set_property('x_coordinate_of_reference_point', @hash['X1'].to_f.to_s)
          ref_pt1.set_property('y_coordinate_of_reference_point', @hash['Y1'].to_f.to_s)
          ref_pt1.set_property('z_coordinate_of_reference_point', @hash['Z1'].to_f.to_s)
        end

        if num_points >= 2 and not @hash['X2'].to_s.empty? and not @hash['Y2'].to_s.empty? and not @hash['Z2'].to_s.empty? && ref_pt2
          ref_pt2.set_property('x_coordinate_of_reference_point', @hash['X2'].to_f.to_s)
          ref_pt2.set_property('y_coordinate_of_reference_point', @hash['Y2'].to_f.to_s)
          ref_pt2.set_property('z_coordinate_of_reference_point', @hash['Z2'].to_f.to_s)
        end
      else
        i = 1
        m_to_ft = 3.2808399
        ft_to_m = 1/m_to_ft
        if ref_pt1
          ref_pt1.set_property('x_coordinate_of_reference_point', (ft_to_m*@hash['X1'].to_f).to_s)
          ref_pt1.set_property('y_coordinate_of_reference_point', (ft_to_m*@hash['Y1'].to_f).to_s)
          ref_pt1.set_property('z_coordinate_of_reference_point', (ft_to_m*@hash['Z1'].to_f).to_s)
        end

        if num_points >= 2 and not @hash['X2'].to_s.empty? and not @hash['Y2'].to_s.empty? and not @hash['Z2'].to_s.empty? && ref_pt2
          ref_pt2.set_property('x_coordinate_of_reference_point', (ft_to_m*@hash['X2'].to_f).to_s)
          ref_pt2.set_property('y_coordinate_of_reference_point', (ft_to_m*@hash['Y2'].to_f).to_s)
          ref_pt2.set_property('z_coordinate_of_reference_point', (ft_to_m*@hash['Z2'].to_f).to_s)
        end
      end

      # Update object text with changes
      @hash['OBJECT_TEXT'] = @input_object.to_idf

      # Update drawing interface
      @drawing_interface.on_change_input_object

      if (@input_object != input_object_copy)
        Plugin.model_manager.input_file.modified = true
      end

      populate_hash

      return(true)
    end

  end

end
