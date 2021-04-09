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
  PDF).  Later, mention is made of individual adjacency lists.
- The paper doesn't specify when mutations of variables are to occur.  When
  mutations are performed exactly as listed in the paper's MERGE subroutine,
  the clockwise and counterclockwise navigation functions (PRED and SUCC) get
  confused by newly added or removed edges.  This can cause the point-walk on
  the right and left side hulls to cross over to the wrong hull, and also try
  to navigate around a point that has been removed (and thus is no longer in
  the adjacency list).
- It's not really clear how the FIRST function is supposed to operate.  I'm
  just manually marking an edge as "first" when I know it's part of a convex
  hull.

## References

- [Lee and Schachter, 1980](http://www.personal.psu.edu/cxc11/AERSP560/DELAUNEY/13_Two_algorithms_Delauney.pdf)
- [Computing constrained Delaunay triangulations](https://web.archive.org/web/20170922181219/http://www.geom.uiuc.edu/~samuelp/del_project.html)
- https://en.wikipedia.org/wiki/Delaunay_triangulation


## Testing

- `bin/delaunay_bench.rb` crashes at 13 but works at 12 points
