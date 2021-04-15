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
  PDF).  Later, mention is made of individual adjacency lists rather than a
  single adjacency list.
- The paper doesn't specify exactly when mutations of variables or neighbors
  are to occur.
  - Assigning variables in sequence would cause some computed values to be
    discarded, so they have to be computed separately and then assigned
    afterward.
  - When mutations are performed exactly as listed in the paper's MERGE
    subroutine, the clockwise and counterclockwise navigation functions (PRED
    and SUCC) get confused by newly added or removed edges.  This can cause the
    point-walk on the right and left side hulls to cross over to the wrong
    hull, and also try to navigate around a point that has been removed (and
    thus is no longer in the adjacency list).
- It's not really clear how the FIRST function is supposed to operate.  I'm
  just manually marking an edge as "first" when I know it's part of a convex
  hull.
- Rounding error on the circumcircle distance comparison can cause
  triangulation to fail, if not accounted for.  This implementation rounds to a
  fixed number of decimal places as a partial workaround.
- The paper doesn't specify how to triangulate the bottom-level subdivisions of
  2 or 3 points.  I took a few guesses to try to maintain the invariant that
  `point.first()` will navigate counterclockwise around the convex hull, but if
  the bottom-level subdivision contains 3 collinear or approximately collinear
  points, it's less clear what is correct.
- The algorithm detail section of the paper doesn't mention some degenerate or
  difficult cases like straight lines or nearly straight lines.

## References

- [Lee and Schachter, 1980](http://www.personal.psu.edu/cxc11/AERSP560/DELAUNEY/13_Two_algorithms_Delauney.pdf)
- [Computing constrained Delaunay triangulations](https://web.archive.org/web/20170922181219/http://www.geom.uiuc.edu/~samuelp/del_project.html)
- https://en.wikipedia.org/wiki/Delaunay_triangulation
