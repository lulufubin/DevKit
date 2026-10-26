use devkit_core::crypto_compare as compare;
use devkit_core::crypto_tools as core;

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

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum AesMode {
    Gcm,
    Cbc,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum AesKeyMode {
    Raw,
    Passphrase,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum CompareStatus {
    Match,
    Differ,
    Unsupported,
    Error,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CompareColumn {
    pub label: String,
    pub output: String,
    pub status: CompareStatus,
    pub message: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CompareResult {
    pub rust: CompareColumn,
    pub python: CompareColumn,
    pub node: CompareColumn,
}

impl From<BinaryEncoding> for core::BinaryEncoding {
    fn from(value: BinaryEncoding) -> Self {
        match value {
            BinaryEncoding::Utf8 => Self::Utf8,
            BinaryEncoding::Hex => Self::Hex,
            BinaryEncoding::Base64 => Self::Base64,
        }
    }
}

impl From<HashAlg> for core::HashAlg {
    fn from(value: HashAlg) -> Self {
        match value {
            HashAlg::Md5 => Self::Md5,
            HashAlg::Sha1 => Self::Sha1,
            HashAlg::Sha256 => Self::Sha256,
            HashAlg::Sm3 => Self::Sm3,
        }
    }
}

impl From<RsaPadding> for core::RsaPadding {
    fn from(value: RsaPadding) -> Self {
        match value {
            RsaPadding::OaepSha256 => Self::OaepSha256,
            RsaPadding::Pkcs1V15 => Self::Pkcs1V15,
        }
    }
}

impl From<RsaSignPadding> for core::RsaSignPadding {
    fn from(value: RsaSignPadding) -> Self {
        match value {
            RsaSignPadding::Pkcs1V15Sha256 => Self::Pkcs1V15Sha256,
            RsaSignPadding::PssSha256 => Self::PssSha256,
        }
    }
}

impl From<Sm4Mode> for core::Sm4Mode {
    fn from(value: Sm4Mode) -> Self {
        match value {
            Sm4Mode::Ecb => Self::Ecb,
            Sm4Mode::Cbc => Self::Cbc,
        }
    }
}

impl From<AesMode> for compare::AesMode {
    fn from(value: AesMode) -> Self {
        match value {
            AesMode::Gcm => Self::Gcm,
            AesMode::Cbc => Self::Cbc,
        }
    }
}

impl From<AesKeyMode> for compare::AesKeyMode {
    fn from(value: AesKeyMode) -> Self {
        match value {
            AesKeyMode::Raw => Self::Raw,
            AesKeyMode::Passphrase => Self::Passphrase,
        }
    }
}

fn map_status(status: compare::CompareStatus) -> CompareStatus {
    match status {
        compare::CompareStatus::Match => CompareStatus::Match,
        compare::CompareStatus::Differ => CompareStatus::Differ,
        compare::CompareStatus::Unsupported => CompareStatus::Unsupported,
        compare::CompareStatus::Error => CompareStatus::Error,
    }
}

fn map_column(column: compare::CompareColumn) -> CompareColumn {
    CompareColumn {
        label: column.label,
        output: column.output,
        status: map_status(column.status),
        message: column.message,
    }
}

fn map_result(result: compare::CompareResult) -> CompareResult {
    CompareResult {
        rust: map_column(result.rust),
        python: map_column(result.python),
        node: map_column(result.node),
    }
}

pub fn codec_encode(input: String, encoding: BinaryEncoding) -> Result<String, String> {
    core::codec_encode(&input, encoding.into())
}

pub fn codec_decode(input: String, encoding: BinaryEncoding) -> Result<String, String> {
    core::codec_decode(&input, encoding.into())
}

pub fn url_encode(input: String) -> Result<String, String> {
    core::url_encode(&input)
}

pub fn url_decode(input: String) -> Result<String, String> {
    core::url_decode(&input)
}

pub fn hash_text(input: String, encoding: BinaryEncoding, alg: HashAlg) -> Result<String, String> {
    core::hash_text(&input, encoding.into(), alg.into())
}

pub fn hmac_sha256(
    key: String,
    key_encoding: BinaryEncoding,
    message: String,
    message_encoding: BinaryEncoding,
) -> Result<String, String> {
    core::hmac_sha256(&key, key_encoding.into(), &message, message_encoding.into())
}

pub fn aes256_gcm_encrypt(
    key: String,
    key_encoding: BinaryEncoding,
    plaintext: String,
    plaintext_encoding: BinaryEncoding,
    output_encoding: BinaryEncoding,
) -> Result<String, String> {
    core::aes256_gcm_encrypt(
        &key,
        key_encoding.into(),
        &plaintext,
        plaintext_encoding.into(),
        output_encoding.into(),
    )
}

pub fn aes256_gcm_decrypt(
    key: String,
    key_encoding: BinaryEncoding,
    ciphertext: String,
    ciphertext_encoding: BinaryEncoding,
    output_encoding: BinaryEncoding,
) -> Result<String, String> {
    core::aes256_gcm_decrypt(
        &key,
        key_encoding.into(),
        &ciphertext,
        ciphertext_encoding.into(),
        output_encoding.into(),
    )
}

pub fn rsa_generate_keypair(bits: Option<u32>) -> Result<RsaKeyPair, String> {
    let pair = core::rsa_generate_keypair(bits)?;
    Ok(RsaKeyPair {
        private_pem: pair.private_pem,
        public_pem: pair.public_pem,
    })
}

pub fn rsa_encrypt(
    public_pem: String,
    plaintext: String,
    plaintext_encoding: BinaryEncoding,
    padding: RsaPadding,
    output_encoding: BinaryEncoding,
) -> Result<String, String> {
    core::rsa_encrypt(
        &public_pem,
        &plaintext,
        plaintext_encoding.into(),
        padding.into(),
        output_encoding.into(),
    )
}

pub fn rsa_decrypt(
    private_pem: String,
    ciphertext: String,
    ciphertext_encoding: BinaryEncoding,
    padding: RsaPadding,
    output_encoding: BinaryEncoding,
) -> Result<String, String> {
    core::rsa_decrypt(
        &private_pem,
        &ciphertext,
        ciphertext_encoding.into(),
        padding.into(),
        output_encoding.into(),
    )
}

pub fn rsa_sign(
    private_pem: String,
    message: String,
    message_encoding: BinaryEncoding,
    padding: RsaSignPadding,
    output_encoding: BinaryEncoding,
) -> Result<String, String> {
    core::rsa_sign(
        &private_pem,
        &message,
        message_encoding.into(),
        padding.into(),
        output_encoding.into(),
    )
}

pub fn rsa_verify(
    public_pem: String,
    message: String,
    message_encoding: BinaryEncoding,
    signature: String,
    signature_encoding: BinaryEncoding,
    padding: RsaSignPadding,
) -> Result<bool, String> {
    core::rsa_verify(
        &public_pem,
        &message,
        message_encoding.into(),
        &signature,
        signature_encoding.into(),
        padding.into(),
    )
}

pub fn sm2_generate_keypair() -> Result<Sm2KeyPair, String> {
    let pair = core::sm2_generate_keypair()?;
    Ok(Sm2KeyPair {
        private_hex: pair.private_hex,
        public_hex: pair.public_hex,
    })
}

pub fn sm2_encrypt(
    public_hex: String,
    plaintext: String,
    plaintext_encoding: BinaryEncoding,
    output_encoding: BinaryEncoding,
) -> Result<String, String> {
    core::sm2_encrypt(
        &public_hex,
        &plaintext,
        plaintext_encoding.into(),
        output_encoding.into(),
    )
}

pub fn sm2_decrypt(
    private_hex: String,
    ciphertext: String,
    ciphertext_encoding: BinaryEncoding,
    output_encoding: BinaryEncoding,
) -> Result<String, String> {
    core::sm2_decrypt(
        &private_hex,
        &ciphertext,
        ciphertext_encoding.into(),
        output_encoding.into(),
    )
}

pub fn sm2_sign(
    private_hex: String,
    message: String,
    message_encoding: BinaryEncoding,
    output_encoding: BinaryEncoding,
) -> Result<String, String> {
    core::sm2_sign(
        &private_hex,
        &message,
        message_encoding.into(),
        output_encoding.into(),
    )
}

pub fn sm2_verify(
    public_hex: String,
    message: String,
    message_encoding: BinaryEncoding,
    signature: String,
    signature_encoding: BinaryEncoding,
) -> Result<bool, String> {
    core::sm2_verify(
        &public_hex,
        &message,
        message_encoding.into(),
        &signature,
        signature_encoding.into(),
    )
}

pub fn sm3_hash(input: String, encoding: BinaryEncoding) -> Result<String, String> {
    core::sm3_hash(&input, encoding.into())
}

pub fn sm4_encrypt(
    key: String,
    key_encoding: BinaryEncoding,
    plaintext: String,
    plaintext_encoding: BinaryEncoding,
    mode: Sm4Mode,
    output_encoding: BinaryEncoding,
) -> Result<String, String> {
    core::sm4_encrypt(
        &key,
        key_encoding.into(),
        &plaintext,
        plaintext_encoding.into(),
        mode.into(),
        output_encoding.into(),
    )
}

pub fn sm4_decrypt(
    key: String,
    key_encoding: BinaryEncoding,
    ciphertext: String,
    ciphertext_encoding: BinaryEncoding,
    mode: Sm4Mode,
    output_encoding: BinaryEncoding,
) -> Result<String, String> {
    core::sm4_decrypt(
        &key,
        key_encoding.into(),
        &ciphertext,
        ciphertext_encoding.into(),
        mode.into(),
        output_encoding.into(),
    )
}

pub fn compare_hash(input: String, encoding: BinaryEncoding, alg: HashAlg) -> Result<CompareResult, String> {
    compare::compare_hash(&input, encoding.into(), alg.into()).map(map_result)
}

pub fn compare_hmac(
    key: String,
    key_encoding: BinaryEncoding,
    message: String,
    message_encoding: BinaryEncoding,
) -> Result<CompareResult, String> {
    compare::compare_hmac(&key, key_encoding.into(), &message, message_encoding.into()).map(map_result)
}

pub fn compare_aes_encrypt(
    key: String,
    key_encoding: BinaryEncoding,
    plaintext: String,
    plaintext_encoding: BinaryEncoding,
    output_encoding: BinaryEncoding,
    mode: AesMode,
    key_mode: AesKeyMode,
) -> Result<CompareResult, String> {
    compare::compare_aes_encrypt(
        &key,
        key_encoding.into(),
        &plaintext,
        plaintext_encoding.into(),
        output_encoding.into(),
        mode.into(),
        key_mode.into(),
    )
    .map(map_result)
}

pub fn compare_aes_decrypt(
    key: String,
    key_encoding: BinaryEncoding,
    ciphertext: String,
    ciphertext_encoding: BinaryEncoding,
    output_encoding: BinaryEncoding,
    mode: AesMode,
    key_mode: AesKeyMode,
) -> Result<CompareResult, String> {
    compare::compare_aes_decrypt(
        &key,
        key_encoding.into(),
        &ciphertext,
        ciphertext_encoding.into(),
        output_encoding.into(),
        mode.into(),
        key_mode.into(),
    )
    .map(map_result)
}
