//
//  OCCTBridge_AIS.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm, issue #99.
//
//  AIS annotations + measurements + point cloud (v0.26):
//
//  - PrsDim_*Dimension: length / radius / diameter / angle dimensions
//    on B-Rep edges and faces
//  - AIS_TextLabel: 3D text annotation
//  - OCCTPointCloud: lightweight point + color buffer with bounds
//
//  All three internal struct types (OCCTDimension / OCCTTextLabel /
//  OCCTPointCloud) live entirely inside this TU.
//
//  Public C surface unchanged. No symbol changes: a pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Area-specific OCCT headers ===

#include <AIS_TextLabel.hxx>
#include <PrsDim_AngleDimension.hxx>
#include <PrsDim_DiameterDimension.hxx>
#include <PrsDim_Dimension.hxx>
#include <PrsDim_LengthDimension.hxx>
#include <PrsDim_RadiusDimension.hxx>

#include <Quantity_Color.hxx>
#include <TCollection_AsciiString.hxx>
#include <TCollection_ExtendedString.hxx>

#include <gp_Circ.hxx>
#include <gp_Dir.hxx>
#include <gp_Pln.hxx>
#include <gp_Pnt.hxx>
#include <gp_Vec.hxx>

#include <TopAbs.hxx>
#include <TopExp.hxx>
#include <TopoDS.hxx>
#include <BRep_Tool.hxx>

#include <cmath>
#include <cstring>
#include <vector>

// MARK: - AIS Annotations & Measurements (v0.26.0)
// ============================================================

#include <PrsDim_LengthDimension.hxx>
#include <PrsDim_RadiusDimension.hxx>
#include <PrsDim_AngleDimension.hxx>
#include <PrsDim_DiameterDimension.hxx>
#include <PrsDim_Dimension.hxx>
#include <AIS_TextLabel.hxx>
#include <TCollection_ExtendedString.hxx>
#include <TCollection_AsciiString.hxx>

struct OCCTDimension
{
  Handle(PrsDim_Dimension) dim;
  int                      kind; // OCCTDimensionKind
};

struct OCCTTextLabel
{
  Handle(AIS_TextLabel) label;
};

struct OCCTPointCloud
{
  std::vector<double> coords; // xyz triplets
  std::vector<float>  colors; // rgb triplets (empty if uncolored)
  int32_t             count;
  double              minBound[3];
  double              maxBound[3];
};

// Helper: compute a plane containing the line from p1 to p2
static gp_Pln computePlaneForPoints(const gp_Pnt& p1, const gp_Pnt& p2)
{
  gp_Vec lineDir(p1, p2);
  if (lineDir.Magnitude() < 1e-10)
  {
    return gp_Pln(p1, gp::DZ());
  }
  gp_Vec up(0, 0, 1);
  if (lineDir.IsParallel(up, 1e-6))
  {
    up = gp_Vec(0, 1, 0);
  }
  gp_Vec normal = lineDir.Crossed(up);
  return gp_Pln(p1, gp_Dir(normal));
}

// --- Dimension creation ---

OCCTDimensionRef OCCTDimensionCreateLengthFromPoints(double p1x,
                                                     double p1y,
                                                     double p1z,
                                                     double p2x,
                                                     double p2y,
                                                     double p2z)
{
  try
  {
    gp_Pnt                         p1(p1x, p1y, p1z);
    gp_Pnt                         p2(p2x, p2y, p2z);
    gp_Pln                         plane  = computePlaneForPoints(p1, p2);
    Handle(PrsDim_LengthDimension) dim    = new PrsDim_LengthDimension(p1, p2, plane);
    auto*                          result = new OCCTDimension();
    result->dim                           = dim;
    result->kind                          = OCCTDimensionKindLength;
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

// #1026: these four reach ShapeType() through a TopoDS_Shape& reference alias, so a grep for
// `->shape.ShapeType()` does not see them, but the dereference is the same one and so is the crash.
// Dimension(edge:) and Dimension(face1:face2:) take a Shape, so Shape.nullified reached all four.
OCCTDimensionRef OCCTDimensionCreateLengthFromEdge(OCCTShapeRef edge)
{
  if (!occtShapeIsPresent(edge))
    return nullptr;
  try
  {
    TopoDS_Shape& shape = edge->shape;
    if (shape.ShapeType() != TopAbs_EDGE)
      return nullptr;
    TopoDS_Edge e = TopoDS::Edge(shape);

    // Get vertices for plane computation
    TopoDS_Vertex v1, v2;
    TopExp::Vertices(e, v1, v2);
    if (v1.IsNull() || v2.IsNull())
      return nullptr;
    gp_Pnt p1    = BRep_Tool::Pnt(v1);
    gp_Pnt p2    = BRep_Tool::Pnt(v2);
    gp_Pln plane = computePlaneForPoints(p1, p2);

    Handle(PrsDim_LengthDimension) dim    = new PrsDim_LengthDimension(e, plane);
    auto*                          result = new OCCTDimension();
    result->dim                           = dim;
    result->kind                          = OCCTDimensionKindLength;
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTDimensionRef OCCTDimensionCreateLengthFromFaces(OCCTShapeRef face1, OCCTShapeRef face2)
{
  if (!occtShapeIsPresent(face1) || !occtShapeIsPresent(face2))
    return nullptr;
  try
  {
    TopoDS_Shape& s1 = face1->shape;
    TopoDS_Shape& s2 = face2->shape;
    if (s1.ShapeType() != TopAbs_FACE || s2.ShapeType() != TopAbs_FACE)
      return nullptr;
    TopoDS_Face f1 = TopoDS::Face(s1);
    TopoDS_Face f2 = TopoDS::Face(s2);

    Handle(PrsDim_LengthDimension) dim    = new PrsDim_LengthDimension(f1, f2);
    auto*                          result = new OCCTDimension();
    result->dim                           = dim;
    result->kind                          = OCCTDimensionKindLength;
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

// #1026, a SECOND class from the same input: these two never touch a hazardous TopoDS_Shape member
// themselves, so the gate's third walk does not see them and cannot. They hand the shape to
// PrsDim_RadiusDimension / PrsDim_DiameterDimension, whose constructors dereference it inside the
// kernel, which is the shape-side equivalent of #556's "the OCCT entry point dereferences it for
// you". Measured, both are SIGSEGV on Shape.nullified through RadiusDimension(shape:) and
// DiameterDimension(shape:). Fixed here because this file is already in this diff; the general
// sweep of which OCCT entry points dereference a null TopoDS_Shape is its own issue, not this one.
OCCTDimensionRef OCCTDimensionCreateRadiusFromShape(OCCTShapeRef shape)
{
  if (!occtShapeIsPresent(shape))
    return nullptr;
  try
  {
    Handle(PrsDim_RadiusDimension) dim    = new PrsDim_RadiusDimension(shape->shape);
    auto*                          result = new OCCTDimension();
    result->dim                           = dim;
    result->kind                          = OCCTDimensionKindRadius;
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTDimensionRef OCCTDimensionCreateAngleFromEdges(OCCTShapeRef edge1, OCCTShapeRef edge2)
{
  if (!occtShapeIsPresent(edge1) || !occtShapeIsPresent(edge2))
    return nullptr;
  try
  {
    TopoDS_Shape& s1 = edge1->shape;
    TopoDS_Shape& s2 = edge2->shape;
    if (s1.ShapeType() != TopAbs_EDGE || s2.ShapeType() != TopAbs_EDGE)
      return nullptr;
    TopoDS_Edge e1 = TopoDS::Edge(s1);
    TopoDS_Edge e2 = TopoDS::Edge(s2);

    Handle(PrsDim_AngleDimension) dim    = new PrsDim_AngleDimension(e1, e2);
    auto*                         result = new OCCTDimension();
    result->dim                          = dim;
    result->kind                         = OCCTDimensionKindAngle;
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTDimensionRef OCCTDimensionCreateAngleFromPoints(double p1x,
                                                    double p1y,
                                                    double p1z,
                                                    double cx,
                                                    double cy,
                                                    double cz,
                                                    double p2x,
                                                    double p2y,
                                                    double p2z)
{
  try
  {
    gp_Pnt p1(p1x, p1y, p1z);
    gp_Pnt center(cx, cy, cz);
    gp_Pnt p2(p2x, p2y, p2z);

    Handle(PrsDim_AngleDimension) dim    = new PrsDim_AngleDimension(p1, center, p2);
    auto*                         result = new OCCTDimension();
    result->dim                          = dim;
    result->kind                         = OCCTDimensionKindAngle;
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTDimensionRef OCCTDimensionCreateAngleFromFaces(OCCTShapeRef face1, OCCTShapeRef face2)
{
  if (!occtShapeIsPresent(face1) || !occtShapeIsPresent(face2))
    return nullptr;
  try
  {
    TopoDS_Shape& s1 = face1->shape;
    TopoDS_Shape& s2 = face2->shape;
    if (s1.ShapeType() != TopAbs_FACE || s2.ShapeType() != TopAbs_FACE)
      return nullptr;
    TopoDS_Face f1 = TopoDS::Face(s1);
    TopoDS_Face f2 = TopoDS::Face(s2);

    Handle(PrsDim_AngleDimension) dim    = new PrsDim_AngleDimension(f1, f2);
    auto*                         result = new OCCTDimension();
    result->dim                          = dim;
    result->kind                         = OCCTDimensionKindAngle;
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTDimensionRef OCCTDimensionCreateDiameterFromShape(OCCTShapeRef shape)
{
  if (!occtShapeIsPresent(shape))
    return nullptr;
  try
  {
    Handle(PrsDim_DiameterDimension) dim    = new PrsDim_DiameterDimension(shape->shape);
    auto*                            result = new OCCTDimension();
    result->dim                             = dim;
    result->kind                            = OCCTDimensionKindDiameter;
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

// --- Dimension common functions ---

void OCCTDimensionRelease(OCCTDimensionRef dim)
{
  delete dim;
}

double OCCTDimensionGetValue(OCCTDimensionRef dim)
{
  if (!dim || dim->dim.IsNull())
    return 0.0;
  try
  {
    return dim->dim->GetValue();
  }
  catch (...)
  {
    return 0.0;
  }
}

bool OCCTDimensionGetGeometry(OCCTDimensionRef dim, OCCTDimensionGeometry* out)
{
  if (!dim || !out || dim->dim.IsNull())
    return false;
  try
  {
    memset(out, 0, sizeof(OCCTDimensionGeometry));
    out->kind    = dim->kind;
    out->value   = dim->dim->GetValue();
    out->isValid = dim->dim->IsValid();

    switch (dim->kind)
    {
      case OCCTDimensionKindLength: {
        Handle(PrsDim_LengthDimension) ld = Handle(PrsDim_LengthDimension)::DownCast(dim->dim);
        if (ld.IsNull())
          return false;
        gp_Pnt fp           = ld->FirstPoint();
        gp_Pnt sp           = ld->SecondPoint();
        out->firstPoint[0]  = fp.X();
        out->firstPoint[1]  = fp.Y();
        out->firstPoint[2]  = fp.Z();
        out->secondPoint[0] = sp.X();
        out->secondPoint[1] = sp.Y();
        out->secondPoint[2] = sp.Z();
        gp_Pnt mid((fp.X() + sp.X()) / 2, (fp.Y() + sp.Y()) / 2, (fp.Z() + sp.Z()) / 2);
        out->textPosition[0] = mid.X();
        out->textPosition[1] = mid.Y();
        out->textPosition[2] = mid.Z();
        break;
      }
      case OCCTDimensionKindRadius: {
        Handle(PrsDim_RadiusDimension) rd = Handle(PrsDim_RadiusDimension)::DownCast(dim->dim);
        if (rd.IsNull())
          return false;
        gp_Circ circ         = rd->Circle();
        gp_Pnt  center       = circ.Location();
        gp_Pnt  anchor       = rd->AnchorPoint();
        out->firstPoint[0]   = anchor.X();
        out->firstPoint[1]   = anchor.Y();
        out->firstPoint[2]   = anchor.Z();
        out->centerPoint[0]  = center.X();
        out->centerPoint[1]  = center.Y();
        out->centerPoint[2]  = center.Z();
        gp_Dir axis          = circ.Axis().Direction();
        out->circleNormal[0] = axis.X();
        out->circleNormal[1] = axis.Y();
        out->circleNormal[2] = axis.Z();
        out->circleRadius    = circ.Radius();
        gp_Pnt mid((center.X() + anchor.X()) / 2,
                   (center.Y() + anchor.Y()) / 2,
                   (center.Z() + anchor.Z()) / 2);
        out->textPosition[0] = mid.X();
        out->textPosition[1] = mid.Y();
        out->textPosition[2] = mid.Z();
        break;
      }
      case OCCTDimensionKindAngle: {
        Handle(PrsDim_AngleDimension) ad = Handle(PrsDim_AngleDimension)::DownCast(dim->dim);
        if (ad.IsNull())
          return false;
        gp_Pnt fp           = ad->FirstPoint();
        gp_Pnt sp           = ad->SecondPoint();
        gp_Pnt cp           = ad->CenterPoint();
        out->firstPoint[0]  = fp.X();
        out->firstPoint[1]  = fp.Y();
        out->firstPoint[2]  = fp.Z();
        out->secondPoint[0] = sp.X();
        out->secondPoint[1] = sp.Y();
        out->secondPoint[2] = sp.Z();
        out->centerPoint[0] = cp.X();
        out->centerPoint[1] = cp.Y();
        out->centerPoint[2] = cp.Z();
        // Text position on arc bisector
        gp_Vec v1(cp, fp);
        gp_Vec v2(cp, sp);
        if (v1.Magnitude() > 1e-10 && v2.Magnitude() > 1e-10)
        {
          v1.Normalize();
          v2.Normalize();
          gp_Vec bisector = v1 + v2;
          if (bisector.Magnitude() > 1e-10)
          {
            bisector.Normalize();
            double dist          = fp.Distance(cp) * 0.7;
            gp_Pnt textPt        = cp.Translated(bisector * dist);
            out->textPosition[0] = textPt.X();
            out->textPosition[1] = textPt.Y();
            out->textPosition[2] = textPt.Z();
          }
        }
        break;
      }
      case OCCTDimensionKindDiameter: {
        Handle(PrsDim_DiameterDimension) dd = Handle(PrsDim_DiameterDimension)::DownCast(dim->dim);
        if (dd.IsNull())
          return false;
        gp_Circ circ   = dd->Circle();
        gp_Pnt  center = circ.Location();
        gp_Pnt  anchor = dd->AnchorPoint();
        // Diameter line: from anchor through center to opposite side
        gp_Vec toAnchor(center, anchor);
        gp_Pnt opposite      = center.Translated(-toAnchor);
        out->firstPoint[0]   = anchor.X();
        out->firstPoint[1]   = anchor.Y();
        out->firstPoint[2]   = anchor.Z();
        out->secondPoint[0]  = opposite.X();
        out->secondPoint[1]  = opposite.Y();
        out->secondPoint[2]  = opposite.Z();
        out->centerPoint[0]  = center.X();
        out->centerPoint[1]  = center.Y();
        out->centerPoint[2]  = center.Z();
        gp_Dir axis          = circ.Axis().Direction();
        out->circleNormal[0] = axis.X();
        out->circleNormal[1] = axis.Y();
        out->circleNormal[2] = axis.Z();
        out->circleRadius    = circ.Radius();
        out->textPosition[0] = center.X();
        out->textPosition[1] = center.Y();
        out->textPosition[2] = center.Z();
        break;
      }
    }
    return true;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTDimensionSetCustomValue(OCCTDimensionRef dim, double value)
{
  if (!dim || dim->dim.IsNull())
    return;
  try
  {
    dim->dim->SetCustomValue(value);
  }
  catch (...)
  {
  }
}

bool OCCTDimensionIsValid(OCCTDimensionRef dim)
{
  if (!dim || dim->dim.IsNull())
    return false;
  try
  {
    return dim->dim->IsValid();
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTDimensionGetKind(OCCTDimensionRef dim)
{
  if (!dim)
    return -1;
  return dim->kind;
}

// --- Text Label ---

OCCTTextLabelRef OCCTTextLabelCreate(const char* text, double x, double y, double z)
{
  if (!text)
    return nullptr;
  try
  {
    Handle(AIS_TextLabel) label = new AIS_TextLabel();
    label->SetText(TCollection_ExtendedString(text, Standard_True));
    label->SetPosition(gp_Pnt(x, y, z));
    auto* result  = new OCCTTextLabel();
    result->label = label;
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTTextLabelRelease(OCCTTextLabelRef label)
{
  delete label;
}

void OCCTTextLabelSetText(OCCTTextLabelRef label, const char* text)
{
  if (!label || !text || label->label.IsNull())
    return;
  try
  {
    label->label->SetText(TCollection_ExtendedString(text, Standard_True));
  }
  catch (...)
  {
  }
}

void OCCTTextLabelSetPosition(OCCTTextLabelRef label, double x, double y, double z)
{
  if (!label || label->label.IsNull())
    return;
  try
  {
    label->label->SetPosition(gp_Pnt(x, y, z));
  }
  catch (...)
  {
  }
}

void OCCTTextLabelSetHeight(OCCTTextLabelRef label, double height)
{
  if (!label || label->label.IsNull())
    return;
  try
  {
    label->label->SetHeight(height);
  }
  catch (...)
  {
  }
}

bool OCCTTextLabelGetInfo(OCCTTextLabelRef label, OCCTTextLabelInfo* out)
{
  if (!label || !out || label->label.IsNull())
    return false;
  try
  {
    memset(out, 0, sizeof(OCCTTextLabelInfo));
    gp_Pnt pos       = label->label->Position();
    out->position[0] = pos.X();
    out->position[1] = pos.Y();
    out->position[2] = pos.Z();

    // Get text as UTF-8
    TCollection_ExtendedString extStr = label->label->Text();
    TCollection_AsciiString    ascii(extStr);
    strncpy(out->text, ascii.ToCString(), 255);
    out->text[255] = '\0';

    out->height = 12.0; // Default height
    return true;
  }
  catch (...)
  {
    return false;
  }
}

// --- Point Cloud ---

static void computePointCloudBounds(OCCTPointCloud* cloud)
{
  if (cloud->count == 0)
  {
    memset(cloud->minBound, 0, sizeof(cloud->minBound));
    memset(cloud->maxBound, 0, sizeof(cloud->maxBound));
    return;
  }
  cloud->minBound[0] = cloud->maxBound[0] = cloud->coords[0];
  cloud->minBound[1] = cloud->maxBound[1] = cloud->coords[1];
  cloud->minBound[2] = cloud->maxBound[2] = cloud->coords[2];
  for (int32_t i = 1; i < cloud->count; ++i)
  {
    int idx = i * 3;
    for (int j = 0; j < 3; ++j)
    {
      if (cloud->coords[idx + j] < cloud->minBound[j])
        cloud->minBound[j] = cloud->coords[idx + j];
      if (cloud->coords[idx + j] > cloud->maxBound[j])
        cloud->maxBound[j] = cloud->coords[idx + j];
    }
  }
}

OCCTPointCloudRef OCCTPointCloudCreate(const double* coords, int32_t count)
{
  if (!coords || count <= 0)
    return nullptr;
  try
  {
    auto* cloud  = new OCCTPointCloud();
    cloud->count = count;
    cloud->coords.assign(coords, coords + count * 3);
    computePointCloudBounds(cloud);
    return cloud;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTPointCloudRef OCCTPointCloudCreateColored(const double* coords,
                                              const float*  colors,
                                              int32_t       count)
{
  if (!coords || !colors || count <= 0)
    return nullptr;
  try
  {
    auto* cloud  = new OCCTPointCloud();
    cloud->count = count;
    cloud->coords.assign(coords, coords + count * 3);
    cloud->colors.assign(colors, colors + count * 3);
    computePointCloudBounds(cloud);
    return cloud;
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTPointCloudRelease(OCCTPointCloudRef cloud)
{
  delete cloud;
}

int32_t OCCTPointCloudGetCount(OCCTPointCloudRef cloud)
{
  if (!cloud)
    return 0;
  return cloud->count;
}

bool OCCTPointCloudGetBounds(OCCTPointCloudRef cloud, double* outMinXYZ, double* outMaxXYZ)
{
  if (!cloud || !outMinXYZ || !outMaxXYZ || cloud->count == 0)
    return false;
  memcpy(outMinXYZ, cloud->minBound, 3 * sizeof(double));
  memcpy(outMaxXYZ, cloud->maxBound, 3 * sizeof(double));
  return true;
}

int32_t OCCTPointCloudGetPoints(OCCTPointCloudRef cloud, double* outCoords, int32_t maxCount)
{
  if (!cloud || !outCoords || maxCount <= 0)
    return 0;
  int32_t n = std::min(maxCount, cloud->count);
  memcpy(outCoords, cloud->coords.data(), n * 3 * sizeof(double));
  return n;
}

int32_t OCCTPointCloudGetColors(OCCTPointCloudRef cloud, float* outColors, int32_t maxCount)
{
  if (!cloud || !outColors || maxCount <= 0 || cloud->colors.empty())
    return 0;
  int32_t n = std::min(maxCount, cloud->count);
  memcpy(outColors, cloud->colors.data(), n * 3 * sizeof(float));
  return n;
}
