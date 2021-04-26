RSpec.describe(MB::Geometry::VoronoiAnimator) do
  let(:points0) {
    [[0, 0], [1, 0], [1, 1]]
  }

  let(:points1) {
    [[1, 2], [-1, 1], [0, -1]]
  }

  let(:v0) {
    MB::Geometry::Voronoi.new(points0)
  }

  let(:anim0) {
    MB::Geometry::VoronoiAnimator.new(v0)
  }

  it 'can be constructed' do
    expect(anim0).to respond_to(:update)
  end

  describe '#update' do
    it 'updates animations' do
      expect(v0.cells.map(&:point)).to eq(points0)

      anim0.spin
      anim0.bounce

      10.times do
        expect(anim0.update).to eq(true)
      end

      expect(v0.cells.map(&:point)).not_to eq(points0)
    end
  end

  describe '#transition' do
    it 'can replace one set of points with another' do
      expect(v0.cells.map(&:point)).to eq(points0)
      expect(v0.cells.map(&:point)).not_to eq(points1)

      anim0.transition(points1, 30)

      15.times do
        expect(anim0.update).to eq(true)
      end

      expect(v0.cells.map(&:point)).not_to eq(points0)
      expect(v0.cells.map(&:point)).not_to eq(points1)

      15.times do
        expect(anim0.update).to eq(true)
      end

      expect(anim0.update).not_to eq(true)

      expect(v0.cells.map(&:point)).not_to eq(points0)
      expect(v0.cells.map(&:point)).to eq(points1)
    end

    pending 'can keep old animators'
    pending 'can remove old animators'

    pending 'can add points'
    pending 'can remove points'
  end
end
