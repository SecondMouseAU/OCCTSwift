#include <gp_Ax2d.hxx>
#include <gp_Dir2d.hxx>
#include <gp_GTrsf2d.hxx>
#include <gp_Pnt2d.hxx>
#include <cstdio>
int main()
{
  printf("constructing gp_Dir2d(0, 0) the way OCCTGTrsf2dAffinity does...\n");
  fflush(stdout);
  gp_GTrsf2d gt;
  gt.SetAffinity(gp_Ax2d(gp_Pnt2d(1.0, 2.0), gp_Dir2d(0.0, 0.0)), 2.0);
  printf("survived, no throw\n");
  return 0;
}
