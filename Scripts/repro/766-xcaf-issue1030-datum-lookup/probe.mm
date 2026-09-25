// Kernel-parity probe for #766 (OCCTXCAFTests). Calls the OCCT API the bridge calls, with the
// test's inputs, and prints what the kernel returns. Build line: CLAUDE.md "Compile a Ground
// Truth C++ Test", headers/lib from the pinned OCCT.xcframework.
#include <TDocStd_Application.hxx>
#include <TDocStd_Document.hxx>
#include <TDF_Label.hxx>
#include <TDF_LabelSequence.hxx>
#include <TCollection_ExtendedString.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDoc_ShapeTool.hxx>
#include <XCAFDoc_ColorTool.hxx>
#include <XCAFDoc_VisMaterialTool.hxx>
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

static const char* tf(bool b) { return b ? "true" : "false"; }

#include <XCAFDoc_DimTolTool.hxx>
#include <XCAFDoc_Datum.hxx>
#include <XCAFDoc_Editor.hxx>
#include <XCAFDimTolObjects_DatumObject.hxx>
#include <TDataStd_RealArray.hxx>
#include <TCollection_HAsciiString.hxx>

// Issue1030DatumLookupGuardTests: a datum written by OCCTDocumentCreateDatum, then the point child
// (tag 17) and plane-location child (tag 14) arrays the tests author, then XCAFDoc_Datum::GetObject,
// which is what every bridge read reaches. Pinned kernel carries patch 0029, so the point-without-
// plane shape must read rather than crash.
static TDF_Label makeDatum(const Handle(TDocStd_Document)& d)
{
  Handle(XCAFDoc_DimTolTool) t = XCAFDoc_DocumentTool::DimTolTool(d->Main());
  TDF_Label                  l = t->AddDatum();
  Handle(XCAFDoc_Datum)      a;
  l.FindAttribute(XCAFDoc_Datum::GetID(), a);
  Handle(XCAFDimTolObjects_DatumObject) o = new XCAFDimTolObjects_DatumObject();
  o->SetPosition(0);
  o->SetModifierWithValue(XCAFDimTolObjects_DatumModifWithValue_None, 0.0);
  o->SetName(new TCollection_HAsciiString("Datum1030"));
  a->SetObject(o);
  return l;
}

static void triple(const TDF_Label& l, int tag, double v, int lower = 1, int upper = 3)
{
  Handle(TDataStd_RealArray) arr = TDataStd_RealArray::Set(l.FindChild(tag, true), lower, upper);
  for (int i = lower; i <= upper; i++)
    arr->SetValue(i, v);
}

static void read(const char* what, const TDF_Label& l)
{
  Handle(XCAFDoc_Datum) a;
  l.FindAttribute(XCAFDoc_Datum::GetID(), a);
  Handle(XCAFDimTolObjects_DatumObject) o = a->GetObject();
  printf("%s: GetObject null=%s name=%s\n", what, tf(o.IsNull()),
         (o.IsNull() || o->GetName().IsNull()) ? "-" : o->GetName()->ToCString());
}

int main()
{
  Handle(TDocStd_Application) app;
  {
    Handle(TDocStd_Document) d = newDoc(app);
    TDF_Label                l = makeDatum(d);
    printf("fresh datum: child 17 exists=%s child 14 exists=%s, point array present=%s\n",
           tf(!l.FindChild(17, false).IsNull()), tf(!l.FindChild(14, false).IsNull()),
           tf(l.FindChild(17, false).IsAttribute(TDataStd_RealArray::GetID())));
    triple(l, 17, 7);
    Handle(TDataStd_RealArray) p;
    l.FindChild(17, false).FindAttribute(TDataStd_RealArray::GetID(), p);
    printf("point array written: bounds %d..%d value(1)=%g value(3)=%g\n", p->Lower(), p->Upper(), p->Value(1), p->Value(3));
    read("point, no plane location (the #1030 shape)", l);
    TDF_LabelSequence ls;
    XCAFDoc_DocumentTool::DimTolTool(d->Main())->GetDatumLabels(ls);
    printf("datum labels=%d\n", ls.Length());
  }
  {
    Handle(TDocStd_Document) d = newDoc(app);
    TDF_Label                l = makeDatum(d);
    triple(l, 14, 6);
    triple(l, 17, 7);
    read("point and plane location", l);
  }
  {
    Handle(TDocStd_Document) d = newDoc(app);
    TDF_Label                l = makeDatum(d);
    triple(l, 14, 6);
    triple(l, 17, 0, 1000000, 1000002);
    read("plane location 1..3, point at 1000000", l);
  }
  {
    Handle(TDocStd_Document) d = newDoc(app);
    TDF_Label                l = makeDatum(d);
    triple(l, 17, 0, 1, 2);
    read("point array of length 2", l);
  }
  {
    Handle(TDocStd_Document) d = newDoc(app);
    makeDatum(d);
    bool ok = XCAFDoc_Editor::RescaleGeometry(d->Main(), 2.0, true);
    printf("RescaleGeometry(Main, 2.0, force) with one readable datum=%s\n", tf(ok));
  }
  return 0;
}
