# OpenStudio
# Copyright (c) 2008-2015, Alliance for Sustainable Energy.  All rights reserved.
# Copyright (c) 2017-2020, Big Ladder Software LLC. All rights reserved.
# See the file "License.txt" for additional terms and conditions.


module LegacyOpenStudio

  # Maps IDF field indices to epJSON property names
  # This enables the interface classes to work with both IDF and epJSON formats
  class FieldMapper
    
    # Mappings for geometry-related objects
    MAPPINGS = {
      "ZONE" => {
        1 => "name",  # Note: in epJSON, name is the object key, not a property
        2 => "direction_of_relative_north",
        3 => "x_origin",
        4 => "y_origin",
        5 => "z_origin",
        6 => "type",
        7 => "multiplier",
        8 => "ceiling_height",
        9 => "volume",
        10 => "floor_area",
        11 => "zone_inside_convection_algorithm",
        12 => "zone_outside_convection_algorithm",
        13 => "part_of_total_floor_area"
      },
      
      "BUILDINGSURFACE:DETAILED" => {
        1 => "name",
        2 => "surface_type",
        3 => "construction_name",
        4 => "zone_name",
        5 => "space_name",
        6 => "outside_boundary_condition",
        7 => "outside_boundary_condition_object",
        8 => "sun_exposure",
        9 => "wind_exposure",
        10 => "view_factor_to_ground",
        11 => "number_of_vertices"
        # 12+ are vertices (handled specially)
      },
      
      "FENESTRATIONSURFACE:DETAILED" => {
        1 => "name",
        2 => "surface_type",
        3 => "construction_name",
        4 => "building_surface_name",
        5 => "outside_boundary_condition_object",
        6 => "view_factor_to_ground",
        7 => "frame_and_divider_name",
        8 => "multiplier",
        9 => "number_of_vertices"
        # 10+ are vertices
      },
      
      "SHADING:SITE:DETAILED" => {
        1 => "name",
        2 => "transmittance_schedule_name",
        3 => "number_of_vertices"
        # 4+ are vertices
      },
      
      "SHADING:BUILDING:DETAILED" => {
        1 => "name",
        2 => "transmittance_schedule_name",
        3 => "number_of_vertices"
        # 4+ are vertices
      },
      
      "SHADING:ZONE:DETAILED" => {
        1 => "name",
        2 => "base_surface_name",
        3 => "transmittance_schedule_name",
        4 => "number_of_vertices"
        # 5+ are vertices
      },
      
      "BUILDING" => {
        1 => "name",
        2 => "north_axis",
        3 => "terrain",
        4 => "loads_convergence_tolerance_value",
        5 => "temperature_convergence_tolerance_value",
        6 => "solar_distribution",
        7 => "maximum_number_of_warmup_days",
        8 => "minimum_number_of_warmup_days"
      },
      
      "SITE:LOCATION" => {
        1 => "name",
        2 => "latitude",
        3 => "longitude",
        4 => "time_zone",
        5 => "elevation"
      },
      
      "GLOBALGEOMETRYRULES" => {
        1 => "starting_vertex_position",
        2 => "vertex_entry_direction",
        3 => "coordinate_system"
      },
      
      "DAYLIGHTING:CONTROLS" => {
        1 => "name",
        2 => "zone_name",
        3 => "daylighting_method",
        4 => "availability_schedule_name",
        5 => "lighting_control_type",
        6 => "minimum_input_power_fraction_for_continuous_or_continuousoff_dimming_control",
        7 => "minimum_light_output_fraction_for_continuous_or_continuousoff_dimming_control",
        8 => "number_of_stepped_control_steps",
        9 => "probability_lighting_will_be_reset_when_needed_in_manual_stepped_control",
        10 => "glare_calculation_daylighting_reference_point_name",
        11 => "glare_calculation_azimuth_angle_of_view_direction_clockwise_from_zone_y_axis",
        12 => "maximum_allowable_discomfort_glare_index",
        13 => "dep_height_of_work_plane",
        14 => "minimum_input_power_fraction_for_continuous_dimming_control",
        15 => "minimum_light_output_fraction_for_continuous_dimming_control",
        16 => "number_of_control_steps"
      },
      
      "OUTPUT:ILLUMINANCEMAP" => {
        1 => "name",
        2 => "zone_name",
        3 => "z_height",
        4 => "x_minimum_coordinate",
        5 => "x_maximum_coordinate",
        6 => "number_of_x_grid_points",
        7 => "y_minimum_coordinate",
        8 => "y_maximum_coordinate",
        9 => "number_of_y_grid_points"
      }
    }
    
    # Convert IDF field index to epJSON property name
    def self.to_property(object_type, field_index)
      MAPPINGS[object_type.upcase]&.[](field_index)
    end
    
    # Convert epJSON property name to IDF field index
    def self.to_field_index(object_type, property_name)
      mapping = MAPPINGS[object_type.upcase]
      return nil unless mapping
      mapping.key(property_name)
    end
    
    # Check if this field index represents vertices
    def self.is_vertices?(object_type, field_index)
      case object_type.upcase
      when "BUILDINGSURFACE:DETAILED"
        field_index >= 12
      when "FENESTRATIONSURFACE:DETAILED"
        field_index >= 10
      when "SHADING:SITE:DETAILED"
        field_index >= 4
      when "SHADING:BUILDING:DETAILED"
        field_index >= 4
      when "SHADING:ZONE:DETAILED"
        field_index >= 5
      else
        false
      end
    end
    
    # Get the starting field index for vertices
    def self.vertices_start_index(object_type)
      case object_type.upcase
      when "BUILDINGSURFACE:DETAILED"
        12
      when "FENESTRATIONSURFACE:DETAILED"
        10
      when "SHADING:SITE:DETAILED"
        4
      when "SHADING:BUILDING:DETAILED"
        4
      when "SHADING:ZONE:DETAILED"
        5
      else
        nil
      end
    end
  end

end
