# DSA — Two Sum

## Problem

Given an array of integers and a target integer, return the indices of two numbers whose sum equals the target.

Example:

```text
Input:
nums = [2, 7, 11, 15, 3, 6]
target = 9

Output:
[0, 1]
```

Because:

```text
nums[0] + nums[1] = 2 + 7 = 9
```

## Constraint

Design the solution to run in:

```text
O(n)
```

time.

## Questions

1. What data structure would you use?
2. What would you store in it?
3. How do you find the matching pair in one pass?
4. What are the time and space complexities?

## Expected direction

Use a hash map / dictionary.

As you scan the array, for each value `x`, check whether:

```text
target - x
```

has already been seen.

If it has, the stored index and the current index form the answer.

Otherwise, store:

```text
value → index
```

## Complexity

```text
Time:  O(n)
Space: O(n)
```

The hash-map lookup is expected O(1), so each array element is processed once.
