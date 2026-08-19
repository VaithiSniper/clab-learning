#include <iostream>

class SLL {
private:
  struct Node {
    int val;
    Node *next;

    Node(int val) : val(val), next(nullptr) {};
  };

  Node *sll;

public:
  SLL(int val) : sll(new Node(val)) {};

  ~SLL() {
    Node *curr = sll;
    while (curr) {
      Node *next = curr->next;
      delete curr;
      curr = next;
    }
  }

  void insert_head(int val) {
    Node *new_node = new Node(val);
    new_node->next = sll;
    sll = new_node;
  }

  void reverse() {
    Node *prev, *curr, *next;
    prev = nullptr;
    curr = sll;

    while (curr) {
      next = curr->next;
      curr->next = prev;
      prev = curr;
      curr = next;
    }
    sll = prev;
  }

  void print_elements() {
    Node *curr = sll;
    while (curr) {
      std::cout << " " << curr->val;
      curr = curr->next;
    }
    std::cout << "\n";
  }
};
