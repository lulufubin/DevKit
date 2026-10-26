//! 三库对比：进程内 Rust + 可选 Python / Node 助手。

use std::io::{BufRead, BufReader, Write};
use std::path::PathBuf;
use std::process::{Child, ChildStdin, ChildStdout, Command, Stdio};
use std::sync::Mutex;
use std::time::{Duration, Instant};

use base64::engine::general_purpose::STANDARD as BASE64;
use base64::Engine;
use serde_json::{json, Value};

use crate::crypto_tools::{
    aes256_cbc_decrypt, aes256_cbc_encrypt, aes256_cbc_passphrase_decrypt, aes256_cbc_passphrase_encrypt,
    aes256_gcm_decrypt, aes256_gcm_encrypt, decode_bytes, encode_bytes, hash_text, hmac_sha256, split_cbc_iv,
    split_gcm_nonce, split_openssl_salt, BinaryEncoding, HashAlg,
};
use crate::json::{ensure_size_limit, MAX_TEXT_BYTES};

const HELPER_TIMEOUT: Duration = Duration::from_secs(30);

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

struct HelperSpec {
    label: &'static str,
    program: PathBuf,
    args: Vec<String>,
    cwd: PathBuf,
}

struct HelperProc {
    child: Child,
    stdin: ChildStdin,
    stdout: BufReader<ChildStdout>,
}

impl Drop for HelperProc {
    fn drop(&mut self) {
        let _ = self.child.kill();
        let _ = self.child.wait();
    }
}

static PYTHON: Mutex<Option<HelperProc>> = Mutex::new(None);
static NODE: Mutex<Option<HelperProc>> = Mutex::new(None);

pub fn compare_hash(input: &str, encoding: BinaryEncoding, alg: HashAlg) -> Result<CompareResult, String> {
    ensure_size_limit(input, MAX_TEXT_BYTES)?;
    let rust = match hash_text(input, encoding, alg) {
        Ok(output) => ok_column("Rust", output),
        Err(error) => err_column("Rust", error),
    };
    let req = json!({
        "id": "hash",
        "op": "hash",
        "alg": hash_alg_name(alg),
        "data": input,
        "encoding": encoding_name(encoding),
    });
    Ok(finish(rust, ask_python(&req, alg == HashAlg::Sm3), ask_node(&req, alg == HashAlg::Sm3)))
}

pub fn compare_hmac(
    key: &str,
    key_encoding: BinaryEncoding,
    message: &str,
    message_encoding: BinaryEncoding,
) -> Result<CompareResult, String> {
    ensure_size_limit(key, MAX_TEXT_BYTES)?;
    ensure_size_limit(message, MAX_TEXT_BYTES)?;
    let rust = match hmac_sha256(key, key_encoding, message, message_encoding) {
        Ok(output) => ok_column("Rust", output),
        Err(error) => err_column("Rust", error),
    };
    let req = json!({
        "id": "hmac",
        "op": "hmac",
        "alg": "sha256",
        "key": key,
        "keyEncoding": encoding_name(key_encoding),
        "data": message,
        "encoding": encoding_name(message_encoding),
    });
    Ok(finish(rust, ask_python(&req, false), ask_node(&req, false)))
}

pub fn compare_aes_encrypt(
    key: &str,
    key_encoding: BinaryEncoding,
    plaintext: &str,
    plaintext_encoding: BinaryEncoding,
    output_encoding: BinaryEncoding,
    mode: AesMode,
    key_mode: AesKeyMode,
) -> Result<CompareResult, String> {
    ensure_size_limit(key, MAX_TEXT_BYTES)?;
    ensure_size_limit(plaintext, MAX_TEXT_BYTES)?;
    if mode == AesMode::Gcm && key_mode == AesKeyMode::Passphrase {
        return Err("GCM 只支持原始密钥".to_string());
    }
    match (mode, key_mode) {
        (AesMode::Gcm, AesKeyMode::Raw) => {
            let packed = aes256_gcm_encrypt(key, key_encoding, plaintext, plaintext_encoding, output_encoding)?;
            let raw = decode_bytes(&packed, output_encoding)?;
            let (nonce, _) = split_gcm_nonce(&raw)?;
            let rust = ok_column("Rust", packed);
            let req = json!({
                "id": "enc",
                "op": "encrypt",
                "alg": "aes-256-gcm",
                "key": key,
                "keyEncoding": encoding_name(key_encoding),
                "data": plaintext,
                "encoding": encoding_name(plaintext_encoding),
                "outputEncoding": encoding_name(output_encoding),
                "keyMode": "raw",
                "nonceHex": hex::encode(nonce),
            });
            Ok(finish(rust, ask_python(&req, false), ask_node(&req, true)))
        }
        (AesMode::Cbc, AesKeyMode::Raw) => {
            let packed = aes256_cbc_encrypt(key, key_encoding, plaintext, plaintext_encoding, output_encoding, None)?;
            let raw = decode_bytes(&packed, output_encoding)?;
            let (iv, _) = split_cbc_iv(&raw)?;
            let rust = ok_column("Rust", packed);
            let req = json!({
                "id": "enc",
                "op": "encrypt",
                "alg": "aes-256-cbc",
                "key": key,
                "keyEncoding": encoding_name(key_encoding),
                "data": plaintext,
                "encoding": encoding_name(plaintext_encoding),
                "outputEncoding": encoding_name(output_encoding),
                "keyMode": "raw",
                "ivHex": hex::encode(iv),
            });
            Ok(finish(rust, ask_python(&req, false), ask_node(&req, false)))
        }
        (AesMode::Cbc, AesKeyMode::Passphrase) => {
            let packed = aes256_cbc_passphrase_encrypt(key, plaintext, plaintext_encoding, None)?;
            let raw = BASE64.decode(packed.trim()).map_err(|err| err.to_string())?;
            let (salt, _) = split_openssl_salt(&raw)?;
            let rust = ok_column("Rust", packed);
            let req = json!({
                "id": "enc",
                "op": "encrypt",
                "alg": "aes-256-cbc",
                "key": key,
                "keyEncoding": "utf8",
                "data": plaintext,
                "encoding": encoding_name(plaintext_encoding),
                "outputEncoding": "base64",
                "keyMode": "passphrase",
                "saltHex": hex::encode(salt),
            });
            Ok(finish(rust, ask_python(&req, false), ask_node(&req, false)))
        }
        (AesMode::Gcm, AesKeyMode::Passphrase) => Err("GCM 只支持原始密钥".to_string()),
    }
}

pub fn compare_aes_decrypt(
    key: &str,
    key_encoding: BinaryEncoding,
    ciphertext: &str,
    ciphertext_encoding: BinaryEncoding,
    output_encoding: BinaryEncoding,
    mode: AesMode,
    key_mode: AesKeyMode,
) -> Result<CompareResult, String> {
    ensure_size_limit(key, MAX_TEXT_BYTES)?;
    ensure_size_limit(ciphertext, MAX_TEXT_BYTES)?;
    if mode == AesMode::Gcm && key_mode == AesKeyMode::Passphrase {
        return Err("GCM 只支持原始密钥".to_string());
    }
    let rust = match (mode, key_mode) {
        (AesMode::Gcm, AesKeyMode::Raw) => {
            aes256_gcm_decrypt(key, key_encoding, ciphertext, ciphertext_encoding, output_encoding)
        }
        (AesMode::Cbc, AesKeyMode::Raw) => {
            aes256_cbc_decrypt(key, key_encoding, ciphertext, ciphertext_encoding, output_encoding)
        }
        (AesMode::Cbc, AesKeyMode::Passphrase) => {
            aes256_cbc_passphrase_decrypt(key, ciphertext).and_then(|plain| encode_bytes(plain.as_bytes(), output_encoding))
        }
        (AesMode::Gcm, AesKeyMode::Passphrase) => Err("GCM 只支持原始密钥".to_string()),
    };
    let rust = match rust {
        Ok(output) => ok_column("Rust", output),
        Err(error) => err_column("Rust", error),
    };
    let alg = match mode {
        AesMode::Gcm => "aes-256-gcm",
        AesMode::Cbc => "aes-256-cbc",
    };
    let req = json!({
        "id": "dec",
        "op": "decrypt",
        "alg": alg,
        "key": key,
        "keyEncoding": if key_mode == AesKeyMode::Passphrase { "utf8" } else { encoding_name(key_encoding) },
        "data": ciphertext,
        "encoding": if key_mode == AesKeyMode::Passphrase { "base64" } else { encoding_name(ciphertext_encoding) },
        "outputEncoding": encoding_name(output_encoding),
        "keyMode": if key_mode == AesKeyMode::Passphrase { "passphrase" } else { "raw" },
    });
    let node_unsupported = mode == AesMode::Gcm;
    Ok(finish(rust, ask_python(&req, false), ask_node(&req, node_unsupported)))
}

fn finish(rust: CompareColumn, python: CompareColumn, node: CompareColumn) -> CompareResult {
    CompareResult {
        python: against_rust(&rust, python),
        node: against_rust(&rust, node),
        rust,
    }
}

fn against_rust(rust: &CompareColumn, mut other: CompareColumn) -> CompareColumn {
    if other.status == CompareStatus::Error || other.status == CompareStatus::Unsupported {
        return other;
    }
    if rust.status != CompareStatus::Match && rust.status != CompareStatus::Differ {
        // Rust 失败时助手成功只标为已算出，不叫「一致」
        if other.status == CompareStatus::Match && rust.status == CompareStatus::Error {
            other.status = CompareStatus::Differ;
            other.message = "Rust 失败，无法对齐".to_string();
        }
        return other;
    }
    if other.output == rust.output {
        other.status = CompareStatus::Match;
        other.message = "一致".to_string();
    } else {
        other.status = CompareStatus::Differ;
        other.message = "不一致".to_string();
    }
    other
}

fn ok_column(label: &str, output: String) -> CompareColumn {
    CompareColumn {
        label: label.to_string(),
        output,
        status: CompareStatus::Match,
        message: "成功".to_string(),
    }
}

fn err_column(label: &str, error: String) -> CompareColumn {
    CompareColumn {
        label: label.to_string(),
        output: String::new(),
        status: CompareStatus::Error,
        message: sanitize_error(error),
    }
}

fn unsupported_column(label: &str, message: &str) -> CompareColumn {
    CompareColumn {
        label: label.to_string(),
        output: String::new(),
        status: CompareStatus::Unsupported,
        message: message.to_string(),
    }
}

fn sanitize_error(error: String) -> String {
    error
}

fn hash_alg_name(alg: HashAlg) -> &'static str {
    match alg {
        HashAlg::Md5 => "md5",
        HashAlg::Sha1 => "sha1",
        HashAlg::Sha256 => "sha256",
        HashAlg::Sm3 => "sm3",
    }
}

fn encoding_name(encoding: BinaryEncoding) -> &'static str {
    match encoding {
        BinaryEncoding::Utf8 => "utf8",
        BinaryEncoding::Hex => "hex",
        BinaryEncoding::Base64 => "base64",
    }
}

fn ask_python(req: &Value, force_unsupported: bool) -> CompareColumn {
    if force_unsupported {
        return unsupported_column("Python", "Python 标准库不支持 SM3");
    }
    ask_named("Python", python_spec(), req)
}

fn ask_node(req: &Value, force_unsupported: bool) -> CompareColumn {
    if force_unsupported {
        let reason = if req.get("alg").and_then(|v| v.as_str()) == Some("sm3") {
            "crypto-js 不支持 SM3"
        } else {
            "crypto-js 不支持 AES-GCM"
        };
        return unsupported_column("crypto-js", reason);
    }
    ask_named("crypto-js", node_spec(), req)
}

fn ask_named(label: &str, spec: Option<HelperSpec>, req: &Value) -> CompareColumn {
    let Some(spec) = spec else {
        return err_column(label, missing_helper_message());
    };
    match call_helper(&spec, req) {
        Ok(value) => column_from_json(label, value),
        Err(error) => err_column(label, error),
    }
}

fn column_from_json(label: &str, value: Value) -> CompareColumn {
    if value.get("unsupported").and_then(|v| v.as_bool()).unwrap_or(false) {
        return unsupported_column(label, value.get("error").and_then(|v| v.as_str()).unwrap_or("不支持"));
    }
    if value.get("ok").and_then(|v| v.as_bool()).unwrap_or(false) {
        return ok_column(
            label,
            value.get("output").and_then(|v| v.as_str()).unwrap_or("").to_string(),
        );
    }
    err_column(
        label,
        value
            .get("error")
            .and_then(|v| v.as_str())
            .unwrap_or("助手返回失败")
            .to_string(),
    )
}

fn missing_helper_message() -> String {
    if cfg!(windows) {
        "未找到助手，请先按文档打包".to_string()
    } else {
        "当前安装包未带 Python / Node 助手".to_string()
    }
}

fn python_spec() -> Option<HelperSpec> {
    let roots = helper_roots();
    for root in &roots {
        let exe = root.join("crypto-python").join(python_exe_name());
        if exe.is_file() {
            let cwd = exe.parent()?.to_path_buf();
            return Some(HelperSpec {
                label: "Python",
                program: exe,
                args: Vec::new(),
                cwd,
            });
        }
    }
    None
}

fn node_spec() -> Option<HelperSpec> {
    let roots = helper_roots();
    for root in &roots {
        let dir = root.join("crypto-node");
        let node = dir.join(node_exe_name());
        let script = dir.join("index.js");
        if node.is_file() && script.is_file() {
            return Some(HelperSpec {
                label: "crypto-js",
                program: node,
                args: vec![script.to_string_lossy().into_owned()],
                cwd: dir,
            });
        }
    }
    None
}

fn python_exe_name() -> &'static str {
    if cfg!(windows) {
        "devkit-crypto-python.exe"
    } else {
        "devkit-crypto-python"
    }
}

fn node_exe_name() -> &'static str {
    if cfg!(windows) {
        "node.exe"
    } else {
        "node"
    }
}

fn helper_roots() -> Vec<PathBuf> {
    let mut roots = Vec::new();
    if let Ok(exe) = std::env::current_exe() {
        if let Some(dir) = exe.parent() {
            roots.push(dir.join("helpers"));
            roots.push(dir.join("data").join("helpers"));
        }
    }
    let repo = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../..");
    roots.push(repo.join("helpers/dist"));
    roots.push(repo.join("helpers"));
    roots
}

fn call_helper(spec: &HelperSpec, req: &Value) -> Result<Value, String> {
    let slot: &Mutex<Option<HelperProc>> = if spec.label == "Python" { &PYTHON } else { &NODE };
    let mut guard = slot.lock().map_err(|_| "助手锁失败".to_string())?;
    if guard.as_mut().is_some_and(|proc| proc.child.try_wait().ok().flatten().is_some()) {
        *guard = None;
    }
    if guard.is_none() {
        *guard = Some(spawn_helper(spec)?);
    }
    let proc = guard.as_mut().ok_or_else(|| "助手未启动".to_string())?;
    match write_and_read(proc, req) {
        Ok(value) => Ok(value),
        Err(error) => {
            *guard = None;
            Err(error)
        }
    }
}

/// Windows 上 node.exe / Nuitka 默认是控制台程序，不设此标志会弹出黑窗。
const CREATE_NO_WINDOW: u32 = 0x0800_0000;

fn hide_helper_console(cmd: &mut Command) {
    #[cfg(windows)]
    {
        use std::os::windows::process::CommandExt;
        cmd.creation_flags(CREATE_NO_WINDOW);
    }
    let _ = cmd;
}

fn spawn_helper(spec: &HelperSpec) -> Result<HelperProc, String> {
    let mut cmd = Command::new(&spec.program);
    cmd.args(&spec.args)
        .current_dir(&spec.cwd)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());
    hide_helper_console(&mut cmd);
    let mut child = cmd.spawn().map_err(|err| format!("无法启动助手：{err}"))?;
    let stdin = child.stdin.take().ok_or_else(|| "助手没有 stdin".to_string())?;
    let stdout = child.stdout.take().ok_or_else(|| "助手没有 stdout".to_string())?;
    Ok(HelperProc {
        child,
        stdin,
        stdout: BufReader::new(stdout),
    })
}

fn write_and_read(proc: &mut HelperProc, req: &Value) -> Result<Value, String> {
    let line = serde_json::to_string(req).map_err(|err| err.to_string())?;
    writeln!(proc.stdin, "{line}").map_err(|err| format!("写入助手失败：{err}"))?;
    proc.stdin.flush().map_err(|err| format!("写入助手失败：{err}"))?;
    let started = Instant::now();
    let mut reply = String::new();
    loop {
        reply.clear();
        match proc.stdout.read_line(&mut reply) {
            Ok(0) => return Err("助手已退出".to_string()),
            Ok(_) => {
                let trimmed = reply.trim();
                if trimmed.is_empty() {
                    if started.elapsed() > HELPER_TIMEOUT {
                        return Err("助手超时".to_string());
                    }
                    continue;
                }
                return serde_json::from_str(trimmed).map_err(|err| format!("助手输出无法解析：{err}"));
            }
            Err(err) => return Err(format!("读取助手失败：{err}")),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hash_compare_without_helpers_keeps_rust() {
        let result = compare_hash("abc", BinaryEncoding::Utf8, HashAlg::Sha256).unwrap();
        assert_eq!(
            result.rust.output,
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        );
        assert_eq!(result.rust.status, CompareStatus::Match);
        if python_spec().is_none() {
            assert_eq!(result.python.status, CompareStatus::Error);
            assert!(!result.python.message.is_empty());
        }
        if node_spec().is_none() {
            assert_eq!(result.node.status, CompareStatus::Error);
        }
    }

    #[test]
    fn sm3_marks_helpers_unsupported() {
        let result = compare_hash("abc", BinaryEncoding::Utf8, HashAlg::Sm3).unwrap();
        assert_eq!(result.python.status, CompareStatus::Unsupported);
        assert_eq!(result.node.status, CompareStatus::Unsupported);
        assert!(!result.rust.output.is_empty());
    }

    #[test]
    fn helper_console_flag_hides_window_on_windows() {
        assert_eq!(CREATE_NO_WINDOW, 0x0800_0000);
        #[cfg(windows)]
        {
            let mut cmd = Command::new("cmd");
            cmd.args(["/C", "echo ok"])
                .stdin(Stdio::null())
                .stdout(Stdio::piped())
                .stderr(Stdio::piped());
            hide_helper_console(&mut cmd);
            let output = cmd.output().unwrap();
            assert!(String::from_utf8_lossy(&output.stdout).contains("ok"));
        }
    }
}
