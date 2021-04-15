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

  describe '.generate' do
    it 'can generate a polygon' do
      spec = {
        generator: :polygon,
        sides: 6,
        radius: 2.0
      }

      points = MB::Geometry::Generators.generate(spec)

      expect(points.length).to eq(6)
      expect(points[0].values_at(:x, :y)).to eq([2, 0])
    end

    it 'can generate random points' do
      spec = {
        generator: :random,
        count: 10000,
        xmin: -5.0,
        xmax: 3.0,
        ymin: -4.0,
        ymax: -1.0
      }

      points = MB::Geometry::Generators.generate(spec)

      expect(points.length).to eq(10000)

      x, y = points.map { |p| p.values_at(:x, :y) }.transpose

      expect(x.min.round(2)).to eq(-5)
      expect(x.max.round(2)).to eq(3)
      expect(y.min.round(2)).to eq(-4)
      expect(y.max.round(2)).to eq(-1)
    end

    it 'can use a random seed' do
      spec1 = {
        generator: :random,
        count: 10,
        seed: 1
      }

      spec2 = {
        generator: :random,
        count: 10,
        seed: 2
      }

      points_1a = MB::Geometry::Generators.generate(spec1)
      points_1b = MB::Geometry::Generators.generate(spec1)

      points_2a = MB::Geometry::Generators.generate(spec2)
      points_2b = MB::Geometry::Generators.generate(spec2)

      # Verify contents are the same but object IDs differ with the same seed
      expect(points_1a).to eq(points_1b)
      expect(points_1a).not_to equal(points_1b)

      expect(points_2a).to eq(points_2b)
      expect(points_2a).not_to equal(points_2b)

      # Verify contents differ when seeds differ
      expect(points_1a).not_to eq(points_2a)
    end

    it 'can mix different generators together and apply names and colors' do
      spec = {
        generator: :multi,
        generators: [
          {
            generator: :polygon,
            sides: 5,
          },
          {
            points: [[2, 2], [3, 5]]
          }
        ],
        names: ['A', 'B', 'C', 'D', 'E', 'F', 'G'],
        colors: [
          [1, 1, 1, 1],
          [0.5, 1.0, 0.5, 1.0],
        ],
      }

      points = MB::Geometry::Generators.generate(spec)
      expect(points.count).to eq(7)
      expect(points.last).to eq({x: 3, y: 5, name: 'G', color: [1, 1, 1, 1]})
    end

    describe ':anneal' do
      let(:plain_spec) {
        {
          generator: :random,
          count: 10,
          seed: 1,
        }
      }

      let(:annealed_spec) {
        {
          generator: :random,
          count: 10,
          seed: 1,
          anneal: 5,
        }
      }

      let(:plain_points) {
        MB::Geometry::Generators.generate(plain_spec)
      }

      let(:annealed_points) {
        MB::Geometry::Generators.generate(annealed_spec)
      }

      it 'can anneal points using the Voronoi partition' do
        pending 'Need to copy over the Voronoi code for this to work'

        expect(plain_points).not_to eq(annealed_points)
      end

      it 'preserves X and Y range' do
        pending 'Need to copy over the Voronoi code for this to work'

        x1, y1 = plain_points.map { |p| p.values_at(:x, :y) }.transpose
        x2, y2 = annealed_points.map { |p| p.values_at(:x, :y) }.transpose

        expect(x1.min.round(5)).to eq(x2.min.round(5))
        expect(x1.max.round(5)).to eq(x2.max.round(5))
        expect(y1.min.round(5)).to eq(y2.min.round(5))
        expect(y1.max.round(5)).to eq(y2.max.round(5))
      end
    end
  end

  describe '.generate_from_file' do
    it 'can load a .yml file' do
      file = File.expand_path('../../../../test_data/square.yml', __dir__)
      points = MB::Geometry::Generators.generate_from_file(file)
      expect(points.length).to eq(4)
      expect(points[0][:color]).to eq([0.9, 0.3, 0.1])
    end

    it 'can load a .json file' do
      file = File.expand_path('../../../../test_data/pentagon.json', __dir__)
      points = MB::Geometry::Generators.generate_from_file(file)
      expect(points.length).to eq(5)
      expect(points[0][:name]).to eq('P1')
    end

    it 'can load a .csv file' do
      file = File.expand_path('../../../../test_data/simple_csv_points.csv', __dir__)
      points = MB::Geometry::Generators.generate_from_file(file)
      expect(points.length).to eq(5)
      expect(points[0][:name]).to eq('A')
    end
  end
end
