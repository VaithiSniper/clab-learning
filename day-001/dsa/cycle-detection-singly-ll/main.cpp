#include "sll.hpp"
#include <iostream>

int main() {
  SLL list(1);

  list.insert_head(2);
  list.insert_head(3);
  list.insert_head(4);

  list.print_elements();

  std::cout << "Has cycle: " << (list.detect_cycle() ? "true" : "false")
            << "\n";

  list.create_cycle(1);
  std::cout << "Has cycle: " << (list.detect_cycle() ? "true" : "false")
            << "\n";

  return 0;
}
