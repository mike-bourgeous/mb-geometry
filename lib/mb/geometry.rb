require 'matrix'

require 'mb-math'
require 'mb-util'

require_relative 'geometry/version'

module MB
  # Inefficient algorithms for some basic geometric operations.
  module Geometry
    # Geometry DSL methods to add to Numeric.
    module NumericAddons
      # Returns a rotation matrix of the current numeric in radians.
      #
      # Example:
      # 1.degree.rotation
      # => Matrix[....]
      #
      # 90.degree.rotation * Vector[1, 0]
      # => Vector[0, 1]
      def rotation
        # Values are rounded to 12 decimal places so that exact values like 0,
        # 0.5, and 1 come out whole.
        a = self.to_f
        Matrix[
          [Math.cos(a).round(12), -Math.sin(a).round(12)],
          [Math.sin(a).round(12), Math.cos(a).round(12)]
        ]
      end
    end

    Numeric.include(NumericAddons)

    class << self
      # Finds the line intersection, if any, between two lines given coordinates
      # in the form used by rubyvor (either [a, b, c] or [:l, a, b, c], using
      # the formula ax + by = c).  Returns an array of [x, y] if a single
      # intersection exists.  Returns nil if the lines are coincident or there is
      # no intersection.
      def line_intersection(line1, line2)
        a, b, c = line1
        d, e, f = line2

        denom = (b * d - a * e).to_f

        # Detect coincident and parallel lines
        return nil if denom == 0

        x = (b * f - c * e) / denom
        y = (c * d - a * f) / denom

        [x, y]
      end

      # Returns an array of [x, y] if the two segments (given by arrays of [x1,
      # y1, x2, y2]) intersect.  Returns nil if the segments are parallel or do
      # not intersect.
      def segment_intersection(seg1, seg2)
        x1, y1, x2, y2 = seg1
        x3, y3, x4, y4 = seg2
        line1 = segment_to_line(*seg1)
        line2 = segment_to_line(*seg2)

        xmin = [[x1, x2].min, [x3, x4].min].max
        xmax = [[x1, x2].max, [x3, x4].max].min
        ymin = [[y1, y2].min, [y3, y4].min].max
        ymax = [[y1, y2].max, [y3, y4].max].min

        x, y = line_intersection(line1, line2)
        return nil unless x && y

        if x >= xmin && x <= xmax && y >= ymin && y <= ymax
          return [x, y]
        end

        nil
      end

      # Generates an arbitrary segment for the given line a * x + b * y = c.
      # Possibly useful for working with vertical or horizontal lines via the dot
      # product.  Returns [x1, y1, x2, y2].
      def line_to_segment(a, b, c)
        raise 'Invalid line (a or b must be nonzero)' if a == 0 && b == 0

        if a == 0
          y = c.to_f / b
          [0.0, y, 1.0, y]
        elsif b == 0
          x = c.to_f / a
          [x, 0.0, x, 1.0]
        else
          [0.0, c.to_f / b, 1.0, (c - a).to_f / b]
        end
      end

      # Finds the general form of a line intersecting the given points.  Returns
      # [a, b, c] where a * x + b * y = c.
      def segment_to_line(x1, y1, x2, y2)
        raise 'Need two distinct points to define a segment' if x1 == x2 && y1 == y2

        # Vertical/horizontal/oblique lines
        if y1 == y2
          [0.0, 1.0, y1]
        elsif x1 == x2
          [1.0, 0.0, x1]
        else
          [y1 - y2, x2 - x1, x2 * y1 - x1 * y2]
        end
      end

      # Returns the area of a 2D polygon with the given +vertices+ in order of
      # connection, each of which must be a 2D coordinate (an array of two
      # numbers).  If vertices are given clockwise, the area will be negative.
      #
      # Uses the formula from http://mathworld.wolfram.com/PolygonArea.html
      def polygon_area(vertices)
        raise "A polygon must have 3 or more vertices, not #{vertices.length}" unless vertices.length >= 3

        area = 0

        # Rely on Ruby's circular array indexing for negative indices
        vertices.size.times do |idx|
          x2, y2 = vertices[idx]
          x1, y1 = vertices[idx - 1]
          area += x1 * y2 - x2 * y1
        end

        return area * 0.5
      end

      # Dot product of two vectors (x1, y1) and (x2, y2).
      #
      # Using Ruby's Vector class (from require 'matrix') is probably a better
      # option, when possible.
      def dot(x1, y1, x2, y2)
        x1 * x2 + y1 * y2
      end

      # Computes a bounding box for the given 2D +points+ (an array of
      # two-element arrays), returned as [xmin, ymin, xmax, ymax].  If +expand+
      # is given and greater than 0.0, then the bounding box dimensions will be
      # multiplied by (1.0 + +expand+).
      def bounding_box(points, expand = nil)
        raise ArgumentError, 'No points were given' if points.empty?

        xmin = Float::INFINITY
        ymin = Float::INFINITY
        xmax = -Float::INFINITY
        ymax = -Float::INFINITY

        points.each do |x, y|
          xmin = x if xmin > x
          ymin = y if ymin > y
          xmax = x if xmax < x
          ymax = y if ymax < y
        end

        if expand && expand > 0.0
          extra_width = 0.5 * expand * (xmax - xmin)
          extra_height = 0.5 * expand * (ymax - ymin)

          xmin -= extra_width
          xmax += extra_width
          ymin -= extra_height
          ymax += extra_height
        end

        [xmin, ymin, xmax, ymax]
      end

      # Clips a segment to a bounding box.  Returns the clipped segment as an
      # array with [x1, y1, x2, y2].
      #
      # TODO: Delete this if it is never used and no tests are written.
      def clip_segment(segment, box)
        xmin, ymin, xmax, ymax = box
        x1, y1, x2, y2 = segment

        new_segment = []

        if x1 >= xmin && x1 <= xmax && y1 >= ymin && y1 <= ymax
          new_segment += [x1, y1]
        end

        if x2 >= xmin && x2 <= xmax && y2 >= ymin && y2 <= ymax
          new_segment += [x2, y2]
        end

        return new_segment if new_segment.size == 4

        bounds = {
          top: [xmin, ymax, xmax, ymax],
          left: [xmin, ymin, xmin, ymax],
          bottom: [xmin, ymin, xmax, ymin],
          right: [xmax, ymin, xmax, ymax],
        }

        bounds.each do |edge, edge_seg|
          if intersection = segment_intersection(segment, edge_seg)
            puts "Segment intersects with #{edge}"
            new_segment += intersection

            puts "New segment is #{new_segment.inspect}"
            return new_segment if new_segment.size == 4
          end
        end

        raise 'No segment could be formed'
      end

      # Returns the distance from the line described by a*x + b*y = c to the
      # point (x, y).
      #
      # Based on the formula from
      # http://mathworld.wolfram.com/Point-LineDistance2-Dimensional.html
      def distance_to_line(a, b, c, x, y)
        # Using -c instead of +c due to moving C across the equals sign
        (a * x + b * y - c).abs.to_f / Math.sqrt(a * a + b * b)
      end

      # Returns a line that is the perpendicular bisector of the given segment as
      # [a, b, c], where a * x + b * y = c.
      #
      # Based on the derivation from https://math.stackexchange.com/a/2079662
      def perpendicular_bisector(x1, y1, x2, y2)
        [
          x2 - x1,
          y2 - y1,
          0.5 * (x2 * x2 - x1 * x1 + y2 * y2 - y1 * y1)
        ]
      end

      # Returns the circumcenter of the triangle defined by the given three
      # points as [x, y].  Returns nil if the points are collinear.
      #
      # The circumcenter of a polygon is the center of the circle that passes
      # through all the points of the polygon.  See also #circumcircle.
      def circumcenter(x1, y1, x2, y2, x3, y3)
        b1 = perpendicular_bisector(x1, y1, x2, y2)
        b2 = perpendicular_bisector(x2, y2, x3, y3)

        x, y = line_intersection(b1, b2)
        return nil if x.nil? || y.nil?

        [x, y]
      end

      # Returns the circumcircle of the triangle defined by the given three
      # points as [x, y, rsquared].  Returns nil if the points are collinear.
      def circumcircle(x1, y1, x2, y2, x3, y3)
        x, y = circumcenter(x1, y1, x2, y2, x3, y3)
        return nil if x.nil? || y.nil?

        dx = x - x1
        dy = y - y1
        rsquared = dx * dx + dy * dy

        [x, y, rsquared]
      end

      # Returns the average of all of the given points.  Each point should have
      # the same number of dimensions.  Returns nil if no points were given.
      def centroid(points)
        return nil if points.empty?

        sum = points.reduce([0] * points.first.size) { |acc, point|
          acc.size.times do |i|
            acc[i] += point[i]
          end
          acc
        }

        sum.map { |v| v.to_f / points.size }
      end

      # Returns a Matrix that will scale 2D vectors by +:xscale+/+:yscale+
      # (each defaults to copying the other, but at least one must be
      # specified) centered around the point (+:xcenter+, +:ycenter+).
      # Multiply with an augmented Vector to apply the transformation.
      #
      # Example:
      #     v = Vector[2, 2, 1] # Third/augmented element (w) must be 1
      #     m = MB::Geometry.scale_matrix(xscale: 3, yscale: 2, xcenter: 1, ycenter: 1)
      #     m * v
      #     # => Vector[4, 3, 1] # x, y, w
      def scale_matrix(xscale:, yscale: nil, xcenter: 0, ycenter: 0)
        raise "Specify at least one of :xscale and :yscale" if !(xscale || yscale)
        xscale ||= yscale
        yscale ||= xscale

        Matrix[
          [xscale, 0, -xcenter * (xscale - 1)],
          [0, yscale, -ycenter * (yscale - 1)],
          [0, 0, 1]
        ]
      end
    end
  end
end

require_relative 'geometry/generators'
require_relative 'geometry/delaunay'
require_relative 'geometry/voronoi'
require_relative 'geometry/voronoi_animator'
require_relative 'geometry/correction'
