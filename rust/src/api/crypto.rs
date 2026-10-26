use std::path::Path;

/// Encrypt a file with an age passphrase. Streams on the Rust side.
pub fn encrypt_file(input: String, output: String, passphrase: String) -> Result<(), String> {
    devkit_core::crypto::encrypt_file(Path::new(&input), Path::new(&output), &passphrase)
        .map_err(|err| err.to_string())
}

/// Decrypt an age passphrase file. Streams on the Rust side.
pub fn decrypt_file(input: String, output: String, passphrase: String) -> Result<(), String> {
    devkit_core::crypto::decrypt_file(Path::new(&input), Path::new(&output), &passphrase)
        .map_err(|err| err.to_string())
}
