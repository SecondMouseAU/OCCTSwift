# Two fillets on the opposite edges of a 4 wide face whose radii add up to more than 4 (2.5 + 3): the arcs cross and the result is the intersection of the two rounded profiles.
# Box: the 4 x 10 x 6 box; b_2 and b_6 are the edges of the top face at x = 0 and x = 4 (the 4 wide face).
# Candidate for tests/blend or tests/bugs/modalg_7 (OCCT#1568, OCCT#1177). Label pr2.q1.2.5_3, expect valid.

# the common helpers of the runner, absent under testgrid
catch { source [file join [file dirname [info script]] .. common.tcl] }

pload MODELING
box b 4 10 6
explode b e

set ok [expr {![catch { blend result b 2.5 b_2 3 b_6 } msg]}]
if { !$ok } {
    puts "Error : the blend is refused: $msg"
} else {
    checkshape result
    checkprops result -v 207.791557091 -eps 1e-9 -deps 1e-5
    checknbshapes result -vertex 10 -edge 15 -wire 7 -face 7 -shell 1 -solid 1
}

# FAMILY line for draw/run-all.py, not part of an upstream test
if { [llength [info procs fam_verdict]] } {
    fam_verdict "pr2.q1.2.5_3" $ok result 207.791557091 valid
}

puts "TEST COMPLETED"
