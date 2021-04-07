require 'matrix'

module MB
  # Pure Ruby Delaunay triangulation.
  class Delaunay
    class Hull
      # Analogous to LM(s) and RM(s) in Lee and Schachter.
      attr_reader :leftmost, :rightmost

      # +points+ *must* already be sorted by [x,y].
      def initialize(points)
        @points = points.dup
        @leftmost = points.first
        @rightmost = points.last
      end

      def add_point(p)
        @leftmost = p if @leftmost.nil? || p < @leftmost
        @rightmost = p if @rightmost.nil? || p > @rightmost
        raise NotImplementedError
      end

      def add_hull(h)
        @leftmost = h.leftmost if @leftmost.nil? || h.leftmost < @leftmost
        @rightmost = h.rightmost if @rightmost.nil? || h.rightmost > @rightmost
        points.concat(h.points)
        points.sort! # TODO: If +h+ is always right of self, then this sort is unnecessary
      end

      # Returns the upper and lower tangents linking this left-side hull to the
      # +right+ convex hull.
      #
      # Called HULL in Lee and Schachter (extended to return both tangents).
      def tangents(right)
        x = self.rightmost
        y = right.leftmost

        raise "Rightmost point on left-side hull #{self} is to the right of leftmost point on right-side hull #{right}" if x > y
        left = self

        lower, upper = nil

        # Walk clockwise around left, counterclockwise around right, until the
        # next point on both sides is left of X->Y, showing that X->Y is the
        # lowest segment.
        z = y.first
        z1 = x.first
        z2 = x.clockwise(z1)
        loop do
          if z.right_of?(x, y)
            old_z = z
            z = z.counterclockwise(y)
            y = old_z
          elsif z2.right_of?(x, y)
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
        z_r = y.clockwise(y.first)
        z_l = x.first
        loop do
          if z_r.left_of?(x, y)
            old_z = z_r
            z_r = z_r.clockwise(y)
            y = old_z
          elsif z_l.left_of?(x, y)
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
      include Comparable

      attr_reader :x, :y

      def initialize(x, y)
        @x = x
        @y = y

        @cw = {}
        @ccw = {}
        @neighbors = []
        @first = nil
      end

      # Compares points by X, using Y to break ties.
      #
      # Lee and Schachter refer to this as lexicographic ordering.
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

      def to_s
        "[#{@x}, #{@y}]{#{@cw.length}}"
      end

      def inspect
        "#<MB::Delaunay::Point:#{__id__} #{to_s}"
      end

      # Returns an angle from self to +p+ from 0 to 2PI starting at the
      # positive X axis.
      def angle(p)
        a = Math.atan2(p.y - self.y, p.x - self.x)
        a += 2.0 * Math::PI if a < 0
        a
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

      # XXX
      def neighbors_clockwise
        return @cw.keys if @cw.length == 1

        start = @cw.keys.first
        ptr = @cw[start]
        arr = [start]

        while ptr != start
          arr << ptr
          ptr = @cw[ptr]
        end

        arr
      end

      # Returns the next clockwise neighbor to this point from point +p+.
      #
      # Called PRED(v_i, v_ij) in Lee and Schachter, where v_i is Ruby +self+,
      # and v_ij is +p+.  This uses a Hash, while the 1980 paper mentions a
      # circular doubly-linked list.
      def clockwise(p)
        # XXX @cw[p] || (raise "Point #{p} is not a neighbor of #{self}")
        @neighbors[@neighbors.index(p) - 1] # XXX FIXME hack to get this working
      end

      # Returns the next counterclockwise neighbor to this point from point
      # +p+.
      #
      # Called SUCC in Lee and Schachter.
      def counterclockwise(p)
        # XXX @ccw[p] || (raise "Point #{p} is not a neighbor of #{self}")
        @neighbors[(@neighbors.index(p) + 1) % @neighbors.length] # XXX FIXME: hack to provide invariants
      end

      def first
        # TODO: FIXME: This is wrong
        # XXX @ccw.keys.first
        # XXX @neighbors.first
        @first
      end

      # Adds point +p+ to the correct location in this point's adjacency lists.
      def add(p)
        raise "Cannot add identical point #{p} as a neighbor of #{self}" if p == self
        raise "Point #{p} is already a neighbor of #{self}" if @cw.include?(p) && @ccw.include?(p)
        raise "BUG: @cw and @ccw have differing lengths" if @cw.length != @ccw.length

        # XXX hack to get the invariants working slowly; remove this later
        @first ||= p
        @neighbors << p
        @neighbors.sort_by! { |p| self.angle(p) } # FIXME: this doesn't catch a neighbor in the same direction as another

        if @cw.empty?
          puts "No existing neighbors on #{self}; #{p} is its own adjacent neighbor" # XXX
          @cw[p] = p
          @ccw[p] = p
        else
          puts "\e[1m#{@cw.length} existing neighbors on #{self}; looking for the right place for #{p}\e[0m" # XXX

          # TODO: @first, and also this is O(edges per node)
          start = first
          ptr = first
          ptr_next = nil
          direction = nil

          # TODO: This loop can probably be simplified; all the complication is
          # in part to avoid just using an Array and sorting by atan2.
          #
          # FIXME: this does the wrong thing if the new point is on the
          # opposite side of self from existing neighbors; maybe need to use
          # atan2
          loop do
            puts "Checking #{self}->#{ptr} while direction is #{direction.equal?(@cw) ? 'clockwise' : (direction.equal?(@ccw) ? 'counterclockwise' : 'unknown')}" # XXX
            cross = p.cross(self, ptr)
            if cross < 0
              direction ||= @cw
              puts "New point #{p} is right of #{self}->#{ptr}, moving clockwise" # XXX

              # p is to the right of self->ptr, so iterate clockwise to find surrounding neighbors
              ptr_next = @cw[ptr]

              if ptr == ptr_next || ptr_next == start || p.cross(self, ptr_next) > 0
                puts "It looks like #{p} goes between #{ptr} and #{ptr_next} on #{self}" # XXX
                @cw[p] = ptr_next
                @cw[ptr] = p
                @ccw[ptr_next] = p
                @ccw[p] = ptr
                break
              else
                ptr = ptr_next
                ptr_next = nil
              end
            elsif cross > 0
              direction ||= @ccw
              puts "New point #{p} is left of #{self}->#{ptr}, moving counterclockwise" # XXX

              ptr_next = @ccw[ptr]

              if ptr == ptr_next || ptr_next == start || p.cross(self, ptr_next) < 0
                puts "It looks like #{p} goes between #{ptr_next} and #{ptr} on #{self}" # XXX
                @ccw[p] = ptr_next
                @ccw[ptr] = p
                @cw[ptr_next] = p
                @cw[p] = ptr
                break
              else
                ptr = ptr_next
                ptr_next = nil
              end
            elsif Math.atan2(ptr.y - @y, ptr.x - @x).round(3) == Math.atan2(p.y - @y, p.x - @x).round(3)
              # This would create a zero-area triangle between self->ptr->p
              raise "New point #{p} is in the same direction from #{self} as existing neighbor #{ptr}"
            else
              puts "New point is collinear but on opposite side of existing neighbor #{ptr}; continuing in #{direction.equal?(@cw) ? 'clockwise' : (direction.equal?(@ccw) ? 'counterclockwise' : 'unknown')} direction"
              direction ||= @ccw

              ptr_next = direction[ptr]
              next_cross = p.cross(self, ptr_next)
              other_direction = direction.equal?(@cw) ? @ccw : @cw

              if ptr == ptr_next || ptr_next == start || (direction == @cw && next_cross > 0) || (direction == @ccw && next_cross < 0)
                puts "It looks like #{p} goes between #{ptr} and #{ptr_next} on #{self}" # XXX
                direction[p] = ptr_next
                direction[ptr] = p
                other_direction[ptr_next] = p
                other_direction[p] = ptr
                break
              else
                ptr = ptr_next
                ptr_next = nil
              end
            end
          end
        end

        if @cw.length != @ccw.length
          puts "\e[1;31m@cw has length #{@cw.length} @ccw has length #{@ccw.length}\e[0m"
          require 'pry'
          puts Pry::ColorPrinter.pp({cw: @cw, ccw: @ccw}, '', 80)
        end
      end

      # Removes point +p+ from this point's adjacency lists.
      def remove(p)
        raise "BUG: Point #{p} is in only one of @cw and @ccw" if @cw.include?(p) != @ccw.include?(p)
        raise "Point #{p} is not a neighbor of #{self}" unless @cw.include?(p) && @ccw.include?(p)

        @neighbors.delete(p)

        next_cw = @cw[p]
        next_ccw = @ccw[p]

        # If +p+ is the last adjacent point, then the #delete calls below will
        # still remove it so that case doesn't need special handling.

        # Remove from cw and re-link cw
        @cw[next_ccw] = next_cw
        @cw.delete(p)

        # Remove from ccw and re-link ccw
        @ccw[next_cw] = next_ccw
        @ccw.delete(p)
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
      p1.add(p2)
      p2.add(p1)
    end

    # Analogous to DELETE(A, B) from Lee and Schachter.
    def unjoin(p1, p2)
      p1.remove(p2)
      p2.remove(p1)
    end

    # Pass a sorted list of points.
    def triangulate(points)
      if points.length == 0
        raise "No points were given to triangulate"
      elsif points.length == 1
        Hull.new(points)
      elsif points.length == 2
        Hull.new(points).tap { |h|
          h.leftmost.add(h.rightmost)
          h.rightmost.add(h.leftmost)
        }
      elsif points.length == 3
        puts "Triangulating at bottom level with #{points} points" # XXX

        h = Hull.new(points)

        p1 = h.leftmost
        p2 = h.rightmost
        raise NotImplementedError, 'TODO: Trivial triangulation; return as a Hull'
      else
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

      raise NotImplementedError
    end

    # Returns true if the query point +q+ is not inside the circumcircle
    # defined by +p1+, +p2+, and +p3+.
    #
    # Analogous to QTEST(H, I, J, K) in Lee and Schachter.
    def outside?(p1, p2, p3, q)
      # TODO: memoize circumcircle and relative-angle computations?
      x, y, r = Delaunay.circumcircle(p1.x, p1.y, p2.x, p2.y, p3.x, p3.y)
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
