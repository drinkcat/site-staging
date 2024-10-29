---
layout: post
title:  "Solving a geocaching problem with Prolog (CLP)"
date: 2024-10-29 15:23:41+01:00
categories: backup
---

Something a bit different for today! I picked up [Geocaching](https://www.geocaching.com/blog/2018/03/what-is-geocaching/) this year. It's a really fun activity, that makes you go out in the real world to find hidden items (a box, little tube...), that you open, sign, and put back carefully. Without anybody else spotting you. Ideally.

Some of the mystery caches require to solve a puzzle to find the final coordinates where you can find the box.

I'll focus on a particular puzzle here, where I ended up using Prolog to find the target coordinates. I will not give out the specific problem I solved, and I heavily modified the numbers below, as I do not want to provide spoilers.

## Coordinates

One example of coordinates looks like this:

```bash
N 25° 02.008 E 121° 33.951
```

Geocaching usually uses degrees (e.g. `25`), followed by minutes (`02`), and a fractional decimal part (`008`).

A mystery cache is usually posted at bogus coordinates, and some computations are required to get to the final location, which "*cannot be more than 2 miles (3.2 kilometers) from the posted coordinates*" ([ref](https://www.geocaching.com/help/index.php?pg=kb.chapter&id=127&pgid=277)).

## Puzzle

The problem I wanted to solve required finding 10 variables (A, B, C, D, E, F, G, H, J, K), based on questions that should be solvable online.

Te puzzle is fairly old, and requires looking at the profile of the geocacher. For some variables, the solution can be found, for others there is no way anymore (I believe geocaching website tightened privacy rules), and for some others, only a lower bound can be found (e.g., the number of finds in a given year excludes caches that have been archived since then, so I can find 7 caches on the website, the number of caches that have actually been found can be anything *more* than 2, or 2 itself).

In my case, I could be find 4 of the variable values (A, E, H, and K),
while I had lower bounds for 3 variables (D, F, G), and no solutions
for 3 more (B, C, and J).

We also know that the sum of those 10 variables must be equal to 25.

Once those 10 variables are found, the final coordinates are given in this form, where each of the expressions in parentheses give out one number in the final coordinates.

```bash
N 25 (J-E)(F+A).(K-F)(E+C)(G+C)
E121 (H-C)(E+G).(E-B)(J-D)(CxA)
```

This is helpful to constraint the variable values above, as we know that each of those numbers must be between 0 and 9 (so, for example, `0 <= (K-F) <= 9`, or, in other words, `K >= F` and `K <= F+9`).

Furthermore, we know that the target must be within 3.2km of the posted coordinates, so we can compute a bounding box for the latitude and longitude coordinates (technically, this is a circle for the maths become too difficult and not worth it).

For the latitude, constraints can easily be computed: earth circumference is 40000km, and there are 360°, so each degree is about 111km (`40000/360`), so each minute is 1.85km (`111/60`). Therefore, we know that the North coordinate must be within 2 minutes (`2*1.85km = 3.7km > 3.2km`) of the starting position.

So for a starting position at `N 25° 02.008`, the minutes must be somewhere within `00` and `04` (2 minutes away from `02`). Based on the expression above, this implies that `J-E=0` (or `J=E`), and that `F+A` must be in between `0` and `4`.

The longitude coordinates are a little bit trickier, as they depend on the latitude (each longitude degree gets shorter as you move away from the equator). For example, at 25° North, each longitude degree is 100km (`111km * cos(25°)`), so each minute is 1.67km. So we must still be within 2 degrees (`2*1.67km = 3.34km > 3.2km`: this would be larger for a puzzle further north, or far south).

So again, we have, for a starting position at `E 121° 33.951`, that the minutes must be between `31` and `35`, which applies constraints on `(H-C)` and `(E+G)`.

Now that we have all of these contraints, we could try to solve this by hand, but this might range from difficult to... impossible. Which is why I introduce Prolog.

## Prolog

[Prolog](https://en.wikipedia.org/wiki/Prolog) is an old programming language from 1972, in the field of Artificial Intelligence (before it was so cool I guess), that allows you to easily state such logic problems.

In this case, I will use the `clpfd` module ("CLP(FD): Constraint Logic Programming over Finite Domains"), as we are just facing a CLP problem. So I suppose we could also simply use a CLP solver instead of Prolog -- but I had to use Prolog for another problem, so this was most
convenient.

Now, lets convert the constraints above:

Not much boiler plate needed, we just include the CLP module, and start
the program with `?-`

```prolog
:- use_module(library(clpfd)).

/* Start of script */
?-
```

Then, we can declare constraints. For known variables, we can just set then:

```prolog
    A #= 1,
    E #= 2,
    H #= 8,
    K #= 2,
```

For the ones that have a known lower bound, we can assign then as such (I do put a larger upper bound, that makes sense given the problem, we could increase it if needed).

```prolog
    D in 2..100, /* e.g. at at least 2 caches found */
    F in 1..100,
    G in 1..100,
```

Finally, we assign the unknown values between 0 and 100:

```prolog
    B in 0..100, /* These cannot be found anymore */
    C in 0..100,
    J in 0..100,
```

Now, we can start adding constraints. We know that the sum is 25:

```prolog
    A+B+C+D+E+F+G+H+J+K #= 25,
```

For the coordinates, I set intermediate variables, then apply constraints:

```prolog
    /* N 25 (J-E)(F+A).(K-F)(E+C)(G+C) */
    N1 #= J-E, N2 #= F+A, N3 #= K-F, N4 #= E+C, N5 #= G+C,
    N1 #= 0, N2 in 0..4, /* Minutes between 00 and 04 */
    N3 in 0..9, N4 in 0..9, N5 in 0..9, /* Decimals between 0 and 9. 
```

And we do something similar on the longitudes coordinates:

```prolog
    /* E121 (H-C)(E+G).(E-B)(J-D)(CxA) */
    E1 #= H-C, E2 #= E+G, E3 #= E-B, E4 #= J-D, E5 #= C*A,
    E1 #= 3,
    E2 in 1..4,
    E3 in 0..9, E4 in 0..9, E5 in 0..9,
```

Then, we tell the solver to solve the constraints, and print the variables, and final coordinates:

```prolog
    /* Solve */
    indomain(B), indomain(C), indomain(D),
    indomain(F), indomain(G), indomain(J),
    /* Print solution */
    write([A, B, C, D, E, F, G, H, J, K]),
    write(": N25 "), write(N1), write(N2), write("."),
    write(N3), write(N4), write(N5),
    write(" E121 "), write(E1), write(E2), write("."),
    write(E3), write(E4), write(E5),
    nl, /* New line*/
    fail. /* Hack that makes it print all solutions. */
```

I'm not 100% sure to understand the `fail` trick here, but that nicely allows Prolog to provide **all** possible solutions, and not just the first one.

Then we can just run the Prolog interpreter (I use [SWI-prolog](https://www.swi-prolog.org/)):

```bash
swipl -s geocaching.pro
```

Which outputs 3 sets of solutions, along with the final location:

```bash
[1,0,5,2,2,1,2,8,2,2]: N25 02.177 E121 34.205
[1,0,5,2,2,2,1,8,2,2]: N25 03.076 E121 33.205
[1,1,5,2,2,1,1,8,2,2]: N25 02.176 E121 33.105
```

We can then see where those locations are on Google maps (e.g. we can eliminate the ones in the middle of a river), or the mystery cache provides a geochecker that allows us to try those 3 options to see which one is correct.

That's it! Happy geocaching!
