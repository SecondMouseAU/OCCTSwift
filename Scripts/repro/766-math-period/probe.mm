// Epic #766 kernel-parity probe: PeriodTests. Same Quantity_Period calls and inputs as
// OCCTPeriodCreate, OCCTPeriodCreateFromSeconds, OCCTPeriodValues, OCCTPeriodTotalSeconds,
// OCCTPeriodAdd, OCCTPeriodSubtract, OCCTPeriodCompare, OCCTPeriodIsValid and
// OCCTPeriodIsValidSeconds.
#include <Quantity_Period.hxx>
#include <cstdio>

static void comps(const char* name, const Quantity_Period& p)
{
  int dd, hh, mn, ss, mis, mics, s, us;
  p.Values(dd, hh, mn, ss, mis, mics);
  p.Values(s, us);
  printf("%s: days=%d hours=%d minutes=%d seconds=%d ms=%d us=%d | sec=%d usec=%d\n",
         name, dd, hh, mn, ss, mis, mics, s, us);
}

int main()
{
  comps("createFromComponents Period(1, 2, 30, 15)", Quantity_Period(1, 2, 30, 15, 0, 0));
  comps("createFromSeconds Period(3661, 500)", Quantity_Period(3661, 500));
  comps("addPeriods 1h + 30min", Quantity_Period(0, 1, 0, 0, 0, 0) + Quantity_Period(0, 0, 30, 0, 0, 0));
  comps("subtractPeriods 2h - 30min", Quantity_Period(0, 2, 0, 0, 0, 0) - Quantity_Period(0, 0, 30, 0, 0, 0));
  {
    Quantity_Period a(0, 1, 30, 0, 0, 0), b(5400, 0);
    printf("equality 1h30 == 5400s: %d\n", (int)(a == b));
  }
  {
    Quantity_Period a(0, 1, 0, 0, 0, 0), b(0, 2, 0, 0, 0, 0);
    printf("comparison 1h < 2h: %d, 2h > 1h: %d\n", (int)(a < b), (int)(b > a));
  }
  printf("isValidComponents (1, 2, 30): %d, (-1): %d\n",
         (int)Quantity_Period::IsValid(1, 2, 30, 0, 0, 0),
         (int)Quantity_Period::IsValid(-1, 0, 0, 0, 0, 0));
  printf("isValidSeconds 100: %d, -1: %d\n",
         (int)Quantity_Period::IsValid(100, 0),
         (int)Quantity_Period::IsValid(-1, 0));
  comps("withMilliseconds Period(s 1, ms 500, us 250)", Quantity_Period(0, 0, 0, 1, 500, 250));
  printf("zeroPeriod IsValid(0, 0): %d\n", (int)Quantity_Period::IsValid(0, 0));
  comps("zeroPeriod Period(0, 0)", Quantity_Period(0, 0));
  return 0;
}
