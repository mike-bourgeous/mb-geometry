#!/usr/bin/env ruby

require 'bundler/setup'

require 'pry'
require 'pry-byebug'

require 'json'
require 'benchmark'

$:.unshift(File.join(__dir__, '..', 'lib'))
require 'mb/geometry/delaunay'

if ARGV.length < 1
  puts "\nUsage: \e[1m#{$0}\e[0m file_with_points_array.json (or .yml) [more files...]"
  puts "\nJSON or YML should be of the form [ { \"x\": 0, \"y\": 0 }, ... ]"
  exit 1
end

errors = {}

until ARGV.empty?
  # TODO: Merge with Geometry::Voronoi.generate_from_file when this project is merged with that one
  puts "Triangulating \e[1;36m#{ARGV[0]}\e[0m"

  begin
    case File.extname(ARGV[0])
    when '.json'
      points = JSON.parse(File.read(ARGV[0]), symbolize_names: true)

    when '.yaml', '.yml'
      points = YAML.load(File.read(ARGV[0]), symbolize_names: true)

    else
      raise "Unknown extension #{File.extname(ARGV[0])}"
    end

    points = points[:points] if points.is_a?(Hash)

    t = nil
    elapsed_triangulate = Benchmark.realtime do
      t = MB::Geometry::Delaunay.new(points.map { |p| p.is_a?(Array) ? p : [p[:x], p[:y], p[:name]] })
    end

    tris = nil
    elapsed_triangles = Benchmark.realtime do
      tris = t.triangles
    end

    circumcircles = tris.map { |t|
      MB::Geometry::Delaunay.circumcircle(t[0].x, t[0].y, t[1].x, t[1].y, t[2].x, t[2].y)
    }

    puts "Triangulated \e[1m#{points.length}\e[0m points in \e[1m#{elapsed_triangulate}\e[0m seconds (\e[1m#{elapsed_triangles}\e[0ms for \e[1m#{tris.length}\e[0m triangles)"

    # TODO: Use MB::Sound::U.highlight after refactoring utilities elsewhere
    puts Pry::ColorPrinter.pp(
      {
        neighbors: t.points.sort.map { |p| [ [p.x, p.y], p.neighbors.sort.map { |n| [n.x, n.y] } ] }.to_h,
        triangles: tris.map { |t| t = t.sort; [t[0].x, t[0].y, t[1].x, t[1].y, t[2].x, t[2].y] }.sort,
      },
      '',
      80
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
  puts "\n\n\e[1mErrors:\e[0m"
  errors.each do |filename, error|
    puts "  \e[1;36m#{filename}\e[0m => \e[31m#{error}"
  end
  exit 1
end
