# OCCTSwift#3428: four fillets just under w / 2 round a 4 x 4 face: valid.
# Box: the 4 x 4 x 4 cube; b_2, b_6, b_10, b_12 are the four edges of the top face (x = 0, x = 4, y = 0, y = 4).
# Candidate for tests/blend or tests/bugs/modalg_7 (OCCT#1568, OCCT#1177). Label pr2.i3428.r1.999999, expect valid.

# the common helpers of the runner, absent under testgrid
catch { source [file join [file dirname [info script]] .. common.tcl] }

pload MODELING
box b 4 4 4
explode b e

set ok [expr {![catch { blend result b 1.999999 b_10 1.999999 b_12 1.999999 b_2 1.999999 b_6 } msg]}]
if { !$ok } {
    puts "Error : the blend is refused: $msg"
} else {
    checkshape result
    checkprops result -v 53.3333333333 -eps 1e-9 -deps 1e-5
    checknbshapes result -vertex 12 -edge 20 -wire 10 -face 10 -shell 1 -solid 1
}

# FAMILY line for draw/run-all.py, not part of an upstream test
if { [llength [info procs fam_verdict]] } {
    fam_verdict "pr2.i3428.r1.999999" $ok result 53.3333333333 valid
}

puts "TEST COMPLETED"
