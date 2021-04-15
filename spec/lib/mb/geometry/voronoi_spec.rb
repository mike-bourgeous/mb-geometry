require 'timeout'

RSpec.describe(MB::Geometry::Voronoi) do
  [:rubyvor, :delaunay].each do |engine|
    context "with the #{engine} engine" do
      it 'can be constructed' do
        v = MB::Geometry::Voronoi.new([[0, 0], [0, 1], [1, 0], [1, 1]], engine: engine)
        expect(v.delaunay_triangles).not_to eq(nil)
        expect(v.delaunay_triangles).not_to be_empty
      end

      it 'can move cells' do
        v = MB::Geometry::Voronoi.new([[0, 0], [0, 1], [1, 0], [1, 1]], engine: engine)
        v.cells[2].move(0.9, 0.1)
        expect(v.delaunay_triangles).not_to eq(nil)
        expect(v.delaunay_triangles).not_to be_empty
        expect(v.raw_points[2][0..1]).to eq([0.9, 0.1])
      end

      it 'can grow the bounding box when moving a cell' do
        v = MB::Geometry::Voronoi.new([
          [-0.75, 0],
          [0.0, 0.85],
          [0.75, 0],
          [-0.33, -0.57],
          [0.33, -0.57],
          [-0.12, -0.635],
          [0.12, -0.635]
        ], engine: engine)
        v.set_area_bounding_box(-1.0, -1.0, 1.0, 1.0)
        v.cells[0].move(-1.0, 0.0)
        v.cells[2].move(1.0, 0.0)
        expect(v.area_bounding_box.map { |v| v.round(3) }).to eq([-1.05, -1.0, 1.05, 1.0])
      end

      describe(MB::Geometry::Voronoi::Cell) do
        it 'can return triangles for a cell without reflection' do
          v = MB::Geometry::Voronoi.new([
            [-1, -1],
            [0, 1],
            [1, -1]
          ], reflect: false, engine: engine)

          expect(v.cells[0].delaunay_triangles.length).to eq(1)
        end

        it 'can return triangles for a cell with reflection' do
          v = MB::Geometry::Voronoi.new([
            [-1, -1],
            [0, 1],
            [1, -1]
          ], engine: engine)

          expect(v.cells[0].delaunay_triangles.length).to be > 1
        end

        it 'can return neighbors for a cell' do
          v = MB::Geometry::Voronoi.new([
            [-1, -1],
            [0, 1],
            [1, -1]
          ], engine: engine)
          v.set_area_bounding_box(-2, -2, 2, 2)

          expect(v.cells[0].neighbors.map(&:index).sort).to eq([1, 2])
          expect(v.cells[1].neighbors.map(&:index).sort).to eq([0, 2])
          expect(v.cells[2].neighbors.map(&:index).sort).to eq([0, 1])
        end
      end

      describe '#natural_neighbors' do
        it 'returns a Hash with neighbor weights and can be called more than once' do
          v = MB::Geometry::Voronoi.new(MB::Geometry::Generators.regular_polygon(7, 0.8), engine: engine)
          Timeout.timeout(5) do # Timeout ensures tests abort if there is an infinite loop
            nn = v.natural_neighbors(0.3, 0.5)
            expect(nn).to be_a(Hash)
            expect(nn).to include(:weights)
          end

          Timeout.timeout(5) do
            v.set_area_bounding_box(-1, -1, 1, 1)
            nn = v.natural_neighbors(-0.1, 0.1)
            expect(nn).to be_a(Hash)
            expect(nn).to include(:weights)
          end
        end
      end

      describe '#cells' do
        let(:v) { MB::Geometry::Voronoi.new(MB::Geometry::Generators.regular_polygon(7, 0.8), engine: engine) }

        it 'can select cells within a range' do
          expect(v.cells(1..3).map(&:index)).to eq([1, 2, 3])
          expect(v.cells(1...3).map(&:index)).to eq([1, 2])
          expect(v.cells(2..4).map(&:index)).to eq([2, 3, 4])
          expect(v.cells(2...2).map(&:index)).to eq([])
        end

        it 'can select cells from an array of Cells' do
          expect(v.cells([v.cells[0], v.cells[2]]).map(&:index)).to eq([0, 2])
        end

        it 'can select cells from an array of cell indices' do
          expect(v.cells([1, 5, 6]).map(&:index)).to eq([1, 5, 6])
          expect(v.cells([1, 10, 100]).map(&:index)).to eq([1])
        end

        it 'can select cells from an array with ranges and indices' do
          expect(v.cells([v.cells[0], 2..4, 1, 6..36]).map(&:index)).to eq([0, 2, 3, 4, 1, 6])
        end
      end

      describe '#anneal' do
        let(:v) {
          MB::Geometry::Voronoi.new(
            MB::Geometry::Generators.generate(
              generator: :random,
              count: 11,
              xmin: -0.75,
              xmax: 0.75,
              ymin: -0.75,
              ymax: 0.75
            )
          )
        }

        it 'does not crash' do
          expect { v.anneal }.not_to raise_exception
        end

        pending 'with scale false'
        pending 'with scale true'
        pending 'with scale nil and no user bounding box'
        pending 'with scale nil and a user bounding box'
      end

      pending 'TODO: add other Voronoi tests'
    end
  end
end
