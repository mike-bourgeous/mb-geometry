#!/usr/bin/env ruby

require 'bundler/setup'

require 'pry'
# Uncomment if debugging --- require 'pry-byebug'

require 'json'
require 'benchmark'

$:.unshift(File.join(__dir__, '..', 'lib'))
require 'mb/geometry'

if ARGV.length < 1 || ARGV.include?('--help')
  puts "\nUsage: \e[1m#{$0}\e[0m file_with_points_array.json (or .yml or .csv) [more files...]"
  puts "\nJSON or YML should be of the form [ { \"x\": 0, \"y\": 0 }, ... ]."
  puts "JSON and YML can also use the MB::Geometry::Generators.generate_from_file syntax."
  puts "CSV should be of the form [[ x, y, name ], [ x, y, name ] ... ].\n\n"
  exit 1
end

errors = {}

until ARGV.empty?
  puts "Triangulating \e[1;36m#{ARGV[0]}\e[0m"

  begin
    points = MB::Geometry::Generators.generate_from_file(ARGV[0])

    t = nil
    neighbors = nil
    triangles = nil

    elapsed_triangulate = Benchmark.realtime do
      if MB::Geometry::Voronoi::DEFAULT_ENGINE == :rubyvor
        t = MB::Geometry::Voronoi.new(points, sigfigs: 9, reflect: false)
        neighbors = t.cells.sort_by(&:point).map { |c| [ c.point, c.neighbors.map(&:point).sort ] }.to_h
      else
        t = MB::Geometry::Delaunay.new(points.map { |p| p.is_a?(Array) ? p : [p[:x], p[:y], p[:name]] })
        neighbors = t.points.sort.map { |p| [ [p.x, p.y], p.neighbors.sort.map { |n| [n.x, n.y] } ] }.to_h
      end
    end

    tris = nil
    elapsed_triangles = Benchmark.realtime do
      if MB::Geometry::Voronoi::DEFAULT_ENGINE == :rubyvor
        tris = t.delaunay_triangles.map { |tr|
          tr.points.sort.flatten
        }.sort
      else
        tris = t.triangles.map(&:sort).map { |tr| tr.map { |p| [p.x, p.y] }.flatten }.sort
      end
    end

    circumcircles = nil
    elapsed_circumcircles = Benchmark.realtime do
      circumcircles = tris.map { |t|
        raise "T is not 6" unless t.length == 6
        MB::Geometry.circumcircle(*t)
      }
    end

    puts "Triangulated \e[1m#{points.length}\e[0m points in \e[1m#{elapsed_triangulate}\e[0m seconds."
    puts "Generated \e[1m#{tris.length}\e[0m triangles in \e[1m#{elapsed_triangles}\e[0m seconds."
    puts "Calculated circumcircles in \e[1m#{elapsed_circumcircles}\e[0m seconds."

    puts MB::U.highlight(
      {
        neighbors: neighbors,
        triangles: tris,
      }
    )

    degenerates = circumcircles.select { |cc| cc.nil? || cc.any?(&:nil?) }
    raise "There are #{degenerates.count} degenerate triangles out of #{tris.count}" unless degenerates.empty?
  rescue => e
    puts "\e[31mError triangulating: \e[1m#{e}\n\t#{e.backtrace.join("\n\t")}\e[0m"

    errors[ARGV[0]] = e.message || e.to_s
  end

  ARGV.shift
end

if errors.any?
  STDERR.puts "\n\n\e[1mErrors:\e[0m"
  errors.each do |filename, error|
    STDERR.puts "  \e[1;36m#{filename}\e[0m => \e[31m#{error}"
  end
  exit 1
end
