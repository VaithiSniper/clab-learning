#include <iostream>

class SLL {
private:
  struct Node {
    int val;
    Node *next;

    Node(int val) : val(val), next(nullptr) {};
  };

  Node *sll;

  Node *tail_ptr = nullptr;

public:
  SLL(int val) : sll(new Node(val)) {};

  ~SLL() {
    Node *curr = sll;
    while (curr) {
      Node *next = curr->next;
      if (curr == tail_ptr) {
        delete curr;
        break;
      }
      delete curr;
      curr = next;
    }
  }

  void insert_head(int val) {
    Node *new_node = new Node(val);
    new_node->next = sll;
    sll = new_node;
  }

  void create_cycle(int index) {
    Node *tail = sll;
    Node *target = nullptr;

    int i = 0;

    while (tail->next) {
      if (i == index)
        target = tail;

      tail = tail->next;
      i++;
    }

    // Check the last node as a possible target.
    if (i == index)
      target = tail;

    if (target)
      tail->next = target;

    tail_ptr = tail;
  }

  bool detect_cycle() {
    Node *fast, *slow;
    fast = sll;
    slow = sll;

    while (fast && fast->next) {
      slow = slow->next;
      fast = fast->next->next;

      if (slow == fast) {
        return true;
      }
    }

    return false;
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
