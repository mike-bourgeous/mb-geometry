require 'matrix'

module MB
  # Pure Ruby Delaunay triangulation.
  class Delaunay
    class Hull
      # Analogous to LM(s) and RM(s) in Lee and Schachter.
      attr_reader :leftmost, :rightmost

      def initialize(points)
        @points = points
        @leftmost = points.min_by(&:idx)
        @rightmost = points.max_by(&:idx)
      end

      def add_point(p)
        @leftmost = p if @leftmost.nil? || p < @leftmost
        @rightmost = p if @rightmost.nil? || p > @rightmost
        raise NotImplementedError
      end

      def add_hull(h)
        @leftmost = h.leftmost if @leftmost.nil? || h.leftmost < @leftmost
        @rightmost = h.rightmost if @rightmost.nil? || h.rightmost > @rightmost
        raise NotImplementedError
      end

      # Returns the upper and lower tangents linking this left-side hull to the
      # +right+ convex hull.
      #
      # Called HULL in Lee and Schachter (extended to return both tangents).
      def tangents(right)
        x = left.rightmost
        y = right.leftmost

        raise "Rightmost point on left-side hull #{self} is to the right of leftmost point on right-side hull #{right}"
        left = self

        # Walk clockwise around left, counterclockwise around right, until the
        # next point on both sides is left of X->Y, showing that X->Y is the
        # lowest segment.
        z = y.first
        z1 = x.first
        z2 = x.previous(z1)
        loop do
          if z.right_of?(x, y)
            old_z = z
            z = z.next(y)
            y = old_z
          elsif z2.right_of?(x, y)
            old_z2 = z2
            z2 = z2.previous(x)
            x = old_z2
          else
            lower = [x, y]
            break
          end
        end

        # Walk counterclockwise around left, clockwise around right, until the
        # next point on both sides is to the right of X->Y, showing that X->Y is
        # the highest segment.
        x = left.rightmost
        y = right.leftmost
        z_r = y.previous(y.first)
        z_l = x.first
        loop do
          if z_r.left_of?(x, y)
            old_z = z_r
            z_r = z_r.previous(y)
            y = old_z
          elsif z_l.left_of?(x, y)
            old_z = z_l
            z_l = z_l.next(x)
            x = old_z
          else
            upper = [x, y]
            break
          end
        end

        return lower, upper
      end
    end

    # TODO: Do we need a Line class to represent the tangents worked on by #merge?

    class Point
      include Comparable

      attr_reader :x, :y

      def initialize(x, y)
        @x = x
        @y = y

        @cw = {}
        @ccw = {}
      end

      def <=>(other)
        return nil unless other.is_a?(Point)

        if x < other.x || (x == other.x && y < other.y)
          -1
        elsif x == other.x && y == other.y
          0
        else
          1
        end
      end

      # Returns the 2D cross product between the two rays +o+->+p+ and
      # +o+->self.  If this value is 0, then +p+ and self are on the same line
      # through o.  If negative, then self is to the right of +o+->+p+.  If
      # positive, then self is to the left.
      #
      # FIXME: this should maybe reordered as a method on +o+?
      def cross(o, p)
        (p.x - o.x) * (self.y - o.y) - (p.y - o.y) * (self.x - o.x)
      end

      # Returns true if this point is to the right of the ray from +p1+ to
      # +p2+.  Returns false if left or collinear.
      # TODO: understand better and explain better
      # https://en.wikipedia.org/wiki/Cross_product#Computational_geometry
      # https://stackoverflow.com/questions/1560492/how-to-tell-whether-a-point-is-to-the-right-or-left-side-of-a-line
      def right_of?(p1, p2)
        cross(p1, p2) < 0
      end

      # Returns true if this point is to the left of the ray from +p1+ to +p2+.
      # Returns false if right or collinear.
      def left_of?(p1, p2)
        cross(p1, p2) > 0
      end

      # Returns the next clockwise neighbor to this point from point +p+.
      # 
      # Called PRED(v_i, v_ij) in Lee and Schachter, where v_i is Ruby +self+,
      # and v_ij is +p+.  This uses a Hash, while the 1980 paper mentions a
      # circular doubly-linked list.
      def previous(p)
        @cw[p] || (raise "Point #{p} is not a neighbor of #{self}")
      end

      # Returns the next counterclockwise neighbor to this point from point
      # +p+.
      #
      # Called SUCC in Lee and Schachter.
      def next(p)
        @ccw[p] || (raise "Point #{p} is not a neighbor of #{self}")
      end

      def first
        raise NotImplementedError
      end

      def add(p)
        raise "Cannot add an identical point as a neighbor of a point" if p == self

        # Add to cw in sorted order by relative angle
        # Add to ccw [ditto]
        raise NotImplementedError
      end

      def remove(p)
        # Remove from cw and re-link cw
        # Remove from ccw and re-link ccw
        raise NotImplementedError
      end
    end

    def initialize(points)
      @points = points.map { |x, y| Point.new(x, y) }
      @points.sort! # Point implements <=> to sort by X and break ties by Y
      triangulate(@points)
    end

    private

    # Creates an edge between two points.
    #
    # Analogous to INSERT(A, B) from Lee and Schachter.
    def join(p1, p2)
      raise NotImplementedError
      p1.add(p2)
      p2.add(p1)
    end

    # Analogous to DELETE(A, B) from Lee and Schachter.
    def unjoin(p1, p2)
      p1.remove(p2)
      p2.remove(p2)
    end

    def triangulate(points)
      if points.length <= 3
        raise NotImplementedError, 'TODO: Trivial triangulation; return as a Hull'
      else
        n = points.length / 2
        left = points[0...n]
        right = points[n..-1]
        merge(triangulate(left), triangulate(right))
      end
    end

    # Merges two convex hulls that contain locally complete Delauney
    # triangulations.
    #
    # Called MERGE in Lee and Schachter.
    def merge(left, right)
      raise NotImplementedError
    end

    # Returns true if the query point +q+ is not inside the circumcircle
    # defined by +p1+, +p2+, and +p3+.
    #
    # Analogous to QTEST(H, I, J, K) in Lee and Schachter.
    def outside?(p1, p2, p3, q)
      # TODO: memoize circumcircle and relative-angle computations?
      x, y, r = circumcircle(p1.x, p1.y, p2.x, p2.y, p3.x, p3.y)
      d = Math.sqrt((q.x - x) ** 2 + (q.y - y) ** 2)
      d >= r
    end

    public

    # Temporarily copied here from my Geometry class in another project, to be
    # merged eventually.
    # Returns the circumcenter of the triangle defined by the given three
    # points as [x, y].  Returns nil if the points are collinear.
    #
    # The circumcenter of a polygon is the center of the circle that passes
    # through all the points of the polygon.  See also #circumcircle.
    def self.circumcenter(x1, y1, x2, y2, x3, y3)
      b1 = perpendicular_bisector(x1, y1, x2, y2)
      b2 = perpendicular_bisector(x2, y2, x3, y3)

      x, y = line_intersection(b1, b2)
      return nil if x.nil? || y.nil?

      [x, y]
    end

    # Temporarily copied here from my Geometry class in another project, to be
    # merged eventually.
    # Returns the circumcircle of the triangle defined by the given three
    # points as [x, y, r].  Returns nil if the points are collinear.
    def self.circumcircle(x1, y1, x2, y2, x3, y3)
      x, y = circumcenter(x1, y1, x2, y2, x3, y3)
      return nil if x.nil? || y.nil?

      r = Math.sqrt((x - x1) ** 2 + (y - y1) ** 2)
      [x, y, r]
    end

    # Temporarily copied here from my Geometry class in another project, to be
    # merged eventually.
    # Returns a line that is the perpendicular bisector of the given segment as
    # [a, b, c], where a * x + b * y = c.
    #
    # Based on the derivation from https://math.stackexchange.com/a/2079662
    def self.perpendicular_bisector(x1, y1, x2, y2)
      [
        x2 - x1,
        y2 - y1,
        0.5 * (x2 * x2 - x1 * x1 + y2 * y2 - y1 * y1)
      ]
    end
    
    # Temporarily copied here from my Geometry class in another project, to be
    # merged eventually.
    # Finds the line intersection, if any, between two lines given coordinates
    # in the form used by rubyvor (either [a, b, c] or [:l, a, b, c], using
    # the formula ax + by = c).  Returns an array of [x, y] if a single
    # intersection exists.  Returns nil if the lines are coincident or there is
    # no intersection.
    def self.line_intersection(line1, line2)
      line1 = line1[1..3] if line1[0] == :l
      line2 = line2[1..3] if line2[0] == :l
      a, b, c = line1
      d, e, f = line2

      # Detect coincident and parallel lines
      return nil if (b * d - a * e) == 0

      denom = (b * d - a * e).to_f
      x = (b * f - c * e) / denom
      y = (c * d - a * f) / denom

      [x, y]
    end
  end
end
