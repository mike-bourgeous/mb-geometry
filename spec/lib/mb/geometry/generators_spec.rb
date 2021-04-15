RSpec.describe(MB::Geometry::Generators) do
  describe '.regular_polygon' do
    it 'returns an area approaching PI for a very large number of sides' do
      expect(MB::Geometry.polygon_area(MB::Geometry::Generators.regular_polygon(1000, 1.0)).round(4)).to eq(Math::PI.round(4))
    end

    it 'returns an area of 1 for a unit square regardless of rotation' do
      expect(MB::Geometry.polygon_area(MB::Geometry::Generators.regular_polygon(4, Math.sqrt(2) / 2)).round(4)).to eq(1.0)
      expect(MB::Geometry.polygon_area(MB::Geometry::Generators.regular_polygon(4, Math.sqrt(2) / 2, rotation: 45.degrees)).round(4)).to eq(1.0)
    end

    it 'returns the expected number of points' do
      for sides in 3..10
        expect(MB::Geometry::Generators.regular_polygon(sides, 1.0).length).to eq(sides)
      end
    end

    it 'can rotate the polygon' do
      diamond = MB::Geometry::Generators.regular_polygon(4, Math.sqrt(2) / 2)
      expect(MB::M.round(diamond[0], 4)).to eq(MB::M.round([Math.sqrt(2) / 2, 0], 4))

      square = MB::Geometry::Generators.regular_polygon(4, Math.sqrt(2) / 2, rotation: 45.degrees)
      expect(MB::M.round(square[0], 4)).to eq([0.5, 0.5])
    end
  end

  describe '.random_points' do
    it 'returns the correct number of points' do
      for count in (0..100).step(5)
        expect(MB::Geometry::Generators.random_points(count).length).to eq(count)
      end
    end

    it 'has a range of -1 to 1 by default' do
      points = MB::Geometry::Generators.random_points(10000, random: Random.new(0))
      x, y = points.transpose
      expect(x.min.round(2)).to eq(-1)
      expect(x.max.round(2)).to eq(1)
      expect(y.min.round(2)).to eq(-1)
      expect(y.max.round(2)).to eq(1)

      expect((x.sum / x.length).round(1)).to eq(0)
      expect((y.sum / y.length).round(1)).to eq(0)
    end

    it 'can use a different range' do
      points = MB::Geometry::Generators.random_points(10000, xmin: 2.0, xmax: 7.0, ymin: 3.0, ymax: 5.0, random: Random.new(0))

      expect(points.flatten.all?(Integer)).to eq(false)

      x, y = points.transpose
      expect(x.min.round(2)).to eq(2)
      expect(x.max.round(2)).to eq(7)
      expect(y.min.round(2)).to eq(3)
      expect(y.max.round(2)).to eq(5)

      expect((x.sum / x.length).round(1)).to eq(4.5)
      expect((y.sum / y.length).round(1)).to eq(4)
    end

    it 'can generate integer-only points if given integer ranges' do
      points = MB::Geometry::Generators.random_points(10000, xmin: -100, xmax: 100, ymin: -100, ymax: 100, random: Random.new(0))
      expect(points.flatten.all?(Integer)).to eq(true)
    end
  end

  pending '.generate'
  pending '.generate_from_file'
end
