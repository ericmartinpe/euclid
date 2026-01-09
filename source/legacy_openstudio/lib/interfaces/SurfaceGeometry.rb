# OpenStudio
# Copyright (c) 2008-2015, Alliance for Sustainable Energy.  All rights reserved.
# See the file "License.txt" for additional terms and conditions.

require("euclid/lib/legacy_openstudio/lib/interfaces/DrawingInterface")
require("euclid/lib/legacy_openstudio/lib/inputfile/InputObjectAdapter")


module LegacyOpenStudio

  class SurfaceGeometry < DrawingInterface

    def create_input_object
      @input_object = InputObject.new("GLOBALGEOMETRYRULES")
      @input_object.fields[1] = "UpperLeftCorner"
      @input_object.fields[2] = "Counterclockwise"
      @input_object.fields[3] = "World"

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

        # Check "First Vertex" field (field 1 = starting_vertex_position)
        if (adapter.get_field(1).nil? || adapter.get_field(1).to_s.empty?)
          puts "SurfaceGeometry.first_vertex:  missing input for starting vertex"
          adapter.set_field(1, "UpperLeftCorner")
        else
          case(adapter.get_field(1).to_s.upcase)

          when "UPPERLEFTCORNER", "ULC"
            adapter.set_field(1, "UpperLeftCorner")

          when "LOWERLEFTCORNER", "LLC"
            adapter.set_field(1, "LowerLeftCorner")

          when "UPPERRIGHTCORNER", "URC"
            adapter.set_field(1, "UpperRightCorner")

          when "LOWERRIGHTCORNER", "LRC"
            adapter.set_field(1, "LowerRightCorner")

          else
            puts "SurfaceGeometry.vertex_order:  bad input for starting vertex"
            Plugin.model_manager.add_error("Error:  Bad input for starting vertex in GlobalGeometryRules object.\n")
            Plugin.model_manager.add_error("Starting vertex order has been reset to UpperLeftCorner.\n\n")

            adapter.set_field(1, "UpperLeftCorner")
          end
        end

        # Check "Vertex Order" field (field 2 = vertex_entry_direction)
        if (adapter.get_field(2).nil? || adapter.get_field(2).to_s.empty?)
          puts "SurfaceGeometry.vertex_order:  missing input for vertex order"
          adapter.set_field(2, "Counterclockwise")
        else
          case(adapter.get_field(2).to_s.upcase)

          when "CLOCKWISE", "CW"
            adapter.set_field(2, "Clockwise")

          when "COUNTERCLOCKWISE", "CCW"
            adapter.set_field(2, "Counterclockwise")

          else
            puts "SurfaceGeometry.vertex_order:  bad input for vertex order"
            Plugin.model_manager.add_error("Error:  Bad input for vertex order in GlobalGeometryRules object.\n")
            Plugin.model_manager.add_error("Vertex order has been reset to Counterclockwise.\n\n")

            adapter.set_field(2, "Counterclockwise")
          end
        end

        # Check "Coordinate System" field (field 3 = coordinate_system)
        if (adapter.get_field(3).nil? || adapter.get_field(3).to_s.empty?)
          puts "SurfaceGeometry.coordinate_system:  missing input for coordinate system"
          adapter.set_field(3, "World")
        else
          case(adapter.get_field(3).to_s.upcase)

          when "RELATIVE"
            adapter.set_field(3, "Relative")

          when "WCS", "WORLDCOORDINATESYSTEM", "WORLD", "ABSOLUTE"
            adapter.set_field(3, "World")

          else
            puts "SurfaceGeometry.coordinate_system:  bad input for coordinate system"
            Plugin.model_manager.add_error("Error:  Bad input for coordinate system in GlobalGeometryRules object.\n")
            Plugin.model_manager.add_error("Coordinate system has been reset to World.\n\n")

            adapter.set_field(3, "World")
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
