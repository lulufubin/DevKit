//! String-based developer crypto helpers for the desktop UI.

use aes_gcm::aead::{Aead, KeyInit};
use aes_gcm::{Aes256Gcm, Key, Nonce};
use base64::engine::general_purpose::STANDARD as BASE64;
use base64::Engine;
use getrandom::SysRng;
use gmcrypto_core::sm2::{
    sign_with_id, verify_with_id, Sm2PrivateKey, Sm2PublicKey, DEFAULT_SIGNER_ID,
};
use hmac::{Hmac, Mac};
use rand::rngs::OsRng;
use rand::RngCore;
use rsa::pkcs1::{DecodeRsaPrivateKey, DecodeRsaPublicKey};
use rsa::pkcs8::{DecodePrivateKey, DecodePublicKey, EncodePrivateKey, EncodePublicKey, LineEnding};
use rsa::sha2::Sha256 as RsaSha256;
use rsa::signature::{RandomizedSigner, SignatureEncoding, Verifier};
use rsa::{Oaep, Pkcs1v15Encrypt, RsaPrivateKey, RsaPublicKey};
use sha2::Sha256;

use crate::json::{ensure_size_limit, MAX_TEXT_BYTES};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum BinaryEncoding {
    Utf8,
    Hex,
    Base64,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum HashAlg {
    Md5,
    Sha1,
    Sha256,
    Sm3,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum RsaPadding {
    OaepSha256,
    Pkcs1V15,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum RsaSignPadding {
    Pkcs1V15Sha256,
    PssSha256,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Sm4Mode {
    Ecb,
    Cbc,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RsaKeyPair {
    pub private_pem: String,
    pub public_pem: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Sm2KeyPair {
    pub private_hex: String,
    pub public_hex: String,
}

const AES_NONCE_LEN: usize = 12;
const AES_KEY_LEN: usize = 32;
const SM4_BLOCK_LEN: usize = 16;
const SM2_PRIV_LEN: usize = 32;

pub fn codec_encode(input: &str, encoding: BinaryEncoding) -> Result<String, String> {
    ensure_size_limit(input, MAX_TEXT_BYTES)?;
    encode_bytes(input.as_bytes(), encoding)
}

pub fn codec_decode(input: &str, encoding: BinaryEncoding) -> Result<String, String> {
    let bytes = decode_bytes(input, encoding)?;
    String::from_utf8(bytes).map_err(|err| err.to_string())
}

pub fn url_encode(input: &str) -> Result<String, String> {
    ensure_size_limit(input, MAX_TEXT_BYTES)?;
    Ok(urlencoding::encode(input).into_owned())
}

pub fn url_decode(input: &str) -> Result<String, String> {
    ensure_size_limit(input, MAX_TEXT_BYTES)?;
    urlencoding::decode(input)
        .map(|cow| cow.into_owned())
        .map_err(|err| err.to_string())
}

pub fn hash_text(input: &str, encoding: BinaryEncoding, alg: HashAlg) -> Result<String, String> {
    let data = decode_bytes(input, encoding)?;
    Ok(digest_hex(alg, &data))
}

pub fn hmac_sha256(
    key: &str,
    key_encoding: BinaryEncoding,
    message: &str,
    message_encoding: BinaryEncoding,
) -> Result<String, String> {
    let key_bytes = decode_bytes(key, key_encoding)?;
    let message_bytes = decode_bytes(message, message_encoding)?;
    let mut mac =
        <Hmac<Sha256> as Mac>::new_from_slice(&key_bytes).map_err(|err| err.to_string())?;
    mac.update(&message_bytes);
    Ok(hex::encode(mac.finalize().into_bytes()))
}

pub fn aes256_gcm_encrypt(
    key: &str,
    key_encoding: BinaryEncoding,
    plaintext: &str,
    plaintext_encoding: BinaryEncoding,
    output_encoding: BinaryEncoding,
) -> Result<String, String> {
    let key_bytes = aes_key(key, key_encoding)?;
    let plaintext = decode_bytes(plaintext, plaintext_encoding)?;
    let cipher = Aes256Gcm::new(Key::<Aes256Gcm>::from_slice(&key_bytes));
    let mut nonce_bytes = [0u8; AES_NONCE_LEN];
    OsRng.fill_bytes(&mut nonce_bytes);
    let nonce = Nonce::from_slice(&nonce_bytes);
    let ciphertext = cipher
        .encrypt(nonce, plaintext.as_ref())
        .map_err(|err| err.to_string())?;
    let mut packed = Vec::with_capacity(AES_NONCE_LEN + ciphertext.len());
    packed.extend_from_slice(&nonce_bytes);
    packed.extend_from_slice(&ciphertext);
    encode_bytes(&packed, output_encoding)
}

pub fn aes256_gcm_decrypt(
    key: &str,
    key_encoding: BinaryEncoding,
    ciphertext: &str,
    ciphertext_encoding: BinaryEncoding,
    output_encoding: BinaryEncoding,
) -> Result<String, String> {
    let key_bytes = aes_key(key, key_encoding)?;
    let packed = decode_bytes(ciphertext, ciphertext_encoding)?;
    if packed.len() < AES_NONCE_LEN + 16 {
        return Err("AES-GCM 密文过短".to_string());
    }
    let (nonce_bytes, body) = packed.split_at(AES_NONCE_LEN);
    let cipher = Aes256Gcm::new(Key::<Aes256Gcm>::from_slice(&key_bytes));
    let nonce = Nonce::from_slice(nonce_bytes);
    let plaintext = cipher
        .decrypt(nonce, body)
        .map_err(|err| err.to_string())?;
    encode_bytes(&plaintext, output_encoding)
}

pub fn rsa_generate_keypair(bits: Option<u32>) -> Result<RsaKeyPair, String> {
    let bits = bits.unwrap_or(2048);
    if !(1024..=4096).contains(&bits) {
        return Err("RSA 密钥长度必须在 1024 到 4096 之间".to_string());
    }
    let private = RsaPrivateKey::new(&mut OsRng, bits as usize).map_err(|err| err.to_string())?;
    let public = RsaPublicKey::from(&private);
    Ok(RsaKeyPair {
        private_pem: private
            .to_pkcs8_pem(LineEnding::LF)
            .map_err(|err| err.to_string())?
            .to_string(),
        public_pem: public
            .to_public_key_pem(LineEnding::LF)
            .map_err(|err| err.to_string())?,
    })
}

pub fn rsa_encrypt(
    public_pem: &str,
    plaintext: &str,
    plaintext_encoding: BinaryEncoding,
    padding: RsaPadding,
    output_encoding: BinaryEncoding,
) -> Result<String, String> {
    let public = parse_rsa_public(public_pem)?;
    let data = decode_bytes(plaintext, plaintext_encoding)?;
    let ciphertext = match padding {
        RsaPadding::OaepSha256 => public
            .encrypt(&mut OsRng, Oaep::new::<RsaSha256>(), &data)
            .map_err(|err| err.to_string())?,
        RsaPadding::Pkcs1V15 => public
            .encrypt(&mut OsRng, Pkcs1v15Encrypt, &data)
            .map_err(|err| err.to_string())?,
    };
    encode_bytes(&ciphertext, output_encoding)
}

pub fn rsa_decrypt(
    private_pem: &str,
    ciphertext: &str,
    ciphertext_encoding: BinaryEncoding,
    padding: RsaPadding,
    output_encoding: BinaryEncoding,
) -> Result<String, String> {
    let private = parse_rsa_private(private_pem)?;
    let data = decode_bytes(ciphertext, ciphertext_encoding)?;
    let plaintext = match padding {
        RsaPadding::OaepSha256 => private
            .decrypt(Oaep::new::<RsaSha256>(), &data)
            .map_err(|err| err.to_string())?,
        RsaPadding::Pkcs1V15 => private
            .decrypt(Pkcs1v15Encrypt, &data)
            .map_err(|err| err.to_string())?,
    };
    encode_bytes(&plaintext, output_encoding)
}

pub fn rsa_sign(
    private_pem: &str,
    message: &str,
    message_encoding: BinaryEncoding,
    padding: RsaSignPadding,
    output_encoding: BinaryEncoding,
) -> Result<String, String> {
    let private = parse_rsa_private(private_pem)?;
    let message = decode_bytes(message, message_encoding)?;
    let signature = match padding {
        RsaSignPadding::Pkcs1V15Sha256 => {
            let signing_key = rsa::pkcs1v15::SigningKey::<RsaSha256>::new(private);
            signing_key.sign_with_rng(&mut OsRng, &message).to_bytes().to_vec()
        }
        RsaSignPadding::PssSha256 => {
            let signing_key = rsa::pss::BlindedSigningKey::<RsaSha256>::new(private);
            signing_key.sign_with_rng(&mut OsRng, &message).to_bytes().to_vec()
        }
    };
    encode_bytes(&signature, output_encoding)
}

pub fn rsa_verify(
    public_pem: &str,
    message: &str,
    message_encoding: BinaryEncoding,
    signature: &str,
    signature_encoding: BinaryEncoding,
    padding: RsaSignPadding,
) -> Result<bool, String> {
    let public = parse_rsa_public(public_pem)?;
    let message = decode_bytes(message, message_encoding)?;
    let signature = decode_bytes(signature, signature_encoding)?;
    let ok = match padding {
        RsaSignPadding::Pkcs1V15Sha256 => {
            let verifying_key = rsa::pkcs1v15::VerifyingKey::<RsaSha256>::new(public);
            let parsed = rsa::pkcs1v15::Signature::try_from(signature.as_slice())
                .map_err(|err| err.to_string())?;
            verifying_key.verify(&message, &parsed).is_ok()
        }
        RsaSignPadding::PssSha256 => {
            let verifying_key = rsa::pss::VerifyingKey::<RsaSha256>::new(public);
            let parsed =
                rsa::pss::Signature::try_from(signature.as_slice()).map_err(|err| err.to_string())?;
            verifying_key.verify(&message, &parsed).is_ok()
        }
    };
    Ok(ok)
}

pub fn sm2_generate_keypair() -> Result<Sm2KeyPair, String> {
    for _ in 0..64 {
        let mut d = [0u8; SM2_PRIV_LEN];
        getrandom::fill(&mut d).map_err(|err| err.to_string())?;
        if let Some(private) = Sm2PrivateKey::from_bytes_be(&d).into_option() {
            let public = private.public_key().to_sec1_uncompressed();
            return Ok(Sm2KeyPair {
                private_hex: hex::encode(d),
                public_hex: hex::encode(public),
            });
        }
    }
    Err("SM2 密钥生成失败".to_string())
}

pub fn sm2_encrypt(
    public_hex: &str,
    plaintext: &str,
    plaintext_encoding: BinaryEncoding,
    output_encoding: BinaryEncoding,
) -> Result<String, String> {
    let public = parse_sm2_public(public_hex)?;
    let plaintext = decode_bytes(plaintext, plaintext_encoding)?;
    let mut rng = SysRng;
    let ciphertext =
        gmcrypto_core::sm2::encrypt(&public, &plaintext, &mut rng).map_err(|err| err.to_string())?;
    encode_bytes(&ciphertext, output_encoding)
}

pub fn sm2_decrypt(
    private_hex: &str,
    ciphertext: &str,
    ciphertext_encoding: BinaryEncoding,
    output_encoding: BinaryEncoding,
) -> Result<String, String> {
    let private = parse_sm2_private(private_hex)?;
    let ciphertext = decode_bytes(ciphertext, ciphertext_encoding)?;
    let plaintext =
        gmcrypto_core::sm2::decrypt(&private, &ciphertext).map_err(|err| err.to_string())?;
    encode_bytes(&plaintext, output_encoding)
}

pub fn sm2_sign(
    private_hex: &str,
    message: &str,
    message_encoding: BinaryEncoding,
    output_encoding: BinaryEncoding,
) -> Result<String, String> {
    let private = parse_sm2_private(private_hex)?;
    let message = decode_bytes(message, message_encoding)?;
    let mut rng = SysRng;
    let signature = sign_with_id(&private, DEFAULT_SIGNER_ID, &message, &mut rng)
        .map_err(|err| err.to_string())?;
    encode_bytes(&signature, output_encoding)
}

pub fn sm2_verify(
    public_hex: &str,
    message: &str,
    message_encoding: BinaryEncoding,
    signature: &str,
    signature_encoding: BinaryEncoding,
) -> Result<bool, String> {
    let public = parse_sm2_public(public_hex)?;
    let message = decode_bytes(message, message_encoding)?;
    let signature = decode_bytes(signature, signature_encoding)?;
    Ok(verify_with_id(
        &public,
        DEFAULT_SIGNER_ID,
        &message,
        &signature,
    ))
}

pub fn sm3_hash(input: &str, encoding: BinaryEncoding) -> Result<String, String> {
    hash_text(input, encoding, HashAlg::Sm3)
}

pub fn sm4_encrypt(
    key: &str,
    key_encoding: BinaryEncoding,
    plaintext: &str,
    plaintext_encoding: BinaryEncoding,
    mode: Sm4Mode,
    output_encoding: BinaryEncoding,
) -> Result<String, String> {
    let key = sm4_key(key, key_encoding)?;
    let plaintext = decode_bytes(plaintext, plaintext_encoding)?;
    let packed = match mode {
        Sm4Mode::Cbc => {
            let mut iv = [0u8; SM4_BLOCK_LEN];
            OsRng.fill_bytes(&mut iv);
            let ciphertext = gmcrypto_core::sm4::mode_cbc::encrypt(&key, &iv, &plaintext);
            let mut packed = Vec::with_capacity(SM4_BLOCK_LEN + ciphertext.len());
            packed.extend_from_slice(&iv);
            packed.extend_from_slice(&ciphertext);
            packed
        }
        Sm4Mode::Ecb => sm4_ecb_encrypt(&key, &plaintext),
    };
    encode_bytes(&packed, output_encoding)
}

pub fn sm4_decrypt(
    key: &str,
    key_encoding: BinaryEncoding,
    ciphertext: &str,
    ciphertext_encoding: BinaryEncoding,
    mode: Sm4Mode,
    output_encoding: BinaryEncoding,
) -> Result<String, String> {
    let key = sm4_key(key, key_encoding)?;
    let packed = decode_bytes(ciphertext, ciphertext_encoding)?;
    let plaintext = match mode {
        Sm4Mode::Cbc => {
            if packed.len() < SM4_BLOCK_LEN * 2 {
                return Err("SM4-CBC 密文过短".to_string());
            }
            let (iv, body) = packed.split_at(SM4_BLOCK_LEN);
            let iv: [u8; SM4_BLOCK_LEN] = iv.try_into().map_err(|_| "SM4 IV 无效")?;
            gmcrypto_core::sm4::mode_cbc::decrypt(&key, &iv, body)
                .ok_or_else(|| "SM4-CBC 解密失败".to_string())?
        }
        Sm4Mode::Ecb => sm4_ecb_decrypt(&key, &packed)?,
    };
    encode_bytes(&plaintext, output_encoding)
}

fn decode_bytes(input: &str, encoding: BinaryEncoding) -> Result<Vec<u8>, String> {
    ensure_size_limit(input, MAX_TEXT_BYTES)?;
    match encoding {
        BinaryEncoding::Utf8 => Ok(input.as_bytes().to_vec()),
        BinaryEncoding::Hex => decode_hex(input),
        BinaryEncoding::Base64 => BASE64.decode(input.trim()).map_err(|err| err.to_string()),
    }
}

fn encode_bytes(bytes: &[u8], encoding: BinaryEncoding) -> Result<String, String> {
    match encoding {
        BinaryEncoding::Utf8 => String::from_utf8(bytes.to_vec()).map_err(|err| err.to_string()),
        BinaryEncoding::Hex => Ok(hex::encode(bytes)),
        BinaryEncoding::Base64 => Ok(BASE64.encode(bytes)),
    }
}

fn decode_hex(input: &str) -> Result<Vec<u8>, String> {
    let cleaned: String = input.chars().filter(|ch| !ch.is_ascii_whitespace()).collect();
    let stripped = cleaned
        .strip_prefix("0x")
        .or_else(|| cleaned.strip_prefix("0X"))
        .unwrap_or(&cleaned);
    hex::decode(stripped).map_err(|err| err.to_string())
}

fn digest_hex(alg: HashAlg, data: &[u8]) -> String {
    match alg {
        HashAlg::Md5 => {
            use md5::Digest;
            hex::encode(md5::Md5::digest(data))
        }
        HashAlg::Sha1 => {
            use sha1::Digest;
            hex::encode(sha1::Sha1::digest(data))
        }
        HashAlg::Sha256 => {
            use sha2::Digest;
            hex::encode(sha2::Sha256::digest(data))
        }
        HashAlg::Sm3 => hex::encode(gmcrypto_core::sm3::hash(data)),
    }
}

fn aes_key(key: &str, encoding: BinaryEncoding) -> Result<Vec<u8>, String> {
    let bytes = decode_bytes(key, encoding)?;
    if bytes.len() != AES_KEY_LEN {
        return Err("AES-256-GCM 密钥必须是 32 字节".to_string());
    }
    Ok(bytes)
}

fn sm4_key(key: &str, encoding: BinaryEncoding) -> Result<[u8; SM4_BLOCK_LEN], String> {
    let bytes = decode_bytes(key, encoding)?;
    bytes
        .try_into()
        .map_err(|_| "SM4 密钥必须是 16 字节".to_string())
}

fn parse_rsa_private(pem: &str) -> Result<RsaPrivateKey, String> {
    ensure_size_limit(pem, MAX_TEXT_BYTES)?;
    let pem = pem.trim();
    RsaPrivateKey::from_pkcs8_pem(pem)
        .or_else(|_| RsaPrivateKey::from_pkcs1_pem(pem))
        .map_err(|err| err.to_string())
}

fn parse_rsa_public(pem: &str) -> Result<RsaPublicKey, String> {
    ensure_size_limit(pem, MAX_TEXT_BYTES)?;
    let pem = pem.trim();
    RsaPublicKey::from_public_key_pem(pem)
        .or_else(|_| RsaPublicKey::from_pkcs1_pem(pem))
        .map_err(|err| err.to_string())
}

fn parse_sm2_private(hex_str: &str) -> Result<Sm2PrivateKey, String> {
    let bytes = decode_bytes(hex_str, BinaryEncoding::Hex)?;
    let arr: [u8; SM2_PRIV_LEN] = bytes
        .try_into()
        .map_err(|_| "SM2 私钥必须是 32 字节 hex".to_string())?;
    Sm2PrivateKey::from_bytes_be(&arr)
        .into_option()
        .ok_or_else(|| "无效的 SM2 私钥".to_string())
}

fn parse_sm2_public(hex_str: &str) -> Result<Sm2PublicKey, String> {
    let bytes = decode_bytes(hex_str, BinaryEncoding::Hex)?;
    Sm2PublicKey::from_sec1_bytes(&bytes).ok_or_else(|| "无效的 SM2 公钥".to_string())
}

fn pkcs7_pad(data: &[u8], block: usize) -> Vec<u8> {
    let pad_len = block - (data.len() % block);
    let mut out = Vec::with_capacity(data.len() + pad_len);
    out.extend_from_slice(data);
    out.resize(data.len() + pad_len, pad_len as u8);
    out
}

fn pkcs7_unpad(data: &[u8], block: usize) -> Result<Vec<u8>, String> {
    if data.is_empty() || data.len() % block != 0 {
        return Err("PKCS7 填充无效".to_string());
    }
    let pad_len = *data.last().unwrap() as usize;
    if pad_len == 0 || pad_len > block || pad_len > data.len() {
        return Err("PKCS7 填充无效".to_string());
    }
    if !data[data.len() - pad_len..]
        .iter()
        .all(|byte| *byte as usize == pad_len)
    {
        return Err("PKCS7 填充无效".to_string());
    }
    Ok(data[..data.len() - pad_len].to_vec())
}

fn sm4_ecb_encrypt(key: &[u8; SM4_BLOCK_LEN], plaintext: &[u8]) -> Vec<u8> {
    let mut buf = pkcs7_pad(plaintext, SM4_BLOCK_LEN);
    let cipher = gmcrypto_core::sm4::cipher::Sm4Cipher::new(key);
    for chunk in buf.chunks_exact_mut(SM4_BLOCK_LEN) {
        let block: &mut [u8; SM4_BLOCK_LEN] = chunk.try_into().expect("SM4 block is 16 bytes");
        cipher.encrypt_block(block);
    }
    buf
}

fn sm4_ecb_decrypt(key: &[u8; SM4_BLOCK_LEN], ciphertext: &[u8]) -> Result<Vec<u8>, String> {
    if ciphertext.is_empty() || ciphertext.len() % SM4_BLOCK_LEN != 0 {
        return Err("SM4-ECB 密文长度必须是 16 的倍数".to_string());
    }
    let mut buf = ciphertext.to_vec();
    let cipher = gmcrypto_core::sm4::cipher::Sm4Cipher::new(key);
    for chunk in buf.chunks_exact_mut(SM4_BLOCK_LEN) {
        let block: &mut [u8; SM4_BLOCK_LEN] = chunk.try_into().expect("SM4 block is 16 bytes");
        cipher.decrypt_block(block);
    }
    pkcs7_unpad(&buf, SM4_BLOCK_LEN)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn base64_roundtrip() {
        let encoded = codec_encode("hello DevKit", BinaryEncoding::Base64).unwrap();
        assert_eq!(encoded, "aGVsbG8gRGV2S2l0");
        assert_eq!(
            codec_decode(&encoded, BinaryEncoding::Base64).unwrap(),
            "hello DevKit"
        );
    }

    #[test]
    fn sha256_of_abc() {
        let digest = hash_text("abc", BinaryEncoding::Utf8, HashAlg::Sha256).unwrap();
        assert_eq!(
            digest,
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        );
    }

    #[test]
    fn hmac_sha256_is_deterministic() {
        let mac = hmac_sha256(
            "key",
            BinaryEncoding::Utf8,
            "The quick brown fox jumps over the lazy dog",
            BinaryEncoding::Utf8,
        )
        .unwrap();
        assert_eq!(
            mac,
            "f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8"
        );
        assert_eq!(
            mac,
            hmac_sha256(
                "key",
                BinaryEncoding::Utf8,
                "The quick brown fox jumps over the lazy dog",
                BinaryEncoding::Utf8,
            )
            .unwrap()
        );
    }

    #[test]
    fn aes256_gcm_roundtrip() {
        let key = hex::encode([0x11u8; 32]);
        let packed = aes256_gcm_encrypt(
            &key,
            BinaryEncoding::Hex,
            "secret payload",
            BinaryEncoding::Utf8,
            BinaryEncoding::Hex,
        )
        .unwrap();
        let plain = aes256_gcm_decrypt(
            &key,
            BinaryEncoding::Hex,
            &packed,
            BinaryEncoding::Hex,
            BinaryEncoding::Utf8,
        )
        .unwrap();
        assert_eq!(plain, "secret payload");
        assert!(packed.len() > 24);
    }

    #[test]
    fn rsa_1024_oaep_roundtrip() {
        let pair = rsa_generate_keypair(Some(1024)).unwrap();
        let packed = rsa_encrypt(
            &pair.public_pem,
            "rsa-hi",
            BinaryEncoding::Utf8,
            RsaPadding::OaepSha256,
            BinaryEncoding::Hex,
        )
        .unwrap();
        let plain = rsa_decrypt(
            &pair.private_pem,
            &packed,
            BinaryEncoding::Hex,
            RsaPadding::OaepSha256,
            BinaryEncoding::Utf8,
        )
        .unwrap();
        assert_eq!(plain, "rsa-hi");
    }

    #[test]
    fn rsa_pss_sign_verify() {
        let pair = rsa_generate_keypair(Some(1024)).unwrap();
        let signature = rsa_sign(
            &pair.private_pem,
            "sign-me",
            BinaryEncoding::Utf8,
            RsaSignPadding::PssSha256,
            BinaryEncoding::Hex,
        )
        .unwrap();
        assert!(rsa_verify(
            &pair.public_pem,
            "sign-me",
            BinaryEncoding::Utf8,
            &signature,
            BinaryEncoding::Hex,
            RsaSignPadding::PssSha256,
        )
        .unwrap());
        assert!(!rsa_verify(
            &pair.public_pem,
            "other",
            BinaryEncoding::Utf8,
            &signature,
            BinaryEncoding::Hex,
            RsaSignPadding::PssSha256,
        )
        .unwrap());
    }

    #[test]
    fn sm4_cbc_and_ecb_roundtrip() {
        let key = "0123456789abcdef";
        for mode in [Sm4Mode::Cbc, Sm4Mode::Ecb] {
            let packed = sm4_encrypt(
                key,
                BinaryEncoding::Utf8,
                "hello sm4",
                BinaryEncoding::Utf8,
                mode,
                BinaryEncoding::Hex,
            )
            .unwrap();
            let plain = sm4_decrypt(
                key,
                BinaryEncoding::Utf8,
                &packed,
                BinaryEncoding::Hex,
                mode,
                BinaryEncoding::Utf8,
            )
            .unwrap();
            assert_eq!(plain, "hello sm4");
        }
    }

    #[test]
    fn sm2_encrypt_and_sign_roundtrip() {
        let pair = sm2_generate_keypair().unwrap();
        assert_eq!(pair.private_hex.len(), 64);
        assert!(pair.public_hex.starts_with("04"));
        assert_eq!(pair.public_hex.len(), 130);

        let packed = sm2_encrypt(
            &pair.public_hex,
            "gm hello",
            BinaryEncoding::Utf8,
            BinaryEncoding::Hex,
        )
        .unwrap();
        let plain = sm2_decrypt(
            &pair.private_hex,
            &packed,
            BinaryEncoding::Hex,
            BinaryEncoding::Utf8,
        )
        .unwrap();
        assert_eq!(plain, "gm hello");

        let signature = sm2_sign(
            &pair.private_hex,
            "gm hello",
            BinaryEncoding::Utf8,
            BinaryEncoding::Hex,
        )
        .unwrap();
        assert!(sm2_verify(
            &pair.public_hex,
            "gm hello",
            BinaryEncoding::Utf8,
            &signature,
            BinaryEncoding::Hex,
        )
        .unwrap());
        assert!(!sm2_verify(
            &pair.public_hex,
            "other",
            BinaryEncoding::Utf8,
            &signature,
            BinaryEncoding::Hex,
        )
        .unwrap());
    }
}
