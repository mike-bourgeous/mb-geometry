require 'set'
require 'matrix'
require 'forwardable'

require 'mb/math'

module MB::Geometry
  # Animates changes to MB::Geometry::Voronoi in frame-by-frame increments.
  # Methods like #scale, #bounce, #spin, #anneal, or #transition create
  # animations, and the #update method advances the animation by one frame.
  #
  # Example:
  #
  #     # Animate from a hexagon to a triangle (;nil for pasting into Pry)
  #     hex = MB::Geometry::Generators.regular_polygon(6, 0.5)
  #     tri = MB::Geometry::Generators.regular_polygon(3, 0.5)
  #     v = MB::Geometry::Voronoi.new(hex) ; nil
  #     v.set_area_bounding_box(-1, -1, 1, 1) # Limit SVG rendering area
  #     anim = MB::Geometry::VoronoiAnimator.new(v) ; nil
  #     anim.transition(tri, 119) ; nil # one less so final frame is post-transition
  #     120.times do |t|
  #       v.save_svg("/tmp/6to3_#{'%03d' % t}.svg")
  #       anim.update
  #     end
  class VoronoiAnimator
    DEFAULT_RANDOM_SEED = ENV['RANDOM_SEED']&.to_i || 0

    # A group of cell animations, or a whole-graph animation, that can apply a
    # global weight.
    class AnimationGroup
      extend Forwardable

      def_delegators :@animators, :map, :each, :to_enum

      attr_reader :base, :animators, :weight

      def initialize(base:, animators: [])
        raise "Base must be a VoronoiAnimator" unless base.is_a?(VoronoiAnimator)
        raise "All animators must be CellAnimator instances" unless animators.all?(CellAnimator)
        @base = base
        @animators = animators
        @weight = @animators.empty? ? 1.0 : @animators.map(&:weight).sum.to_f / @animators.length
      end

      # Sets the influence weight (typically 0.0..1.0) for all animators in
      # this group, and for the group as a whole (e.g. TransitionAnimation).
      def weight=(w)
        @weight = w
        @animators.each do |a|
          a.weight = w
        end
      end

      # Calls #update on each CellAnimator in this animation group.
      def update
        # TODO: Add a way for AnimationGroups to be rebuilt when a Voronoi
        # graph is changed, or refactor so most animations operate on the graph
        # as a whole.
        @animators.each(&:update)
      end
    end

    # An animation that transitions from one set of Voronoi points to another
    # over a given number of frames.
    class TransitionAnimation < AnimationGroup
      attr_accessor :weight

      def initialize(base:, new_points:, frames:, weight: nil)
        super(base: base, animators: [])

        @base = base
        @new_point_scale = 1.5 * [@base.voronoi.width, @base.voronoi.height].max
        @old_length = @base.voronoi.cells.length
        @current_frame = 0

        # TODO: Probably delete :weight parameter; probably won't use it
        raise "Specify exactly one of :frames or :weight" if (frames && weight) || !(frames || weight)
        if frames
          raise ":frames must be an integer greater than zero unless :weight is given, not #{frames.inspect}" unless frames.is_a?(Integer) && frames > 0
          @frames = frames
          @weight = 0.0
        else
          raise ":weight must be numeric" unless weight.is_a?(Numeric)
          @frames = -1
          @weight = weight.to_f
        end

        # Build new points array
        case new_points
        when MB::Geometry::Voronoi
          @new_points = new_points.cells.map(&:to_h)

        when Array
          unless new_points.all?{ |v| v.is_a?(Array) || v.is_a?(Hash) }
            raise "All elements of :new_points must be either a 2- or 3-element Array or a Hash"
          end

          @new_length = new_points.length
          @new_points = new_points.map.with_index { |p, idx|
            p = { x: p[0], y: p[1], name: p[2] } if p.is_a?(Array)
            p[:color] ||= MB::Geometry::Voronoi::SVG.generate_rgb(idx, @new_length)
            p
          }

        else
          raise ":new_points must be a point Array or a MB::Geometry::Voronoi, not #{to.class}"
        end

        # Add extra Voronoi cells if the new list of points is longer
        for idx in @old_length...@new_length
          h = @new_points[idx]
          x, y = out_of_scene(h[:x], h[:y])

          # If going from zero points to one or more, have points fade in from alpha=0
          # (TODO: have all points optionally fade in from alpha=0?)
          color = h[:color].dup
          color[3] = 0 if @old_length == 0

          @base.voronoi.add_point(h.merge(x: x, y: y, color: color))
        end

        @old_points = @base.voronoi.cells.map(&:to_h)
        @total_length = @old_points.length # max length of new and old

        # Arrange for excess old cells to move out of scene
        for idx in @new_length...@old_length
          h = @old_points[idx]
          x, y = out_of_scene(h[:x], h[:y])

          # Have points that are going away fade out (TODO: make this optional)
          color = h[:color].dup
          color[3] = 0

          @new_points[idx] = h.merge(x: x, y: y, color: color)
        end

        # FIXME: how can the old animators continue when points are being
        # moved?  Would probably need to have them act on both old and new
        # points
        @old_animators = @base.cell_animators.dup
        @old_groups = @base.animation_groups.dup
      end

      def update
        if @frames >= 0
          # Using frame-based weight if @frames is nonnegative; otherwise using an externally applied weight
          return if @current_frame >= @frames
          @current_frame += 1
          if @current_frame == @frames
            @weight = 1.0 # Avoid rounding error
          else
            @weight = MB::M.smootherstep(@current_frame.to_f / @frames)
          end
        end

        @old_animators.each do |a|
          a.weight = 1.0 - @weight
        end

        @old_groups.each do |g|
          g.weight = 1.0 - @weight
        end

        # Move matched points toward new points, and move extra old points out of the scene
        for idx in 0...@total_length
          c = @base.voronoi.cells[idx]
          p_old = @old_points[idx]
          p_new = @new_points[idx]

          old_color = p_old[:color]
          new_color = p_new[:color]
          if new_color.length > old_color.length
            old_color[3] = 1.0
          elsif old_color.length > new_color.length
            new_color[3] = 1.0
          end

          # TODO: Maybe use the cell's current point instead of p_old, so animations still have some effect?
          c.color = MB::M.interp(old_color, new_color, @weight)
          c.name = p_new[:name]

          c.move(
            MB::M.interp(p_old[:x], p_new[:x], @weight),
            MB::M.interp(p_old[:y], p_new[:y], @weight)
          )
        end

        # If in frame-based mode, clear old points at the end of the animation
        if @frames >= 0 && @current_frame >= @frames
          (@old_length - @new_length).times do
            @base.voronoi.cells[@new_length].remove
          end

          # TODO: Should I really just keep the animators?  Would need a way to regenerate their Cell associations
          @old_groups.each do |g|
            @base.remove(g)
          end
          @old_animators.each do |g|
            @base.remove(a)
          end

          @base.remove(self)
        end
      end

      private

      # Returns an x, y pair that is well out of scene, in the same direction
      # as a given x, y pair.
      def out_of_scene(x, y)
        # Bring new points at the origin from the right
        if x == 0 && y == 0
          x = 1.0
          y = 0.0
        end

        x, y = *(Vector[x, y].normalize * @new_point_scale)

        return x, y
      end
    end

    class CellAnimator
      # A value, typically from 0.0 to 1.0, that scales the influence of an
      # animator.  0.0 means effectively disabled, 1.0 means fully enabled, 2.0
      # means twice as much difference is applied, etc.
      attr_accessor :weight

      # The MB::Geometry::Voronoi::Cell associated with this animation.
      attr_reader :cell

      def initialize(base:, cell:)
        raise "Base must be a VoronoiAnimator" unless base.is_a?(VoronoiAnimator)
        raise "Cell must be a MB::Geometry::Voronoi::Cell" unless cell.is_a?(MB::Geometry::Voronoi::Cell)

        @base = base
        @cell = cell
        @weight = 1.0
        @xmin, @ymin, @xmax, @ymax = @cell.voronoi.area_bounding_box
      end

      # Moves the associated cell to the next point for this animation.
      def update
        # Don't try to update cells that have been removed from the Voronoi
        # graph.  FIXME: this won't actually remove most CellAnimators because
        # they will be in AnimationGroups, but returning will still prevent
        # attempts to modify deleted cells.  TODO: Add a way for
        # AnimationGroups to be rebuilt when a Voronoi graph is changed.
        @base.remove(self) and return if @cell.voronoi.nil?

        return if @weight == 0.0

        # FIXME: allow subclasses to override the way weight is applied
        x, y = @cell.point
        new_x, new_y = new_point

        if @weight == 1.0
          @cell.move(new_x, new_y)
        else
          dx = new_x - x
          dy = new_y - y

          # This creates a discontinuity in the derivative at 0 and 1, but
          # whatevs, weights outside 0..1 are going to be weird anyway
          if @weight > 0 && @weight < 1
            w = MB::M.smoothstep(@weight)
          else
            w = @weight
          end

          @cell.move(
            MB::M.clamp(x + w * dx, @xmin, @xmax),
            MB::M.clamp(y + w * dy, @ymin, @ymax)
          )
        end
      end

      def new_point
        raise NotImplementedError, 'Subclasses must implement #new_point and return new X and Y coordinates'
      end
    end

    # Bounces a cell off the walls of the Voronoi's area bounding box.
    class BounceAnimator < CellAnimator
      def initialize(base:, cell:, dx: nil, dy: nil)
        super(base: base, cell: cell)

        v = Vector[cell.x, cell.y].normalize * 0.005
        @dx = dx || v[0]
        @dy = dy || v[1]
      end

      def new_point
        x, y = @cell.point

        x += @dx
        if x >= @xmax
          @dx = -@dx.abs
          x = 2.0 * @xmax - x
        elsif x <= @xmin
          @dx = @dx.abs
          x = 2.0 * @xmin - x
        end

        y += @dy
        if y >= @ymax
          @dy = -@dy.abs
          y = 2.0 * @ymax - y
        elsif y <= @ymin
          @dy = @dy.abs
          y = 2.0 * @ymin - y
        end

        return x, y
      end
    end

    # Multiplies a cell's vector by a Matrix on every frame, constraining points
    # to the edges of the graph.  Useful for rotations.  Default matrix is a
    # rotation by one degree clockwise.
    class MatrixAnimator < CellAnimator
      def initialize(base:, cell:, matrix: nil)
        raise 'Matrix must be a Ruby Matrix' unless matrix.nil? || matrix.is_a?(Matrix)

        super(base: base, cell: cell)

        @matrix = matrix || -1.degree.rotation
      end

      def new_point
        x, y = @cell.point

        x, y = *(@matrix * Vector[x, y])

        x = MB::M.clamp(x, @xmin, @xmax)
        y = MB::M.clamp(y, @ymin, @ymax)

        return x, y
      end
    end

    attr_reader :voronoi
    attr_reader :cell_animators
    attr_reader :animation_groups

    # Initializes a Voronoi graph animator with no CellAnimators.
    def initialize(voronoi, random_seed: DEFAULT_RANDOM_SEED)
      @voronoi = voronoi
      @random = Random.new(random_seed)
      @cell_animators = Set.new
      @group_animators = Set.new
      @animation_groups = Set.new
    end

    # Adds the given CellAnimator or AnimationGroup to be run on every frame,
    # then returns it (for method chaining).
    def add(cell_animator_or_group)
      case cell_animator_or_group
      when CellAnimator
        raise "AnimationGroup animators should not be added individually" if @group_animators.include?(cell_animator_or_group)
        @cell_animators << cell_animator_or_group

      when AnimationGroup
        raise "AnimationGroup animators were already added individually" unless (@cell_animators & cell_animator_or_group.animators).empty?
        @animation_groups << cell_animator_or_group
        @group_animators += cell_animator_or_group.animators

      else
        raise ArgumentError, "Invalid type to add: #{cell_animator_or_group.class}"
      end

      cell_animator_or_group
    end

    # Removes a CellAnimator or AnimationGroup from future updates.
    def remove(cell_animator_or_group)
      case cell_animator_or_group
      when CellAnimator
        @cell_animators.delete(cell_animator_or_group)

      when AnimationGroup
        @animation_groups.delete(cell_animator_or_group)
        @group_animators -= cell_animator_or_group.animators

      else
        raise ArgumentError, "Invalid type to remove: #{cell_animator_or_group.class}"
      end
    end

    # Removes all CellAnimators and AnimationGroups.
    def clear
      @cell_animators.clear
      @animation_groups.clear
    end

    # Adds bouncing cell animators for all cells, or for a given subset of cells
    # or cell indices.
    def bounce(selector = nil)
      add(
        AnimationGroup.new(
          base: self,
          animators: @voronoi.cells(selector).map { |c|
            BounceAnimator.new(base: self, cell: c)
          }
        )
      )
    end

    # Adds a rotation matrix cell animator for all (or given) cells, rotating by
    # +:rotation+ radians per frame (default is -1.degree (clockwise)).
    def spin(selector = nil, rotation: nil)
      matrix = rotation&.rotation

      add(
        AnimationGroup.new(
          base: self,
          animators: @voronoi.cells(selector).map { |c|
            MatrixAnimator.new(base: self, cell: c, matrix: matrix)
          }
        )
      )
    end

    # Animates a transition from the current graph to the given new set of
    # points, over the given number of frames.
    def transition(points, frames)
      # Cancel any existing transitions
      @animation_groups.grep(TransitionAnimation).each { |a|
        remove(a)
      }

      add(TransitionAnimation.new(base: self, new_points: points, frames: frames))
    end

    # Deterministically shuffles the current points in the graph over the given
    # number of +frames+, so each point is randomly animated to another point
    # until the original graph reappears.  See #transition.
    def shuffle(frames)
      points = @voronoi.cells.map(&:to_h)
      new_points = points.dup
      new_points.shuffle! while points.length > 1 && new_points == points
      transition(new_points, frames)
    end

    # Reverses the order of points in the graph over the given number of
    # +frames+.  See #transition.
    def reverse(frames)
      transition(@voronoi.cells.map(&:to_h).reverse, frames)
    end

    # Cycles the points +offset+ points (so offset.abs points are moved from
    # the end to the beginning if positive, or vice versa if negative).  See
    # #transition.
    def cycle(offset, frames)
      points = @voronoi.cells.map(&:to_h)
      transition(points.rotate(-offset), frames)
    end

    # Transitions to a version of the current graph that has been annealed zero
    # or more +times+, across +frames+ frames.  See MB::Geometry::Voronoi#anneal.
    def anneal(times, frames)
      old_points = @voronoi.cells.map(&:to_h)
      new_points = MB::Geometry::Generators.generate(
        points: old_points,
        anneal: times,
        bounding_box: @voronoi.area_bounding_box
      )
      transition(new_points, frames)
    end

    # Transitions to a scaled version of the current graph, by factors +x+ and
    # +y+ (1.0 for no change), over +frames+ frames.
    def scale(x, y, frames)
      points = @voronoi.cells.map { |p|
        h = p.to_h
        h[:x] *= x
        h[:y] *= y
        h
      }
      transition(points, frames)
    end

    # Causes all animations to advance by one frame.  Returns true if there
    # were any animations present, false if there were no animations (useful to
    # re-render something only when animation is in progress).
    def update
      # Check before and after as the list of animators may change in an
      # #update call (see TransitionAnimation)
      started_with_animators = @cell_animators.any? || @animation_groups.any?

      @cell_animators.each do |a|
        a.update
      end
      @animation_groups.each do |g|
        g.update
      end

      return started_with_animators || cell_animators.any? || @animation_groups.any?
    end
  end
end
