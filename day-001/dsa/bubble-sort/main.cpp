#include <iostream>
#include <vector>

void bubble_sort(std::vector<int> &arr) {
  int n = arr.size();

  for (int i = 0; i < n - 1; i++) {
    bool swapped = false;

    for (int j = 0; j < n - i - 1; j++) {
      if (arr[j] > arr[j + 1]) {
        std::swap(arr[j], arr[j + 1]);
        swapped = true;
      }
    }

    // Already sorted
    if (!swapped)
      break;
  }
}

int main() {
  std::vector<int> arr = {5, 1, 4, 2, 8, 3};

  std::cout << "Before: ";
  for (int x : arr)
    std::cout << x << " ";
  std::cout << "\n";

  bubble_sort(arr);

  std::cout << "After:  ";
  for (int x : arr)
    std::cout << x << " ";
  std::cout << "\n";

  return 0;
}
