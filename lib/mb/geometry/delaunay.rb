if ENV['DELAUNAY_DEBUG'] || (defined?($delaunay_debug) && $delaunay_debug)
  $delaunay_debug = true
  require_relative 'delaunay_debug'
else
  require_relative 'delaunay_fast'
end
