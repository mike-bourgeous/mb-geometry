#!/usr/bin/env ruby

require 'bundler/setup'

require 'pry'
require 'pry-byebug'

require 'benchmark'

require 'json'

$:.unshift(File.join(__dir__, '..', 'lib'))
require 'mb/geometry'

random = Random.new(ENV['RANDOM_SEED']&.to_i || 0)

count = ARGV[0]&.to_i || 100
points = count.times.map {
  [random.rand(-1.0..1.0), random.rand(-1.0..1.0)]
}

v = nil
t = nil
neighbors = nil

begin
  puts "Benchmarking the \e[1m#{MB::Geometry::Voronoi::DEFAULT_ENGINE}\e[0m triangulation engine"

  elapsed = Benchmark.realtime do
    if MB::Geometry::Voronoi::DEFAULT_ENGINE == :rubyvor
      100.times do
        v = MB::Geometry::Voronoi.new(points, reflect: false)
        t = v.delaunay_triangles
      end

      neighbors = v.cells.sort_by(&:point).map { |c| [ c.point, c.neighbors.map(&:point).sort ] }.to_h
    else
      100.times do
        v = MB::Geometry::Delaunay.new(points)
        t = v.triangles
      end

      neighbors = v.points.sort.map { |p| [ [p.x, p.y], p.neighbors.sort.map { |n| [n.x, n.y] } ] }.to_h
    end
  end
rescue => e
  puts "\n\n\e[31mError in triangulation: \e[1m#{e}\e[0m"

  filename = File.join(__dir__, '..', 'test_data', Time.now.strftime("%Y-%m-%d_%H-%M-%S_bad_bench.json"))
  puts "Saving problematic points to \e[1m#{filename}\e[0m\n\n"

  File.write(filename, JSON.pretty_generate(points.sort.map { |p| { x: p[0], y: p[1] } }))

  raise
end

puts MB::U.highlight(neighbors, columns: 80)

puts "\n\e[1m#{elapsed}\e[0m seconds for \e[1m#{points.length}\e[0m points and \e[1m#{t.length}\e[0m triangles\n\n"
