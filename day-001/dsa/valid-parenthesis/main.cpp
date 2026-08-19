#include <iostream>
#include <stack>
#include <string>

bool valid_parentheses(const std::string &s) {
  std::stack<char> st;

  for (char c : s) {
    if (c == '(' || c == '[' || c == '{') {
      st.push(c);
    } else {
      if (st.empty())
        return false;

      char top = st.top();
      st.pop();

      if ((c == ')' && top != '(') || (c == ']' && top != '[') ||
          (c == '}' && top != '{')) {
        return false;
      }
    }
  }

  return st.empty();
}

int main() {
  std::string tests[] = {"()[]{}", "([{}])", "([)]", "{[]}", "(", "}", ""};

  for (const auto &test : tests) {
    std::cout << test << " -> " << (valid_parentheses(test) ? "true" : "false")
              << "\n";
  }

  return 0;
}
