require 'matrix'
require 'forwardable'
require 'set'

module MB
  # Pure Ruby Delaunay triangulation.
  class Delaunay
    class Hull
      extend Forwardable

      # Analogous to LM(s) and RM(s) in Lee and Schachter.
      attr_reader :leftmost, :rightmost, :points, :hull_id

      def_delegators :@points, :count, :length, :size

      # +points+ *must* already be sorted by [x,y].
      def initialize(points)
        @@hull_id ||= 0
        @hull_id = @@hull_id
        @@hull_id += 1

        @points = points.dup
        @leftmost = points.first
        @rightmost = points.last

        points.each do |p| p.hull = self end
      end

      def add_hull(h)
        @rightmost = h.rightmost
        @points.concat(h.points)

        h.points.each do |p| p.hull = self end

        self
      end

      # Returns the upper and lower tangents linking this left-side hull to the
      # +right+ convex hull.
      #
      # Called HULL in Lee and Schachter (extended to return both tangents).
      def tangents(right)
        left = self

        max_count = left.count + right.count

        # Walk clockwise around left, counterclockwise around right, until the
        # next point on both sides is left of X->Y, showing that X->Y is the
        # lowest segment.
        x = left.rightmost
        y = right.leftmost
        z = y.first
        z1 = x.first
        z2 = z1 && x.clockwise(z1)
        lower = nil
        max_count.times do
          if z && z.right_of?(x, y)
            old_z = z
            z = z.counterclockwise(y)
            y = old_z
          elsif z2 && z2.right_of?(x, y)
            old_z2 = z2
            z2 = z2.clockwise(x)
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
        z = y.first
        z_r = z && y.clockwise(z)
        z_l = x.first
        upper = nil
        max_count.times do
          if z_r && z_r.left_of?(x, y)
            old_z = z_r
            z_r = z_r.clockwise(y)
            y = old_z
          elsif z_l && z_l.left_of?(x, y)
            old_z = z_l
            z_l = z_l.counterclockwise(x)
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
      attr_reader :x, :y, :first

      attr_accessor :hull

      def initialize(x, y, idx = nil)
        @x = x.round(9)
        @y = y.round(9)
        @idx = idx

        @pointset = Set.new
        @neighbors = []
        @first = nil
        @hull = nil
        @name = nil
      end

      def name
        @name || "#{@idx}"
      end

      # Sets a name for this point (+n+ will be prefixed by the point's index).
      def name=(n)
        if n.nil?
          @name = nil
        else
          @name = "#{@idx}: #{n}"
        end
      end

      # Compares points by X, using Y to break ties.
      #
      # Lee and Schachter refer to this as lexicographic ordering.  It's what
      # would happen naturally if you sorted a point array in Ruby by [x, y].
      def <=>(other)
        if x < other.x || (x == other.x && y < other.y)
          -1
        elsif x == other.x && y == other.y
          0
        else
          1
        end
      end

      def <(other)
        x < other.x || x == other.x && y < other.y
      end

      def >(other)
        x > other.x || x == other.x && y > other.y
      end

      def to_s
        "#{@idx}: [#{@x}, #{@y}]{#{@neighbors.length}}"
      end

      def inspect
        "#<MB::Delaunay::Point:#{__id__} #{to_s}"
      end

      # Returns an angle from self to +p+ from -PI to PI starting at the
      # negative X axis.
      def angle(p)
        Math.atan2(p.y - self.y, p.x - self.x)
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

      def neighbors
        @neighbors.dup
      end

      # Returns the next clockwise neighbor to this point from point +p+.
      #
      # Called PRED(v_i, v_ij) in Lee and Schachter, where v_i is Ruby +self+,
      # and v_ij is +p+.  This uses a Hash, while the 1980 paper mentions a
      # circular doubly-linked list.
      def clockwise(p)
        base_idx = @neighbors.index(p) # FIXME: this is using <=> but we want __id__

        idx = base_idx
        n = nil
        loop do
          # Skip newly added neighbors during a hull merge; not sure if this is
          # a proper fix for the point-walk ending up on the wrong hull, or if
          # it causes new problems
          idx = (idx - 1) % @neighbors.length
          n = @neighbors[idx]

          break if n.hull == hull || idx == base_idx
        end

        n
      end

      # Returns the next counterclockwise neighbor to this point from point
      # +p+.
      #
      # Called SUCC in Lee and Schachter.
      def counterclockwise(p)
        base_idx = @neighbors.index(p) # FIXME: this is using <=> but we want __id__

        idx = base_idx
        n = nil
        loop do
          # Skip newly added neighbors during a hull merge; not sure if this is
          # a proper fix for the point-walk ending up on the wrong hull, or if
          # it causes new problems
          idx = (idx + 1) % @neighbors.length
          n = @neighbors[idx]

          break if n.hull == hull || idx == base_idx
        end

        n
      end

      # Adds point +p+ to the correct location in this point's adjacency lists.
      def add(p, set_first = false)
        angle = self.angle(p)
        prior_idx = @neighbors.bsearch_index { |n| self.angle(n) >= angle }
        raise "Point #{p.inspect} is already a neighbor of #{self.inspect}" if prior_idx && (@neighbors[prior_idx] == p || @neighbors[prior_idx - 1] == p || @neighbors[prior_idx + 1] == p)
        @neighbors.insert(prior_idx || @neighbors.length, p)

        @first = p if @first.nil? || set_first
      end

      # Removes point +p+ from this point's adjacency lists.
      def remove(p)
        @neighbors.delete(p)

        @first = @neighbors.first if @first.equal?(p)
      end
    end

    attr_reader :points

    # Initializes a triangulation of the given Array of +points+ of the
    # following form: [ [x1, y1], [x2, y2], ... ].
    #
    # Use #points to retrieve an Array of MB::Delaunay::Point objects and the
    # MB::Delaunay::Point#neighbors method to access the neighbor graph after
    # construction.
    def initialize(points)
      @points = points.map.with_index { |(x, y, name), idx|
        Point.new(x, y, idx).tap { |p| p.name = name if name }
      }
      @sorted_points = @points.sort # Point implements <=> to sort by X and break ties by Y
      triangulate(@sorted_points)
    end

    # TODO: methods for adding and removing individual points, using a fast
    # algorithm for single-point insertion

    # TODO: methods for retrieving a set of triangles, not just points/edges

    def to_a
      @sorted_points.map { |p|
        if p.hull.nil?
          c = nil
        else
          id = (p.hull.hash ^ p.hull.hull_id) % 64 # XXX p.hull.hull_id % 64

          r = (id % 4) / 6.0 + 0.25
          g = ((id / 4) % 4) / 6.0 + 0.25
          b = (id / 16) / 6.0 + 0.25
          a = 0.8

          c = [r, g, b, a]
        end

        {
          x: p.x, y: p.y,
          color: c,
          name: p.name,
          neighbors: p.neighbors.map { |n| { x: n.x, y: n.y, color: n == p.first ? [0.9, 0.1, 0.1, 0.9] : nil } }
        }
      }
    end

    def to_h
      { points: self.to_a }
    end

    def triangles
      traversed = Set.new
      triangles = Set.new

      @sorted_points.each do |p|
        p.neighbors.each do |n|
          key = n > p ? [p, n] : [n, p]
          next if traversed.include?(key)
          traversed << key

          ncw = n.clockwise(p)
          pccw = p.counterclockwise(n)
          if ncw == pccw
            # TODO: There are still a lot of cases where a triangle is already
            # in the set; try to find a way to skip more of that duplicated
            # work
            triangles << [n, p, ncw].sort
          end
        end
      end

      triangles.to_a
    end

    private

    # Creates an edge between two points.
    #
    # Analogous to INSERT(A, B) from Lee and Schachter.
    def join(p1, p2, set_first)
      p1.add(p2, set_first)
      p2.add(p1)
    end

    # Analogous to DELETE(A, B) from Lee and Schachter.
    def unjoin(p1, p2, whence = nil)
      p1.remove(p2)
      p2.remove(p1)
    end

    # Pass a sorted list of points.
    def triangulate(points)
      case points.length
      when 0
        raise "No points were given to triangulate"

      when 1
        Hull.new(points)

      when 2
        points[0].add(points[1])
        points[1].add(points[0])
        Hull.new(points)

      when 3
        h = Hull.new(points)

        # Because points are known to be sorted, p1 is leftmost and p3 is rightmost
        p1, p2, p3 = points

        # Connect points to each other in counterclockwise order
        cross = p2.cross(p1, p3)
        if cross < 0
          # p2 is right of p1->p3; put p2 on the bottom
          p1.add(p2)
          p2.add(p3)
          p3.add(p1)

          p3.add(p2)
          p2.add(p1)
          p1.add(p3)
        elsif cross > 0
          # p2 is left of p1->p3; put p2 on the top
          p1.add(p3)
          p3.add(p2)
          p2.add(p1)

          p1.add(p2)
          p2.add(p3)
          p3.add(p1)
        else
          # p2 is on a line between p1 and p3; link left-to-right
          p1.add(p2)
          p2.add(p3)

          p3.add(p2)
          p2.add(p1)
        end

        h

      else
        # 4 or more points; divide and conquer
        n = points.length / 2
        left = points[0...n]
        right = points[n..-1]

        merge(triangulate(left), triangulate(right))
      end
    end

    # Merges two convex hulls that contain locally complete Delaunay
    # triangulations.
    #
    # Called MERGE in Lee and Schachter.
    def merge(left, right)
      (l_l, l_r), (u_l, u_r) = left.tangents(right)

      l = l_l
      r = l_r
      l1 = nil
      r1 = nil
      l2 = nil
      r2 = nil

      until l == u_l && r == u_r
        # TODO: Name these better than just A and B (the original paper's names)
        a = false
        b = false

        join(l, r, l == l_l && r == l_r)

        r1 = r.clockwise(l)
        if r1.left_of?(l, r)
          r2 = r.clockwise(r1)

          until outside?(r1, l, r, r2)
            unjoin(r, r1, 'from the right')
            r1 = r2
            r2 = r.clockwise(r1)
          end
        else
          a = true
        end

        l1 = l.counterclockwise(r)
        if l1.right_of?(r, l)
          l2 = l.counterclockwise(l1)

          until outside?(l, r, l1, l2)
            unjoin(l, l1, 'from the left')
            l1 = l2
            l2 = l.counterclockwise(l1)
          end
        else
          b = true
        end

        if a
          l = l1
        elsif b
          r = r1
        elsif outside?(l, r, r1, l1)
          r = r1
        else
          l = l1
        end
      end

      # Add the top tangent; this seems to be omitted from Lee and Schachter,
      # either that or the "UNTIL" loop behaves differently in their pseudocode
      # and runs one final iteration.
      join(u_r, u_l, true)

      left.add_hull(right)
    end

    # Returns true if the query point +q+ is not inside the circumcircle
    # defined by +p1+, +p2+, and +p3+.
    #
    # Analogous to QTEST(H, I, J, K) in Lee and Schachter.
    def outside?(p1, p2, p3, q)
      return true if q.equal?(p1) || q.equal?(p2) || q.equal?(p3)

      x, y, rsquared = Delaunay.circumcircle(p1.x, p1.y, p2.x, p2.y, p3.x, p3.y)

      dx = q.x - x
      dy = q.y - y
      dsquared = dx * dx + dy * dy

      dsquared.round(9) >= rsquared.round(9)
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
    # points as [x, y, rsquared].  Returns nil if the points are collinear.
    def self.circumcircle(x1, y1, x2, y2, x3, y3)
      x, y = circumcenter(x1, y1, x2, y2, x3, y3)
      return nil unless x

      dx = x - x1
      dy = y - y1
      rsquared = dx * dx + dy * dy
      [x, y, rsquared]
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
      a, b, c = line1
      d, e, f = line2

      denom = (b * d - a * e).to_f

      # Detect coincident and parallel lines
      return nil if denom == 0

      x = (b * f - c * e) / denom
      y = (c * d - a * f) / denom

      [x, y]
    end
  end
end
