const UPPERCASE = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
const LOWERCASE = 'abcdefghijkmnopqrstuvwxyz';
const DIGITS = '23456789';
const SYMBOLS = '!@#$%^&*()-_=+';
const ALL_CHARACTERS = UPPERCASE + LOWERCASE + DIGITS + SYMBOLS;

function secureIndex(length: number): number {
  const values = new Uint32Array(1);
  const limit = Math.floor(0x1_0000_0000 / length) * length;
  do {
    crypto.getRandomValues(values);
  } while (values[0] >= limit);
  return values[0] % length;
}

export function generateStrongTemporaryPassword(): string {
  const characters = [
    UPPERCASE[secureIndex(UPPERCASE.length)],
    LOWERCASE[secureIndex(LOWERCASE.length)],
    DIGITS[secureIndex(DIGITS.length)],
    SYMBOLS[secureIndex(SYMBOLS.length)],
  ];

  while (characters.length < 20) {
    characters.push(ALL_CHARACTERS[secureIndex(ALL_CHARACTERS.length)]);
  }

  for (let i = characters.length - 1; i > 0; i -= 1) {
    const swapIndex = secureIndex(i + 1);
    [characters[i], characters[swapIndex]] = [
      characters[swapIndex],
      characters[i],
    ];
  }

  return characters.join('');
}
