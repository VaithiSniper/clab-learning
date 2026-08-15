#pragma once

#include <array>
#include <cstddef>
#include <optional>
#include <vector>

template <typename T, std::size_t MAX_VALS> class Trie {
private:
  struct Node {
    std::array<Node *, MAX_VALS> children{};
    std::optional<T> value;

    Node() { children.fill(nullptr); }
  };

  Node *root;

public:
  Trie() { root = new Node(); }

  ~Trie() { destroy(root); }

  Trie(const Trie &) = delete;
  Trie &operator=(const Trie &) = delete;

  void insert(const std::vector<std::size_t> &path, const T &value) {
    Node *curr = root;

    for (std::size_t idx : path) {
      if (idx >= MAX_VALS) {
        return;
      }

      if (curr->children[idx] == nullptr) {
        curr->children[idx] = new Node();
      }
      curr = curr->children[idx];
    }

    curr->value = value;
  }

  const T *longest_prefix_match(const std::vector<std::size_t> &path) {
    Node *curr = root;
    const T *best_match = nullptr;

    if (curr->value.has_value()) {
      best_match = &curr->value.value();
    }

    for (std::size_t idx : path) {
      if (idx >= MAX_VALS) {
        break;
      }

      if (curr->children[idx] == nullptr) {
        break;
      }

      curr = curr->children[idx];

      if (curr->value.has_value()) {
        best_match = &curr->value.value();
      }
    }

    return best_match;
  }

  bool exact_match(const std::vector<std::size_t> &path) {
    Node *curr = root;
    bool found = false;

    for (std::size_t idx : path) {
      if (idx >= MAX_VALS) {
        return false;
      }

      if (curr->children[idx] == nullptr) {
        return false;
      }

      curr = curr->children[idx];
    }

    return curr->value.has_value();
  }

private:
  void destroy(Node *node) {
    if (node == nullptr) {
      return;
    }

    for (Node *node : node->children) {
      destroy(node);
    }

    delete node;
  }
};
