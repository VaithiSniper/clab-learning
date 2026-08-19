#include <unordered_map>
#include <utility>

class LRUCache {
private:
  struct Node {
    Node *prev;
    Node *next;
    int key;
    int value;

    Node(int k, int v) : key(k), value(v), prev(nullptr), next(nullptr) {};
  };

  size_t capacity;

  std::unordered_map<int, Node *> key_node_map;

  Node *head; // LRU side
  Node *tail; // MRU side

private:
  void remove_node(Node *node) {
    Node *prev = node->prev;
    Node *next = node->next;
    prev->next = next;
    next->prev = prev;
  }

  void add_to_back(Node *node) {
    node->prev = tail->prev;
    node->next = tail;
    tail->prev->next = node;
    tail->prev = node;
  }

public:
  LRUCache(int capacity) : capacity(capacity) {

    head = new Node(-1, -1);
    tail = new Node(-1, -1);

    head->next = tail;
    tail->prev = head;
  }

  ~LRUCache() {
    Node *curr = head;

    while (curr) {
      Node *next = curr->next;
      delete curr;
      curr = next;
    }
  }

  int get(int key) {
    int val = -1;

    auto it = key_node_map.find(key);
    if (it != key_node_map.end()) {
      Node *node = it->second;
      val = node->value;

      // Move to MRU
      remove_node(node);
      add_to_back(node);
    }

    return val;
  }

  void put(int key, int value) {
    auto it = key_node_map.find(key);

    if (it != key_node_map.end()) {
      // Key exists
      // Grab the node
      Node *node = it->second;
      // Update value
      node->value = value;
      // And put to front
      remove_node(node);
      add_to_back(node);
    } else {
      // Evict LRU entry (if needed)
      if (key_node_map.size() == capacity) {
        Node *lru_entry = head->next;
        remove_node(lru_entry);
        key_node_map.erase(key);
        delete lru_entry;
      }

      // Create and add new node to MRU tail
      Node *new_node = new Node(key, value);
      add_to_back(new_node);
      key_node_map.insert(std::pair<int, Node *>(key, new_node));
    }
  }
};
