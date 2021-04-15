module MB
  module Geometry
    # Methods for generating lists of points (random points, polygons, etc.).
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
        # region, using the given pseudorandom number generator.  If Integers
        # are given for both sides of a range, then that range will only
        # generate Integers.
        def random_points(count, xmin: -1.0, xmax: 1.0, ymin: -1.0, ymax: 1.0, random: Random::DEFAULT)
          xrange = xmin..xmax
          yrange = ymin..ymax

          count.times.map {
            [ random.rand(xrange), random.rand(yrange) ]
          }
        end

        # Loads points or a generation spec from a given file, detecting file type
        # by extension.  Do not load untrusted YAML.
        #
        # Yields the loaded data before generating points, if a block is given.
        def generate_from_file(filename)
          case File.extname(filename)
          when '.yaml', '.yml', '.YAML', '.YML'
            data = YAML.load(File.read(filename), filename: filename, symbolize_names: true)

          when '.json', '.JSON'
            data = JSON.parse(File.read(filename), symbolize_names: true)

          when '.csv', '.CSV'
            data = CSV.read(filename, converters: :numeric)

          else
            raise "Unsupported extension on file #{filename.inspect}"
          end

          # TODO: Need a better way of getting more than just the Array of
          # points back from files that have extra data
          yield data if block_given?

          case data
          when Array
            generate(points: data)

          when Hash
            generate(data)

          else
            raise "Unsupported type #{data.class} loaded from #{filename.inspect}"
          end
        end

        # Returns an Array of points generated from the given +spec+, which is a
        # Hash describing how to generate points:
        #
        # {
        #   generator: :polygon, # see MB::Geometry::Generators.regular_polygon
        #   sides: 4,
        #   radius: 0.5, # optional, default is 0.5
        #   aspect: 1.0, # optional, width is multiplied by aspect
        #   rotate: 45,  # optional, degrees
        #   translate: [0, 0], # optional shift
        #   clockwise: false, # optional reversal
        #   colors: [      # optional, colors will be cycled if excess points are given
        #     [1, 1, 1, 1]
        #   ],
        #   names: [       # optional
        #     'A',
        #     'B',
        #     'C',
        #     'D'
        #   ],
        #   anneal: 0,     # optional, number of times to move points to polygon centers
        #   bounding_box:, # optional, area bounding box to use during annealing
        # }
        #
        # {
        #   generator: :random, # see MB::Geometry::Generators.random_points
        #   count: 12,
        #   seed: 0,
        #   xmin: -1,      # optional, default is -1
        #   xmax: 1,       # optional, default is 1
        #   ymin: -1,      # optional, default is -1
        #   ymax: 1,       # optional, default is 1
        #   anneal: 0,     # optional, number of times to move points to polygon centers
        #   bounding_box:, # optional, area bounding box to use during annealing
        #   colors: [...], # optional
        #   names: [...],  # optional
        # }
        #
        # {
        #   generator: :points, # May be omitted
        #   points: [
        #     { x: 0, y: 1, name: 'A', color: [0, 1, 0, 1] },
        #     { x: 1, y: 0, name: 'B', color: [1, 0, 0, 1] },
        #     { x: 1, y: 0, name: 'C', color: [0, 1, 1, 0] },
        #     [ -1, -1, 'D' ]
        #   ],
        #   colors: [...], # optional; point color takes precedence
        #   names: [...], # optional; point name takes precedence
        # }
        #
        # {
        #   generator: :multi,
        #   generators: [
        #     { ... },
        #     { points: ... },
        #   ],
        # }
        def generate(spec)
          raise "Spec must be a Hash" unless spec.is_a?(Hash)

          case spec[:generator]&.to_sym
          when :polygon
            sides = spec[:sides]
            raise "Number of sides must be a non-negative Integer for :polygon" unless sides.is_a?(Integer) && sides >= 0

            radius = spec[:radius] || 0.5
            raise "Radius must be a Numeric for :polygon, if given" unless radius.is_a?(Numeric)

            aspect = spec[:aspect] || 1.0
            raise "Aspect must be a Numeric for :polygon, if given" unless aspect.is_a?(Numeric)

            # TODO: Maybe make rotation and translation post-generation transforms, like :anneal?

            rotate = spec[:rotate] || 0
            raise "Rotate must be a Numeric of degrees for :polygon, if given" unless rotate.is_a?(Numeric)

            translate = spec[:translate] || [0, 0]
            unless translate.is_a?(Array) && translate.length == 2 && translate.all?(Numeric)
              raise "Translate must be an Array of two numbers, if given"
            end

            points = MB::Geometry::Generators.regular_polygon(sides, radius, rotation: rotate.degrees)
            points = points.reverse if spec[:clockwise]
            points = points.map { |p|
              { x: p[0] * aspect + translate[0], y: p[1] + translate[1] }
            }

          when :random
            count = spec[:count]
            raise "Count must be an Integer for :random" unless count.is_a?(Integer)

            # Use an incrementing seed by default for deterministic generation
            @@seed ||= 0
            seed = spec[:seed] || (@@seed += 1)
            raise "Seed must be an Integer for :random" unless seed.is_a?(Integer)

            xmin = spec[:xmin] || -1.0
            raise "Xmin must be a Numeric for :random" unless xmin.is_a?(Numeric)

            ymin = spec[:ymin] || -1.0
            raise "Ymin must be a Numeric for :random" unless ymin.is_a?(Numeric)

            xmax = spec[:xmax] || 1.0
            raise "Xmax must be a Numeric for :random" unless xmax.is_a?(Numeric)

            ymax = spec[:ymax] || 1.0
            raise "Ymax must be a Numeric for :random" unless ymax.is_a?(Numeric)

            rnd = Random.new(seed)
            points = MB::Geometry::Generators.random_points(count, xmin: xmin, xmax: xmax, ymin: ymin, ymax: ymax, random: rnd).map { |p|
              { x: p[0], y: p[1] }
            }

          when :multi
            raise "Generators must be a list of generators or point arrays" unless spec[:generators].is_a?(Array)

            points = spec[:generators].flat_map { |s|
              if s.is_a?(Array)
                generate(points: s)
              elsif s.is_a?(Hash)
                generate(s)
              else
                raise "Invalid type in list of generators: #{s.class}"
              end
            }

          when nil, :points
            if spec[:points].is_a?(Array)
              points = spec[:points].map { |p|
                if p.is_a?(Array)
                  { x: p[0], y: p[1], name: p[2] }
                else
                  p
                end
              }

            else
              raise "Missing both :generator and :points"
            end
          end

          if spec[:colors]
            raise "Colors must be an Array, if given" unless spec[:colors].is_a?(Array)

            # TODO: Allow using generated colors past the end, instead of looping?
            points.each_with_index do |p, idx|
              p[:color] ||= spec[:colors][idx % spec[:colors].length]
            end
          end

          if spec[:names]
            raise "Names must be an Array, if given" unless spec[:names].is_a?(Array)

            points.each_with_index do |p, idx|
              break if idx >= spec[:names].length
              p[:name] ||= spec[:names][idx]
            end
          end

          if anneal = spec[:anneal]
            raise "Anneal must be an Integer, if given" unless anneal.is_a?(Integer)

            raise NotImplementedError, 'Need to bring MB::Geometry::Voronoi into mb-geometry'

            v = MB::Geometry::Voronoi.new(points)

            # TODO: Pass the bounding box into the final MB::Geometry::Voronoi if one is constructed?
            if box = spec[:bounding_box]
              raise "Bounding box must be a 4-element array, if given" unless box.is_a?(Array)

              v.set_area_bounding_box(*box)

              anneal.times do v.anneal end

              v.cells.each_with_index do |c, idx|
                points[idx][:x] = c.x
                points[idx][:y] = c.y
              end
            else
              # 0.64 was tweaked empirically to give a reasonable balance between
              # shrinking and growing graphs.  The #anneal function will ensure the
              # width and height stay the same if there is no user bounding box.
              # This just keeps the outer points from bunching in on the rest.
              xmin = v.x_center - v.width * 0.64
              xmax = v.x_center + v.width * 0.64
              ymin = v.y_center - v.height * 0.64
              ymax = v.y_center + v.height * 0.64

              v.set_area_bounding_box(xmin, ymin, xmax, ymax)
            end

            anneal.times do v.anneal(scale: !spec[:bounding_box]) end

            v.cells.each_with_index do |c, idx|
              points[idx][:x] = c.x
              points[idx][:y] = c.y
            end
          end

          points
        end
      end
    end
  end
end
