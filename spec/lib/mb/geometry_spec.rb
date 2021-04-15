RSpec.describe MB::Geometry do
  describe '.line_intersection' do
    it 'can intersect horizontal with vertical lines' do
      expect(MB::Geometry.line_intersection([0, 1, 100], [1, 0, 200])).to eq([200, 100])
      expect(MB::Geometry.line_intersection([0, 1, 100], [1, 0, -200])).to eq([-200, 100])
    end

    it 'returns nil for parallel lines' do
      expect(MB::Geometry.line_intersection([1, 1, 10], [1, 1, 20])).to eq(nil)
    end

    it 'returns nil for coincident lines' do
      expect(MB::Geometry.line_intersection([1, 1, 10], [1, 1, 10])).to eq(nil)
      expect(MB::Geometry.line_intersection([1, 1, 10], [2, 2, 20])).to eq(nil)
    end

    it 'can intersect oblique lines with vertical lines' do
      expect(MB::Geometry.line_intersection([-1, 1, 0], [1, 0, 50])).to eq([50, 50])
      expect(MB::Geometry.line_intersection([-2, 1, 0], [1, 0, 50])).to eq([50, 100])
      expect(MB::Geometry.line_intersection([-2, 1, 1], [1, 0, 50])).to eq([50, 101])
    end

    it 'can intersect oblique lines with horizontal lines' do
      expect(MB::Geometry.line_intersection([0.5, 1, 0], [0, 1, 10])).to eq([-20, 10])
    end

    it 'can intersect oblique lines' do
      expect(MB::Geometry.line_intersection([0.5, 1, 0], [-1, 1, 0])).to eq([0, 0])
      expect(MB::Geometry.line_intersection([0.5, 1, 6], [-1, 1, 0])).to eq([4, 4])
    end
  end

  describe '.segment_intersection' do
    it 'can intersect perpendicular segments' do
      expect(MB::Geometry.segment_intersection([-1, -1, 1, 1], [1, -1, -1, 1])).to eq([0, 0])
    end

    it 'can intersect segments with one entirely within the other bounding box' do
      expect(MB::Geometry.segment_intersection([-10, -5, 10, 5], [0, -2, 4, 4])).to eq([2.0, 1.0])
      expect(MB::Geometry.segment_intersection([0, -2, 4, 4], [-10, -5, 10, 5])).to eq([2.0, 1.0])
      expect(MB::Geometry.segment_intersection([0, 5, 20, 15], [10, 8, 14, 14])).to eq([12.0, 11.0])
      expect(MB::Geometry.segment_intersection([10, 8, 14, 14], [0, 5, 20, 15])).to eq([12.0, 11.0])
    end

    it 'can intersect segments with one point above/below and one point within' do
      # Checking permutations of argument ordering
      expect(MB::Geometry.segment_intersection([2, 2, 8, 8], [5, 3, 7, 9])).to eq([6.0, 6.0])
      expect(MB::Geometry.segment_intersection([8, 8, 2, 2], [5, 3, 7, 9])).to eq([6.0, 6.0])
      expect(MB::Geometry.segment_intersection([5, 3, 7, 9], [8, 8, 2, 2])).to eq([6.0, 6.0])
      expect(MB::Geometry.segment_intersection([7, 9, 5, 3], [8, 8, 2, 2])).to eq([6.0, 6.0])
    end

    it 'can intersect segments with one point left/right and one point within' do
      expect(MB::Geometry.segment_intersection([2, 2, 8, 8], [3, 5, 9, 7])).to eq([6.0, 6.0])
      expect(MB::Geometry.segment_intersection([9, 7, 3, 5], [8, 8, 2, 2])).to eq([6.0, 6.0])
    end

    it 'treats a segment that ends along another segment as intersecting' do
      expect(MB::Geometry.segment_intersection([-1, -1, 1, 1], [0, 0, 1, 0])).to eq([0, 0])
      expect(MB::Geometry.segment_intersection([0, 0, 1, 0], [-1, -1, 1, 1])).to eq([0, 0])
      expect(MB::Geometry.segment_intersection([1, 0, 0, 0], [1, -1, -1, 1])).to eq([0, 0])
    end

    it 'treats segments that share an endpoint as intersecting' do
      expect(MB::Geometry.segment_intersection([-1, -1, 1, -1], [1, -1, 1, 1])).to eq([1, -1])
    end

    it 'returns nil for parallel segments' do
      expect(MB::Geometry.segment_intersection([1, 1, 2, 2], [2, 1, 3, 2])).to eq(nil)
    end

    it 'returns nil for non-intersecting segments' do
      expect(MB::Geometry.segment_intersection([1, 1, 2, 2], [2, 1, 2, 1.5])).to eq(nil)
    end
  end

  describe '.segment_to_line' do
    it 'can create vertical lines' do
      expect(MB::Geometry.segment_to_line(0, 1, 0, 2)).to eq([1, 0, 0])
      expect(MB::Geometry.segment_to_line(5, 1, 5, 2)).to eq([1, 0, 5])
    end

    it 'can create horizontal lines' do
      expect(MB::Geometry.segment_to_line(1, 0, 2, 0)).to eq([0, 1, 0])
      expect(MB::Geometry.segment_to_line(1, -5, 2, -5)).to eq([0, 1, -5])
    end

    it 'can create lines with positive slope' do
      a, b, c = MB::Geometry.segment_to_line(5, 5, 7, 6)
      expect(-a.to_f / b).to eq(0.5)
    end

    it 'can create lines with negative slope' do
      a, b, c = MB::Geometry.segment_to_line(5, 5, 7, 4)
      expect(-a.to_f / b).to eq(-0.5)
    end

    it 'raises an error for indistinct points' do
      expect { MB::Geometry.segment_to_line(1, 2, 1, 2) }.to raise_error(/distinct/)
    end
  end

  describe '.polygon_area' do
    it 'can calculate the area of a triangle' do
      expect(MB::Geometry.polygon_area([[-1, 0], [1, 0], [0, 1]])).to eq(1.0)
    end

    it 'can calculate the area of a square' do
      expect(MB::Geometry.polygon_area([[0, 0], [1, 0], [1, 1], [0, 1]])).to eq(1.0)
      expect(MB::Geometry.polygon_area([[-1, 0], [0, -1], [1, 0], [0, 1]])).to eq(2.0)
    end

    it 'returns a negative area for clockwise vertices' do
      expect(MB::Geometry.polygon_area([[0, 0], [0, 1], [1, 1], [1, 0]])).to eq(-1.0)
    end

    it 'returns zero for a degenerate polygon' do
      expect(MB::Geometry.polygon_area([[0, 0], [1, 1], [2, 2], [0, 0]])).to eq(0.0)
    end
  end

  describe '.bounding_box' do
    it 'can bound a single point' do
      expect(MB::Geometry.bounding_box([[5, 5]])).to eq([5, 5, 5, 5])
      expect(MB::Geometry.bounding_box([[-3, -12]])).to eq([-3, -12, -3, -12])
    end

    it 'can bound multiple points' do
      expect(MB::Geometry.bounding_box([[-1, -2], [1, 3], [5, 5], [4, -6]])).to eq([-1, -6, 5, 5])
    end

    it 'does not expand a single point box' do
      expect(MB::Geometry.bounding_box([[3, 3]], 1)).to eq([3, 3, 3, 3])
    end

    it 'can expand a multi-point box' do
      expect(MB::Geometry.bounding_box([[1, 1], [2, 2]], 2)).to eq([0, 0, 3, 3])
      expect(MB::Geometry.bounding_box([[1, 1], [2, 2]], 1)).to eq([0.5, 0.5, 2.5, 2.5])
    end
  end

  pending '.dot'
  pending '.clip_segment'
  pending '.regular_polygon'
  pending '.distance_to_line'
  pending '.perpendicular_bisector'
  pending '.circumcenter'
  pending '.circumcircle'
  pending '.centroid'
end
