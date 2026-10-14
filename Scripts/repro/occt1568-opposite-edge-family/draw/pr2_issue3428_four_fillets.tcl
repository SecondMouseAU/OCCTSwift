puts "============"
puts "OCCT#1568 / PR2 (WireExplorer + validity): four fillets on one face of a cube, OCCTSwift#3428"
puts "============"
puts ""
##########################################################################
# Cube 4 x 4 x 4. Four fillets round the four edges of the top face.
# At r = w / 2 = 2 the arcs meet on the centre lines and the face between
# them is a point. IR before: blend returns a "solid" in a few ms, and
# checkshape on it never returns (BRepTools_WireExplorer loops). With the
# WireExplorer fix and the validity check: refused, in a few ms.
# The analytic volume at r = 2 is 160/3 (the limit of the r < 2 results).
##########################################################################

source [file join [file dirname [info script]] common.tcl]

pload MODELING
box b 4 4 4
set e1 [fam_edge_at b 2 0 4]
set e2 [fam_edge_at b 2 4 4]
set e3 [fam_edge_at b 0 2 4]
set e4 [fam_edge_at b 4 2 4]

set ok [expr {![catch {blend t_lo b 1.999999 $e1 1.999999 $e2 1.999999 $e3 1.999999 $e4} msg]}]
fam_verdict "pr2.i3428.r1.999999" $ok t_lo 53.3333333333 valid

# r = 3 is past half the face: refused (on IR before: done, invalid)
set ok [expr {![catch {blend t3 b 3 $e1 3 $e2 3 $e3 3 $e4} msg]}]
fam_verdict "pr2.i3428.r3" $ok t3 0 refused

# r = 2 is last: on IR before checkshape of the result does not return, which ends the process.
# mkimages.py --no-check <state> sets FAM_NO_CHECK=1, which makes this case print its line without
# calling checkshape; without it run-all.py reports the TIMEOUT.
set ::fam_check_may_hang 1
set ok [expr {![catch {blend t2 b 2 $e1 2 $e2 2 $e3 2 $e4} msg]}]
fam_verdict "pr2.i3428.r2" $ok t2 53.3333333333 valid_or_refused
unset ::fam_check_may_hang
