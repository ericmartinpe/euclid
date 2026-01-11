# OpenStudio
# Copyright (c) 2008-2015, Alliance for Sustainable Energy.  All rights reserved.
# See the file "License.txt" for additional terms and conditions.

require("euclid/lib/legacy_openstudio/lib/interfaces/DrawingInterface")
require("euclid/lib/legacy_openstudio/lib/inputfile/InputObjectAdapter")


module LegacyOpenStudio

  class SurfaceGeometry < DrawingInterface

    def create_input_object
      @input_object = JsonInputObject.new("GlobalGeometryRules", "GlobalGeometryRules 1", {
        "starting_vertex_position" => "UpperLeftCorner",
        "vertex_entry_direction" => "Counterclockwise",
        "coordinate_system" => "World"
      })

      super
    end
    
    # Get an adapter for the input object
    def adapter
      @adapter ||= InputObjectAdapter.new(@input_object)
    end


    def parent_from_input_object
      return(Plugin.model_manager.model_interface)
    end


    # Drawing interfaces that don't correspond directly to a SketchUp entity (SurfaceGeometry, Building)
    # should return false here.
    def valid_entity?
      return(false)
    end


    # Drawing interfaces that don't correspond directly to a SketchUp entity (SurfaceGeometry, Building)
    # should return false here.
    def check_entity
      return(false)
    end


    # Checks needed before the entity can be drawn.
    # There should be no references to @entity in here.
    # Checks the input object for errors and tries to fix them before drawing the entity.
    # Returns false if errors are beyond repair.
    def check_input_object
      if (super)

        # Check "First Vertex" field (starting_vertex_position)
        if (@input_object.get_property("starting_vertex_position").nil? || @input_object.get_property("starting_vertex_position").to_s.empty?)
          puts "SurfaceGeometry.first_vertex:  missing input for starting vertex"
          @input_object.set_property("starting_vertex_position", "UpperLeftCorner")
        else
          case(@input_object.get_property("starting_vertex_position").to_s.upcase)

          when "UPPERLEFTCORNER", "ULC"
            @input_object.set_property("starting_vertex_position", "UpperLeftCorner")

          when "LOWERLEFTCORNER", "LLC"
            @input_object.set_property("starting_vertex_position", "LowerLeftCorner")

          when "UPPERRIGHTCORNER", "URC"
            @input_object.set_property("starting_vertex_position", "UpperRightCorner")

          when "LOWERRIGHTCORNER", "LRC"
            @input_object.set_property("starting_vertex_position", "LowerRightCorner")

          else
            puts "SurfaceGeometry.vertex_order:  bad input for starting vertex"
            Plugin.model_manager.add_error("Error:  Bad input for starting vertex in GlobalGeometryRules object.\n")
            Plugin.model_manager.add_error("Starting vertex order has been reset to UpperLeftCorner.\n\n")

            @input_object.set_property("starting_vertex_position", "UpperLeftCorner")
          end
        end

        # Check "Vertex Order" field (vertex_entry_direction)
        if (@input_object.get_property("vertex_entry_direction").nil? || @input_object.get_property("vertex_entry_direction").to_s.empty?)
          puts "SurfaceGeometry.vertex_order:  missing input for vertex order"
          @input_object.set_property("vertex_entry_direction", "Counterclockwise")
        else
          case(@input_object.get_property("vertex_entry_direction").to_s.upcase)

          when "CLOCKWISE", "CW"
            @input_object.set_property("vertex_entry_direction", "Clockwise")

          when "COUNTERCLOCKWISE", "CCW"
            @input_object.set_property("vertex_entry_direction", "Counterclockwise")

          else
            puts "SurfaceGeometry.vertex_order:  bad input for vertex order"
            Plugin.model_manager.add_error("Error:  Bad input for vertex order in GlobalGeometryRules object.\n")
            Plugin.model_manager.add_error("Vertex order has been reset to Counterclockwise.\n\n")

            @input_object.set_property("vertex_entry_direction", "Counterclockwise")
          end
        end

        # Check "Coordinate System" field (coordinate_system)
        if (@input_object.get_property("coordinate_system").nil? || @input_object.get_property("coordinate_system").to_s.empty?)
          puts "SurfaceGeometry.coordinate_system:  missing input for coordinate system"
          @input_object.set_property("coordinate_system", "World")
        else
          case(@input_object.get_property("coordinate_system").to_s.upcase)

          when "RELATIVE"
            @input_object.set_property("coordinate_system", "Relative")

          when "WCS", "WORLDCOORDINATESYSTEM", "WORLD", "ABSOLUTE"
            @input_object.set_property("coordinate_system", "World")

          else
            puts "SurfaceGeometry.coordinate_system:  bad input for coordinate system"
            Plugin.model_manager.add_error("Error:  Bad input for coordinate system in GlobalGeometryRules object.\n")
            Plugin.model_manager.add_error("Coordinate system has been reset to World.\n\n")

            @input_object.set_property("coordinate_system", "World")
          end
        end

        return(true)
      else
        return(false)
      end
    end


    def on_change_input_object
      # Recalculates all vertex coordinates based on current SurfaceGeometry rules (coord sys, vertex order, first vertex)
      Plugin.model_manager.all_surfaces.each { |drawing_interface| drawing_interface.update_input_object }
      Plugin.model_manager.output_illuminance_maps.each { |drawing_interface| drawing_interface.update_input_object }
      Plugin.model_manager.daylighting_controls.each { |drawing_interface| drawing_interface.update_input_object }

      Plugin.dialog_manager.update(ObjectInfoInterface)
    end


    # Not used, but could recalculate and redraw all geometry in the new coordinate system.
    def update_entity
    end


  end

end
