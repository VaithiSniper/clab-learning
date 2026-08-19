#include "lru_cache.hpp"
#include <iostream>

int main() {
  LRUCache cache(3);

  cache.put(1, 100);
  cache.put(2, 200);
  cache.put(3, 300);

  std::cout << cache.get(1) << "\n";  // 100
  std::cout << cache.get(2) << "\n";  // 200
  std::cout << cache.get(99) << "\n"; // -1

  // Current order:
  // LRU -> 3, 1, 2 <- MRU

  cache.put(4, 400);

  // 3 should be evicted.
  std::cout << cache.get(3) << "\n"; // -1
  std::cout << cache.get(4) << "\n"; // 400

  // Current order:
  // LRU -> 1, 2, 4 <- MRU

  // Update existing key.
  cache.put(1, 111);

  std::cout << cache.get(1) << "\n"; // 111

  // 1 is now MRU:
  // LRU -> 2, 4, 1 <- MRU

  cache.put(5, 500);

  // 2 should now be evicted.
  std::cout << cache.get(2) << "\n"; // -1
  std::cout << cache.get(4) << "\n"; // 400
  std::cout << cache.get(5) << "\n"; // 500
  std::cout << cache.get(1) << "\n"; // 111

  return 0;
}
