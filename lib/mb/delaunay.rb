module MB
  # Pure Ruby Delaunay triangulation.
  class Delaunay
    class Hull
      def initialize(points)
        @points = points

        # 
        @leftmost = points.min_by(&:idx)
        @rightmost = points.max_by(&:idx)
      end

      def add_point(p)
        @leftmost = p if @leftmost.nil? || p.idx < @leftmost.idx
        @rightmost = p if @rightmost.nil? || p.idx > @rightmost.idx

        raise NotImplementedError
      end
    end

    class Point
      attr_reader :x, :y, :idx

      def initialize(x, y, idx)
        @x = x
        @y = y
        @idx = idx

        @cw = {}
        @ccw = {}
      end

      # Returns the next clockwise neighbor to this point from point +p+.
      # Called PRED(v_i, v_ij) in Lee and Schachter, where v_i is Ruby +self+,
      # and v_ij is +p+.
      def previous(p)
        @cw[p] || raise "Point #{p} is not a neighbor of #{self}"
      end

      # Returns the next counterclockwise neighbor to this point from point
      # +p+.  Called SUCC in Lee and Schachter.
      def next(p)
        @ccw[p] || raise "Point #{p} is not a neighbor of #{self}"
      end

      def add(p, after)
        raise NotImplementedError
      end

      def remove(p)
        raise NotImplementedError
      end
    end

    def initialize(points)
      @points = points.sort.map { |p| Point.new(p[0], p[1]) }
    end
  end
end
