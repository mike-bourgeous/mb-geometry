RSpec.describe(MB::Geometry::VoronoiAnimator) do
  it 'can be constructed' do
    v = MB::Geometry::Voronoi.new([[0, 0], [1, 0], [1, 1]])
    anim = MB::Geometry::VoronoiAnimator.new(v)
    expect(anim).to respond_to(:update)
  end
end
