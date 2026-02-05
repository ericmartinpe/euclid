# OpenStudio
# Copyright (c) 2008-2015, Alliance for Sustainable Energy.  All rights reserved.
# See the file "License.txt" for additional terms and conditions.

require("euclid/lib/legacy_openstudio/lib/dialogs/DialogInterface")


module LegacyOpenStudio

  class OutputIlluminanceMapInfoInterface < DialogInterface

    def populate_hash
      @drawing_interface = Plugin.model_manager.selected_drawing_interface

      if (not @drawing_interface.nil?)
        @input_object = @drawing_interface.input_object

        @hash['NAME'] = @input_object.name
        @hash['NUMXPOINTS'] = @input_object.get_property('number_of_x_grid_points', '10').to_i
        @hash['NUMYPOINTS'] = @input_object.get_property('number_of_y_grid_points', '10').to_i

        # Need better method here
        if (Plugin.model_manager.units_system == "SI")
          i = 0
          @hash['ZHEIGHT'] = @input_object.get_property('z_height', '0.0').to_f
          @hash['XMIN'] = @input_object.get_property('x_minimum_coordinate', '0.0').to_f
          @hash['XMAX'] = @input_object.get_property('x_maximum_coordinate', '1.0').to_f
          @hash['YMIN'] = @input_object.get_property('y_minimum_coordinate', '0.0').to_f
          @hash['YMAX'] = @input_object.get_property('y_maximum_coordinate', '1.0').to_f
          area = @drawing_interface.area.to_m.to_m
        else
          i = 1
          m_to_ft = 3.2808399
          ft_to_m = 1/m_to_ft
          @hash['ZHEIGHT'] = (m_to_ft*@input_object.get_property('z_height', '0.0').to_f).round_to(Plugin.model_manager.length_precision)
          @hash['XMIN'] = (m_to_ft*@input_object.get_property('x_minimum_coordinate', '0.0').to_f).round_to(Plugin.model_manager.length_precision)
          @hash['XMAX'] = (m_to_ft*@input_object.get_property('x_maximum_coordinate', '1.0').to_f).round_to(Plugin.model_manager.length_precision)
          @hash['YMIN'] = (m_to_ft*@input_object.get_property('y_minimum_coordinate', '0.0').to_f).round_to(Plugin.model_manager.length_precision)
          @hash['YMAX'] = (m_to_ft*@input_object.get_property('y_maximum_coordinate', '1.0').to_f).round_to(Plugin.model_manager.length_precision)
          area = @drawing_interface.area.to_feet.to_feet
        end

        @hash['ZHEIGHT_LABEL'] = "Z Height " + Plugin.model_manager.units_hash['m'][i] + ":"
        @hash['MIN_LABEL'] = "Minimum Coordinate " + Plugin.model_manager.units_hash['m'][i] + ":"
        @hash['MAX_LABEL'] = "Maximum Coordinate " + Plugin.model_manager.units_hash['m'][i] + ":"
        @hash['AREA'] = area.round_to(Plugin.model_manager.length_precision).to_s + " " + Plugin.model_manager.units_hash['m2'][i]
        @hash['OBJECT_TEXT'] = @input_object.to_idf
      end

    end


    def report
      input_object_copy = @input_object.copy

      @input_object.name = @hash['NAME']
      @input_object.set_property('number_of_x_grid_points', [@hash['NUMXPOINTS'].to_i, 1].max.to_s)
      @input_object.set_property('number_of_y_grid_points', [@hash['NUMYPOINTS'].to_i, 1].max.to_s)

      # Need better method here
      if (Plugin.model_manager.units_system == "SI")
        i = 0
        @input_object.set_property('z_height', @hash['ZHEIGHT'].to_f.to_s)
        @input_object.set_property('x_minimum_coordinate', @hash['XMIN'].to_f.to_s)
        @input_object.set_property('x_maximum_coordinate', @hash['XMAX'].to_f.to_s)
        @input_object.set_property('y_minimum_coordinate', @hash['YMIN'].to_f.to_s)
        @input_object.set_property('y_maximum_coordinate', @hash['YMAX'].to_f.to_s)
      else
        i = 1
        m_to_ft = 3.2808399
        ft_to_m = 1/m_to_ft
        @input_object.set_property('z_height', (ft_to_m*@hash['ZHEIGHT'].to_f).round_to(Plugin.model_manager.length_precision).to_s)
        @input_object.set_property('x_minimum_coordinate', (ft_to_m*@hash['XMIN'].to_f).round_to(Plugin.model_manager.length_precision).to_s)
        @input_object.set_property('x_maximum_coordinate', (ft_to_m*@hash['XMAX'].to_f).round_to(Plugin.model_manager.length_precision).to_s)
        @input_object.set_property('y_minimum_coordinate', (ft_to_m*@hash['YMIN'].to_f).round_to(Plugin.model_manager.length_precision).to_s)
        @input_object.set_property('y_maximum_coordinate', (ft_to_m*@hash['YMAX'].to_f).round_to(Plugin.model_manager.length_precision).to_s)
      end

      # Update object text with changes
      @hash['OBJECT_TEXT'] = @input_object.to_idf

      # Update drawing interface
      @drawing_interface.on_change_input_object

      if (@input_object != input_object_copy)
        Plugin.model_manager.input_file.modified = true
      end

      return(true)
    end

  end

end
