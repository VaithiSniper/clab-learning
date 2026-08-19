#include "sll.hpp"

int main() {
  SLL list(1);
  list.insert_head(2);
  list.insert_head(3);
  list.insert_head(4);

  list.print_elements();

  list.reverse();

  list.print_elements();

  return 0;
}
