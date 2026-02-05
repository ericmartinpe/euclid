# OpenStudio
# Copyright (c) 2008-2015, Alliance for Sustainable Energy.  All rights reserved.
# See the file "License.txt" for additional terms and conditions.

require("euclid/lib/legacy_openstudio/lib/dialogs/DialogInterface")
require("euclid/lib/legacy_openstudio/lib/dialogs/SimulationInfoDialog")


module LegacyOpenStudio

  class SimulationInfoInterface < DialogInterface

    def initialize
      super
      @dialog = SimulationInfoDialog.new(nil, self, @hash)
    end


    def populate_hash
      input_object = Plugin.model_manager.surface_geometry.input_object

      if (input_object.get_property('coordinate_system', '').upcase == "RELATIVE")
        @hash['COORDINATE_SYSTEM'] = "RELATIVE"
      else
        @hash['COORDINATE_SYSTEM'] = "WORLD"
      end

      if (input_object.get_property('daylighting_reference_point_coordinate_system', '') and input_object.get_property('daylighting_reference_point_coordinate_system', '').upcase == "WORLD")
        @hash['DAYLIGHTING_COORDINATE_SYSTEM'] = "WORLD"
      else
        @hash['DAYLIGHTING_COORDINATE_SYSTEM'] = "RELATIVE"
      end

      if (input_object.get_property('rectangular_surface_coordinate_system', '') and input_object.get_property('rectangular_surface_coordinate_system', '').upcase == "WORLD")
        @hash['RECTANGULAR_COORDINATE_SYSTEM'] = "WORLD"
      else
        @hash['RECTANGULAR_COORDINATE_SYSTEM'] = "RELATIVE"
      end

      @hash['VERTEX_ORDER'] = input_object.get_property('vertex_entry_direction', '').upcase

      case(input_object.get_property('starting_vertex_position', '').upcase)
      when "UPPERLEFTCORNER"
        @hash['STARTING_VERTEX'] = "UPPER_LEFT_CORNER"

      when "LOWERLEFTCORNER"
        @hash['STARTING_VERTEX'] = "LOWER_LEFT_CORNER"

      when "UPPERRIGHTCORNER"
        @hash['STARTING_VERTEX'] = "UPPER_RIGHT_CORNER"

      when "LOWERRIGHTCORNER"
        @hash['STARTING_VERTEX'] = "LOWER_RIGHT_CORNER"
      end

      input_object = Plugin.model_manager.location.input_object
      if (input_object)
        @hash['LOCATION_NAME'] = input_object.name
        @hash['LATITUDE'] = input_object.get_property('latitude', '')
        @hash['LONGITUDE'] = input_object.get_property('longitude', '')
        @hash['TIME_ZONE'] = input_object.get_property('time_zone', '')
        @hash['ELEVATION'] = input_object.get_property('elevation', '')
      else
        puts "This file has no location."
      end

    end


    def report
      # Must handle SurfaceGeometry first because changing Location will trigger the ShadowInfoObserver which, in turn, updates this interface.

      # Report SurfaceGeometry input object
      input_object = Plugin.model_manager.surface_geometry.input_object
      input_object_copy = input_object.copy

      if (@hash['COORDINATE_SYSTEM'] == "RELATIVE")
        input_object.set_property('coordinate_system', 'Relative')
      else
        input_object.set_property('coordinate_system', 'World')
      end

      if (@hash['DAYLIGHTING_COORDINATE_SYSTEM'] == "RELATIVE")
        input_object.set_property('daylighting_reference_point_coordinate_system', 'Relative')
      else
        input_object.set_property('daylighting_reference_point_coordinate_system', 'World')
      end

      if (@hash['RECTANGULAR_COORDINATE_SYSTEM'] == "RELATIVE")
        input_object.set_property('rectangular_surface_coordinate_system', 'Relative')
      else
        input_object.set_property('rectangular_surface_coordinate_system', 'World')
      end

      if (@hash['VERTEX_ORDER'] == "CLOCKWISE")
        input_object.set_property('vertex_entry_direction', 'Clockwise')
      else
        input_object.set_property('vertex_entry_direction', 'Counterclockwise')
      end

      case(@hash['STARTING_VERTEX'])

      when "UPPER_LEFT_CORNER"
        input_object.set_property('starting_vertex_position', 'UpperLeftCorner')

      when "LOWER_LEFT_CORNER"
        input_object.set_property('starting_vertex_position', 'LowerLeftCorner')

      when "UPPER_RIGHT_CORNER"
        input_object.set_property('starting_vertex_position', 'UpperRightCorner')

      when "LOWER_RIGHT_CORNER"
        input_object.set_property('starting_vertex_position', 'LowerRightCorner')
      end

      Plugin.model_manager.surface_geometry.on_change_input_object  #.recalculate_vertices
      # There is a problem with putting 'recalculate_vertices' in the draw method
      # because it saves the existing vertices of any persistent drawing interfaces
      # and does not allow them to update with the new input object values.

      if (input_object != input_object_copy)
        Plugin.model_manager.input_file.modified = true
      end

      # Report Location input object
      input_object = Plugin.model_manager.location.input_object

      input_object.set_property('name', @hash['LOCATION_NAME'])
      input_object.set_property('latitude', @hash['LATITUDE'])
      input_object.set_property('longitude', @hash['LONGITUDE'])
      input_object.set_property('time_zone', @hash['TIME_ZONE'])
      input_object.set_property('elevation', @hash['ELEVATION'])

      # Update drawing interface
      Plugin.model_manager.location.on_change_input_object

      if (input_object != input_object_copy)
        Plugin.model_manager.input_file.modified = true
      end

      Plugin.dialog_manager.update(SimulationInfoInterface)
      Plugin.dialog_manager.update(ObjectInfoInterface)

      return(true)
    end


  end

end
