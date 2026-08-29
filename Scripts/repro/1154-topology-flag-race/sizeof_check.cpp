#include <atomic>
#include <cstdint>
#include <cstdio>
int main() {
  printf("sizeof(uint16_t) = %zu\n", sizeof(uint16_t));
  printf("sizeof(std::atomic<uint16_t>) = %zu\n", sizeof(std::atomic<uint16_t>));
  printf("alignof(uint16_t) = %zu\n", alignof(uint16_t));
  printf("alignof(std::atomic<uint16_t>) = %zu\n", alignof(std::atomic<uint16_t>));
  printf("is_always_lock_free = %d\n", std::atomic<uint16_t>::is_always_lock_free);
  return 0;
}
