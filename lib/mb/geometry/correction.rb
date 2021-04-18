module MB::Geometry
  # Experimental, algebraically derived, probably not very good correction from
  # one 2D trapezoid to another.  Doing this to reinforce my understanding of
  # the problem, before diving into a vector-/matrix-based version.
  #
  # This probably needs a full conic equation, or at least an X*Y term, but
  # it's currently just an affine transform.  This video from CodeParade might
  # be a good starting point to find useful mathematical tools for this:
  # https://www.youtube.com/watch?v=X83vac2uTUsu?t=667
  #
  # The optimization algorithm is an ad hoc semi-random hill climb.
  class Correction
    attr_reader :a, :b, :c, :d, :e, :f, :constants

    # Creates a correction instance that rotates counterclockwise by the given
    # number of radians.
    def self.rotation(radians)
      self.new([
        Math.cos(radians).round(10), -Math.sin(radians).round(10), 0,
        Math.sin(radians).round(10), Math.cos(radians).round(10), 0
      ])
    end

    # Initializes an affine correction that tries to map the given four or more
    # input points to the given equal number of output points.  The first four
    # points are used to form a guess at the parameters needed, then an
    # optimization algorithm is run to produce a better set of parameters.
    #
    # If the second parameter is omitted, then the first parameter is used
    # directly as the constants for the affine transform, and should be a
    # single-dimensional Array with the first two rows of the 3x3 affine
    # transformation matrix.
    def initialize(in_points_or_constants, out_points_or_nil = nil)
      if out_points_or_nil
        in_points = in_points_or_constants
        out_points = out_points_or_nil

        raise 'Provide at least four input points' unless in_points.is_a?(Array) && in_points.length >= 4
        raise 'Provide at least four output points' unless out_points.is_a?(Array) && out_points.length >= 4
        raise 'Provide the same number of input and output points' unless in_points.length == out_points.length
        raise 'Every input point must be a 2-element numeric array' unless in_points.all? { |el| el.is_a?(Array) && el.length == 2 }
        raise 'Every output point must be a 2-element numeric array' unless out_points.all? { |el| el.is_a?(Array) && el.length == 2 }

        # FIXME: this is mostly wrong, and the #optimize call is what gets most of the way to an approximate correction

        # X
        d1 = in_points[0][0] - in_points[3][0] # p1.x - p4.x
        d2 = in_points[1][0] - in_points[2][0] # p2.x - p3.x
        n1 = out_points[3][0] - out_points[0][0] # q4.x - q1.x
        n2 = out_points[1][0] - out_points[2][0] # q2.x - q3.x
        n3 = in_points[3][1] - in_points[0][1] # p4.y - p1.y
        n4 = in_points[1][1] - in_points[2][1] # p2.y - p3.y
        d1 = 1 if d1 == 0 # FIXME: hacks to avoid div by 0
        d2 = 1 if d2 == 0
        d = n3 / d1 + n4 / d2
        d = 1 if d == 0
        @b = (n1 / d1 + n2 / d2) / d

        @a = (-n1 - @b * n3) / d1

        @c = out_points[3][0] - (@a * in_points[3][0] + @b * in_points[3][1])

        # Y
        # TODO: this was just copied/swapped from X
        d1 = in_points[0][1] - in_points[3][1] # p1.x - p4.x
        d2 = in_points[1][1] - in_points[2][1] # p2.x - p3.x
        n1 = out_points[3][1] - out_points[0][1] # q4.x - q1.x
        n2 = out_points[1][1] - out_points[2][1] # q2.x - q3.x
        n3 = in_points[3][0] - in_points[0][0] # p4.y - p1.y
        n4 = in_points[1][0] - in_points[2][0] # p2.y - p3.y
        d1 = 1 if d1 == 0 # FIXME: hacks to avoid div by 0
        d2 = 1 if d2 == 0
        d = n3 / d1 + n4 / d2
        d = 1 if d == 0
        @d = (n1 / d1 + n2 / d2) / d

        @e = (-n1 - @d * n3) / d1

        @f = out_points[3][1] - (@d * in_points[3][0] + @e * in_points[3][1])

        @constants = [@a, @b, @c, @d, @e, @f].freeze

        _, best = optimize(in_points, out_points, objective_threshold: 1.0e-4)
        puts "Note: correction error after optimization was #{best}" if best != 0
      else
        constants = in_points_or_constants
        unless constants.is_a?(Array) && constants.length == 6 && constants.all? { |v| v.is_a?(Numeric) }
          raise 'Provide six constants ABCDEF for x=Ax+By+C, y=Dx+Ey+F'
        end

        self.constants = constants
      end

      # FIXME: correcting *four* points requires an X*Y term

    end

    # Returns the given X/Y coordinate projected according to the mapping given
    # to the constructor.
    def project(x, y)
      [
        @a*x + @b*y + @c,
        @d*x + @e*y + @f
      ]
    end

    # Use a stochastic algorithm to try to optimize the transformation from
    # in_points to out_points.
    def optimize(in_points, out_points, **climb_args)
      self.constants, best_objective = Correction.random_climb(constants, **climb_args) do |test|
        in_points.map.with_index { |p, idx|
          p = Correction.affine(*p, *test)
          p2 = out_points[idx]
          Math.sqrt((p2[0] - p[0]) ** 2 + (p2[1] - p[1]) ** 2)
        }.sum
      end

      return @constants, best_objective
    end

    def debug(*msg)
      puts(*msg) if false
    end

    def self.debug(*msg)
      puts(*msg) if false
    end

    def constants=(constants)
      @a, @b, @c, @d, @e, @f = *constants
      @constants = [@a, @b, @c, @d, @e, @f].freeze
    end

    def self.affine(x, y, a, b, c, d, e, f)
      [
        a*x + b*y + c,
        d*x + e*y + f
      ]
    end

    # Picks +samples+ random variations on +parameters+ (plus a few other
    # guesses), within a range of +scale+ times the value each parameter.
    # Returns the randomized parameters that had the lowest value returned by
    # the objective function.  Returns +parameters+ itself if all of the random
    # variations had worse objective scores.
    #
    # Provide a block that returns a floating point value for the objective
    # score (closer to zero is better).
    #
    # Returns [new_parameters, best_objective].
    def self.climb_step(parameters, scale: 0.5, samples: 100)
      raise 'An objective to minimize must be passed as a block' unless block_given?

      scale = 0.01 if scale <= 0

      max_abs = parameters.map(&:abs).max

      debug "Testing scale #{scale}"

      attempts = [parameters]

      # Try sigfigs and rounding
      5.times do |digs|
        attempts << parameters.map { |p|
          MB::M.sigfigs(p, digs + 1)
        }
        attempts << parameters.map { |p|
          p.round(digs)
        }
      end

      # Try all ones and all zeros
      attempts << [-1] * parameters.length
      attempts << [0] * parameters.length
      attempts << [1] * parameters.length

      # Try flipping a single parameter's sign, rounding a single parameter,
      # setting a single parameter to zero, stepping a parameter a small
      # amount, or setting a single parameter to 1, etc.
      parameters.length.times do |idx|
        attempts << parameters.dup.tap { |v| v[idx] = -v[idx] }
        attempts << parameters.dup.tap { |v| v[idx] = v[idx].round }
        attempts << parameters.dup.tap { |v| v[idx] = v[idx].round(2) }
        attempts << parameters.dup.tap { |v| v[idx] = (v[idx] <=> 0) * Math.sqrt((v[idx] ** 2).round(1)) }
        attempts << parameters.dup.tap { |v| v[idx] = (v[idx] <=> 0) * Math.sqrt((v[idx] ** 2).round(3)) }
        attempts << parameters.dup.tap { |v| v[idx] = 0 }
        attempts << parameters.dup.tap { |v| v[idx] = 1 }
        attempts << parameters.dup.tap { |v| v[idx] *= 1 - 0.1 * scale }
        attempts << parameters.dup.tap { |v| v[idx] *= 1 + 0.1 * scale }
        attempts << parameters.dup.tap { |v| v[idx] *= scale }
        attempts << parameters.dup.tap { |v| v[idx] /= scale }
        attempts << parameters.dup.tap { |v| v[idx] -= 10 * scale }
        attempts << parameters.dup.tap { |v| v[idx] += 10 * scale }
        attempts << parameters.dup.tap { |v| v[idx] -= scale }
        attempts << parameters.dup.tap { |v| v[idx] += scale }
        attempts << parameters.dup.tap { |v| v[idx] -= 0.1 * scale }
        attempts << parameters.dup.tap { |v| v[idx] += 0.1 * scale }
        attempts << parameters.dup.tap { |v| v[idx] -= 0.0113131 * scale }
        attempts << parameters.dup.tap { |v| v[idx] += 0.0121172 * scale }
        attempts << parameters.dup.tap { |v| v[idx] -= 0.00113131 * scale }
        attempts << parameters.dup.tap { |v| v[idx] += 0.00121172 * scale }
        attempts << parameters.dup.tap { |v| v[idx] = rand(-max_abs..max_abs) }
        attempts << parameters.dup.tap { |v| v[idx] = -max_abs }
        attempts << parameters.dup.tap { |v| v[idx] = max_abs }
      end

      # Try flipping all parameters' signs
      attempts << parameters.map { |v| -v }

      # Try a few ways of randomizing all parameters
      max_delta = max_abs * scale.abs
      max_delta = 1 if max_delta == 0
      [(samples - attempts.length) / 2, parameters.length].max.times do |s|
        attempts << parameters.map { |p|
          delta = p.abs * scale.abs
          delta = scale.abs if delta == 0
          p + rand(-delta..delta)
        }
        attempts << parameters.map { |p|
          p + rand(-max_delta..max_delta)
        }
      end

      baseline = yield parameters
      best_objective = baseline

      attempts.sort_by! { |v|
        result = (yield v).abs
        best_objective = result if result < best_objective
        result
      }

      return attempts.first, best_objective
    end

    # Does a semi-random hill climb on the given parameters, with some hacks to
    # find round numbers and simple fractions faster.  Returns
    # [best_parameters, best_objective].  Provide a block that returns a float
    # from 0..inf to measure progress, where lower is better.
    #
    # Tries +:samples+ random samples (plus some other guesses) for each
    # iteration, starting within +/- +:scale+ times each parameter, scaling up
    # when no progress is made, scaling down otherwise.  Stops trying when
    # either the objective reaches 0.0, when there are +iterations+ rounds in a
    # row with no improvement, or if improvement continues for longer than
    # iterations*samples.
    def self.random_climb(parameters, scale: 0.5, samples: 150, iterations: 50, objective_threshold: 0)
      raise 'An objective to minimize must be passed as a block' unless block_given?

      best_objective = Float::INFINITY

      t = 0
      loop do
        new_parameters, best_objective = climb_step(parameters, scale: scale, samples: samples) do |test|
          yield test
        end

        new_parameters, best_objective = climb_step(parameters, scale: 1.0 / scale, samples: samples) do |test|
          yield test
        end

        if new_parameters == parameters
          debug "No improvement: #{t} #{scale} #{best_objective}"
          t = 0 if t < 0
          t += 1
          scale *= rand(0.9..2.1)
          scale = 123456.78 - rand(1000) if scale > 123456.78
        else
          debug "improved: #{t} #{scale} #{best_objective}"
          debug "Prior parameters: #{parameters}"
          debug "new parameters: #{new_parameters}"
          t = 0 if t > 0
          t -= 1

          # FIXME: how should scale uh.. scale?
          scale *= rand(0.1..1.1)
          scale = 0.00001 if scale < 0.00001
        end

        parameters = new_parameters

        break if t >= iterations || t <= -(iterations * samples) || best_objective <= objective_threshold
      end

      return parameters, best_objective
    end
  end
end
