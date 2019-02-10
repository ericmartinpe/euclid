# OpenStudio
# Copyright (c) 2008-2015, Alliance for Sustainable Energy.  All rights reserved.
# See the file "License.txt" for additional terms and conditions.

require("euclid/lib/legacy_openstudio/lib/AsynchProc")
require("euclid/lib/legacy_openstudio/lib/interfaces/DrawingUtils")


module LegacyOpenStudio

  class FaceObserver < Sketchup::EntityObserver

    def initialize(drawing_interface)
      @drawing_interface = drawing_interface
    end


    # Gets called when the geometry of the Face changes, or when it is painted.
    def onChangeEntity(entity)
      #puts "FaceObserver.onChangeEntity:" + entity.to_s

      AsynchProc.new {
        # This proc is essential, otherwise there was an API bug with 'onChangeEntity' for faces that share an edge.
        # Only one face was getting the callback.  Appears the first callback was breaking the second callback.
        # Changing to an asynchronous proc solves the problem.

        #puts "on change proc for " + entity.to_s

        case (Sketchup.active_model.tools.active_tool_id)
        when (21041)  # PushPullTool
          # 'onChangeEntity' does not get called for bordering faces; only gets called for the face this is being
          # push/pulled. The result was that push/pulling a wall of a zone was not updating the bordering walls,
          # roof, and floor which created bad geometry.

          # On the first push/pull of a single face, the new bordering faces are already created at this point.
          # This is problematic because the new faces have not yet been updated with their own drawing_interface
          # attributes. Consequently the drawing_interface for the original face was being updated 6 times
          # (or more)--once for each face. The solution is to only update the unique drawing_interfaces.

          puts "push-pull surface: update immediate bordering surfaces"
          unique_interfaces = []
          @drawing_interface.entity.edges.each do |edge|
            edge.faces.each do |face|
              interface = face.drawing_interface
              if (not unique_interfaces.include?(interface))
                unique_interfaces << interface
              end
            end
          end

          unique_interfaces.each do |interface|
            if (interface.valid_entity? and interface.parent_from_entity)
              interface.on_change_entity
            end
          end
        else

          # Original update for just the changed surface:
          # Need to check the parent entity to make sure this face didn't find itself outside of a Group after an explode.
          if (@drawing_interface.valid_entity? and @drawing_interface.parent_from_entity)
            @drawing_interface.on_change_entity
          end
        end
      }
    end


    def onEraseEntity(entity)
      #puts "FaceObserver.onEraseEntity:" + entity.to_s

      # Because Face entities can become swapped, @drawing_interface might not be the one that was actually deleted.
      # See the description of the problem under SurfaceGroupEntitiesObserver.onElementAdded.

      # API Bug:  the 'entity' argument passed in to this callback appears to be a dummy Face object,
      # unrelated to the deleted Face (all of the Face data is gone, except entityID which is now negative.)

      # Which is why @drawing_interface is used to store the interface.  Otherwise, entity.drawing_interface is nil.

      AsynchProc.new {
        #puts "on erase face"
        # onEraseEntity gets called for each Face even when the parent Group gets erased.
        # This check avoids an error if the Group is already deleted.
        if (@drawing_interface.group_entity.valid?)

          swapped_face = nil

          # Check for swapping of face entities if the erased face was a BaseSurface.
          # (Swapping never happens when @drawing_interface is a SubSurface.)
          if (@drawing_interface.class == BaseSurface)
            drawing_interface_points = @drawing_interface.surface_polygon.points

            @drawing_interface.group_entity.entities.each { |this_entity|
              if ((this_entity.class == Sketchup::Face))
                face_points = this_entity.outer_polygon.reduce.points

                # Check to see if all drawing_object points are a subset of the face points.
                if (drawing_interface_points.is_subset_of?(face_points))
                  #puts "Found swapped face = " + this_entity.to_s
                  swapped_face = this_entity
                  break
                end
              end
            }
          end

          if (swapped_face)
            # 'swapped_face' is the only entity that is left.  'entity' is already erased.

            # Detach the drawing interface from the swapped surface.
            swapped_face.drawing_interface.remove_observers
            swapped_face.drawing_interface.on_erase_entity

            # Restore the drawing interface to the original face.
            swapped_face.drawing_interface = @drawing_interface
            swapped_face.input_object_key = @drawing_interface.input_object.key

            @drawing_interface.entity = swapped_face
            @drawing_interface.on_change_entity
            @drawing_interface.add_observers

          else
            # Normal erase
            @drawing_interface.on_erase_entity
          end

        else
          # Group was deleted--make sure to still erase the drawing interface!
          @drawing_interface.on_erase_entity
        end
      }

    end


  end

end
