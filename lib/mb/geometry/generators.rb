module MB
  module Geometry
    module Generators
      class << self
        # Returns an array of vertices (two-element arrays) representing a regular
        # polygon with +sides+ sides, having a radius of +radius+, with the first
        # point on the right side of the X axis (plus +:rotation+ radians) and
        # proceeding counterclockwise.
        def regular_polygon(sides, radius, rotation: 0)
          points = []

          sides.times do |s|
            angle = rotation + s * 2.0 * Math::PI / sides
            x = radius * Math.cos(angle)
            y = radius * Math.sin(angle)
            points << [x, y]
          end

          points
        end

        # Returns an Array of randomly generated 2D points within a specified
        # region, using the given pseudorandom number generator.
        def random_points(count, xmin: -1.0, xmax: 1.0, ymin: -1.0, ymax: 1.0, random: Random::DEFAULT)
          xrange = xmin..xmax
          yrange = ymin..ymax

          count.times.map {
            [ random.rand(xrange), random.rand(yrange) ]
          }
        end
      end
    end
  end
end
