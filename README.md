# mb-geometry

[![Tests](https://github.com/mike-bourgeous/mb-geometry/actions/workflows/test.yml/badge.svg)](https://github.com/mike-bourgeous/mb-geometry/actions/workflows/test.yml)

Recreational Ruby tools for geometry.  This ranges from simple functions like
area calculation and line intersection, to Delaunay triangulation and Voronoi
partitions.  This is companion code to my [educational video series about code
and sound][0], and this code was [featured in a video about Voronoi diagrams
and Delaunay triangulations][8].  I've also [written more about this code on my
blog][6].

```bash
XRES=960 YRES=540 bin/voronoi_transitions.rb /tmp/polygon.gif \
    test_data/3gon.yml 30 60 \
    test_data/square.yml 30 60 \
    test_data/pentagon.json 30 60 \
    test_data/zero.csv 30 0
```

![Animation of Voronoi transitions](readme_images/polygon.gif)

You might also be interested in [mb-sound][1], [mb-math][2], and [mb-util][3].

This code is reasonably well-tested, but I recommend using it for non-critical
tasks like fun and offline graphics, and not for making important decisions or
mission-critical data modeling.

## Examples

Check out all of the scripts in `bin/`; they usually have a header comment
describing what they do.

### Video or GIF of Voronoi transitions

The `bin/voronoi_transitions.rb` script will turn a sequence of Voronoi
diagrams into an animation with smooth transitions.

See the documentation for `MB::Geometry::Generators.generate` in
`lib/mb/geometry/generators.rb` for the syntax of the Voronoi diagram file
format (.json, .yml, or .csv), with examples in `test_data/`.  Also check out
the `MB::Geometry::VoronoiAnimator` class.

#### Shuffling points

```bash
XRES=640 RANDOM_SEED=10 bin/voronoi_transitions.rb /tmp/shuffle.gif \
    test_data/lines.json 0 \
    __shuffle 60
```

![Shuffling Voronoi points](readme_images/shuffle.gif)

#### 60fps video transitions

```bash
XRES=960 YRES=540 bin/voronoi_transitions.rb /tmp/polygon.mp4 \
    test_data/3gon.yml 30 15 \
    test_data/square.yml 30 15 \
    test_data/pentagon.json 30 15 \
    test_data/zero.csv 30 0
```

![Output of the voronoi\_transitions.rb command](readme_images/mp4_creation.png)

https://user-images.githubusercontent.com/5015814/115095460-41428300-9ed6-11eb-800c-2c00307309f9.mp4

### Static SVG image from Voronoi diagram

From the shell:

```bash
bin/voronoi_to_svg.rb test_data/pentagon.json /tmp/pentagon.svg
```

From code:

```ruby
require 'mb-geometry'

# The Hash must be inside an Array to prevent it being interpreted as keyword args
# Rotation is in degrees
v = MB::Geometry::Voronoi.new([{ generator: :polygon, sides: 5, rotate: 30 }]) ; nil
v.save_svg('/tmp/pentagon_from_code.svg')

# You can save the Delaunay triangulation instead:
v.save_delaunay_svg('/tmp/pentagon_delaunay.svg')
```

### Voronoi diagram from image

You can generate a JSON points file for a Voronoi diagram from a PNG (or other)
image, then generate a pixel-art SVG from that (16x16 or smaller images
recommended):

```bash
bin/png_to_voronoi.rb image.png image.json
bin/voronoi_to_svg.rb image.json image.svg
```

| Input | Output |
| --- | --- |
| ![Smiley](readme_images/png_to_voronoi_example.png) | ![SVG Pixel Art Smiley](readme_images/png_to_voronoi_example.svg)


### Voronoi points file format

The `bin/triangulate.rb`, `bin/voronoi_to_svg.rb`, and
`bin/voronoi_transitions.rb` tools all use a common file format to describe a
Voronoi partition.  Any JSON, YAML, or CSV file that parses to an Array of X
and Y coordinates is supported.  There is also an abbreviated syntax for
generating polygons or random points.  The file format is documented below in
the [Voronoi points file format](#voronoi-points-file-format) section.  See
[MB::Geometry::Generators#generate\_from\_file][7] for more info.

#### Raw array of points

![Three simple points in a Voronoi diagram](readme_images/array.svg)

JSON:

```json
[
  [-1, 1],
  [1.5, -0.5],
  [-1, 0],
]
```

YML:

```yml
- [-1, 1]
- - 1.5  
  - -0.5
- [-1, 0]
```

CSV:

```csv
-1,1
1.5,-0.5
-1,0
```

#### Raw array of point hashes

Point hashes may include a name and a color for a point.

![Three points with custom colors](readme_images/hashes.svg)

JSON:

```json
[
  { "x": -1, "y": 1, "name": "A", "color": [0.1, 0.2, 0.5, 0.9] },
  { "x": 1.5, "y": -0.5, "name": "B", "color": [0.6, 0.2, 0.5, 0.9] },
  { "x": -1, "y": 0, "name": "C", "color": [0.3, 0.8, 0.4, 0.9] }
]
```

```bash
bin/voronoi_to_svg.rb /tmp/hashes.json /tmp/hashes.svg
```

#### Generators

See the source code and files under `test_data/` for details.  Generators
include `:random`, `:segment`, `:polygon`, `:grid`, `:points`, and `:multi`.

##### Random points

Colors and names may be specified in separate Arrays.  Colors will be reused in
a loop if there are more points than colors.

The `anneal` option controls how many times points are moved toward their
cell's center.  The `bounding_box` option controls the maximum space in which
the points may expand.  See `MB::Geometry::Voronoi#anneal`.

![Random points with a deterministic seed](readme_images/random_points.svg)

YML:

```yml
generator: :random
count: 10
seed: 3
anneal: 1
bounding_box: [-3, -2, 3, 2]
colors:
  - [0.1, 0.2, 0.5, 0.9]
  - [0.5, 0.3, 0.2, 0.9]
names:
  - "P0"
  - "P1"
  - "P2"
  - "P3"
  - "P4"
  - "P5"
  - "P6"
  - "P7"
  - "P8"
  - "P9"
```

```bash
LABELS=1 bin/voronoi_to_svg.rb /tmp/random_points.yml /tmp/random_points.svg
```

##### Multiple generators combined

![Voronoi diagram generated from the YML below](readme_images/multi.svg)

YML:

```yml
generator: :multi
generators:
  # Line segment generator
  - generator: :segment
    count: 5
    from: [-3, -0.1]
    to: [-2, -1]
  # Polygon generator
  - generator: :polygon
    sides: 7
    radius: 0.5
    rotate: 45
    clockwise: true
  # Random points generator
  - generator: :random
    count: 10
    seed: 3
    xmin: 1.5
    xmax: 3.25
    ymin: -1.5
    ymax: 1.5
    anneal: 1
  # Another segment
  - generator: :segment
    count: 5
    from: [-3, 0.1]
    to: [-2, 1]
```

### Delaunay triangulation

The Voronoi diagrams generated by this code are all derived from Delaunay
triangulation.  There are three backends for Delaunay triangulation that can be switched by
setting the `DELAUNAY_ENGINE` and `DELAUNAY_DEBUG` environment variables.

- `DELAUNAY_ENGINE=rubyvor` -- Uses the RubyVor Gem's C extension for Delaunay
  triangulation.  This is very fast, and the default.
- `DELAUNAY_ENGINE=delaunay` -- My pure Ruby implementation of Lee and
  Schacter's 1980 divide and conquer algorithm.  See `README-Delaunay.md` and
  `lib/mb/geometry/delaunay.rb` for more info.  This is reasonably fast.
- `DELAUNAY_ENGINE=delaunay_debug DELAUNAY_DEBUG=1` -- The same pure Ruby
  implementation, but with lots of debugging output and each step of the
  algorithm dumped to a .json file in /tmp (or the directory specified by
  the `JSON_DIR` environment variable, if set).  This is slow.

#### Pure Ruby algorithm

The `triangulate.rb` command prints each input point's neighbors and the final
list of triangles in Ruby Hash syntax.

```bash
DELAUNAY_ENGINE=delaunay bin/triangulate.rb test_data/square.yml
```

#### Rubyvor gem algorithm

```bash
DELAUNAY_ENGINE=rubyvor bin/triangulate.rb test_data/square.yml
```

### Simple geometric functions

See [`MB::Geometry`](blob/master/lib/mb/geometry.rb).

#### Area of a polygon

```ruby
MB::Geometry.polygon_area([[0, 0], [1, 0], [1, 1], [0, 1]])
# => 1.0
```

## Installation and usage

This project contains some useful programs of its own, or you can use it as a
Gem (with Git source) in your own projects.

### Standalone usage and development

First, install a Ruby version manager like RVM.  Using the system's Ruby is not
recommended -- that is only for applications that come with the system.  You
should follow the instructions from https://rvm.io, but here are the basics:

```bash
gpg2 --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
\curl -sSL https://get.rvm.io | bash -s stable
```

Next, install Ruby.  RVM binary rubies are still broken on Ubuntu 20.04.x, so
use the `--disable-binary` option if you are running Ubuntu 20.04.x.

```bash
rvm install --disable-binary 2.7.3
```

You can tell RVM to isolate all your projects and switch Ruby versions
automatically by creating `.ruby-version` and `.ruby-gemset` files (already
present in this project):

```bash
cd mb-geometry
cat .ruby-gemset
cat .ruby-version
```

Now install dependencies:

```bash
bundle install
```

You will also want ffmpeg if you want to make GIFs or videos:

```bash
# Debian/Ubuntu
sudo apt-get install ffmpeg

# macOS (might not be exactly right, but this is the gist)
brew install ffmpeg
```

### Using the project as a Gem

To use mb-geometry in your own Ruby projects, add this Git repo to your
`Gemfile` (plus the Git repos of other pre-release gems it depends on):

```ruby
# your-project/Gemfile
gem 'mb-geometry', git: 'https://github.com/mike-bourgeous/mb-geometry.git'
gem 'mb-math', git: 'https://github.com/mike-bourgeous/mb-math.git'
gem 'mb-util', git: 'https://github.com/mike-bourgeous/mb-util.git'
```

## Testing

Run `rspec`, or play with the included scripts under `bin/`.

## Contributing

Pull requests welcome, though development is focused specifically on the needs
of my video series.

## License

This project is released under a 2-clause BSD license.  See the LICENSE file.

## See also

### Dependencies

- [RubyVor][4]; unfortunately the homepage link is no longer valid, but the
  [RubyVor source code][5] is still available.

### References

See `README-Delaunay.md` for Delaunay tringulation references.


[0]: https://www.youtube.com/playlist?list=PLpRqC8LaADXnwve3e8gI239eDNRO3Nhya
[1]: https://github.com/mike-bourgeous/mb-sound
[2]: https://github.com/mike-bourgeous/mb-math
[3]: https://github.com/mike-bourgeous/mb-util
[4]: https://rubygems.org/gems/rubyvor
[5]: https://github.com/abscondment/rubyvor
[6]: https://blog.mikebourgeous.com/2021/04/18/animated-graphics-with-ruby-and-voronoi-partitions/
[7]: https://github.com/mike-bourgeous/mb-geometry/blob/master/lib/mb/geometry/generators.rb#L80
[8]: https://www.youtube.com/watch?v=jxOAU7YfypA
