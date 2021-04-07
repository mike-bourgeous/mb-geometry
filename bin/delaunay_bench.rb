#!/usr/bin/env ruby

require 'bundler/setup'

require 'pry'
require 'pry-byebug'

require 'benchmark'

$:.unshift(File.join(__dir__, '..', 'lib'))
require 'mb/delaunay'

random = Random.new(0)

count = ARGV[0]&.to_i || 100
points = count.times.map {
  [random.rand(-1.0..1.0), random.rand(-1.0..1.0)]
}

t = nil

elapsed = Benchmark.realtime do
  10.times do
    t = MB::Delaunay.new(points)
  end
end

puts Pry::ColorPrinter.pp(
  t.points.sort.map { |p| [ [p.x, p.y], p.neighbors.sort.map { |n| [n.x, n.y] } ] }.to_h,
  '',
  80
)

puts "\n\e[1m#{elapsed}\e[0m seconds\n\n"
