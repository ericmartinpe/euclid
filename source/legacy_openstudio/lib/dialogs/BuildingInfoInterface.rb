# OpenStudio
# Copyright (c) 2008-2015, Alliance for Sustainable Energy.  All rights reserved.
# See the file "License.txt" for additional terms and conditions.

require("euclid/lib/legacy_openstudio/lib/dialogs/DialogInterface")
require("euclid/lib/legacy_openstudio/lib/inputfile/InputObjectAdapter")


module LegacyOpenStudio

  class BuildingInfoInterface < DialogInterface

    def populate_hash

      @drawing_interface = Plugin.model_manager.selected_drawing_interface

      if (not @drawing_interface.nil?)
        @input_object = @drawing_interface.input_object

        @hash['NAME'] = @input_object.name
        @hash['ROTATION'] = @input_object.get_property('north_axis', '')
        terrain = @input_object.get_property('terrain', '').to_s
        if (terrain.empty?)
          @hash['TERRAIN'] = "SUBURBS"  # Show default value when blank
        else
          @hash['TERRAIN'] = terrain.upcase
        end
        @hash['LOADS_TOLERANCE'] = @input_object.get_property('loads_convergence_tolerance_value', '')
        @hash['TEMPERATURE_TOLERANCE'] = @input_object.get_property('temperature_convergence_tolerance_value', '')
        solar_dist = @input_object.get_property('solar_distribution', '').to_s
        if (solar_dist.empty?)
          @hash['SOLAR_DISTRIBUTION'] = "FULLEXTERIOR"  # Show default value when blank
        else
          @hash['SOLAR_DISTRIBUTION'] = solar_dist.upcase
        end
        @hash['MAX_WARMUP_DAYS'] = @input_object.get_property('maximum_number_of_warmup_days', '')

        zones = Plugin.model_manager.zones
        @hash['ZONES'] = zones.count

        spaces = Plugin.model_manager.input_file.find_objects_by_class_name("SPACE").collect { |object| object }
        @hash['SPACES'] = spaces.count

        floor_area = 0.0
        exterior_area = 0.0  # Exterior
        exterior_glazing_area = 0.0  # Exterior
        for zone in zones
          if (zone.include_in_building_floor_area?)
            floor_area += zone.floor_area
          end

          exterior_area += zone.exterior_area
          exterior_glazing_area += zone.exterior_glazing_area
        end

        if (exterior_area > 0.0)
          percent_glazing = 100.0 * exterior_glazing_area / exterior_area
        else
          percent_glazing = 0.0
        end

        # Need better method here
        if (Plugin.model_manager.units_system == "SI")
          i = 0
          floor_area = floor_area.to_m.to_m
          exterior_area = exterior_area.to_m.to_m
        else
          i = 1
          floor_area = floor_area.to_feet.to_feet
          exterior_area = exterior_area.to_feet.to_feet
        end

        @hash['FLOOR_AREA'] = floor_area.round_to(Plugin.model_manager.length_precision).to_s + " " + Plugin.model_manager.units_hash['m2'][i]
        @hash['EXTERIOR_AREA'] = exterior_area.round_to(Plugin.model_manager.length_precision).to_s + " " + Plugin.model_manager.units_hash['m2'][i]
        @hash['PERCENT_GLAZING'] = percent_glazing.round_to(1).to_s + " %"
        @hash['OBJECT_TEXT'] = @input_object.to_idf
      end

    end


    def report
      input_object_copy = @input_object.copy

      @input_object.set_property('name', @hash['NAME'].strip)
      @input_object.set_property('north_axis', @hash['ROTATION'].strip)
      @input_object.set_property('terrain', @hash['TERRAIN'])
      @input_object.set_property('loads_convergence_tolerance_value', @hash['LOADS_TOLERANCE'].strip)
      @input_object.set_property('temperature_convergence_tolerance_value', @hash['TEMPERATURE_TOLERANCE'].strip)
      @input_object.set_property('solar_distribution', @hash['SOLAR_DISTRIBUTION'])
      @input_object.set_property('maximum_number_of_warmup_days', @hash['MAX_WARMUP_DAYS'].strip)

      # Update object text with changes
      @hash['OBJECT_TEXT'] = @input_object.to_idf

      # Update drawing interface
      # Needs to transform all zones if the Building Axis has changed.

      if (@input_object != input_object_copy)
        Plugin.model_manager.input_file.modified = true
      end

      populate_hash

      # Update drawing interface
      Plugin.model_manager.building.on_change_input_object

      return(true)
    end

  end

end
