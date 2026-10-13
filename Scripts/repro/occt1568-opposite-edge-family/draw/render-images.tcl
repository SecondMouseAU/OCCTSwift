# Take a picture of every case a script computes. Not a test: source it before a case script.
#
#   FAM_OUT=<dir> FAM_STATE=<label> DRAWEXE -c "source render-images.tcl; source pr2_row2_opposite_3_3.tcl; exit"
#
# Needs a window (vinit in batch mode has no Cocoa application), so DRAWEXE is started without -b.
# Writes <dir>/<state>--<label>--prof.ppm (looking along the filleted edges) and ...--axo.ppm.
# Colours: a valid solid is gold, an invalid solid (IsDone true, BRepCheck rejects it) is red,
# a refusal is the input in grey with the edges that were to be filleted in red.

pload MODELING
pload OPENGL
pload VISUALIZATION

set ::fam_out $::env(FAM_OUT)
set ::fam_state $::env(FAM_STATE)

# remember what each blend was asked: the input shape and the edge arguments
rename blend fam_blend_orig
proc blend {result obj args} {
  set ::fam_log($result) [list $obj $args]
  uplevel 1 [list fam_blend_orig $result $obj {*}$args]
}

# DRAW looks shape names up in the current frame: run its commands at global level
proc G {args} { uplevel #0 $args }

proc fam_snap {name} {
  global fam_out fam_state
  G vfit
  G vzfit
  G vdump [file join $fam_out $name].ppm
}

proc fam_hook {label ok res valid vol verdict} {
  global fam_log fam_out fam_state
  if {![info exists ::fam_viewer]} {
    G vinit View1 w=520 h=420
    G vbackground -color WHITE
    set ::fam_viewer 1
    set ::fam_n 0
  }
  G vclear
  set key [string map {/ _ { } _} $label]
  lassign $fam_log($res) obj blendargs
  # the edges named in the blend call, every second argument
  set edges {}
  foreach {r e} $blendargs { lappend edges $e }
  set dir z
  if {[llength $edges]} {
    # the longest side of the first edge's box is the direction it runs in
    set k [incr ::fam_n]
    G bounding [lindex $edges 0] -save fh_x0_$k fh_y0_$k fh_z0_$k fh_x1_$k fh_y1_$k fh_z1_$k -nodraw
    set ext(x) [expr {abs([G dval fh_x1_$k] - [G dval fh_x0_$k])}]
    set ext(y) [expr {abs([G dval fh_y1_$k] - [G dval fh_y0_$k])}]
    set ext(z) [expr {abs([G dval fh_z1_$k] - [G dval fh_z0_$k])}]
    set best -1
    foreach a {x y z} { if {$ext($a) > $best} { set best $ext($a); set dir $a } }
  }
  set shown {}
  if {$ok} {
    G vdisplay -dispMode 1 $res
    if {$valid} {
      G vaspects $res -color 0.86 0.66 0.15 -faceBoundaryDraw 1 -faceBoundaryColor BLACK
    } else {
      G vaspects $res -color RED -faceBoundaryDraw 1 -faceBoundaryColor BLACK
    }
    set shown $res
  } else {
    G vdisplay -dispMode 1 $obj
    G vaspects $obj -color 0.75 0.75 0.75 -faceBoundaryDraw 1 -faceBoundaryColor BLACK
    set n 0
    foreach e $edges {
      set en fam_edge_[incr n]
      G copy $e $en
      G vdisplay $en
      G vaspects $en -color RED -width 6
    }
  }
  foreach v {prof axo} {
    if {$v eq "axo"} {
      G vviewparams -proj 1 -1 0.8 -up 0 0 1
    } else {
      # along the filleted edges, tilted a little: a face exactly facing the light renders white
      switch $dir {
        x { G vviewparams -proj 1 0.2 0.2 -up 0 0 1 }
        y { G vviewparams -proj 0.2 1 0.2 -up 0 0 1 }
        default { G vviewparams -proj 0.2 0.2 1 -up 0 1 0 }
      }
    }
    fam_snap "${fam_state}--${key}--$v"
  }
}
