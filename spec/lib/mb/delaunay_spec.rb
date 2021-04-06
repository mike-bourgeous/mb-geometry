RSpec.describe(MB::Delaunay) do
  describe(MB::Delaunay::Point) do
    describe '#cross' do
      it 'returns positive for points to the left of a segment' do
        p1 = MB::Delaunay::Point.new(0, 0)
        p2 = MB::Delaunay::Point.new(0, 1)

        p3 = MB::Delaunay::Point.new(-1, 0)
        expect(p3.cross(p1, p2)).to be > 0

        p4 = MB::Delaunay::Point.new(-1, 1)
        expect(p4.cross(p1, p2)).to be > 0

        p5 = MB::Delaunay::Point.new(-1, -1)
        expect(p5.cross(p1, p2)).to be > 0

        p6 = MB::Delaunay::Point.new(1, 0)
        expect(p6.cross(p2, p1)).to be > 0

        p7 = MB::Delaunay::Point.new(1, 1)
        expect(p7.cross(p2, p1)).to be > 0

        p8 = MB::Delaunay::Point.new(1, -1)
        expect(p8.cross(p2, p1)).to be > 0
      end

      it 'returns zero for points collinear with a segment' do
        p1 = MB::Delaunay::Point.new(0, 0)
        p2 = MB::Delaunay::Point.new(1, 1)

        p3 = MB::Delaunay::Point.new(2, 2)
        expect(p3.cross(p1, p2)).to eq(0)

        p4 = MB::Delaunay::Point.new(-1, -1)
        expect(p4.cross(p1, p2)).to eq(0)
      end

      it 'returns negative for points to the right of a segment' do
        p1 = MB::Delaunay::Point.new(0, 0)
        p2 = MB::Delaunay::Point.new(0, -1)

        p3 = MB::Delaunay::Point.new(-1, 0)
        expect(p3.cross(p1, p2)).to be < 0

        p4 = MB::Delaunay::Point.new(-1, 1)
        expect(p4.cross(p1, p2)).to be < 0

        p5 = MB::Delaunay::Point.new(-1, -1)
        expect(p5.cross(p1, p2)).to be < 0

        p6 = MB::Delaunay::Point.new(1, 0)
        expect(p6.cross(p2, p1)).to be < 0

        p7 = MB::Delaunay::Point.new(1, 1)
        expect(p7.cross(p2, p1)).to be < 0

        p8 = MB::Delaunay::Point.new(1, -1)
        expect(p8.cross(p2, p1)).to be < 0
      end
    end

    describe '#left_of?' do
      it 'returns true for points to the right' do
        p1 = MB::Delaunay::Point.new(0, 0)
        p2 = MB::Delaunay::Point.new(1, 1)

        p3 = MB::Delaunay::Point.new(2, 1)
        expect(p3.left_of?(p1, p2)).to eq(false)
      end

      it 'returns false for collinear points' do
        p1 = MB::Delaunay::Point.new(0, 0)
        p2 = MB::Delaunay::Point.new(1, 1)

        p3 = MB::Delaunay::Point.new(2, 2)
        expect(p3.left_of?(p1, p2)).to eq(false)
      end

      it 'returns false for points to the left' do
        p1 = MB::Delaunay::Point.new(0, 0)
        p2 = MB::Delaunay::Point.new(1, 1)

        p3 = MB::Delaunay::Point.new(0, 2)
        expect(p3.left_of?(p1, p2)).to eq(true)
      end
    end

    describe '#right_of?' do
      it 'returns true for points to the right' do
        p1 = MB::Delaunay::Point.new(0, 0)
        p2 = MB::Delaunay::Point.new(1, 1)

        p3 = MB::Delaunay::Point.new(2, 1)
        expect(p3.right_of?(p1, p2)).to eq(true)
      end

      it 'returns false for collinear points' do
        p1 = MB::Delaunay::Point.new(0, 0)
        p2 = MB::Delaunay::Point.new(1, 1)

        p3 = MB::Delaunay::Point.new(2, 2)
        expect(p3.right_of?(p1, p2)).to eq(false)
      end

      it 'returns false for points to the left' do
        p1 = MB::Delaunay::Point.new(0, 0)
        p2 = MB::Delaunay::Point.new(1, 1)

        p3 = MB::Delaunay::Point.new(0, 2)
        expect(p3.right_of?(p1, p2)).to eq(false)
      end
    end
  end
end
