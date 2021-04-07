# Delaunay triangulation in pure Ruby

Due to some odd bugs in Rubyvor, I'm trying to write a pure Ruby implementation
of a Delaunay triangulation.  I am using the 1980 algorithm from D.T. Lee and
B.J. Schachter as a reference, but several implementation details are unclear,
so I am changing a few things to use Ruby primitives instead.

I am also referring to a website by Samuel Peterson (linked from Wikipedia) to
help resolve ambiguities or misunderstandings I have from Lee and Schachter.
This website describes a similar divide and conquer algorithm from 1985 by
Guibas and Stolfi, which the ACM still charges for and thus I have not read.

## Questions about L&S

- The adjacency list is specified as being a circular doubly-linked list, which
  is a linear structure, but then accessed using two-parameter functions PRED
  and SUCC making it seem like a two dimensional (page 226 of the below-linked
  PDF).  Later, mention is made

## References

- [Lee and Schachter, 1980](http://www.personal.psu.edu/cxc11/AERSP560/DELAUNEY/13_Two_algorithms_Delauney.pdf)
- [Computing constrained Delaunay triangulations](https://web.archive.org/web/20170922181219/http://www.geom.uiuc.edu/~samuelp/del_project.html)
- https://en.wikipedia.org/wiki/Delaunay_triangulation


## Testing

- `bin/delaunay_bench.rb` crashes at 13 but works at 12 points
