// Helpers for candidate bitmasks. Digit `d` (1-9) is stored as bit `d - 1`.

const int allDigitsMask = 0x1FF;

int digitBit(int digit) => 1 << (digit - 1);

bool hasDigit(int mask, int digit) => mask & digitBit(digit) != 0;

int popCount(int mask) {
  var count = 0;
  while (mask != 0) {
    mask &= mask - 1;
    count++;
  }
  return count;
}

/// The digits in [mask], ascending.
List<int> digitsOf(int mask) => [
  for (var d = 1; d <= 9; d++)
    if (hasDigit(mask, d)) d,
];
