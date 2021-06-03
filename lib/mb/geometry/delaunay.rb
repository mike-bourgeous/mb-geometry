# Switches between fast version and debuggable/visualizable version of the
# pure-Ruby Delaunay triangulation algorithm.
if ENV['DELAUNAY_DEBUG'] || (defined?($delaunay_debug) && $delaunay_debug)
  $delaunay_debug = true
  require_relative 'delaunay_debug'
  MB::Geometry::Delaunay = MB::Geometry::DelaunayDebug
else
  $delaunay_debug = false
  require_relative 'delaunay_debug'
  require_relative 'delaunay_fast'
end
