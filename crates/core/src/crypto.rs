use std::fs::{self, File};
use std::io::{self, BufReader, BufWriter, Write};
use std::path::{Path, PathBuf};

use age::secrecy::SecretString;
use age::{Decryptor, Encryptor};

/// Passphrase encrypt/decrypt errors. Never include the passphrase in messages.
#[derive(Debug, thiserror::Error)]
pub enum CryptoError {
    #[error("passphrase must not be empty")]
    EmptyPassphrase,
    #[error("input file not found: {0}")]
    InputNotFound(PathBuf),
    #[error("this file was not encrypted with a passphrase")]
    UnsupportedIdentity,
    #[error("{0}")]
    Encrypt(String),
    #[error("{0}")]
    Decrypt(String),
    #[error("{0}")]
    Io(#[from] io::Error),
}

fn require_passphrase(passphrase: &str) -> Result<SecretString, CryptoError> {
    if passphrase.trim().is_empty() {
        return Err(CryptoError::EmptyPassphrase);
    }
    Ok(SecretString::from(passphrase.to_owned()))
}

fn open_input(path: &Path) -> Result<File, CryptoError> {
    File::open(path).map_err(|err| {
        if err.kind() == io::ErrorKind::NotFound {
            CryptoError::InputNotFound(path.to_path_buf())
        } else {
            CryptoError::Io(err)
        }
    })
}

fn partial_path(output: &Path) -> PathBuf {
    let mut raw = output.as_os_str().to_owned();
    raw.push(".partial");
    PathBuf::from(raw)
}

/// Encrypt `input` to `output` with an age passphrase. Streams with buffered I/O.
pub fn encrypt_file(input: &Path, output: &Path, passphrase: &str) -> Result<(), CryptoError> {
    let secret = require_passphrase(passphrase)?;
    let tmp = partial_path(output);
    let result = (|| {
        let mut reader = BufReader::new(open_input(input)?);
        let encryptor = Encryptor::with_user_passphrase(secret);
        let mut file = BufWriter::new(File::create(&tmp)?);
        let mut writer = encryptor
            .wrap_output(&mut file)
            .map_err(|err| CryptoError::Encrypt(err.to_string()))?;
        io::copy(&mut reader, &mut writer).map_err(CryptoError::from)?;
        writer
            .finish()
            .map_err(|err| CryptoError::Encrypt(err.to_string()))?;
        file.flush()?;
        Ok(())
    })();
    finalize(result, &tmp, output)
}

/// Decrypt an age passphrase file from `input` to `output`. Streams with buffered I/O.
pub fn decrypt_file(input: &Path, output: &Path, passphrase: &str) -> Result<(), CryptoError> {
    let secret = require_passphrase(passphrase)?;
    let tmp = partial_path(output);
    let result = (|| {
        let reader = BufReader::new(open_input(input)?);
        let decryptor = Decryptor::new_buffered(reader)
            .map_err(|err| CryptoError::Decrypt(err.to_string()))?;
        if !decryptor.is_scrypt() {
            return Err(CryptoError::UnsupportedIdentity);
        }
        let identity = age::scrypt::Identity::new(secret);
        let mut decrypted = decryptor
            .decrypt(std::iter::once(&identity as &dyn age::Identity))
            .map_err(|err| CryptoError::Decrypt(err.to_string()))?;
        let mut writer = BufWriter::new(File::create(&tmp)?);
        io::copy(&mut decrypted, &mut writer)?;
        writer.flush()?;
        Ok(())
    })();
    finalize(result, &tmp, output)
}

fn finalize(result: Result<(), CryptoError>, tmp: &Path, output: &Path) -> Result<(), CryptoError> {
    match result {
        Ok(()) => {
            if output.exists() {
                fs::remove_file(output)?;
            }
            fs::rename(tmp, output)?;
            Ok(())
        }
        Err(err) => {
            let _ = fs::remove_file(tmp);
            Err(err)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{SystemTime, UNIX_EPOCH};

    fn temp_dir() -> PathBuf {
        let dir = std::env::temp_dir().join(format!(
            "devkit-core-{}-{}",
            std::process::id(),
            SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        fs::create_dir_all(&dir).unwrap();
        dir
    }

    #[test]
    fn encrypt_then_decrypt_restores_bytes() {
        let dir = temp_dir();
        let input = dir.join("plain.bin");
        let encrypted = dir.join("plain.bin.age");
        let output = dir.join("roundtrip.bin");
        let payload = b"devkit streaming roundtrip \x00\x01\x02";
        fs::write(&input, payload).unwrap();

        encrypt_file(&input, &encrypted, "correct horse").unwrap();
        assert_ne!(fs::read(&encrypted).unwrap(), payload);

        decrypt_file(&encrypted, &output, "correct horse").unwrap();
        assert_eq!(fs::read(&output).unwrap(), payload);
    }

    #[test]
    fn decrypt_rejects_wrong_passphrase() {
        let dir = temp_dir();
        let input = dir.join("plain.txt");
        let encrypted = dir.join("plain.txt.age");
        let output = dir.join("out.txt");
        fs::write(&input, "secret document").unwrap();
        encrypt_file(&input, &encrypted, "right").unwrap();

        let err = decrypt_file(&encrypted, &output, "wrong").unwrap_err();
        assert!(matches!(err, CryptoError::Decrypt(_)));
        assert!(!output.exists());
    }

    #[test]
    fn encrypt_rejects_empty_passphrase() {
        let dir = temp_dir();
        let input = dir.join("plain.txt");
        let encrypted = dir.join("plain.txt.age");
        fs::write(&input, "data").unwrap();

        let err = encrypt_file(&input, &encrypted, "  ").unwrap_err();
        assert!(matches!(err, CryptoError::EmptyPassphrase));
        assert!(!encrypted.exists());
    }

    #[test]
    fn encrypt_streams_a_multi_megabyte_file() {
        let dir = temp_dir();
        let input = dir.join("large.bin");
        let encrypted = dir.join("large.bin.age");
        let output = dir.join("large.out");
        let payload = vec![0x5A_u8; 8 * 1024 * 1024];
        fs::write(&input, &payload).unwrap();

        encrypt_file(&input, &encrypted, "large-file-pass").unwrap();
        decrypt_file(&encrypted, &output, "large-file-pass").unwrap();
        assert_eq!(fs::read(&output).unwrap(), payload);
    }

    #[test]
    fn missing_input_is_a_not_found_error() {
        let dir = temp_dir();
        let err = encrypt_file(
            &dir.join("missing.bin"),
            &dir.join("out.age"),
            "pass",
        )
        .unwrap_err();
        assert!(matches!(err, CryptoError::InputNotFound(_)));
    }
}
