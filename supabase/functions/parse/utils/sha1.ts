// Minimal, dependency-free SHA-1 implementation for Deno/edge usage
// Kaynak: https://github.com/emn178/js-sha1
// TypeScript'e uyarlanmıştır.

export function sha1(ascii: string): string {
  function rotl(n: number, s: number) {
    return (n << s) | (n >>> (32 - s));
  }

  function toHex(val: number) {
    return ('00000000' + val.toString(16)).slice(-8);
  }

  // PREPROCESSING
  let i: number, j: number;
  const l = ascii.length;
  const words: number[] = [];
  for (i = 0, j = 0; i < l; ++i, j += 8)
    words[j >> 5] |= (ascii.charCodeAt(i) & 0xff) << (24 - j % 32);
  words[(l << 3) >> 5] |= 0x80 << (24 - (l << 3) % 32);
  words[(((l + 8) >> 6) << 4) + 15] = l << 3;

  // INITIALIZE
  let w = Array(80).fill(0);
  let a = 0x67452301;
  let b = 0xefcdab89;
  let c = 0x98badcfe;
  let d = 0x10325476;
  let e = 0xc3d2e1f0;

  // HASH COMPUTATION
  for (let block = 0; block < words.length; block += 16) {
    for (i = 0; i < 16; i++) w[i] = words[block + i] || 0;
    for (i = 16; i < 80; i++) w[i] = rotl(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1);

    let aa = a, bb = b, cc = c, dd = d, ee = e;
    for (i = 0; i < 80; i++) {
      let temp = rotl(a, 5) + e + w[i];
      if (i < 20) temp += ((b & c) | (~b & d)) + 0x5a827999;
      else if (i < 40) temp += (b ^ c ^ d) + 0x6ed9eba1;
      else if (i < 60) temp += ((b & c) | (b & d) | (c & d)) + 0x8f1bbcdc;
      else temp += (b ^ c ^ d) + 0xca62c1d6;
      e = d;
      d = c;
      c = rotl(b, 30);
      b = a;
      a = temp | 0;
    }
    a = (a + aa) | 0;
    b = (b + bb) | 0;
    c = (c + cc) | 0;
    d = (d + dd) | 0;
    e = (e + ee) | 0;
  }

  return toHex(a) + toHex(b) + toHex(c) + toHex(d) + toHex(e);
}
