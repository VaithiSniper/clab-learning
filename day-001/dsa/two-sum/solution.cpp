#include <cstdio>
#include <unordered_map>
#include <vector>

using namespace std;

vector<int> two_sum(int req_sum, const vector<int> &arr) {
  unordered_map<int, int> ele_idx;

  for (int i = 0; i < arr.size(); i++) {
    int ele = arr[i];
    int complement = req_sum - ele;

    auto it = ele_idx.find(complement);
    if (it != ele_idx.end()) {
      return {i, it->second};
    }

    ele_idx[ele] = i;
  }

  return {};
}

int main() {
  int req_sum = 10;
  vector<int> arr = {2, 7, 11, 15, 3, 6};

  vector<int> result = two_sum(req_sum, arr);
  printf("(%d,%d)\n", result[0], result[1]);

  return 0;
}
