#include <BRep_Builder.hxx>
#include <BRepTools.hxx>
#include <TopoDS_Shape.hxx>
#include <ShapeUpgrade_UnifySameDomain.hxx>
#include <iostream>

int main() {
    TopoDS_Shape shape;
    BRep_Builder builder;
    BRepTools::Read(shape, "/tmp/issue348/unify-crash.brep", builder);
    std::cout << "Loaded shape, type=" << shape.ShapeType() << std::endl;

    ShapeUpgrade_UnifySameDomain unify(shape, true, true, false);
    unify.SetAngularTolerance(1.0 * M_PI / 180.0);
    std::cout << "Calling Build()..." << std::endl;
    unify.Build();
    std::cout << "Build() completed" << std::endl;
    TopoDS_Shape result = unify.Shape();
    std::cout << "Done" << std::endl;
    return 0;
}
