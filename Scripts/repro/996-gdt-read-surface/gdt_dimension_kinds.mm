// Ground truth for #996: how XCAFDimTolObjects_DimensionObject encodes a dimension's magnitude,
// and what OCCTDocumentGetDimensionInfo's pre-#996 formula reported for each kind.
//
// Build (from the repo root):
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/996-gdt-read-surface/gdt_dimension_kinds.mm -o /tmp/gdt_dimension_kinds
//   /tmp/gdt_dimension_kinds
//
// Three parts. Part 1 drives XCAFDimTolObjects_DimensionObject directly, which is where the
// encoding lives and where the Get*TolValue naming question is settled. Part 2 puts each object on
// a real TDF_Label through XCAFDoc_DimTolTool and reads it back exactly the way the bridge does, so
// the wrong answer is observed on the real path rather than inferred from part 1. Part 3 measures
// the mutators, whose contracts decide what the bridge's write path is allowed to report.

#include <TDocStd_Application.hxx>
#include <TDocStd_Document.hxx>
#include <TDF_Label.hxx>
#include <TDF_LabelSequence.hxx>
#include <TColStd_HArray1OfReal.hxx>
#include <XCAFDoc_DimTolTool.hxx>
#include <XCAFDoc_Dimension.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDoc_ShapeTool.hxx>
#include <XCAFDimTolObjects_DimensionObject.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <TopoDS_Shape.hxx>

#include <cstdio>

static void values(const Handle(XCAFDimTolObjects_DimensionObject) & obj)
{
  Handle(TColStd_HArray1OfReal) vals = obj->GetValues();
  printf("values=[");
  if (!vals.IsNull())
    for (int i = vals->Lower(); i <= vals->Upper(); ++i)
      printf("%s%g", i == vals->Lower() ? "" : ",", vals->Value(i));
  printf("]");
}

static void dump(const char* label, const Handle(XCAFDimTolObjects_DimensionObject) & obj)
{
  Handle(TColStd_HArray1OfReal) vals = obj->GetValues();
  printf("%-22s ", label);
  values(obj);
  printf("  len=%d  IsRange=%d IsPlusMinus=%d IsClassOfTol=%d\n",
         vals.IsNull() ? 0 : vals->Length(),
         (int)obj->IsDimWithRange(),
         (int)obj->IsDimWithPlusMinusTolerance(),
         (int)obj->IsDimWithClassOfTolerance());
  printf("%-22s GetValue=%g  GetLowerBound=%g GetUpperBound=%g  "
         "GetLowerTolValue=%g GetUpperTolValue=%g\n",
         "",
         obj->GetValue(),
         obj->GetLowerBound(),
         obj->GetUpperBound(),
         obj->GetLowerTolValue(),
         obj->GetUpperTolValue());
  // What OCCTDocumentGetDimensionInfo reported before #996: the FIRST values slot as `value`, plus
  // the two tolerance accessors, with nothing saying which of them applies.
  double bridgeValue = vals.IsNull() || vals->Length() == 0 ? 0.0 : vals->Value(vals->Lower());
  printf("%-22s bridge before #996 -> value=%g lowerTol=%g upperTol=%g\n",
         "",
         bridgeValue,
         obj->GetLowerTolValue(),
         obj->GetUpperTolValue());
}

int main()
{
  printf("== part 1: XCAFDimTolObjects_DimensionObject directly ==\n\n");

  Handle(XCAFDimTolObjects_DimensionObject) simple = new XCAFDimTolObjects_DimensionObject();
  simple->SetType(XCAFDimTolObjects_DimensionType_Size_Diameter);
  simple->SetValue(20.0);
  dump("simple 20", simple);

  Handle(XCAFDimTolObjects_DimensionObject) range = new XCAFDimTolObjects_DimensionObject();
  range->SetType(XCAFDimTolObjects_DimensionType_Size_Diameter);
  range->SetLowerBound(10.0);
  range->SetUpperBound(12.0);
  dump("range 10..12", range);

  Handle(XCAFDimTolObjects_DimensionObject) pm = new XCAFDimTolObjects_DimensionObject();
  pm->SetType(XCAFDimTolObjects_DimensionType_Size_Diameter);
  pm->SetValue(20.0);
  // Asymmetric on purpose: a symmetric -0.1/+0.1 pair cannot tell a correct accessor from a
  // swapped one, which is the whole question the header's swapped doc comments raise.
  pm->SetLowerTolValue(-0.3);
  pm->SetUpperTolValue(0.7);
  dump("plusMinus 20 -0.3+0.7", pm);

  Handle(XCAFDimTolObjects_DimensionObject) cls = new XCAFDimTolObjects_DimensionObject();
  cls->SetType(XCAFDimTolObjects_DimensionType_Size_Diameter);
  cls->SetValue(20.0);
  cls->SetClassOfTolerance(true,
                           XCAFDimTolObjects_DimensionFormVariance_H,
                           XCAFDimTolObjects_DimensionGrade_IT7);
  dump("classOfTol H7 hole", cls);
  {
    bool                                    hole  = false;
    XCAFDimTolObjects_DimensionFormVariance fv    = XCAFDimTolObjects_DimensionFormVariance_None;
    XCAFDimTolObjects_DimensionGrade        grade = XCAFDimTolObjects_DimensionGrade_IT01;
    bool                                    ok    = cls->GetClassOfTolerance(hole, fv, grade);
    printf("%-22s GetClassOfTolerance -> ok=%d hole=%d formVariance=%d grade=%d\n",
           "",
           (int)ok,
           (int)hole,
           (int)fv,
           (int)grade);
  }

  printf("\n-- which array slot does each tolerance accessor read --\n");
  {
    Handle(XCAFDimTolObjects_DimensionObject) probe = new XCAFDimTolObjects_DimensionObject();
    Handle(TColStd_HArray1OfReal)             raw   = new TColStd_HArray1OfReal(1, 3);
    raw->SetValue(1, 100.0);  // slot 1
    raw->SetValue(2, 200.0);  // slot 2
    raw->SetValue(3, 300.0);  // slot 3
    probe->SetValues(raw);
    printf("raw [100,200,300] -> GetValue=%g GetLowerTolValue=%g GetUpperTolValue=%g\n",
           probe->GetValue(),
           probe->GetLowerTolValue(),
           probe->GetUpperTolValue());
    printf("so slot 2 is the LOWER tolerance and slot 3 the UPPER, matching what the pm case above\n"
           "shows SetLowerTolValue/SetUpperTolValue write. The header's doc comments on\n"
           "GetUpperTolValue/GetLowerTolValue are swapped; the functions themselves are not.\n");
  }

  printf("\n== part 2: the same objects on a real document, read the way the bridge reads ==\n\n");

  Handle(TDocStd_Application) app = new TDocStd_Application();
  Handle(TDocStd_Document)    doc;
  app->NewDocument("BinXCAF", doc);
  Handle(XCAFDoc_ShapeTool)  shapeTool = XCAFDoc_DocumentTool::ShapeTool(doc->Main());
  Handle(XCAFDoc_DimTolTool) dimTol    = XCAFDoc_DimTolTool::Set(doc->Main());

  TopoDS_Shape      box      = BRepPrimAPI_MakeBox(100.0, 50.0, 25.0).Shape();
  TDF_Label         shapeLbl = shapeTool->AddShape(box, false);
  TDF_LabelSequence shapes;
  shapes.Append(shapeLbl);

  const Handle(XCAFDimTolObjects_DimensionObject) objs[4]  = {simple, range, pm, cls};
  const char*                                     names[4] = {"simple",
                                                              "range",
                                                              "plusMinus",
                                                              "classOfTol"};
  for (int i = 0; i < 4; ++i)
  {
    TDF_Label         dimLbl = dimTol->AddDimension();
    TDF_LabelSequence empty;
    dimTol->SetDimension(shapes, empty, dimLbl);
    Handle(XCAFDoc_Dimension) attr;
    dimLbl.FindAttribute(XCAFDoc_Dimension::GetID(), attr);
    attr->SetObject(objs[i]);
  }

  TDF_LabelSequence dimLabels;
  dimTol->GetDimensionLabels(dimLabels);
  printf("dimension labels: %d\n\n", dimLabels.Length());
  for (int i = 1; i <= dimLabels.Length(); ++i)
  {
    Handle(XCAFDoc_Dimension) attr;
    if (!dimLabels.Value(i).FindAttribute(XCAFDoc_Dimension::GetID(), attr))
      continue;
    Handle(XCAFDimTolObjects_DimensionObject) obj = attr->GetObject();
    dump(names[i - 1], obj);
  }

  printf("\n== part 3: what the mutators do, which is what the bridge write path may report ==\n\n");

  printf("-- SetLowerBound / SetUpperBound converge from either order --\n");
  {
    Handle(XCAFDimTolObjects_DimensionObject) o = new XCAFDimTolObjects_DimensionObject();
    o->SetValue(20.0);
    o->SetLowerBound(10.0);
    printf("  simple 20, SetLowerBound(10)  -> ");
    values(o);
    printf("\n");
    o->SetUpperBound(12.0);
    printf("  then SetUpperBound(12)        -> ");
    values(o);
    printf("  GetValue=%g\n", o->GetValue());

    Handle(XCAFDimTolObjects_DimensionObject) r = new XCAFDimTolObjects_DimensionObject();
    r->SetValue(20.0);
    r->SetUpperBound(12.0);
    printf("  simple 20, SetUpperBound(12)  -> ");
    values(r);
    printf("\n");
    r->SetLowerBound(10.0);
    printf("  then SetLowerBound(10)        -> ");
    values(r);
    printf("  GetValue=%g\n", r->GetValue());
    printf("  Each setter resets a non-range dimension to a degenerate range holding its own\n"
           "  argument twice, so either order ends at [10,12]. The bridge does not depend on one.\n");
  }

  printf("\n-- SetLowerTolValue / SetUpperTolValue refuse a range dimension --\n");
  {
    Handle(XCAFDimTolObjects_DimensionObject) s = new XCAFDimTolObjects_DimensionObject();
    s->SetValue(20.0);
    bool a = s->SetLowerTolValue(-0.3);
    bool b = s->SetUpperTolValue(0.7);
    printf("  on a simple dimension: SetLowerTolValue=%d SetUpperTolValue=%d  ", (int)a, (int)b);
    values(s);
    printf("\n");

    Handle(XCAFDimTolObjects_DimensionObject) r = new XCAFDimTolObjects_DimensionObject();
    r->SetLowerBound(10.0);
    r->SetUpperBound(12.0);
    bool c = r->SetLowerTolValue(-0.3);
    bool d = r->SetUpperTolValue(0.7);
    printf("  on a range dimension:  SetLowerTolValue=%d SetUpperTolValue=%d  ", (int)c, (int)d);
    values(r);
    printf("\n");
    printf("  So a bridge that discards these two return values reports success for a call that\n"
           "  changed nothing. OCCTDocumentSetDimensionTolerance now returns their conjunction.\n");
  }

  printf("\n-- SetValue overwrites the whole values array --\n");
  {
    Handle(XCAFDimTolObjects_DimensionObject) o = new XCAFDimTolObjects_DimensionObject();
    o->SetValue(20.0);
    o->SetLowerTolValue(-0.3);
    o->SetUpperTolValue(0.7);
    printf("  plusMinus            -> ");
    values(o);
    printf("\n");
    o->SetValue(30.0);
    printf("  after SetValue(30)   -> ");
    values(o);
    printf("  IsPlusMinus=%d\n", (int)o->IsDimWithPlusMinusTolerance());
  }

  printf("\n-- a class of tolerance is independent of the values array --\n");
  {
    Handle(XCAFDimTolObjects_DimensionObject) o = new XCAFDimTolObjects_DimensionObject();
    o->SetLowerBound(10.0);
    o->SetUpperBound(12.0);
    o->SetClassOfTolerance(true,
                           XCAFDimTolObjects_DimensionFormVariance_H,
                           XCAFDimTolObjects_DimensionGrade_IT7);
    printf("  range 10..12 + H7    -> ");
    values(o);
    printf("  IsRange=%d IsClassOfTol=%d\n",
           (int)o->IsDimWithRange(),
           (int)o->IsDimWithClassOfTolerance());
    printf("  This is why the Swift model carries `classOfTolerance` alongside `bounds` rather\n"
           "  than as a fourth Bounds case: the two are orthogonal in OCCT.\n");
  }

  printf("\n-- a dimension with no values array at all --\n");
  {
    Handle(XCAFDimTolObjects_DimensionObject) o = new XCAFDimTolObjects_DimensionObject();
    printf("  default-constructed  -> ");
    values(o);
    printf("  GetValues().IsNull()=%d GetValue=%g\n",
           (int)o->GetValues().IsNull(),
           o->GetValue());
    printf("  GetValue() answers 0 for a dimension that has no value. That 0 is the reason\n"
           "  Dimension.value is Double? and .unset is a Bounds case rather than a synonym for 0.\n");
  }

  return 0;
}
