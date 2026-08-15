#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

#include "trie.hpp"

struct Route {
  uint32_t prefix;
  uint8_t prefix_len;
  std::string nexthop;
};

class RouteManager {
private:
  Trie<Route, 2> route_trie;

  std::vector<std::size_t> addr_uint32_to_bits_vec(uint32_t &addr,
                                                   uint8_t prefix_len) {
    std::vector<std::size_t> addr_bits;
    for (int bit = 31; bit >= (32 - prefix_len); --bit) {
      addr_bits.push_back((addr >> bit) & 1);
    }

    return addr_bits;
  }

public:
  void insert(Route _route) {
    Route route = _route;

    route_trie.insert(addr_uint32_to_bits_vec(route.prefix, route.prefix_len),
                      route);
  }

  const Route *lookup(uint32_t destination) {
    return route_trie.longest_prefix_match(
        addr_uint32_to_bits_vec(destination, 32));
  }
};
