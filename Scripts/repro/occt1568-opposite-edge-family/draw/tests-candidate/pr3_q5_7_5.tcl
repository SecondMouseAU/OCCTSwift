# Two fillets each wider than the 4 wide wall between them: the intersection of the two pivot results.
# Box: the 10 x 4 x 6 box; b_2 and b_6 are the top edges at x = 0 and x = 10 (the 10 wide face).
# Candidate for tests/blend or tests/bugs/modalg_7 (OCCT#1568, OCCT#1177). Label pr3.q5.7_5, expect valid.

# the common helpers of the runner, absent under testgrid
catch { source [file join [file dirname [info script]] .. common.tcl] }

pload MODELING
box b 10 4 6
explode b e

set ok [expr {![catch { blend result b 7.5 b_2 7.5 b_6 } msg]}]
if { !$ok } {
    puts "Error : the blend is refused: $msg"
} else {
    checkshape result
    checkprops result -v 153.644087465 -eps 1e-9 -deps 1e-5
    checknbshapes result -vertex 6 -edge 9 -wire 5 -face 5 -shell 1 -solid 1
}

# FAMILY line for draw/run-all.py, not part of an upstream test
if { [llength [info procs fam_verdict]] } {
    fam_verdict "pr3.q5.7_5" $ok result 153.644087465 valid
}

puts "TEST COMPLETED"
