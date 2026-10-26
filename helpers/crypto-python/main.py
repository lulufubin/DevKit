#!/usr/bin/env python3
"""DevKit Python 加解密助手。stdin/stdout 各一行 JSON，密钥不写盘。"""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import sys
from typing import Any

from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.padding import PKCS7

OPENSSL_MAGIC = b"Salted__"
MAX_BYTES = 20 * 1024 * 1024


def main() -> None:
    for raw in sys.stdin:
        line = raw.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
            resp = handle(req)
        except Exception as exc:  # noqa: BLE001 — 必须回一行，不能把密钥写进消息
            resp = {"id": "", "ok": False, "error": "处理失败"}
            _ = exc
        sys.stdout.write(json.dumps(resp, ensure_ascii=False) + "\n")
        sys.stdout.flush()


def handle(req: dict[str, Any]) -> dict[str, Any]:
    ident = str(req.get("id") or "")
    op = req.get("op")
    if op == "hash":
        return _hash(ident, req)
    if op == "hmac":
        return _hmac(ident, req)
    if op == "encrypt":
        return _encrypt(ident, req)
    if op == "decrypt":
        return _decrypt(ident, req)
    return fail(ident, "未知操作")


def _hash(ident: str, req: dict[str, Any]) -> dict[str, Any]:
    alg = req.get("alg")
    if alg == "sm3":
        return unsupported(ident, "Python 标准库不支持 SM3")
    data = decode_data(req.get("data") or "", req.get("encoding") or "utf8")
    digest = {
        "md5": hashlib.md5,
        "sha1": hashlib.sha1,
        "sha256": hashlib.sha256,
    }.get(alg)
    if digest is None:
        return fail(ident, "不支持的哈希算法")
    return ok(ident, digest(data).hexdigest())


def _hmac(ident: str, req: dict[str, Any]) -> dict[str, Any]:
    key = decode_data(req.get("key") or "", req.get("keyEncoding") or "utf8")
    data = decode_data(req.get("data") or "", req.get("encoding") or "utf8")
    return ok(ident, hmac.new(key, data, hashlib.sha256).hexdigest())


def _encrypt(ident: str, req: dict[str, Any]) -> dict[str, Any]:
    alg = req.get("alg")
    data = decode_data(req.get("data") or "", req.get("encoding") or "utf8")
    out_enc = req.get("outputEncoding") or "base64"
    key_mode = req.get("keyMode") or "raw"
    if alg == "aes-256-gcm":
        if key_mode != "raw":
            return fail(ident, "GCM 只支持原始密钥")
        key = decode_data(req.get("key") or "", req.get("keyEncoding") or "utf8")
        nonce = bytes.fromhex(req.get("nonceHex") or "")
        if len(key) != 32 or len(nonce) != 12:
            return fail(ident, "AES-GCM 参数无效")
        packed = nonce + AESGCM(key).encrypt(nonce, data, None)
        return ok(ident, encode_data(packed, out_enc))
    if alg == "aes-256-cbc" and key_mode == "raw":
        key = decode_data(req.get("key") or "", req.get("keyEncoding") or "utf8")
        iv = bytes.fromhex(req.get("ivHex") or "")
        if len(key) != 32 or len(iv) != 16:
            return fail(ident, "AES-CBC 参数无效")
        packed = iv + cbc_encrypt(key, iv, data)
        return ok(ident, encode_data(packed, out_enc))
    if alg == "aes-256-cbc" and key_mode == "passphrase":
        password = (req.get("key") or "").encode("utf-8")
        salt = bytes.fromhex(req.get("saltHex") or "")
        if not password or len(salt) != 8:
            return fail(ident, "口令派生参数无效")
        key, iv = evp_bytes_to_key(password, salt, 32, 16)
        packed = OPENSSL_MAGIC + salt + cbc_encrypt(key, iv, data)
        return ok(ident, base64.b64encode(packed).decode("ascii"))
    return fail(ident, "不支持的加密算法")


def _decrypt(ident: str, req: dict[str, Any]) -> dict[str, Any]:
    alg = req.get("alg")
    key_mode = req.get("keyMode") or "raw"
    out_enc = req.get("outputEncoding") or "utf8"
    if alg == "aes-256-gcm":
        key = decode_data(req.get("key") or "", req.get("keyEncoding") or "utf8")
        packed = decode_data(req.get("data") or "", req.get("encoding") or "base64")
        if len(key) != 32 or len(packed) < 28:
            return fail(ident, "AES-GCM 密文过短")
        nonce, body = packed[:12], packed[12:]
        plain = AESGCM(key).decrypt(nonce, body, None)
        return ok(ident, encode_data(plain, out_enc))
    if alg == "aes-256-cbc" and key_mode == "passphrase":
        password = (req.get("key") or "").encode("utf-8")
        packed = base64.b64decode((req.get("data") or "").strip())
        if packed[:8] != OPENSSL_MAGIC or len(packed) < 24:
            return fail(ident, "不是 OpenSSL Salted 密文")
        salt, body = packed[8:16], packed[16:]
        key, iv = evp_bytes_to_key(password, salt, 32, 16)
        return ok(ident, encode_data(cbc_decrypt(key, iv, body), out_enc))
    if alg == "aes-256-cbc":
        key = decode_data(req.get("key") or "", req.get("keyEncoding") or "utf8")
        packed = decode_data(req.get("data") or "", req.get("encoding") or "base64")
        if len(key) != 32 or len(packed) < 32:
            return fail(ident, "AES-CBC 密文过短")
        return ok(ident, encode_data(cbc_decrypt(key, packed[:16], packed[16:]), out_enc))
    return fail(ident, "不支持的解密算法")


def cbc_encrypt(key: bytes, iv: bytes, data: bytes) -> bytes:
    padder = PKCS7(128).padder()
    padded = padder.update(data) + padder.finalize()
    encryptor = Cipher(algorithms.AES(key), modes.CBC(iv)).encryptor()
    return encryptor.update(padded) + encryptor.finalize()


def cbc_decrypt(key: bytes, iv: bytes, data: bytes) -> bytes:
    decryptor = Cipher(algorithms.AES(key), modes.CBC(iv)).decryptor()
    padded = decryptor.update(data) + decryptor.finalize()
    unpadder = PKCS7(128).unpadder()
    return unpadder.update(padded) + unpadder.finalize()


def evp_bytes_to_key(password: bytes, salt: bytes, key_len: int, iv_len: int) -> tuple[bytes, bytes]:
    need = key_len + iv_len
    out = b""
    prev = b""
    while len(out) < need:
        prev = hashlib.md5(prev + password + salt).digest()
        out += prev
    return out[:key_len], out[key_len:need]


def decode_data(text: str, encoding: str) -> bytes:
    if encoding == "utf8":
        raw = text.encode("utf-8")
    elif encoding == "hex":
        cleaned = "".join(text.split())
        if cleaned[:2].lower() == "0x":
            cleaned = cleaned[2:]
        raw = bytes.fromhex(cleaned)
    else:
        raw = base64.b64decode(text.strip())
    if len(raw) > MAX_BYTES:
        raise ValueError("too large")
    return raw


def encode_data(data: bytes, encoding: str) -> str:
    if encoding == "hex":
        return data.hex()
    if encoding == "base64":
        return base64.b64encode(data).decode("ascii")
    return data.decode("utf-8")


def ok(ident: str, output: str) -> dict[str, Any]:
    return {"id": ident, "ok": True, "output": output}


def fail(ident: str, error: str) -> dict[str, Any]:
    return {"id": ident, "ok": False, "error": error}


def unsupported(ident: str, error: str) -> dict[str, Any]:
    return {"id": ident, "ok": False, "unsupported": True, "error": error}


if __name__ == "__main__":
    main()
