RSpec.describe(MB::Geometry::Delaunay) do
  describe(MB::Geometry::Delaunay::Hull) do
    describe '#tangents' do
      it 'returns the correct single tangent for two vertical segments with shared X' do
        # Y is in ascending order, matching sort by [x, y]
        p1 = MB::Geometry::Delaunay::Point.new(-1, -2)
        p2 = MB::Geometry::Delaunay::Point.new(-1, -1)
        p1.add(p2)
        p2.add(p1)
        left = MB::Geometry::Delaunay::Hull.new([p1, p2])

        p3 = MB::Geometry::Delaunay::Point.new(-1, 1)
        p4 = MB::Geometry::Delaunay::Point.new(-1, 2)
        p3.add(p4)
        p4.add(p3)
        right = MB::Geometry::Delaunay::Hull.new([p3, p4])

        tangents = left.tangents(right)
        expect(tangents).to eq([[p2, p3], [p2, p3]])
      end

      it 'returns the correct tangents for two horizontal segments with one shared X' do
        p1 = MB::Geometry::Delaunay::Point.new(-2, -1)
        p2 = MB::Geometry::Delaunay::Point.new(0, -1)
        p1.add(p2)
        p2.add(p1)
        left = MB::Geometry::Delaunay::Hull.new([p1, p2])

        p3 = MB::Geometry::Delaunay::Point.new(0, 0)
        p4 = MB::Geometry::Delaunay::Point.new(2, 0)
        p3.add(p4)
        p4.add(p3)
        right = MB::Geometry::Delaunay::Hull.new([p3, p4])

        tangents = left.tangents(right)
        expect(tangents).to eq([[p2, p4], [p1, p3]])
      end

      it 'returns the correct tangents for two offset horizontal segments' do
        p1 = MB::Geometry::Delaunay::Point.new(-2, -1)
        p2 = MB::Geometry::Delaunay::Point.new(-1, -1)
        p1.add(p2)
        p2.add(p1)
        left = MB::Geometry::Delaunay::Hull.new([p1, p2])

        p3 = MB::Geometry::Delaunay::Point.new(1, 0)
        p4 = MB::Geometry::Delaunay::Point.new(2, 0)
        p3.add(p4)
        p4.add(p3)
        right = MB::Geometry::Delaunay::Hull.new([p3, p4])

        tangents = left.tangents(right)
        expect(tangents).to eq([[p2, p4], [p1, p3]])
      end

      it 'returns the correct single tangent for two horizontal segments at the same Y' do
        p1 = MB::Geometry::Delaunay::Point.new(-2, 0)
        p2 = MB::Geometry::Delaunay::Point.new(-1, 0)
        p1.add(p2)
        p2.add(p1)
        left = MB::Geometry::Delaunay::Hull.new([p1, p2])

        p3 = MB::Geometry::Delaunay::Point.new(1, 0)
        p4 = MB::Geometry::Delaunay::Point.new(2, 0)
        p3.add(p4)
        p4.add(p3)
        right = MB::Geometry::Delaunay::Hull.new([p3, p4])

        tangents = left.tangents(right)
        expect(tangents).to eq([[p2, p3], [p2, p3]])
      end

      it 'returns the correct tangents for a horizontal segment above a vertical segment' do
        p1 = MB::Geometry::Delaunay::Point.new(-2, 3)
        p2 = MB::Geometry::Delaunay::Point.new(-1, 3)
        p1.add(p2)
        p2.add(p1)
        left = MB::Geometry::Delaunay::Hull.new([p1, p2])

        p3 = MB::Geometry::Delaunay::Point.new(1, -1)
        p4 = MB::Geometry::Delaunay::Point.new(1, 1)
        p3.add(p4)
        p4.add(p3)
        right = MB::Geometry::Delaunay::Hull.new([p3, p4])

        tangents = left.tangents(right)
        expect(tangents).to eq([[p1, p3], [p2, p4]])
      end

      it 'returns the correct tangents for a horizontal segment below a vertical segment' do
        p1 = MB::Geometry::Delaunay::Point.new(-2, -3)
        p2 = MB::Geometry::Delaunay::Point.new(-1, -3)
        p1.add(p2)
        p2.add(p1)
        left = MB::Geometry::Delaunay::Hull.new([p1, p2])

        p3 = MB::Geometry::Delaunay::Point.new(1, -1)
        p4 = MB::Geometry::Delaunay::Point.new(1, 1)
        p3.add(p4)
        p4.add(p3)
        right = MB::Geometry::Delaunay::Hull.new([p3, p4])

        tangents = left.tangents(right)
        expect(tangents).to eq([[p2, p3], [p1, p4]])
      end

      it 'returns the correct tangents for a horizontal and a vertical segment at the same Y' do
        p1 = MB::Geometry::Delaunay::Point.new(-2, 0)
        p2 = MB::Geometry::Delaunay::Point.new(-1, 0)
        p1.add(p2)
        p2.add(p1)
        left = MB::Geometry::Delaunay::Hull.new([p1, p2])

        p3 = MB::Geometry::Delaunay::Point.new(1, -1)
        p4 = MB::Geometry::Delaunay::Point.new(1, 1)
        p3.add(p4)
        p4.add(p3)
        right = MB::Geometry::Delaunay::Hull.new([p3, p4])

        tangents = left.tangents(right)
        expect(tangents).to eq([[p1, p3], [p1, p4]])
      end

      it 'returns the correct tangents for two vertical line segments' do
        p1 = MB::Geometry::Delaunay::Point.new(-1, 0)
        p2 = MB::Geometry::Delaunay::Point.new(-1, 1)
        p1.add(p2)
        p2.add(p1)
        left = MB::Geometry::Delaunay::Hull.new([p1, p2])

        p3 = MB::Geometry::Delaunay::Point.new(1, 0)
        p4 = MB::Geometry::Delaunay::Point.new(1, 1)
        p3.add(p4)
        p4.add(p3)
        right = MB::Geometry::Delaunay::Hull.new([p3, p4])

        tangents = left.tangents(right)
        expect(tangents).to eq([[p1, p3], [p2, p4]])
      end

      it 'returns the correct tangents for two tilted line segments' do
        p1 = MB::Geometry::Delaunay::Point.new(-1, 0)
        p2 = MB::Geometry::Delaunay::Point.new(-0.9, 1)
        p1.add(p2)
        p2.add(p1)
        left = MB::Geometry::Delaunay::Hull.new([p1, p2])

        p3 = MB::Geometry::Delaunay::Point.new(1, 0)
        p4 = MB::Geometry::Delaunay::Point.new(0.9, 1)
        p3.add(p4)
        p4.add(p3)
        right = MB::Geometry::Delaunay::Hull.new([p3, p4])

        tangents = left.tangents(right)
        expect(tangents).to eq([[p1, p3], [p2, p4]])
      end

      it 'returns the correct tangents for two single points' do
        p1 = MB::Geometry::Delaunay::Point.new(-2, -1)
        left = MB::Geometry::Delaunay::Hull.new([p1])

        p2 = MB::Geometry::Delaunay::Point.new(2, 1)
        right = MB::Geometry::Delaunay::Hull.new([p2])

        tangents = left.tangents(right)
        expect(tangents).to eq([[p1, p2], [p1, p2]])
      end

      it 'returns the correct tangents for two side-by-side upright triangles' do
        p1 = MB::Geometry::Delaunay::Point.new(-3, -1)
        p2 = MB::Geometry::Delaunay::Point.new(-1, -1)
        p3 = MB::Geometry::Delaunay::Point.new(-2, 1)
        p1.add(p2)
        p2.add(p3)
        p3.add(p1)
        p1.add(p3)
        p3.add(p2)
        p2.add(p1)
        left = MB::Geometry::Delaunay::Hull.new([p1, p3, p2])

        p4 = MB::Geometry::Delaunay::Point.new(1, -1)
        p5 = MB::Geometry::Delaunay::Point.new(3, -1)
        p6 = MB::Geometry::Delaunay::Point.new(2, 1)
        p4.add(p5)
        p5.add(p6)
        p6.add(p4)
        p4.add(p6)
        p6.add(p5)
        p5.add(p4)
        right = MB::Geometry::Delaunay::Hull.new([p4, p6, p5])

        tangents = left.tangents(right)
        expect(tangents).to eq([[p2, p4], [p3, p6]])
      end

      it 'returns the correct tangents for two side-by-side triangles of opposite orientation' do
        p1 = MB::Geometry::Delaunay::Point.new(-3, 1)
        p2 = MB::Geometry::Delaunay::Point.new(-1, 1)
        p3 = MB::Geometry::Delaunay::Point.new(-2, -1)
        p1.add(p3)
        p3.add(p2)
        p2.add(p1)
        p3.add(p1)
        p2.add(p3)
        p1.add(p2)
        left = MB::Geometry::Delaunay::Hull.new([p1, p3, p2])

        p4 = MB::Geometry::Delaunay::Point.new(1, -1)
        p5 = MB::Geometry::Delaunay::Point.new(3, -1)
        p6 = MB::Geometry::Delaunay::Point.new(2, 1)
        p4.add(p5)
        p5.add(p6)
        p6.add(p4)
        p4.add(p6)
        p6.add(p5)
        p5.add(p4)
        right = MB::Geometry::Delaunay::Hull.new([p4, p6, p5])

        tangents = left.tangents(right)
        expect(tangents).to eq([[p3, p4], [p2, p6]])
      end
    end
  end

  describe(MB::Geometry::Delaunay::Point) do
    let(:p0) { MB::Geometry::Delaunay::Point.new(0, -1) }
    let(:p1) { MB::Geometry::Delaunay::Point.new(0, 0) }
    let(:p2) { MB::Geometry::Delaunay::Point.new(0, 1) }
    let(:p3) { MB::Geometry::Delaunay::Point.new(-1, 0) }
    let(:p4) { MB::Geometry::Delaunay::Point.new(-1, 1) }
    let(:p5) { MB::Geometry::Delaunay::Point.new(-1, -1) }
    let(:p6) { MB::Geometry::Delaunay::Point.new(1, 0) }
    let(:p7) { MB::Geometry::Delaunay::Point.new(1, 1) }
    let(:p8) { MB::Geometry::Delaunay::Point.new(1, -1) }
    let(:p9) { MB::Geometry::Delaunay::Point.new(2, 2) }
    let(:p10) { MB::Geometry::Delaunay::Point.new(0, 2) }
    let(:p11) { MB::Geometry::Delaunay::Point.new(2, 1) }
    let(:p12) { MB::Geometry::Delaunay::Point.new(1, 2) }

    let(:ccw) {
      [p2, p4, p3, p5, p0, p8, p6, p11, p7, p12]
    }

    pending '#first'
    pending '#clockwise'
    pending '#counterclockwise'

    describe '#add' do
      cases = {
        counterclockwise: -> { ccw },
        counterclockwise_rotated: -> { ccw.rotate(4) },
        clockwise: -> { ccw.reverse },
        clockwise_rotated: -> { ccw.reverse.rotate(4) },
        left_to_right: -> { ccw.sort },
        right_to_left: -> { ccw.sort.reverse },
        bottom_to_top: -> { ccw.sort_by { |p| [p.y, p.x] } },
        top_to_bottom: -> { ccw.sort_by { |p| [-p.y, p.x] } },
        random: -> { ccw.shuffle(random: Random.new(RSpec.configuration.seed)) }
      }

      cases.each do |name, pts|
        it "can add points around the origin in #{name.to_s.gsub('_', ' ')} order" do
          points = instance_exec(&pts)

          points.each_with_index do |p, idx|
            p1.add(p)
          end

          ccw.each_with_index do |p, idx|
            p2 = ccw[(idx + 1) % ccw.length]
            begin
              expect(p1.counterclockwise(p)).to eq(p2)
            rescue Exception => e # XXX
              puts e
              require 'pry-byebug'; binding.pry
              raise
            end
          end

          # TODO: Verify #first behaves correctly for convex hull navigation
        end
      end

      it 'raises an error when adding an identical point to itself' do
        pending 'This condition was removed for performance reasons'
        expect { p2.add(MB::Geometry::Delaunay::Point.new(p2.x, p2.y)) }.to raise_error(/identical/)
      end

      it 'does not raise an error when adding a collinear point in the opposite direction' do
        p1.add(p7)
        expect { p1.add(p5) }.not_to raise_error

        expect(p1.clockwise(p7)).to eq(p5)
        expect(p1.clockwise(p5)).to eq(p7)
      end

      it 'raises an error when adding a point collinear with another neighbor in the same direction' do
        pending 'This check was removed with @cw and @ccw; it would be an expensive check'

        p1.add(p7)
        expect { p1.add(p9) }.to raise_error(/direction/)

        p1.add(p10)
        expect { p1.add(p2) }.to raise_error(/direction/)
      end
    end

    describe '#remove' do
      it 'rejoins adjacent neighbors' do
        p1.add(p2)
        p1.add(p4)
        p1.add(p3)

        expect(p1.counterclockwise(p2)).to eq(p4)
        expect(p1.clockwise(p2)).to eq(p3)

        p1.remove(p4)
        expect(p1.counterclockwise(p2)).to eq(p3)
        expect(p1.clockwise(p2)).to eq(p3)

        p1.remove(p2)
        expect(p1.counterclockwise(p3)).to eq(p3)
        expect(p1.clockwise(p3)).to eq(p3)
      end
    end

    describe '#cross' do
      it 'returns positive for points to the left of a segment' do
        expect(p3.cross(p1, p2)).to be > 0
        expect(p4.cross(p1, p2)).to be > 0
        expect(p5.cross(p1, p2)).to be > 0
        expect(p6.cross(p2, p1)).to be > 0
        expect(p7.cross(p2, p1)).to be > 0
        expect(p8.cross(p2, p1)).to be > 0
      end

      it 'returns zero for points collinear with a segment' do
        expect(p9.cross(p1, p7)).to eq(0)
        expect(p5.cross(p1, p7)).to eq(0)
      end

      it 'returns negative for points to the right of a segment' do
        expect(p3.cross(p1, p0)).to be < 0
        expect(p4.cross(p1, p0)).to be < 0
        expect(p5.cross(p1, p0)).to be < 0
        expect(p6.cross(p0, p1)).to be < 0
        expect(p7.cross(p0, p1)).to be < 0
        expect(p8.cross(p0, p1)).to be < 0
      end
    end

    describe '#left_of?' do
      it 'returns true for points to the right' do
        p3 = MB::Geometry::Delaunay::Point.new(2, 1)
        expect(p3.left_of?(p1, p7)).to eq(false)
      end

      it 'returns false for collinear points' do
        expect(p9.left_of?(p1, p7)).to eq(false)
      end

      it 'returns false for points to the left' do
        expect(p10.left_of?(p1, p7)).to eq(true)
      end
    end

    describe '#right_of?' do
      it 'returns true for points to the right' do
        expect(p11.right_of?(p1, p7)).to eq(true)
      end

      it 'returns false for collinear points' do
        expect(p9.right_of?(p1, p7)).to eq(false)
      end

      it 'returns false for points to the left' do
        expect(p10.right_of?(p1, p7)).to eq(false)
      end
    end
  end

  let (:trivial3) {
    MB::Geometry::Delaunay.new([
      [-1, -1],
      [1, -1],
      [0, 1]
    ])
  }

  let (:trivial4) {
    MB::Geometry::Delaunay.new([
      [-1, -1],
      [1, -1],
      [0.5, 0],
      [1, 1]
    ])
  }

  describe '#points' do
    it 'returns points in original order' do
      expect(trivial3.points.map { |p| [p.x, p.y] }).to eq([
        [-1, -1],
        [1, -1],
        [0, 1],
      ])

      expect(trivial4.points.map { |p| [p.x, p.y] }).to eq([
        [-1, -1],
        [1, -1],
        [0.5, 0],
        [1, 1],
      ])
    end
  end

  describe '#sorted_points' do
    it 'returns points in sorted order' do
      expect(trivial3.sorted_points.map { |p| [p.x, p.y] }).to eq([
        [-1, -1],
        [0, 1],
        [1, -1],
      ])

      expect(trivial4.sorted_points.map { |p| [p.x, p.y] }).to eq([
        [-1, -1],
        [0.5, 0],
        [1, -1],
        [1, 1],
      ])
    end
  end

  describe '#triangulate' do
    it 'produces a valid triangulation for three trivial input points' do
      expect(trivial3.sorted_points[0].first).to eq(trivial3.sorted_points[2])
      expect(trivial3.sorted_points[2].first).to eq(trivial3.sorted_points[1])
      expect(trivial3.sorted_points[1].first).to eq(trivial3.sorted_points[0])

      expect(trivial3.sorted_points[0].neighbors.sort).to eq([
        trivial3.sorted_points[1], trivial3.sorted_points[2]
      ])
      expect(trivial3.sorted_points[1].neighbors.sort).to eq([
        trivial3.sorted_points[0], trivial3.sorted_points[2]
      ])
      expect(trivial3.sorted_points[2].neighbors.sort).to eq([
        trivial3.sorted_points[0], trivial3.sorted_points[1]
      ])
    end

    it 'produces a valid triangulation for four trivial input points' do
      # Expected values from fft_experiment's Geometry::Voronoi class
      # v.cells.sort_by(&:point).map { |c| [ c.point, c.neighbors.map(&:point).sort ] }.to_h
      expected = {
        [-1, -1] => [[0.5, 0], [1, -1],  [1, 1]],
        [0.5, 0] => [[-1, -1], [1, -1],  [1, 1]],
        [1, -1]  => [[-1, -1], [0.5, 0], [1, 1]],
        [1, 1]   => [[-1, -1], [0.5, 0], [1, -1]]
      }

      actual = trivial4.points.map { |p| [ [p.x, p.y], p.neighbors.sort.map { |n| [n.x, n.y] } ] }.to_h

      expect(actual).to eq(expected)
    end
  end

  pending 'difficult/pathological cases'
  pending 'a horizontal line'
  pending 'a vertical line'
  pending 'alternating sequences of N horizontal and vertical groups'
  pending 'sequences of spaced horizontal groups'
  pending 'sequences of spaced vertical groups'
  pending 'regular polygons (circular)'
  pending 'symmetric reflections'
  pending 'regular polygons with a single central point'
  pending 'nested polygons'
  pending 'very tall skinny triangles'
  pending 'very wide skinny triangles'
  pending 'regular square and hexagonal grids'
end
