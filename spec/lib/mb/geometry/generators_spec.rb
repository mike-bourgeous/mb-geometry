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

  pending '.random_points'
  pending '.generate'
  pending '.generate_from_file'
end
