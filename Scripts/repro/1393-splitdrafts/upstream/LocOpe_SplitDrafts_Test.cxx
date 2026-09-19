// Copyright (c) 2026 OPEN CASCADE SAS
//
// This file is part of Open CASCADE Technology software library.
//
// This library is free software; you can redistribute it and/or modify it under
// the terms of the GNU Lesser General Public License version 2.1 as published
// by the Free Software Foundation, with special exception defined in the file
// OCCT_LGPL_EXCEPTION.txt. Consult the file LICENSE_LGPL_21.txt included in OCCT
// distribution for complete text of the license and disclaimer of any warranty.
//
// Alternatively, this file may be used under the terms of Open CASCADE
// commercial license or contractual agreement.

#include <BRep_Tool.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepGProp.hxx>
#include <BRepLib.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <Geom2d_Line.hxx>
#include <Geom_Plane.hxx>
#include <GProp_GProps.hxx>
#include <LocOpe_SplitDrafts.hxx>
#include <Precision.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <gp_Dir2d.hxx>
#include <gp_Pln.hxx>
#include <gp_Pnt2d.hxx>

#include <gtest/gtest.h>

namespace
{
//! The +Z face of a box built at the origin.
TopoDS_Face TopFace(const TopoDS_Shape& theBox, const double theHeight)
{
  for (TopExp_Explorer anExp(theBox, TopAbs_FACE); anExp.More(); anExp.Next())
  {
    const TopoDS_Face             aFace  = TopoDS::Face(anExp.Current());
    const occ::handle<Geom_Plane> aPlane = occ::down_cast<Geom_Plane>(BRep_Tool::Surface(aFace));
    if (!aPlane.IsNull()
        && std::abs(aPlane->Pln().Location().Z() - theHeight) < Precision::Confusion())
    {
      return aFace;
    }
  }
  return TopoDS_Face();
}
} // namespace

// Perform() pipes along the intersection of the two drafted planes, which is always a line, and
// the pipe's path is the face normal, also a line. Both were passed to GeomFill_Pipe untrimmed,
// and GeomConvert::CurveToBSplineCurve rejects an infinite curve, so every planar request threw
// Standard_DomainError("No such curve").
TEST(LocOpe_SplitDraftsTest, DraftPlanarFace)
{
  const TopoDS_Shape aBox = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
  const TopoDS_Face  aTop = TopFace(aBox, 10.0);
  ASSERT_FALSE(aTop.IsNull()) << "Top face not found";

  // The splitting wire, built on the face at u = 5 so that it carries a pcurve.
  const occ::handle<Geom_Surface> aSurf   = BRep_Tool::Surface(aTop);
  const occ::handle<Geom2d_Line>  aLine2d = new Geom2d_Line(gp_Pnt2d(5.0, 0.0), gp_Dir2d(0.0, 1.0));
  TopoDS_Edge anEdge = BRepBuilderAPI_MakeEdge(aLine2d, aSurf, 0.0, 10.0).Edge();
  BRepLib::BuildCurves3d(anEdge);
  const TopoDS_Wire aWire = BRepBuilderAPI_MakeWire(anEdge).Wire();

  // The neutral plane must not be the face's own plane, or NewPlane() bails.
  const gp_Pln aNeutral(gp_Pnt(5.0, 0.0, 0.0), gp_Dir(1.0, 0.0, 0.0));
  const double anAngle = 10.0 * M_PI / 180.0;

  LocOpe_SplitDrafts aSplit;
  aSplit.Init(aBox);
  ASSERT_NO_THROW(aSplit.Perform(aTop, aWire, gp_Dir(1.0, 0.0, 0.0), aNeutral, anAngle));
  ASSERT_TRUE(aSplit.IsDone()) << "Draft split not performed";

  int aNbFaces = 0;
  for (TopExp_Explorer anExp(aSplit.Shape(), TopAbs_FACE); anExp.More(); anExp.Next())
  {
    ++aNbFaces;
  }
  EXPECT_EQ(aNbFaces, 7) << "The top face should be split in two";

  // Half the top face (5 x 10) is tipped up by the draft angle, adding that wedge.
  GProp_GProps aProps;
  BRepGProp::VolumeProperties(aSplit.Shape(), aProps);
  const double anExpected = 1000.0 + 0.5 * 5.0 * (5.0 * tan(anAngle)) * 10.0;
  EXPECT_NEAR(aProps.Mass(), anExpected, 1.0e-4) << "Drafted volume is wrong";
}
