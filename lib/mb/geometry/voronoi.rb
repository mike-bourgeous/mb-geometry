require 'ruby_vor'

require_relative 'voronoi/svg'

module MB::Geometry
  # Represents a bounded Voronoi partition of a 2D plane.  A Voronoi partition
  # splits the plane into cells that are closest to each input point.  That is,
  # every point within a cell is closer to that cell's input point than to any
  # other input point.  This class is "bounded" because cells are constrained
  # to a rectangular area, rather than allowing for infinite cells.
  #
  # Points may be added, removed, and modified.  None of these operations are
  # thread safe.
  #
  # This code is optimized for clarity over performance, but still runs with
  # acceptable speed.  400 points can be partitioned and saved to an SVG in
  # less than one second.  2000 points can be partitioned and saved in less
  # than 14 seconds.
  class Voronoi
    include MB::Geometry::Voronoi::SVG

    # Represents a triangle from the Delaunay triangulation of input points.
    # The corners of a Delaunay triangle (see #points) are input points to the
    # Voronoi partition, or reflected copies of input points created to prevent
    # infinite cells.  The circumcenter of the Delaunay triangle is a vertex of
    # one or more Voronoi cells.
    #
    # Some triangles may include points that were generated from the original
    # Voronoi diagram as reflections across the diagram boundaries, and were
    # not present in the original set of input points.
    class DelaunayTriangle
      attr_reader :indices, :points

      # Initializes a triangle for the given Voronoi diagram, linking the given
      # points (an array of raw point indices).
      def initialize(voronoi, indices)
        @voronoi = voronoi
        @indices = indices
        @points = indices.map { |idx| @voronoi.raw_points[idx][0..1] }
        @vertex = nil
      end

      # Returns true if this triangle includes the given raw point index
      # (which, for input cells, is the same as the cell index).
      def include?(index)
        @indices.include?(index)
      end

      # Returns the calculated circumcenter as [x, y] of this triangle.
      # This will be at the same place as a vertex in the Voronoi
      # diagram.
      def circumcenter
        @circumcenter ||= MB::Geometry.circumcenter(
          @points[0][0], @points[0][1],
          @points[1][0], @points[1][1],
          @points[2][0], @points[2][1]
        )
      end

      # Returns the circumcircle (circumcenter plus radius) as [x, y,
      # rsquared] of this triangle.
      def circumcircle
        @circumcircle ||= MB::Geometry.circumcircle(
          @points[0][0], @points[0][1],
          @points[1][0], @points[1][1],
          @points[2][0], @points[2][1]
        )
      end

      # Returns the Voronoi cells (as MB::Geometry::Voronoi::Cell objects) at the
      # corners of this triangle.  If some of the corners of the triangle are
      # outside the boundaries of the Voronoi diagram, and thus are actually
      # reflected copies of original input points, then the points of this
      # triangle and the points of the cells will not match.
      def cells
        @cells ||= @indices.map { |idx|
          @voronoi.cells[idx % @voronoi.cells.length]
        }.compact
      end

      # Called internally only.  Removes references to the original Voronoi
      # object when this vertex is removed (e.g. the Voronoi partition is
      # recalculated) to prevent accidental reuse.
      def dispose
        @voronoi = nil
        @indicies = nil
        @points = nil
        @cells = nil
        @circumcenter = nil
        @vertex = nil
        @area = nil
      end

      def vertex
        return @vertex if @vertex
        @voronoi.vertices # trigger vertex generation
        @vertex
      end

      # Returns the area of the triangle.
      def area
        @area ||= MB::Geometry.polygon_area(@points)
      end

      # Called internally only.  Sets the coalesced vertex associated with this
      # triangle (multiple triangles may produce the same vertex).
      def set_vertex(v)
        @vertex = v
      end

      # Returns a simple description of the triangle.
      def to_s
        "DT#{@indices.inspect}"
      end

      # Returns a more detailed string describing the triangle.
      def inspect
        "#<Geometry::Voronoi::DelaunayTriangle @points=#{@points} @vertex=#{@vertex} @voronoi=#{@voronoi.object_id}>"
      end

      # Returns the points that form the corners of this triangle.
      def to_a
        @points.sort
      end
    end

    # Represents a vertex in the Voronoi diagram, where two or more Voronoi
    # segments intersect or terminate.  A vertex object becomes invalid when
    # any modification is made to the Voronoi object that hosts it, and thus
    # references to vertices should not be held across modifications.
    class Vertex
      attr_reader :point

      # Initializes a vertex with the given containing Voronoi partition,
      # vertex coordinates, and vertex index in the raw Delaunay triangle list.
      def initialize(voronoi, point, index)
        @voronoi = voronoi
        @point = point
        @index = index
      end

      # Returns the X coordinate of the vertex.
      def x
        @point[0]
      end

      # Returns the Y coordinate of the vertex.
      def y
        @point[1]
      end

      # Returns the cells that share this vertex.
      def cells
        # TODO: Assign cells to vertices instead of the other way around?  Or
        # come up with something faster than this O(n^2).  This is used by Voronoi#anneal.
        @cells ||= @voronoi.cells.select { |c|
          c.voronoi_vertices.include?(self)
        }
      end

      # Returns the average color of the cells that share this vertex.
      # TODO: Add a method to return the natural neighbor color at this vertex?
      def color(alpha: 1.0)
        @color ||= cells.map { |c| c.color(alpha: alpha) }.reduce { |c1, c2|
          c1 = [*c1, alpha || c2[3]] if (alpha || c2.length == 4) && c1.length == 3
          c2 = [*c2, alpha || c1[3]] if (alpha || c1.length == 4) && c2.length == 3
          c1.map.with_index { |c, idx|
            c + c2[idx]
          }
        }.tap { |c|
          c.map! { |v| v / cells.length }
        }
      end

      # Returns a short string representation of the vertex.
      def to_s
        "V[#{@index}]=#{@point.inspect}"
      end

      # Returns a more detailed string describing the vertex.
      def inspect
        "#<Geometry::Voronoi::Vertex @point=#{@point.inspect} @index=#{@index} @voronoi=#{@voronoi.object_id}>"
      end

      # Called internally only.  Removes references to the original Voronoi
      # object when this vertex is removed (e.g. the Voronoi partition is
      # recalculated) to prevent accidental reuse.
      def dispose
        @voronoi = nil
        @point = nil
        @index = nil
        @cells = nil
        @color = nil
      end
    end

    # Represents an input point with its surrounding Voronoi cell.  Cell
    # objects persist across modifications to the underlying Voronoi object
    # that do not remove the cell itself, so references to cells may be held
    # across modifications.
    class Cell
      # The coordinates of this cell's input point.
      attr_reader :point

      # The index of this cell within the Voronoi partition's list of cells.
      # Returns nil if the cell has been removed.
      attr_reader :index

      # The Voronoi graph that owns this cell.
      attr_reader :voronoi

      # An optional name that may have been given to this cell.
      attr_accessor :name

      # Initializes a cell with the given containing partition, input point,
      # and cell index.
      def initialize(voronoi:, point:, index:, name:, color:)
        @voronoi = voronoi
        @point = point
        @index = index
        @name = name
        @color = color
        reset
      end

      # Returns the X coordinate of the cell's input point.
      def x
        @point[0]
      end

      # Returns the Y coordinate of the cell's input point.
      def y
        @point[1]
      end

      # If a fixed color was set using #color=, returns that color.  If #color=
      # was given a Proc, returns the result of invoking that Proc with this
      # Cell as its parameter.  Otherwise, returns a generated color [r, g, b,
      # a] based on this cell's index.
      #
      # All parameters are ignored if #color= was used to set a fixed color or a
      # color Proc.
      #
      # The +:alpha+ parameter controls opacity when generating a color.  Alpha
      # may be set to nil to generate a 3-element RGB instead of 4-element RGBA
      # color.  The +:alpha+ parameter does not affect a pre-set Proc or Array.
      def color(alpha: 1.0)
        case @color
        when Array
          @color

        when Proc
          @color.call(self)

        else
          # TODO: Find a way to cache the color despite alpha parameter?  OR
          # get rid of alpha parameter and move alpha into callers?
          ::MB::Geometry::Voronoi::SVG.generate_rgb(@index, @voronoi.cells.length, alpha: alpha)
        end
      end

      # Overrides the default color for this cell with a 3- or 4-element numeric
      # RGB(a) array from 0.0..1.0, a Proc that returns such an Array when given
      # a Cell object, or nil to restore the default color.
      def color=(c)
        unless c.nil? || (c.is_a?(Array) && c.all? { |el| el.is_a?(Numeric) }) || c.respond_to?(:call)
          raise "Color must be nil, a 3- or 4-numeric Array, or a Proc"
        end

        @color = c
      end

      # Returns true if a color has been set, overriding any automatically
      # generated color.
      def has_color?
        !!@color
      end

      # Moves this cell's input point to the given location.  If a point
      # already exists at that location, then a random offset will be added to
      # prevent duplicate input points.  Returns the final cell location.
      def move(x, y)
        oldpoint = @point
        newpoint = [x, y]
        reset
        @point = @voronoi.cell_moved(self, oldpoint, newpoint)
        @voronoi.reset
        @point
      end

      # Returns the area (always positive) of the enclosing polygon.
      def area
        @area ||= MB::Geometry.polygon_area(voronoi_vertices.map(&:point)).abs
      end

      # Returns the average of the enclosing polygon's vertices.  Returns nil
      # if there are no vertices somehow.
      def centroid
        MB::Geometry.centroid(voronoi_vertices.map(&:point))
      end

      # Returns Vertex objects representing the Voronoi vertices adjacent to
      # this cell, in counterclockwise order.  These vertices will not contain
      # the entire cell if any of the cell's edges are infinite (but by
      # default, the Voronoi diagram will be reflected to prevent infinite
      # segments).
      def voronoi_vertices
        @voronoi_vertices ||= (
          delaunay_triangles.map(&:vertex).uniq.sort_by { |v|
            -Math.atan2(v.point[1] - @point[1], v.point[0] - @point[0])
          }
        )
      end

      # Returns an Array of points (each a 2D numeric Array) representing the
      # enclosing Voronoi polygon of this Cell, scaled by +xscale+ and +yscale+
      # around the Cell's input point.  The points are returned in
      # counterclockwise order.
      #
      # This method can be used to shrink the Voronoi polygons of a Voronoi
      # diagram around the input points, creating gaps between them.
      #
      # If one of the scale parameters is nil, it will be copied from the
      # other.
      #
      # If +:grow+ is a number, then it will be added to the length of each
      # vector from the chosen center.  This allows shrinking or growing a cell
      # by an absolute number of units rather than by a scaling facter.
      #
      # If +:centroid+ is true, then the scaling will be centered around the
      # polygon's center point, instead of the Cell's input point.
      #
      # See MB::Geometry.scale_matrix.
      def scaled_polygon(xscale = 1, yscale = nil, grow: nil, centroid: false)
        @vertex_points ||= voronoi_vertices.map(&:point)

        xscale ||= yscale
        yscale ||= xscale

        return @vertex_points if xscale == 1 && yscale == 1 && grow.nil?

        xc, yc = *(centroid ? self.centroid : @point)
        vc = Vector[xc, yc]

        # TODO: Other growth/scaling experiments that might be interesting:
        # - Calculating a multiplicative scale factor that will shrink a bounding box by +grow+ in each dimension
        # - Finding edges and shrinking by +grow+ perpendicular to the edge, rather than acting on vertices

        m = MB::Geometry.scale_matrix(xscale: xscale, yscale: yscale, xcenter: xc, ycenter: yc)
        @vertex_points.map { |p|
          v = m * Vector[*p, 1]
          if grow
            v2 = Vector[v[0] - xc, v[1] - yc]
            length = v2.magnitude + grow
            if length <= 0
              v = vc
            else
              v = v2.normalize * length + vc
            end
          end
          v[0..1]
        }
      end

      # Returns the neighboring Cells of this cell in the Delaunay
      # triangulation.
      def neighbors
        @neighbors ||= (
          if @voronoi.engine == :rubyvor
            @voronoi.rubyvor.nn_graph[index].map { |i| @voronoi.cells[i] }.compact
        elsif @voronoi.engine == :delaunay || @voronoi.engine == :delaunay_debug
            @voronoi.delaunay.points[index].neighbors.map { |p| @voronoi.cells[p.idx] }.compact
          else
            raise "Invalid Voronoi engine #{@voronoi.engine}"
          end
        )
      end

      # Returns the DelaunayTriangle objects that have this Cell as one of
      # their corners.
      def delaunay_triangles
        # FIXME: This is O(n^2) if triangles are proportional to cells
        @delaunay_triangles ||= @voronoi.delaunay_triangles.select { |t|
          t.include?(@index)
        }
      end

      # Removes this cell from the Voronoi diagram.  This object should not be
      # used after the cell is removed.
      def remove
        @voronoi.remove_cell(self)
      end

      # Used internally only.  Moves this cell without notifying the Voronoi diagram.
      def set_point_internal(x, y)
        @point = [x, y]
        reset
      end

      # Used internally only.  Sets the index of this cell.  Called when cells
      # are removed.
      def set_index(idx)
        @index = idx
        @voronoi = nil if idx.nil?
      end

      # Used internally only.  Clears any memoized calculations.  Called when
      # the inputs to the Voronoi partition are modified.
      def reset
        @area = nil
        @neighbors = nil
        @delaunay_triangles = nil
        @voronoi_vertices = nil
        @vertex_points = nil
      end

      # A short description of the cell.
      def to_s
        "Cell[#{@index}/#{@name}]=#{@point.inspect}"
      end

      # A detailed description of the cell.
      def inspect
        "#<Geometry::Voronoi::Cell @index=#{@index} @name=#{@name} @point=#{@point} @voronoi=#{@voronoi.object_id} #{neighbors.size} neighbors>"
      end

      def to_h
        {
          x: x,
          y: y,
          name: name,
          color: color,
          centroid: self.centroid,
        }
      end
    end

    # The default engine for generating Delaunay triangulation, either
    # :delaunay to use a pure Ruby implementation, or :rubyvor to use the
    # RubyVor gem.  The DELAUNAY_ENGINE environment variable may set to
    # 'rubyvor' or 'delaunay' to override this default.
    DEFAULT_ENGINE = ENV['DELAUNAY_ENGINE']&.sub(/^:/, '')&.to_sym || :rubyvor

    # Returns the width of the #area_bounding_box.
    attr_reader :width

    # Returns the height of the #area_bounding_box.
    attr_reader :height

    # Returns the width and height of the user-defined bounding box
    # (#user_bounding_box).  Returns the same value as #width or #height if no
    # user bounding box is set.
    attr_reader :user_width, :user_height

    # Returns the horizontal center of the #area_bounding_box.
    attr_reader :x_center

    # Returns the vertical center of the #area_bounding_box.
    attr_reader :y_center

    # An Integer that indicates how many times the graph has been modified.
    # This is used e.g. for invalidating caches of data derived from the graph.
    attr_reader :version

    # The Delaunay triangulation engine for this instance (:delaunay for
    # MB::Geometry::Delaunay or :rubyvor for the RubyVor gem).
    attr_reader :engine

    # Allows assigning a name to the graph (used e.g. in some error messages
    # and in Hash versions of the graph).
    attr_accessor :name

    # Initializes a Voronoi partition for the given list of points, each
    # element of which should be a two-element array with X and Y, or a
    # three-element array with the third element a String to name the point, or
    # a Hash with :x, :y, and optionally :name and :color.  +points+ may also
    # be a Hash with a spec for MB::Geometry::Generators.generate.
    #
    # If there are any duplicate points, subsequently added copies will be
    # randomly shifted to prevent duplication.
    #
    # If +reflect+ is true, then infinite segments are removed by reflecting
    # the diagram across the edges of the area_bounding_box.  This must be true
    # for most of the non-RubyVor-provided features to work.  Set it to false
    # to generate a RubyVor SVG without the reflected copies.
    #
    # The +:sigfigs+ parameter controls vertex coalescing.  Input points are
    # deduplicated by shifting if they are within 5 sigfigs of each other (any
    # closer and RubyVor can't triangulate them correctly).
    #
    # Pass :rubyvor for +:engine+ to use the RubyVor gem for Delaunay
    # triangulation, :delaunay to use a slower pure Ruby implementation written
    # specifically for this library, or :delaunay_debug to use an even slower
    # debugging variant.  The default can be controlled by the DELAUNAY_ENGINE
    # environment variable (see MB::Geometry::Voronoi::DELAUNAY_ENGINE).
    def initialize(points = [], reflect: true, sigfigs: 5, dedupefigs: 5, engine: DEFAULT_ENGINE)
      @cells = []
      @pointset = {}
      @reflect = reflect

      @sigfigs = sigfigs
      @sigscale = 10.0 ** (-@sigfigs)
      @squaredscale = (10 * @sigscale) ** 2

      @dedupefigs = dedupefigs
      @dedupescale = 0.001
      @point_offsets = [
        [@dedupescale, 0],
        [@dedupescale, @dedupescale],
        [0, @dedupescale],
        [-@dedupescale, @dedupescale],
        [-@dedupescale, 0],
        [-@dedupescale, -@dedupescale],
        [0, -@dedupescale],
        [@dedupescale, -@dedupescale],
      ]

      @user_xmin = nil
      @user_xmax = nil
      @user_ymin = nil
      @user_ymax = nil
      @xmin = nil
      @xmax = nil
      @ymin = nil
      @ymax = nil

      @vertices = nil
      @delaunay_triangles = nil

      @version = 0

      @vor = nil
      @delaunay = nil
      @raw_points = []
      @vorpoints = []
      @raw_vertices = nil
      @dispose = true

      @engine = engine
      raise "Invalid engine #{engine.inspect}" if @engine != :rubyvor && @engine != :delaunay && @engine != :delaunay_debug

      replace_points(points)

      reset
    end

    # An array of Cells representing each input point and enclosing polygon.
    # The optional +selector+ may be an Array of Cells, Ranges of indices or
    # names, or Integer cell indices or names; a Range of indices or names; or
    # anything implementing #=== that would match a cell index or name.
    def cells(selector = nil)
      case selector
      when nil, true
        @cells

      when Array
        selector.map { |s|
          case s
          when Cell
            @cells[s.index]

          when Integer
            @cells[s]

          else
            @cells.select { |c| s === c.index || s === c.name }
          end
        }.flatten.compact

      else
        @cells.select { |c| selector === c.index || selector === c.name }
      end
    end

    # Returns a Hash describing this Voronoi partition.  The resulting Hash
    # should be readable by MB::Geometry::Generators.generate to reproduce the
    # graph.  If +:color+ is true, then the color of each cell will be stored,
    # regardless of whether it was generated automatically or set manually.
    def to_h(color: false)
      points = @cells.map { |c|
        # TODO: There's probably a better way to include color selectively
        (color || c.has_color?) ? c.to_h : [c.x, c.y, c.name].compact
      }
      {
        name: @name,
        bounding_box: area_bounding_box,
        points: points,
        triangles: @delaunay_triangles&.map(&:to_a)&.sort,
      }
    end

    # Sets an initial bounding box for cells.  This is the bounding box that
    # will be returned by #user_bounding_box.  The effective bounding box will
    # expand to fit any cell sites outside the existing box, plus a small
    # margin.  This bounding box is used to limit cell area for infinite cells.
    # Returns the final bounding box, which may have expanded to fit all
    # points.
    def set_area_bounding_box(xmin, ymin, xmax, ymax)
      @user_xmin = xmin
      @user_xmax = xmax
      @user_ymin = ymin
      @user_ymax = ymax

      reset

      area_bounding_box
    end

    # Returns the user bounding box given to #set_area_bounding_box as [xmin,
    # ymin, xmax, ymax].  If no such bounding box exists, returns [nil, nil,
    # nil, nil].  See also #area_bounding_box and #computed_bounding_box.
    def user_bounding_box
      [@user_xmin, @user_ymin, @user_xmax, @user_ymax]
    end

    # Returns the user bounding box if it exists, or the computed area bounding
    # box if it does not, regardless of the actual range occupied by points on
    # the graph.
    def user_bounding_box_fallback
      [
        @user_xmin || @xmin,
        @user_ymin || @ymin,
        @user_xmax || @xmax,
        @user_ymax || @ymax
      ]
    end

    # Returns the larger of #user_bounding_box or the bounding box that contains
    # all input points as [xmin, ymin, xmax, ymax] with some margin.  This is
    # used for the reflection process that eliminates infinite cells.
    def area_bounding_box
      [@xmin, @ymin, @xmax, @ymax]
    end

    # Returns the smallest bounding box that contains all of the input points,
    # regardless of a user-set bounding box, as [xmin, ymin, xmax, ymax].  If
    # +expand+ is not zero, then the bounding box dimensions will be multiplied
    # by (1.0 + +expand+).  See MB::Geometry#bounding_box.
    def computed_bounding_box(expand = 0)
      return [0, 0, 0, 0] if @cells.empty?
      MB::Geometry.bounding_box(@cells.map(&:point), expand)
    end

    # Returns the total area of the area_bounding_box.
    def area
      (@xmax - @xmin) * (@ymax - @ymin)
    end

    # Adds a new input point to the Voronoi partition, or multiple points if
    # given a spec for MB::Geometry::Generators.generate.  The bounding box will
    # expand to include the new point if needed.  Returns the Cell representing
    # the newly added point.  If there are any duplicate points, subsequently
    # added copies will be randomly shifted to prevent duplication.  An error
    # will be raised if that still does not result in a unique point.
    #
    # Either pass X, Y, and an optional name; a Hash containing :x, :y, and
    # optionally :name and/or :color; or a spec for MB::Geometry::Generators.generate.
    def add_point(x_or_hash, y_or_nil = nil, name = nil, reset: true)
      case x_or_hash
      when Hash
        if x_or_hash.include?(:generator) || x_or_hash.include?(:points)
          MB::Geometry::Generators.generate(x_or_hash).each { |p| add_point(p, reset: reset) }
          return
        end

        x = x_or_hash[:x]
        y = x_or_hash[:y]
        name = x_or_hash[:name]
        color = x_or_hash[:color]

      else
        x = x_or_hash
        y = y_or_nil
      end

      p = find_safe_point(x.round(9), y.round(9), cells.length)

      Cell.new(voronoi: self, point: p, index: @cells.size, name: name, color: color).tap { |c|
        @cells << c
        @pointset[p] = c

        for reflect in 0..(@reflect ? 4 : 0)
          p, idx, vorp = create_point(c.x, c.y, c.index, reflect)
          @raw_points.insert(idx, p)
          @vorpoints.insert(idx, vorp) if @engine == :rubyvor
        end

        check_lengths("after adding point #{p.inspect}")

        self.reset if reset
      }
    end

    # Removes the given Cell, if present.  An automatically generated bounding
    # box may shrink.
    def remove_cell(cell)
      check_lengths

      prior_length = @cells.length

      @cells.delete(cell)&.tap { |c|
        @pointset.delete(c.point)

        for reflect in ((@reflect ? 4 : 0)..0).step(-1)
          @raw_points.delete_at(prior_length * reflect + c.index)
          @vorpoints.delete_at(prior_length * reflect + c.index)
        end

        check_lengths

        # Renumber cells after this cell
        for idx in c.index...@cells.length
          @cells[idx].set_index(idx)
        end

        c.reset
        c.set_index(nil)

        reset
      }
    end

    # Removes a single point at the given coordinates, if present.  An
    # automatically generated bounding box may shrink.
    def remove_point(x, y)
      @cells.find { |c| c.point == [x, y] }&.yield_self { |c|
        remove_cell(c)
      }
    end

    # Removes the point at the given index, if present.  Does not shrink the
    # bounding box.
    def remove_point_at(idx)
      @cells[idx]&.yield_self { |c|
        remove_cell(c)
      }
    end

    # Removes all Cells and then adds the given Array of point Hashes or Arrays
    # as would be given to #add_point.  +new_points+ may also be a Hash with a
    # generator spec to create points by algorithm.  See
    # MB::Geometry::Generators.generate.
    #
    # Examples:
    #     v.replace_points({ generator: :random, count: 5, seed: 0 })
    #     v.replace_points([{x: 1, y: 1, name: 'P0', color: [1, 1, 1, 1]}])
    def replace_points(new_points)
      new_points = MB::Geometry::Generators.generate(new_points) if new_points.is_a?(Hash)
      raise "New points must be an Array or a generator Hash" unless new_points.is_a?(Array)

      @cells.each do |c|
        c.reset
        c.set_index(nil)
      end
      @cells.clear
      @pointset.clear
      @raw_points.clear
      @vorpoints.clear

      reset(dispose: true)

      new_points.each { |p|
        if p.is_a?(Array)
          add_point(*p, reset: false)
        else
          add_point(p, reset: false)
        end
      }

      check_lengths

      reset
    end

    # Moves all input points to their Voronoi cell's centroid.  This makes the
    # points more evenly spaced.  If +:scale+ is true, or if it's nil and there
    # is no user-supplied bounding box, then Cell points will be rescaled to
    # preserve the original width, height, and center of the graph.
    def anneal(scale: nil)
      @pointset.clear

      scale = @user_xmin.nil? if scale.nil?

      if scale
        old_xmin, old_ymin, old_xmax, old_ymax = self.computed_bounding_box
        old_width = old_xmax - old_xmin
        old_height = old_ymax - old_ymin
        old_xcenter = (old_xmax + old_xmin) / 2.0
        old_ycenter = (old_ymax + old_ymin) / 2.0
      end

      @cells.each do |c, idx|
        centroid = c.centroid || c.point # centroid may return nil if the Voronoi generation failed
        c.set_point_internal(*centroid)
      end

      if scale
        new_xmin, new_ymin, new_xmax, new_ymax = self.computed_bounding_box
        new_width = new_xmax - new_xmin
        new_height = new_ymax - new_ymin
        new_xcenter = (new_xmax + new_xmin) / 2.0
        new_ycenter = (new_ymax + new_ymin) / 2.0

        wmul = old_width / new_width
        wmul = 1.0 unless wmul > 0 && wmul.finite?
        hmul = old_height / new_height
        hmul = 1.0 unless hmul > 0 && hmul.finite?
      end

      @cells.each do |c|
        x, y = c.point

        if scale
          x = (x - new_xcenter) * wmul + old_xcenter
          y = (y - new_ycenter) * hmul + old_ycenter
        end

        new_point = find_safe_point(x, y, c.index)
        c.set_point_internal(*new_point)

        @pointset[new_point] = c
      end

      check_lengths

      reset
    end

    # Calculates the natural neighbor adjacency at the given point by
    # temporarily adding the point to the Voronoi partition and computing how
    # much area was stolen from the original cells by the new point.
    #
    # Returns a Hash with :weights, :point, and :vertices.  The weights,
    # summing to 1.0, are a Hash from cell index to weight for each original
    # cell in the Voronoi partition that neighbors the sampling point.  The
    # point and vertices are those of the temporarily added sample cell.
    #
    # If :color is true, then the Hash also contains a :color key with a
    # blended color from the neighboring cells.  In this case :alpha is passed
    # to MB::Geometry::Voronoi::Cell#color.
    #
    # Note: this might not behave the way you expect for sampling points
    # outside the bounding box of the existing cells in the Voronoi diagram.
    # For example, you might expect a point that lies on the same angle from
    # the center of the diagram as a boundary cell point to be assigned
    # entirely to that point, but the further away the sampling point gets, the
    # more the neighboring cell points on the convex hull may be included,
    # depending on how much the bounding box has to expand and in which
    # dimensions.  Experiment with area_bounding_box sizes if this is a
    # concern.
    #
    # Warning: this modifies the Voronoi diagram and is thus not thread-safe.
    #
    # See https://en.wikipedia.org/wiki/Natural_neighbor_interpolation
    def natural_neighbors(x, y, color: false, alpha: nil)
      prior_version = @version
      prior_triangles = delaunay_triangles
      prior_vertices = vertices
      prior_rubyvor = @vor
      prior_delaunay = @delaunay
      prior_dispose = @dispose

      @dispose = false

      # FIXME: out_of_bounds was false for cases where the bounding box grew,
      # but setting/re-setting the bounding box for every single point is slow.
      out_of_bounds = x <= @xmin || x >= @xmax || y <= @ymin || y >= @ymax
      original_box = self.user_bounding_box

      prior_box = area_bounding_box

      new_cell = add_point(x, y, 'NNsamp')
      new_x = new_cell.x
      new_y = new_cell.y
      new_index = new_cell.index
      new_name = new_cell.name
      new_area = new_cell.area
      new_vertices = new_cell.voronoi_vertices.map(&:point)

      neighbors = new_cell.neighbors.sort_by(&:index)
      new_neighbors = neighbors.map(&:area)
      new_total = new_neighbors.sum + new_area
      new_neighbors_norm = new_neighbors.map { |a| a.to_f / new_total }
      new_area_norm = new_area.to_f / new_total

      # XXX
      cell_present = {
        total: new_total,
        points: cells.map(&:point),
        neighbors: neighbors.map { |n|
          {
            index: n.index,
            name: n.name,
            x: n.x,
            y: n.y,
            area: n.area,
            vertices: n.voronoi_vertices.map(&:point),
          }
        }
      }

      expanded_box = area_bounding_box

      new_cell.remove
      new_cell = nil

      @vor = prior_rubyvor
      @delaunay = prior_delaunay
      @delaunay_triangles = prior_triangles
      @vertices = prior_vertices

      # Back up bounding box and use expanded box if the new point was outside the old bounds
      set_area_bounding_box(*expanded_box) if expanded_box != area_bounding_box

      old_neighbors = neighbors.map(&:area)
      old_total = old_neighbors.sum
      old_neighbors_norm = old_neighbors.map { |a| a / old_total }

      # FIXME: find out why areas are growing (causing negative weights) and
      # why normalized values sometimes exceed 1.0
      weights = old_neighbors_norm.each_with_index.map { |a_old, idx|
        w = (a_old - new_neighbors_norm[idx]) / new_area_norm
        w = 1.0 if w > 1.0 && w < 1.01
        w
      }.each_with_index.map { |w, idx|
        [neighbors[idx].index, w]
      }.reject { |idx, w|
        w <= 0 && w > -0.01
      }.to_h

      # XXX
      cell_absent = {
        total: old_total,
        neighbors: neighbors.map.with_index { |n, idx|
          {
            index: n.index,
            name: n.name,
            weight: weights[n.index],
            x: n.x,
            y: n.y,
            area: n.area,
            color: n.color,
            vertices: n.voronoi_vertices.map(&:point),
          }
        }
      }

      if color
        cell_color = weights.each_with_object([0, 0, 0]) { |(cell_idx, weight), color|
          base = cells[cell_idx].color(alpha: alpha)

          color[0] += (base[0] ** 0.4545) * weight
          color[1] += (base[1] ** 0.4545) * weight
          color[2] += (base[2] ** 0.4545) * weight

          if base[3]
            if color[3]
              color[3] += base[3] * weight
            else
              # FIXME: weight alpha only based on cells that have an alpha?
              color[3] = base[3]
            end
          end
        }

        # Return to gamma color space
        cell_color[0] **= 2.2
        cell_color[1] **= 2.2
        cell_color[2] **= 2.2
      end

      # FIXME: disable vertex coalescing while calculating natural neighbors,
      # and find out what else is causing weights to be incorrect
      wsum = weights.values.sum.round(2)
      raise "Weights at #{x}/#{y} #{weights} / #{wsum} did not sum to 1.0" if wsum < 0.98 || wsum > 1.01
      raise "Weights at #{x}/#{y} #{weights} had a value greater than 1 or less than 0" if weights.any? { |_, w| w.round(3) > 1 || w < 0 }
      raise "Natural neighbor at #{x}/#{y} color #{cell_color} was greater than 1" if color && cell_color[0..2].any? { |v| v.round(3) > 1.0 }

      {
        weights: weights,
        point: [x, y],
        vertices: new_vertices,
        color: cell_color,
      }

    rescue => e
      debug_data = to_h.merge(
        new_cell: {
          index: new_index,
          name: new_name,
          x: new_x,
          y: new_y,
          orig_x: x,
          orig_y: y,
          area: new_area,
          color: cell_color,
          vertices: new_vertices,
        },
        weights: weights,
        cell_present: cell_present,
        cell_absent: cell_absent,
        out_of_bounds: out_of_bounds,
        original_box: original_box,
        prior_box: prior_box,
        expanded_box: expanded_box,
        raw_points: raw_points,
        vorpoints: @vorpoints
      )

      @@neighbor_fail_index ||= 0
      filename = "/tmp/neighbor_#{@@neighbor_fail_index}_#{x.round(5)}_#{y.round(5)}_fail.json"
      @@neighbor_fail_index += 1
      File.write(filename, JSON.pretty_generate(debug_data))

      raise "Error in natural neighbor at #{x}/#{y}: #{e}.  Wrote #{filename} to debug."

    ensure
      remove_cell(new_cell) if new_cell
      set_area_bounding_box(*original_box) if original_box
      @version = prior_version
      @vor = prior_rubyvor
      @delaunay = prior_delaunay
      @delaunay_triangles = prior_triangles
      @vertices = prior_vertices
      @dispose = prior_dispose
    end

    # Returns an array of Vertex objects representing the vertices connecting
    # edges of the Voronoi diagram.  Vertices are recreated whenever the
    # Voronoi diagram is modified, so do not use old vertex objects after a
    # modification.
    def vertices
      return @vertices if @vertices
      generate_vertices
      @vertices
    end

    # Returns a MB::Geometry::Delaunay triangulation of the raw points (including
    # reflections, if enabled) of this diagram.
    def delaunay
      @delaunay ||= (
        if @engine == :delaunay_debug
          MB::Geometry::DelaunayDebug.new(raw_points)
        else
          MB::Geometry::Delaunay.new(raw_points)
        end
      )
    end

    # Returns an array of DelaunayTriangle objects representing all triangles
    # in the Delaunay triangulation of the input points (plus mirrored copies,
    # if reflection is enabled) with at least one triangle point corresponding
    # to an input cell.
    def delaunay_triangles
      @delaunay_triangles ||= (
        if @cells.empty?
          []
        elsif @engine == :rubyvor
          rubyvor.delaunay_triangulation_raw.lazy.select { |indices|
            indices.any? { |idx| idx < @cells.size }
          }.map { |indices|
            indices.sort
          }.uniq.map { |indices|
            DelaunayTriangle.new(self, indices)
          }.reject { |t|
            degenerate = t.area > -0.0000000000001 && t.area < 0.0000000000001
            puts "Warning: ignoring degenerate triangle #{t}" if degenerate
            degenerate
          }.to_a
        elsif @engine == :delaunay || @engine == :delaunay_debug
          delaunay.triangles.lazy.select { |points|
            points.any? { |p| p.idx < @cells.size }
          }.map { |t|
            DelaunayTriangle.new(self, t.map(&:idx))
          }.reject { |t|
            degenerate = t.area > -0.0000000000001 && t.area < 0.0000000000001
            puts "Warning: ignoring degenerate triangle #{t}" if degenerate
            degenerate
          }.to_a
        else
          raise "Invalid engine #{@engine}"
        end
      )
    end

    # Voronoi input points including mirrored points.  Generally for internal
    # use only.
    def raw_points
      @raw_points
    end

    # Returns the RubyVor computation object underlying this Voronoi partition,
    # if the engine is set to :rubyvor.
    def rubyvor
      raise "Engine is not set to :rubyvor" unless @engine == :rubyvor
      @vor ||= RubyVor::VDDT::Computation.from_points(@vorpoints)
    end

    # Resets the memoized Voronoi computation (e.g. when a point is added,
    # changed, or removed).  This normally doesn't need to be called
    # externally.
    def reset(dispose: nil)
      if @vor || @delaunay || @delaunay_triangles || @vertices || @raw_vertices
        check_lengths

        dispose = @dispose if dispose.nil?

        @version += 1
        @vor = nil
        @raw_vertices = nil
        @vertices&.each(&:dispose) if dispose
        @vertices = nil
        @delaunay = nil
        @delaunay_triangles&.each(&:dispose) if dispose
        @delaunay_triangles = nil
        @cells.each_with_index do |c, idx|
          c.reset
        end
      end

      update_bounding_box
    end

    # Called internally by cells to notify the Voronoi diagram that the cell's
    # input point was moved.  If a point already exists at the new coordinates,
    # then a random offset will be added until the point is unique.  Returns
    # the final location of the point including any random offset.
    #
    # The #reset method must be called after the point returned by this method
    # is assigned to the cell.
    def cell_moved(cell, old_point, new_point)
      check_lengths

      @pointset.delete(old_point)

      begin
        new_point = find_safe_point(*new_point, cell.index)
      rescue => e
        @pointset[old_point] = cell
        raise
      end

      @pointset[new_point] = cell

      update_point(*new_point, cell.index, 0)

      check_lengths

      new_point
    end

    private

    def check_lengths(msg = nil)
      raise "BUG: Pointset length #{@pointset.length} doesn't match cells length #{@cells.length} #{msg}".strip if @cells.length != @pointset.length

      expected_reflected_length = @cells.length * (@reflect ? 5 : 1)
      raise "BUG: Raw points length #{@raw_points.length} doesn't match reflected cells length #{expected_reflected_length} #{msg}".strip if @raw_points.length != expected_reflected_length
      raise "BUG: RubyVor points length #{@vorpoints.length} doesn't match reflected cells length #{expected_reflected_length} #{msg}".strip if @vorpoints.length != expected_reflected_length && @engine == :rubyvor
    end

    # Sets the @raw_points and @vorpoints (if using :rubyvor) values at the
    # correct indexes for the given +cell+, e.g. if it has moved or if the
    # bounding box changed.  +min_reflect+ should be 0 (cell moved) or 1
    # (bounding box changed).
    def update_point(x, y, index, min_reflect)
      for reflect in min_reflect..(@reflect ? 4 : 0)
        p, idx, vorp = create_point(x, y, index, reflect)
        @raw_points[idx] = p
        @vorpoints[idx] = vorp if @engine == :rubyvor
      end
    end

    # Returns [[raw_point...], reflected_index, [vorpoint if engine is :rubyvor]]
    #
    # Reflects points around to prevent infinite cells at the edges.
    # Based on a Stackoverflow answer: https://stackoverflow.com/a/33602171/737303
    def create_point(x, y, index, reflect)
      case reflect
      when 0
        # normal; no change

      when 1
        # bottom
        y = 2.0 * @ymin - y

      when 2
        # right
        x = 2.0 * @xmax - x

      when 3
        # top
        y = 2.0 * @ymax - y

      when 4
        # left
        x = 2.0 * @xmin - x

      else
        raise "Invalid value for reflect: #{reflect}"

      end

      p = [x, y, index]
      # Can't subtract xmin/ymin here because xmin/ymin might change, and we
      # don't recalculate every point every time.
      vorp = RubyVor::Point.new(x * 10, y * 10) if @engine == :rubyvor
      [p, @cells.size * reflect + index, vorp]
    end

    # If the given coordinates exist already, shifts them around until they are
    # unique to within @dedupefigs significant figures.  Returns a unique [x,
    # y] that may safely be added to the diagram.
    def find_safe_point(x, y, idx)
      # TODO: Use a different way to find duplicates that allows preserving at
      # least some of the original precision of points, instead of aggressively
      # rounding.
      new_point = [
        MB::M.sigfigs(x.to_f, @dedupefigs).round(@dedupefigs - 2),
        MB::M.sigfigs(y.to_f, @dedupefigs).round(@dedupefigs - 2)
      ]

      if @pointset.include?(new_point)
        catch :deduplicated do
          xoff, yoff = @point_offsets[idx % @point_offsets.length]
          100.times do
            new_point[0] += xoff
            new_point[1] += yoff
            new_point[0] = MB::M.sigfigs(new_point[0], @dedupefigs).round(@dedupefigs + 1)
            new_point[1] = MB::M.sigfigs(new_point[1], @dedupefigs).round(@dedupefigs + 1)

            throw :deduplicated unless @pointset.include?(new_point)
          end

          # Choose a range that is proportionate to the graph, if possible
          @pointrand ||= Random.new(0)
          randscale = @dedupescale
          randrange = MB::M.max_abs(*new_point).abs * randscale
          randrange = randscale * [@xmax - @xmin, @ymax - @ymin].max if randrange == 0
          randrange = randscale if randrange == 0

          # Gradually expand the range if somehow we land on another existing point
          100.times do |t|
            # 1.1 gives a final range of about +/- 1.2 times the original after
            # 100 times if sigfigs is 5
            randrange *= 1.1
            range = -randrange..randrange
            new_point[0] += @pointrand.rand(range)
            new_point[1] += @pointrand.rand(range)
            new_point[0] = MB::M.sigfigs(new_point[0].round(@dedupefigs + 1), @dedupefigs)
            new_point[1] = MB::M.sigfigs(new_point[1].round(@dedupefigs + 1), @dedupefigs)

            throw :deduplicated unless @pointset.include?(new_point)
          end

          # This is incredibly unlikely
          if @pointset.include?(new_point)
            raise "Unable to find a unique point for #{x}, #{y} at index #{idx}"
          end
        end
      end

      new_point
    end

    # Calculates the bounding box of the input points, adding a small margin if
    # there is no user-supplied box or if a point extends outside the
    # user-supplied box.  Stores the larger of the user-provided box and the
    # calculated box.
    def update_bounding_box
      prior_xmin = @xmin
      prior_xmax = @xmax
      prior_ymin = @ymin
      prior_ymax = @ymax

      if @cells.any?
        base = self.computed_bounding_box
        expanded = self.computed_bounding_box(0.05)

        # There's probably still room for improvement in the difficult edge cases
        extra_x = 0.5 * ((expanded[2] - expanded[0]) - (base[2] - base[0]))
        extra_y = 0.5 * ((expanded[3] - expanded[1]) - (base[3] - base[1]))
        extra = [extra_x, extra_y].max
        extra = 1 if extra == 0 # If there was only a single point given

        if @user_xmin && @user_xmin < base[0] && @user_ymin < base[1] && @user_xmax > base[2] && @user_ymax > base[3]
          # Use the non-expanded base box if the user supplied a bounding box
          # and all points fit.  The reflection process that is used to
          # eliminate infinite segments doesn't work if any points are on the
          # edge of the box, because the reflected point will be equal to the
          # original point.
          #
          # This relates to the "A polygon must have 3 or more vertices
          # (RuntimeError)" error message.
          pxmin, pymin, pxmax, pymax = base
        else
          # Use the expanded box if there is no user-supplied box, or if any
          # points would lie on or outside the box.
          pxmin, pymin, pxmax, pymax = expanded
        end

        # Make sure the bounding box is not zero sized in case all input points
        # are collinear.
        if pxmin == pxmax
          pxmin -= extra
          pxmax += extra
        end
        if pymin == pymax
          pymin -= extra
          pymax += extra
        end

        @xmin = [@user_xmin, pxmin].compact.min
        @ymin = [@user_ymin, pymin].compact.min
        @xmax = [@user_xmax, pxmax].compact.max
        @ymax = [@user_ymax, pymax].compact.max
      elsif @user_xmin
        @xmin = @user_xmin
        @ymin = @user_ymin
        @xmax = @user_xmax
        @ymax = @user_ymax
      else
        # The rare case where there are no cells and no bounding box
        @xmin = 0
        @ymin = 0
        @xmax = 1
        @ymax = 1
      end

      if @reflect
        if prior_xmin != @xmin || prior_xmax != @xmax || prior_ymin != @ymin || prior_ymax != @ymax
          # Recalculate reflected points
          @cells.each do |c|
            update_point(c.x, c.y, c.index, 1)
          end
        end
      end

      @user_width = (@user_xmax || @xmax) - (@user_xmin || @xmin)
      @user_height = (@user_ymax || @ymax) - (@user_ymin || @ymin)
      @width = @xmax - @xmin
      @height = @ymax - @ymin
      @x_center = (@xmax + @xmin) / 2.0
      @y_center = (@ymax + @ymin) / 2.0
    end

    # Generates vertices from Delaunay triangulation, then replaces very
    # closely spaced vertices with nearby vertices.  Only called by #vertices.
    # This compensates for floating point error when multiple different
    # Delaunay triangles should have the same circumcenter.
    #
    # Coalescing vertices also helps ensure that cell areas sum to the total
    # area of the bounding box.
    def generate_vertices
      @raw_vertices = delaunay_triangles.map { |tri|
        x, y = tri.circumcenter

        raise "Degenerate triangle: #{tri} / #{tri.to_a}" if x.nil?

        if @reflect
          # If reflection is enabled to eliminate infinite segments, then no
          # vertex should be outside of the area bounding box.  This clamp
          # ensures that vertices remain in bounds in the event a small
          # rounding error pushes an on-edge vertex just over the edge.
          #
          # If reflection is not enabled, then no guarantees about
          # functionality are made.

          x = @xmin if x < @xmin
          x = @xmax if x > @xmax
          y = @ymin if y < @ymin
          y = @ymax if y > @ymax
        end

        [ x, y ]
      }

      replacements = Array.new(@cells.length)

      # TODO: Use a quadtree or similar structure to make this O(nlogn) instead of O(n^2)
      @raw_vertices.each_with_index do |(x1, y1), idx1|
        # Don't replace other vertices with this one if this one is going away
        if replacements[idx1]
          next
        end

        @raw_vertices[(idx1 + 1)..-1].each_with_index do |(x2, y2), idx2|
          idx2 += idx1 + 1

          # Stick with the lowest vertex if it's already in the list
          if replacements[idx2]
            next
          end

          dx = x2 - x1
          dy = y2 - y1
          distsquared = dx * dx + dy * dy
          if distsquared < @squaredscale
            replacements[idx2] = idx1
          end
        end
      end

      vtx_objs = @raw_vertices.each_with_index.map { |v, idx|
        replacements[idx] ? nil : Vertex.new(self, v, idx)
      }

      vtx_objs.each_with_index do |v, idx|
        @delaunay_triangles[idx].set_vertex(
          v || vtx_objs[replacements[idx]] || (raise "No vertex for triangle #{idx}")
        )
      end

      @vertices = vtx_objs.compact

    rescue => e
      @@vertex_fail_index ||= 0
      filename = "/tmp/vertices_#{@@vertex_fail_index}_#{@version}_fail.json"
      @@vertex_fail_index += 1
      debug_info = self.to_h.merge(
        raw_points: raw_points,
        raw_vertices: @raw_vertices,
        replacements: replacements
      )
      File.write(filename, JSON.pretty_generate(debug_info))

      raise "Error in vertex generation: #{e}.  Wrote #{filename} to debug."
    end
  end
end
