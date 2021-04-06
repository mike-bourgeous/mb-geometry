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

    describe '#add' do
      it 'can add points around the origin in counterclockwise order' do
        p1.add(p2)
        p1.add(p4)
        p1.add(p3)
        p1.add(p5)
        p1.add(p0)
        p1.add(p8)
        p1.add(p6)
        p1.add(p11)
        p1.add(p7)

        expect(p1.counterclockwise(p2)).to eq(p4)
        expect(p1.counterclockwise(p4)).to eq(p3)
        expect(p1.counterclockwise(p3)).to eq(p5)
        expect(p1.counterclockwise(p5)).to eq(p0)
        expect(p1.counterclockwise(p0)).to eq(p8)
        expect(p1.counterclockwise(p8)).to eq(p6)
        expect(p1.counterclockwise(p6)).to eq(p11)
        expect(p1.counterclockwise(p11)).to eq(p7)
        expect(p1.counterclockwise(p7)).to eq(p2)

        expect(p1.clockwise(p4)).to eq(p2)
        expect(p1.clockwise(p3)).to eq(p4)
        expect(p1.clockwise(p5)).to eq(p3)
        expect(p1.clockwise(p0)).to eq(p5)
        expect(p1.clockwise(p8)).to eq(p0)
        expect(p1.clockwise(p6)).to eq(p8)
        expect(p1.clockwise(p11)).to eq(p6)
        expect(p1.clockwise(p7)).to eq(p11)
        expect(p1.clockwise(p2)).to eq(p7)
      end

      it 'raises an error when adding the same point' do
        expect { p2.add(MB::Delaunay::Point.new(p2.x, p2.y)) }.to raise_error(/identical/)
      end

      it 'raises an error when adding a point collinear with another neighbor' do
        p1.add(p7)
        expect { p1.add(p9) }.to raise_error(/collinear/)

        p1.add(p10)
        expect { p1.add(p2) }.to raise_error(/collinear/)
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
