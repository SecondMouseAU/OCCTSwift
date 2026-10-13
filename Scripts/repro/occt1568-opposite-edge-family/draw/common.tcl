# Helpers shared by the scripts in this directory (sourced, not a DRAW command set).
# They exist so every case prints one verdict line in one format that run-all.py reads:
#
#   FAMILY label=<label> done=<0|1> valid=<0|1> vol=<volume|-> faces=<n|-> expect=<mode> want=<volume> verdict=<PASS|FAIL>
#
# expect modes:
#   valid             must be done, a valid solid, volume within 1e-6 (relative) of want
#   valid_or_refused  either of: refused (IsDone false), or valid with that volume (1e-4); never invalid
#   refused           must be refused (IsDone false), never invalid and never a crash

# fam_edge_at shape x y z: name of the edge of shape whose bounding box centre is nearest the point.
proc fam_edge_at {shape x y z} {
  set names [uplevel #0 [list explode $shape e]]
  set best ""
  set bestd 1e300
  set i 0
  foreach e $names {
    incr i
    # bounding -save makes DRAW numeric variables (dval reads one); a name is only written once
    uplevel #0 [list bounding $e -save fam_x0_$i fam_y0_$i fam_z0_$i fam_x1_$i fam_y1_$i fam_z1_$i -nodraw]
    # dval looks the name up in the current frame, so it is read at global level too
    set cx [expr {([uplevel #0 [list dval fam_x0_$i]] + [uplevel #0 [list dval fam_x1_$i]]) / 2.0}]
    set cy [expr {([uplevel #0 [list dval fam_y0_$i]] + [uplevel #0 [list dval fam_y1_$i]]) / 2.0}]
    set cz [expr {([uplevel #0 [list dval fam_z0_$i]] + [uplevel #0 [list dval fam_z1_$i]]) / 2.0}]
    set d [expr {($cx - $x) * ($cx - $x) + ($cy - $y) * ($cy - $y) + ($cz - $z) * ($cz - $z)}]
    if {$d < $bestd} {
      set bestd $d
      set best $e
    }
  }
  if {$best eq ""} { error "fam_edge_at: no edges of $shape" }
  return $best
}

# fam_verdict label ok result want expect: classify a blend outcome and print the FAMILY line.
proc fam_verdict {label ok res want expect} {
  set valid 0
  set vol "-"
  set nf "-"
  if {$ok} {
    set chk [uplevel #0 [list checkshape $res]]
    set valid [regexp -nocase {seems to be valid} $chk]
    set props [uplevel #0 [list vprops $res 1e-9 -full]]
    if {[regexp {Mass\s*:\s*([-0-9.eE+]+)} $props -> m]} { set vol $m }
    set cnt [uplevel #0 [list nbshapes $res -face]]
    if {[regexp {FACE\s*:\s*([0-9]+)} $cnt -> n]} { set nf $n }
  }
  set verdict FAIL
  set volok 0
  # valid_or_refused is for radii a hair off a case with a known volume: 1e-4 relative
  set tol [expr {$expect eq "valid_or_refused" ? 1e-4 : 1e-6}]
  if {$vol ne "-" && $want > 0} {
    set volok [expr {abs($vol - $want) <= $tol * $want}]
  }
  switch -- $expect {
    valid            { if {$ok && $valid && $volok} { set verdict PASS } }
    valid_or_refused { if {!$ok || ($valid && $volok)} { set verdict PASS } }
    refused          { if {!$ok} { set verdict PASS } }
  }
  puts "FAMILY label=$label done=$ok valid=$valid vol=$vol faces=$nf expect=$expect want=$want verdict=$verdict"
  flush stdout
  # a windowed DRAW sends puts to its console: FAM_LOG names a file that also gets the line
  if {[info exists ::env(FAM_LOG)]} {
    set fh [open $::env(FAM_LOG) a]
    puts $fh "FAMILY label=$label done=$ok valid=$valid vol=$vol faces=$nf expect=$expect want=$want verdict=$verdict"
    close $fh
  }
  # render-images.tcl defines fam_hook to take a picture of each case
  if {[llength [info procs fam_hook]]} {
    if {[catch {fam_hook $label $ok $res $valid $vol $verdict} err]} {
      puts "HOOKERROR $err"
      if {[info exists ::env(FAM_LOG)]} {
        set fh [open $::env(FAM_LOG) a]
        puts $fh "HOOKERROR $err"
        close $fh
      }
    }
  }
  return $verdict
}
