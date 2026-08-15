#include "route_mgr.hpp"

#include <cstdint>
#include <iostream>
#include <vector>

int main() {
  RouteManager route_mgr;

  std::vector<Route> routes = {
      // Default route (0.0.0.0/0)
      {0x00000000, 0, "R4"}, // 0.0.0.0/0

      // 10.0.0.0/8
      {0x0A000000, 8, "R1"},

      // 10.1.0.0/16
      {0x0A010000, 16, "R2"},

      // 10.1.2.0/24
      {0x0A010200, 24, "R3"},

      // Another branch under 10.1.0.0/16
      {0x0A010300, 24, "R5"}, // 10.1.3.0/24

      // More-specific route under 10.1.2.0/24
      {0x0A010280, 25, "R6"}, // 10.1.2.128/25

      // Completely different /16
      {0x0A020000, 16, "R7"}, // 10.2.0.0/16

      // Another top-level network
      {0xC0A80000, 16, "R8"}, // 192.168.0.0/16

      // More-specific route under 192.168.0.0/16
      {0xC0A80100, 24, "R9"}, // 192.168.1.0/24
  };

  for (Route route : routes) {
    route_mgr.insert(route);
    std::cout << "Inserted route\n";
  }

  std::vector<uint32_t> destinations = {
      0x0A010237, // 10.1.2.55
      0x0A010280, // 10.1.2.128
      0x0A0102C8, // 10.1.2.200
      0x0A0102FF, // 10.1.2.255
      0x0A0102FF, // 10.1.2.255
      0x0A010350, // 10.1.3.80
      0x0A0103FF, // 10.1.3.255

      0x0A010100, // 10.1.1.0
      0x0A0101FF, // 10.1.1.255

      0x0A020123, // 10.2.1.35
      0x0A0202AA, // 10.2.2.170

      0x0A000001, // 10.0.0.1
      0x0B000001, // 11.0.0.1

      0xC0A80001, // 192.168.0.1
      0xC0A80101, // 192.168.1.1
      0xC0A801FE, // 192.168.1.254
      0xC0A80201, // 192.168.2.1

      0x08080808, // 8.8.8.8
  };

  for (uint32_t destination : destinations) {
    const Route *found_route = route_mgr.lookup(destination);
    if (found_route != nullptr) {
      std::cout << "Matched prefix length: /"
                << static_cast<unsigned>(found_route->prefix_len) << "\n"
                << "Next hop: " << found_route->nexthop << "\n";
    } else {
      std::cout << "No route found\n";
    }
  }

  return 0;
}
