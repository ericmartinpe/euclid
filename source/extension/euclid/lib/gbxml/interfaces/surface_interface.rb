# Copyright (c) 2017 Big Ladder Software LLC. All rights reserved.
# See the file "license.txt" for additional terms and conditions.

require("euclid/lib/legacy_openstudio/lib/interfaces/Surface")


module Euclid
  module GbXML

    class SurfaceInterface < LegacyOpenStudio::Surface

      def input_object_polygon
        # Convert BEMkit::Geometry::Polygon to Geom::Polygon.
        points = []
        for point in @input_object.polygon.points
          points << Geom::Point3d.new(point.x.feet.to_f, point.y.feet.to_f, point.z.feet.to_f)
        end
        return(Geom::Polygon.new(points))
      end


      # Sets the vertices of the InputObject as they should literally appear in the input fields.
      def input_object_polygon=(polygon)
        # Convert Geom::Polygon to BEMkit::Geometry::Polygon.
        points = []
        decimal_places = 12
        for point in polygon.points
          x = point.x.to_feet.round_to(decimal_places)
          y = point.y.to_feet.round_to(decimal_places)
          z = point.z.to_feet.round_to(decimal_places)

          points << BEMkit::Geometry::Point.new(x, y, z)
        end
        @input_object.polygon = BEMkit::Geometry::Polygon.new(*points)
      end


      def vertex_order
        return("COUNTERCLOCKWISE")  # gbXML is always counterclockwise
      end


      def first_vertex
        return("UPPERLEFTCORNER")
      end

    end

  end
end
