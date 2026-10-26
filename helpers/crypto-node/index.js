"use strict";

const CryptoJS = require("crypto-js");
const readline = require("readline");

const MAX_BYTES = 20 * 1024 * 1024;

const rl = readline.createInterface({ input: process.stdin, crlfDelay: Infinity });
rl.on("line", (line) => {
  const trimmed = line.trim();
  if (!trimmed) {
    return;
  }
  let req = {};
  try {
    req = JSON.parse(trimmed);
    write(handle(req));
  } catch (_err) {
    write({ id: String(req.id || ""), ok: false, error: "处理失败" });
  }
});

function handle(req) {
  const id = String(req.id || "");
  switch (req.op) {
    case "hash":
      return hash(id, req);
    case "hmac":
      return hmacSha(id, req);
    case "encrypt":
      return encrypt(id, req);
    case "decrypt":
      return decrypt(id, req);
    default:
      return fail(id, "未知操作");
  }
}

function hash(id, req) {
  if (req.alg === "sm3") {
    return unsupported(id, "crypto-js 不支持 SM3");
  }
  const data = toWordArray(req.data || "", req.encoding || "utf8");
  const fn = { md5: CryptoJS.MD5, sha1: CryptoJS.SHA1, sha256: CryptoJS.SHA256 }[req.alg];
  if (!fn) {
    return fail(id, "不支持的哈希算法");
  }
  return ok(id, fn(data).toString(CryptoJS.enc.Hex));
}

function hmacSha(id, req) {
  const key = toWordArray(req.key || "", req.keyEncoding || "utf8");
  const data = toWordArray(req.data || "", req.encoding || "utf8");
  return ok(id, CryptoJS.HmacSHA256(data, key).toString(CryptoJS.enc.Hex));
}

function encrypt(id, req) {
  if (req.alg === "aes-256-gcm") {
    return unsupported(id, "crypto-js 不支持 AES-GCM");
  }
  if (req.alg !== "aes-256-cbc") {
    return fail(id, "不支持的加密算法");
  }
  const data = toWordArray(req.data || "", req.encoding || "utf8");
  if (req.keyMode === "passphrase") {
    const salt = CryptoJS.enc.Hex.parse(req.saltHex || "");
    const derived = CryptoJS.kdf.OpenSSL.execute(req.key || "", 256 / 32, 128 / 32, salt);
    const encrypted = CryptoJS.AES.encrypt(data, derived.key, {
      iv: derived.iv,
      mode: CryptoJS.mode.CBC,
      padding: CryptoJS.pad.Pkcs7,
    });
    const packed = CryptoJS.enc.Utf8.parse("Salted__").concat(salt).concat(encrypted.ciphertext);
    return ok(id, CryptoJS.enc.Base64.stringify(packed));
  }
  const key = toWordArray(req.key || "", req.keyEncoding || "utf8");
  const iv = CryptoJS.enc.Hex.parse(req.ivHex || "");
  const encrypted = CryptoJS.AES.encrypt(data, key, {
    iv,
    mode: CryptoJS.mode.CBC,
    padding: CryptoJS.pad.Pkcs7,
  });
  const packed = iv.concat(encrypted.ciphertext);
  return ok(id, encodeWords(packed, req.outputEncoding || "base64"));
}

function decrypt(id, req) {
  if (req.alg === "aes-256-gcm") {
    return unsupported(id, "crypto-js 不支持 AES-GCM");
  }
  if (req.alg !== "aes-256-cbc") {
    return fail(id, "不支持的解密算法");
  }
  if (req.keyMode === "passphrase") {
    const packed = CryptoJS.enc.Base64.parse((req.data || "").trim());
    const salt = CryptoJS.lib.WordArray.create(packed.words.slice(2, 4), 8);
    const body = CryptoJS.lib.WordArray.create(packed.words.slice(4), packed.sigBytes - 16);
    const derived = CryptoJS.kdf.OpenSSL.execute(req.key || "", 256 / 32, 128 / 32, salt);
    const cipherParams = CryptoJS.lib.CipherParams.create({ ciphertext: body });
    const plain = CryptoJS.AES.decrypt(cipherParams, derived.key, {
      iv: derived.iv,
      mode: CryptoJS.mode.CBC,
      padding: CryptoJS.pad.Pkcs7,
    });
    return ok(id, encodeWords(plain, req.outputEncoding || "utf8"));
  }
  const packed = toWordArray(req.data || "", req.encoding || "base64");
  const iv = CryptoJS.lib.WordArray.create(packed.words.slice(0, 4), 16);
  const body = CryptoJS.lib.WordArray.create(packed.words.slice(4), packed.sigBytes - 16);
  const key = toWordArray(req.key || "", req.keyEncoding || "utf8");
  const cipherParams = CryptoJS.lib.CipherParams.create({ ciphertext: body });
  const plain = CryptoJS.AES.decrypt(cipherParams, key, {
    iv,
    mode: CryptoJS.mode.CBC,
    padding: CryptoJS.pad.Pkcs7,
  });
  return ok(id, encodeWords(plain, req.outputEncoding || "utf8"));
}

function toWordArray(text, encoding) {
  let words;
  if (encoding === "hex") {
    words = CryptoJS.enc.Hex.parse(String(text).replace(/\s+/g, "").replace(/^0x/i, ""));
  } else if (encoding === "base64") {
    words = CryptoJS.enc.Base64.parse(String(text).trim());
  } else {
    words = CryptoJS.enc.Utf8.parse(String(text));
  }
  if (words.sigBytes > MAX_BYTES) {
    throw new Error("too large");
  }
  return words;
}

function encodeWords(words, encoding) {
  if (encoding === "hex") {
    return CryptoJS.enc.Hex.stringify(words);
  }
  if (encoding === "base64") {
    return CryptoJS.enc.Base64.stringify(words);
  }
  return CryptoJS.enc.Utf8.stringify(words);
}

function ok(id, output) {
  return { id, ok: true, output };
}

function fail(id, error) {
  return { id, ok: false, error };
}

function unsupported(id, error) {
  return { id, ok: false, unsupported: true, error };
}

function write(obj) {
  process.stdout.write(JSON.stringify(obj) + "\n");
}
