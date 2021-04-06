RSpec.describe(MB::Delaunay) do
  describe(MB::Delaunay::Hull) do
    describe '#tangents' do
      it 'can join two line segments' do
        p1 = MB::Delaunay::Point.new(-1, 0)
        p2 = MB::Delaunay::Point.new(-0.9, 1)
        p1.add(p2)
        p2.add(p1)
        left = MB::Delaunay::Hull.new([p1, p2])

        p3 = MB::Delaunay::Point.new(1, 0)
        p4 = MB::Delaunay::Point.new(0.9, 1)
        p3.add(p4)
        p4.add(p3)
        right = MB::Delaunay::Hull.new([p3, p4])

        tangents = left.tangents(right)
        expect(tangents).to eq([[p1, p3], [p2, p4]])
      end
    end
  end

  describe(MB::Delaunay::Point) do
    let(:p0) { MB::Delaunay::Point.new(0, -1) }
    let(:p1) { MB::Delaunay::Point.new(0, 0) }
    let(:p2) { MB::Delaunay::Point.new(0, 1) }
    let(:p3) { MB::Delaunay::Point.new(-1, 0) }
    let(:p4) { MB::Delaunay::Point.new(-1, 1) }
    let(:p5) { MB::Delaunay::Point.new(-1, -1) }
    let(:p6) { MB::Delaunay::Point.new(1, 0) }
    let(:p7) { MB::Delaunay::Point.new(1, 1) }
    let(:p8) { MB::Delaunay::Point.new(1, -1) }
    let(:p9) { MB::Delaunay::Point.new(2, 2) }
    let(:p10) { MB::Delaunay::Point.new(0, 2) }
    let(:p11) { MB::Delaunay::Point.new(2, 1) }
    let(:p12) { MB::Delaunay::Point.new(1, 2) }

    let(:ccw) {
      [p2, p4, p3, p5, p0, p8, p6, p11, p7, p12]
    }

    pending '#first'
    pending '#clockwise'
    pending '#counterclockwise'
    pending '#remove'

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

          points.each do |p|
            p1.add(p)
          end

          ccw.each_with_index do |p, idx|
            p2 = ccw[(idx + 1) % ccw.length]
            expect(p1.counterclockwise(p)).to eq(p2)
          end

          # TODO: Verify #first behaves correctly for convex hull navigation
        end
      end

      it 'raises an error when adding an identical point to itself' do
        expect { p2.add(MB::Delaunay::Point.new(p2.x, p2.y)) }.to raise_error(/identical/)
      end

      it 'does not raise an error when adding a collinear point in the opposite direction' do
        p1.add(p7)
        expect { p1.add(p5) }.not_to raise_error

        expect(p1.clockwise(p7)).to eq(p5)
        expect(p1.clockwise(p5)).to eq(p7)
      end

      it 'raises an error when adding a point collinear with another neighbor in the same direction' do
        p1.add(p7)
        expect { p1.add(p9) }.to raise_error(/direction/)

        p1.add(p10)
        expect { p1.add(p2) }.to raise_error(/direction/)
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
        p3 = MB::Delaunay::Point.new(2, 1)
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
end
