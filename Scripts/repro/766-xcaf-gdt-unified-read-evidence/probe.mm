// Kernel-parity probe for #766 (OCCTXCAFTests). Calls the OCCT API the bridge calls, with the
// test's inputs, and prints what the kernel returns. Build line: CLAUDE.md "Compile a Ground
// Truth C++ Test", headers/lib from the pinned OCCT.xcframework.
#include <BRepPrimAPI_MakeBox.hxx>
#include <TDocStd_Application.hxx>
#include <TDocStd_Document.hxx>
#include <TDF_Label.hxx>
#include <TDF_LabelSequence.hxx>
#include <TDF_Tool.hxx>
#include <TCollection_AsciiString.hxx>
#include <TCollection_ExtendedString.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDoc_ShapeTool.hxx>
#include <XCAFDoc_ColorTool.hxx>
#include <XCAFDoc_VisMaterialTool.hxx>
#include <TopoDS_Shape.hxx>
#include <cstdio>

// OCCTDocument(): a private TDocStd_Application (#371), NewDocument("MDTV-XCAF"), then the three
// XCAF tools occtDocumentInit fetches.
static Handle(TDocStd_Document) newDoc(Handle(TDocStd_Application)& app)
{
  app = new TDocStd_Application();
  Handle(TDocStd_Document) d;
  app->NewDocument("MDTV-XCAF", d);
  XCAFDoc_DocumentTool::ShapeTool(d->Main());
  XCAFDoc_DocumentTool::ColorTool(d->Main());
  XCAFDoc_DocumentTool::VisMaterialTool(d->Main());
  return d;
}

// getLabelForTag: tag 0 is Main, otherwise Main().FindChild(tag, create).
static TDF_Label tagLabel(const Handle(TDocStd_Document)& d, int tag)
{
  return tag == 0 ? d->Main() : d->Main().FindChild(tag, Standard_True);
}

// OCCTShapeCreateBox: centred on the origin.
static TopoDS_Shape centredBox(double w, double h, double dp)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -dp / 2), w, h, dp).Shape();
}

static const char* tf(bool b) { return b ? "true" : "false"; }

#include <Standard_OutOfRange.hxx>
#include <TCollection_HAsciiString.hxx>
#include <TColStd_HArray1OfReal.hxx>
#include <XCAFDimTolObjects_AngularQualifier.hxx>
#include <XCAFDimTolObjects_DatumModifWithValue.hxx>
#include <XCAFDimTolObjects_DatumObject.hxx>
#include <XCAFDimTolObjects_DimensionFormVariance.hxx>
#include <XCAFDimTolObjects_DimensionGrade.hxx>
#include <XCAFDimTolObjects_DimensionObject.hxx>
#include <XCAFDimTolObjects_DimensionQualifier.hxx>
#include <XCAFDimTolObjects_DimensionType.hxx>
#include <XCAFDimTolObjects_GeomToleranceMatReqModif.hxx>
#include <XCAFDimTolObjects_GeomToleranceObject.hxx>
#include <XCAFDimTolObjects_GeomToleranceType.hxx>
#include <XCAFDimTolObjects_GeomToleranceTypeValue.hxx>
#include <XCAFDimTolObjects_GeomToleranceZoneModif.hxx>
#include <XCAFDoc_Datum.hxx>
#include <XCAFDoc_Dimension.hxx>
#include <XCAFDoc_DimTolTool.hxx>
#include <XCAFDoc_GeomTolerance.hxx>

// Kernel-parity probe for the #996 GDT unified read surface tests (GDTUnifiedReadTests.swift).
// Every scenario is built the way the bridge builds it (OCCTDocumentCreateDimension / CreateGeomTolerance /
// CreateDatum, OCCTDocumentSetDimensionBounds / SetDimensionTolerance / SetDimensionClassOfTolerance) on a
// document initialised like OCCTDocument(), then read back through a fresh label lookup and GetObject(), which
// is what OCCTDocumentGetDimensionInfo does. The earlier probe in 766-xcaf-gdt-unified-read/ measured detached
// DimensionObjects; this one measures the same quantities through the document.
struct UDoc
{
  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    d;
  Handle(XCAFDoc_DimTolTool)  t;
  TDF_Label                   shape;
};

static void uInit(UDoc& u, double w, double h, double dp)
{
  u.d     = newDoc(u.app);
  u.t     = XCAFDoc_DocumentTool::DimTolTool(u.d->Main());
  u.shape = XCAFDoc_DocumentTool::ShapeTool(u.d->Main())->AddShape(centredBox(w, h, dp), false);
}

// occtDocumentCreateDimensionImpl
static int uAddDim(UDoc& u, XCAFDimTolObjects_DimensionType ty, double value, bool withTol, double lo, double up)
{
  Handle(XCAFDimTolObjects_DimensionObject) o = new XCAFDimTolObjects_DimensionObject();
  o->SetQualifier(XCAFDimTolObjects_DimensionQualifier_None);
  o->SetAngularQualifier(XCAFDimTolObjects_AngularQualifier_None);
  o->SetNbOfDecimalPlaces(0, 0);
  o->SetClassOfTolerance(false, XCAFDimTolObjects_DimensionFormVariance_None, XCAFDimTolObjects_DimensionGrade_IT01);
  o->SetType(ty);
  Handle(TColStd_HArray1OfReal) vals = new TColStd_HArray1OfReal(1, 1);
  vals->SetValue(1, value);
  o->SetValues(vals);
  if (withTol)
  {
    const bool a = o->SetLowerTolValue(lo);
    const bool b = o->SetUpperTolValue(up);
    printf("  creation tolerance: SetLowerTolValue=%s SetUpperTolValue=%s readback=(%g, %g)\n", tf(a), tf(b),
           o->GetLowerTolValue(), o->GetUpperTolValue());
    if (!(a && b && o->GetLowerTolValue() == lo && o->GetUpperTolValue() == up))
      return -1;
  }
  TDF_Label         dl = u.t->AddDimension();
  TDF_LabelSequence seq;
  seq.Append(u.shape);
  u.t->SetDimension(seq, seq, dl);
  Handle(XCAFDoc_Dimension) da;
  if (!dl.FindAttribute(XCAFDoc_Dimension::GetID(), da))
    return -1;
  da->SetObject(o);
  TDF_LabelSequence labels;
  u.t->GetDimensionLabels(labels);
  return labels.Length() - 1;
}

// OCCTDocumentCreateGeomTolerance
static int uAddTol(UDoc& u, XCAFDimTolObjects_GeomToleranceType ty, double value)
{
  TDF_Label         tl = u.t->AddGeomTolerance();
  TDF_LabelSequence seq;
  seq.Append(u.shape);
  u.t->SetGeomTolerance(seq, tl);
  Handle(XCAFDoc_GeomTolerance) ta;
  if (!tl.FindAttribute(XCAFDoc_GeomTolerance::GetID(), ta))
    return -1;
  Handle(XCAFDimTolObjects_GeomToleranceObject) o = new XCAFDimTolObjects_GeomToleranceObject();
  o->SetTypeOfValue(XCAFDimTolObjects_GeomToleranceTypeValue_None);
  o->SetMaterialRequirementModifier(XCAFDimTolObjects_GeomToleranceMatReqModif_None);
  o->SetZoneModifier(XCAFDimTolObjects_GeomToleranceZoneModif_None);
  o->SetValueOfZoneModifier(0.0);
  o->SetMaxValueModifier(0.0);
  o->SetType(ty);
  o->SetValue(value);
  ta->SetObject(o);
  TDF_LabelSequence labels;
  u.t->GetGeomToleranceLabels(labels);
  return labels.Length() - 1;
}

// OCCTDocumentCreateDatum
static int uAddDatum(UDoc& u, const char* name)
{
  TDF_Label             dl = u.t->AddDatum();
  Handle(XCAFDoc_Datum) da;
  if (!dl.FindAttribute(XCAFDoc_Datum::GetID(), da))
    return -1;
  Handle(XCAFDimTolObjects_DatumObject) o = new XCAFDimTolObjects_DatumObject();
  o->SetPosition(0);
  o->SetModifierWithValue(XCAFDimTolObjects_DatumModifWithValue_None, 0.0);
  o->SetName(new TCollection_HAsciiString(name));
  da->SetObject(o);
  TDF_LabelSequence labels;
  u.t->GetDatumLabels(labels);
  return labels.Length() - 1;
}

// occtDocumentGdtObjectAtImpl for the three kinds: index guard, then label, attribute and object.
static bool uDimAt(UDoc& u, int index, Handle(XCAFDoc_Dimension)& a, Handle(XCAFDimTolObjects_DimensionObject)& o)
{
  if (index < 0)
    return false;
  TDF_LabelSequence l;
  u.t->GetDimensionLabels(l);
  if (index >= l.Length())
    return false;
  if (!l.Value(index + 1).FindAttribute(XCAFDoc_Dimension::GetID(), a))
    return false;
  o = a->GetObject();
  return !o.IsNull();
}

static bool uTolAt(UDoc& u, int index, Handle(XCAFDoc_GeomTolerance)& a, Handle(XCAFDimTolObjects_GeomToleranceObject)& o)
{
  if (index < 0)
    return false;
  TDF_LabelSequence l;
  u.t->GetGeomToleranceLabels(l);
  if (index >= l.Length())
    return false;
  if (!l.Value(index + 1).FindAttribute(XCAFDoc_GeomTolerance::GetID(), a))
    return false;
  o = a->GetObject();
  return !o.IsNull();
}

static bool uDatumAt(UDoc& u, int index, Handle(XCAFDoc_Datum)& a, Handle(XCAFDimTolObjects_DatumObject)& o)
{
  if (index < 0)
    return false;
  TDF_LabelSequence l;
  u.t->GetDatumLabels(l);
  if (index >= l.Length())
    return false;
  if (!l.Value(index + 1).FindAttribute(XCAFDoc_Datum::GetID(), a))
    return false;
  o = a->GetObject();
  return !o.IsNull();
}

// OCCTDocumentSetDimensionBounds
static bool uSetBounds(UDoc& u, int index, double lo, double up)
{
  Handle(XCAFDoc_Dimension)                 a;
  Handle(XCAFDimTolObjects_DimensionObject) o;
  if (!uDimAt(u, index, a, o))
    return false;
  if (o->IsDimWithPlusMinusTolerance())
    return false;
  o->SetLowerBound(lo);
  o->SetUpperBound(up);
  if (!o->IsDimWithRange() || o->GetLowerBound() != lo || o->GetUpperBound() != up)
    return false;
  a->SetObject(o);
  return true;
}

// OCCTDocumentSetDimensionTolerance (occtDimensionApplyTolerance), printing the two setter returns
static bool uSetTol(UDoc& u, int index, double lo, double up)
{
  Handle(XCAFDoc_Dimension)                 a;
  Handle(XCAFDimTolObjects_DimensionObject) o;
  if (!uDimAt(u, index, a, o))
    return false;
  const bool lowerOk = o->SetLowerTolValue(lo);
  const bool upperOk = o->SetUpperTolValue(up);
  const bool applied = lowerOk && upperOk && o->GetLowerTolValue() == lo && o->GetUpperTolValue() == up;
  printf("  SetLowerTolValue=%s SetUpperTolValue=%s readback matches=%s -> applied=%s\n", tf(lowerOk), tf(upperOk),
         tf(o->GetLowerTolValue() == lo && o->GetUpperTolValue() == up), tf(applied));
  if (!applied)
    return false;
  a->SetObject(o);
  return true;
}

// OCCTDocumentSetDimensionClassOfTolerance
static bool uSetClass(UDoc& u, int index, bool hole, XCAFDimTolObjects_DimensionFormVariance fv, XCAFDimTolObjects_DimensionGrade g)
{
  Handle(XCAFDoc_Dimension)                 a;
  Handle(XCAFDimTolObjects_DimensionObject) o;
  if (!uDimAt(u, index, a, o))
    return false;
  o->SetClassOfTolerance(hole, fv, g);
  a->SetObject(o);
  return true;
}

// The read side of OCCTDocumentGetDimensionInfo, through a fresh lookup.
static void uShow(const char* what, UDoc& u, int index)
{
  Handle(XCAFDoc_Dimension)                 a;
  Handle(XCAFDimTolObjects_DimensionObject) o;
  if (!uDimAt(u, index, a, o))
  {
    printf("%s: no readable dimension at index %d\n", what, index);
    return;
  }
  Handle(TColStd_HArray1OfReal) vals = o->GetValues();
  printf("%s: type=%d range=%s plusMinus=%s values=%d value=%g lowerBound=%g upperBound=%g lowerTol=%g upperTol=%g class=%s",
         what, (int)o->GetType(), tf(o->IsDimWithRange()), tf(o->IsDimWithPlusMinusTolerance()), vals.IsNull() ? 0 : vals->Length(),
         o->GetValue(), o->GetLowerBound(), o->GetUpperBound(), o->GetLowerTolValue(), o->GetUpperTolValue(),
         tf(o->IsDimWithClassOfTolerance()));
  if (o->IsDimWithClassOfTolerance())
  {
    bool                                    hole = false;
    XCAFDimTolObjects_DimensionFormVariance fv   = XCAFDimTolObjects_DimensionFormVariance_None;
    XCAFDimTolObjects_DimensionGrade        g    = XCAFDimTolObjects_DimensionGrade_IT01;
    const bool                              got  = o->GetClassOfTolerance(hole, fv, g);
    printf(" isHole=%s formVariance=%d grade=%d (GetClassOfTolerance=%s)", tf(hole), (int)fv, (int)g, tf(got));
  }
  printf("\n");
}

static bool sameDim(const Handle(XCAFDimTolObjects_DimensionObject)& x, const Handle(XCAFDimTolObjects_DimensionObject)& y)
{
  return x->GetType() == y->GetType() && x->GetValue() == y->GetValue() && x->IsDimWithRange() == y->IsDimWithRange()
         && x->IsDimWithPlusMinusTolerance() == y->IsDimWithPlusMinusTolerance() && x->GetLowerBound() == y->GetLowerBound()
         && x->GetUpperBound() == y->GetUpperBound() && x->GetLowerTolValue() == y->GetLowerTolValue()
         && x->GetUpperTolValue() == y->GetUpperTolValue() && x->GetQualifier() == y->GetQualifier()
         && x->IsDimWithClassOfTolerance() == y->IsDimWithClassOfTolerance();
}

// populatedDocumentReadsThroughOneFamily
static void populated()
{
  UDoc u;
  uInit(u, 100, 50, 25);
  uAddDim(u, XCAFDimTolObjects_DimensionType_Size_Diameter, 20.0, true, -0.3, 0.7);
  uAddTol(u, XCAFDimTolObjects_GeomToleranceType_Perpendicularity, 0.05);
  uAddDatum(u, "A");

  TDF_LabelSequence dl, tl, al;
  u.t->GetDimensionLabels(dl);
  u.t->GetGeomToleranceLabels(tl);
  u.t->GetDatumLabels(al);
  printf("[populated] labels: dimensions=%d geom tolerances=%d datums=%d\n", dl.Length(), tl.Length(), al.Length());

  // The plural accessor is (0..<count).compactMap { singular($0) }, so its length is the number of indices whose
  // entry reads: the kernel counterpart is the number of labels whose attribute and object read back.
  int rd = 0, rt = 0, ra = 0;
  for (int i = 0; i < dl.Length(); i++)
  {
    Handle(XCAFDoc_Dimension)                 a;
    Handle(XCAFDimTolObjects_DimensionObject) o;
    rd += uDimAt(u, i, a, o) ? 1 : 0;
  }
  for (int i = 0; i < tl.Length(); i++)
  {
    Handle(XCAFDoc_GeomTolerance)                 a;
    Handle(XCAFDimTolObjects_GeomToleranceObject) o;
    rt += uTolAt(u, i, a, o) ? 1 : 0;
  }
  for (int i = 0; i < al.Length(); i++)
  {
    Handle(XCAFDoc_Datum)                 a;
    Handle(XCAFDimTolObjects_DatumObject) o;
    ra += uDatumAt(u, i, a, o) ? 1 : 0;
  }
  printf("[populated] readable entries: dimensions=%d geom tolerances=%d datums=%d\n", rd, rt, ra);

  // Entry 0 of each kind, read twice through two independent lookups (the singular and the first plural element
  // both resolve to labels.Value(1)), and the fields the Swift value types carry.
  Handle(XCAFDoc_Dimension)                 da1, da2;
  Handle(XCAFDimTolObjects_DimensionObject) d1, d2;
  const bool                                gotD = uDimAt(u, 0, da1, d1) && uDimAt(u, 0, da2, d2);
  printf("[populated] dimension entry 0: index=0 type=%d value=%g (read twice, all fields equal=%s)\n", (int)d1->GetType(), d1->GetValue(),
         tf(gotD && sameDim(d1, d2)));

  Handle(XCAFDoc_GeomTolerance)                 ta1, ta2;
  Handle(XCAFDimTolObjects_GeomToleranceObject) t1, t2;
  const bool                                    gotT = uTolAt(u, 0, ta1, t1) && uTolAt(u, 0, ta2, t2);
  const bool sameT = gotT && t1->GetType() == t2->GetType() && t1->GetValue() == t2->GetValue()
                     && t1->GetTypeOfValue() == t2->GetTypeOfValue() && t1->GetZoneModifier() == t2->GetZoneModifier()
                     && t1->GetMaterialRequirementModifier() == t2->GetMaterialRequirementModifier();
  printf("[populated] geom tolerance entry 0: index=0 type=%d value=%g (read twice, all fields equal=%s)\n", (int)t1->GetType(),
         t1->GetValue(), tf(sameT));

  Handle(XCAFDoc_Datum)                 aa1, aa2;
  Handle(XCAFDimTolObjects_DatumObject) x1, x2;
  const bool                            gotA = uDatumAt(u, 0, aa1, x1) && uDatumAt(u, 0, aa2, x2);
  const bool sameA = gotA && TCollection_AsciiString(x1->GetName()->ToCString()) == TCollection_AsciiString(x2->GetName()->ToCString())
                     && x1->GetPosition() == x2->GetPosition();
  printf("[populated] datum entry 0: index=0 name=\"%s\" position=%d (read twice, all fields equal=%s)\n", x1->GetName()->ToCString(),
         (int)x1->GetPosition(), tf(sameA));
}

// rangeDimensionKeepsItsBounds
static void range()
{
  UDoc u;
  uInit(u, 100, 50, 25);
  const int idx = uAddDim(u, XCAFDimTolObjects_DimensionType_Size_Diameter, 10.0, false, 0, 0);
  const bool ok = uSetBounds(u, idx, 10.0, 12.0);
  printf("[range] created at index %d, SetLowerBound(10) SetUpperBound(12) accepted=%s\n", idx, tf(ok));
  uShow("[range] 10..12", u, idx);
}

// plusMinusDimensionKeepsToleranceOrder
static void plusMinus()
{
  UDoc u;
  uInit(u, 10, 10, 10);
  const int idx = uAddDim(u, XCAFDimTolObjects_DimensionType_Size_Radius, 20.0, true, -0.3, 0.7);
  uShow("[plus/minus] 20 -0.3/+0.7", u, idx);
}

// simpleDimensionHasNoBoundsOrTolerances
static void simpleDim()
{
  UDoc u;
  uInit(u, 10, 10, 10);
  const int idx = uAddDim(u, XCAFDimTolObjects_DimensionType_Size_Thickness, 3.5, false, 0, 0);
  uShow("[simple] thickness 3.5", u, idx);
}

// classOfToleranceIsReadBack
static void classH7()
{
  UDoc u;
  uInit(u, 10, 10, 10);
  const int  idx = uAddDim(u, XCAFDimTolObjects_DimensionType_Size_Diameter, 20.0, false, 0, 0);
  const bool ok  = uSetClass(u, idx, true, XCAFDimTolObjects_DimensionFormVariance_H, XCAFDimTolObjects_DimensionGrade_IT7);
  printf("[class h7] SetClassOfTolerance(hole, H, IT7) accepted=%s\n", tf(ok));
  uShow("[class h7] after", u, idx);
}

// rangeDimensionCanCarryAClassOfTolerance
static void classRange()
{
  UDoc u;
  uInit(u, 10, 10, 10);
  const int  idx = uAddDim(u, XCAFDimTolObjects_DimensionType_Size_Diameter, 10.0, false, 0, 0);
  const bool ok1 = uSetBounds(u, idx, 10.0, 12.0);
  const bool ok2 = uSetClass(u, idx, false, XCAFDimTolObjects_DimensionFormVariance_JS, XCAFDimTolObjects_DimensionGrade_IT9);
  printf("[class range] bounds accepted=%s, SetClassOfTolerance(shaft, JS, IT9) accepted=%s\n", tf(ok1), tf(ok2));
  uShow("[class range] after", u, idx);
}

// toleranceOnARangeDimensionIsRefused
static void refused()
{
  UDoc u;
  uInit(u, 10, 10, 10);
  const int  idx = uAddDim(u, XCAFDimTolObjects_DimensionType_Size_Diameter, 10.0, false, 0, 0);
  const bool ok  = uSetBounds(u, idx, 10.0, 12.0);
  printf("[refused] range 10..12 built, accepted=%s\n", tf(ok));
  uShow("[refused] before", u, idx);
  const bool tol = uSetTol(u, idx, -0.3, 0.7);
  printf("[refused] tolerance -0.3/+0.7 on the range: returned=%s\n", tf(tol));
  uShow("[refused] after a fresh read", u, idx);
}

static bool seqRaises(const TDF_LabelSequence& s, int oneBased)
{
  try
  {
    (void)s.Value(oneBased);
    return false;
  }
  catch (const Standard_OutOfRange&)
  {
    return true;
  }
}

// mutatorsRejectAnOutOfRangeIndex
static void outOfRange()
{
  UDoc u;
  u.d = newDoc(u.app);
  u.t = XCAFDoc_DocumentTool::DimTolTool(u.d->Main());
  TDF_LabelSequence dl;
  u.t->GetDimensionLabels(dl);
  bool r1 = seqRaises(dl, 1), r0 = seqRaises(dl, 0);
  printf("[out of range] dimension labels=%d: Value(1) (index 0) raises Standard_OutOfRange=%s, Value(0) (index -1) raises=%s\n", dl.Length(),
         tf(r1), tf(r0));
  printf("[out of range] an entry exists to write to: index 0=%s, index -1=%s\n", tf(0 < dl.Length()), tf(-1 >= 0 && -1 < dl.Length()));
  Handle(XCAFDoc_Dimension)                 a;
  Handle(XCAFDimTolObjects_DimensionObject) o;
  printf("[out of range] the bridge's lookup at index 0: %s, at index -1: %s\n", tf(uDimAt(u, 0, a, o)), tf(uDimAt(u, -1, a, o)));
}

static void enums()
{
  printf("XCAFDimTolObjects_DimensionFormVariance: first=None (%d) last=ZC (%d) cases=%d\n", (int)XCAFDimTolObjects_DimensionFormVariance_None,
         (int)XCAFDimTolObjects_DimensionFormVariance_ZC, (int)XCAFDimTolObjects_DimensionFormVariance_ZC + 1);
  printf("XCAFDimTolObjects_DimensionGrade: first=IT01 (%d) last=IT18 (%d) cases=%d\n", (int)XCAFDimTolObjects_DimensionGrade_IT01,
         (int)XCAFDimTolObjects_DimensionGrade_IT18, (int)XCAFDimTolObjects_DimensionGrade_IT18 + 1);
}

int main()
{
  populated();
  range();
  plusMinus();
  simpleDim();
  classH7();
  classRange();
  refused();
  outOfRange();
  enums();
  return 0;
}
