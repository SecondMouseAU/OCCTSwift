// setjmp/longjmp, which OCCT reaches through OCC_CATCH_SIGNALS and which -fwasm-exceptions does
// nothing for. See #2172 and #2188.
#ifndef STUBSJLJ_H
#define STUBSJLJ_H

// Returns 7 when a longjmp arrived back at its setjmp.
int stubSjLjRoundTrip(void);

#endif
