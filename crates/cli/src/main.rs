use std::io::{self, IsTerminal, Write};
use std::path::PathBuf;
use std::process::ExitCode;

use clap::{Parser, Subcommand};
use devkit_core::crypto::{decrypt_file, encrypt_file};

#[derive(Parser)]
#[command(
    name = "devkit",
    version,
    about = "Local-first developer toolkit. First slice: streaming age encrypt/decrypt."
)]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// Encrypt a file with an age passphrase (streams; does not load the file into memory).
    Encrypt {
        /// Input file path
        #[arg(short, long)]
        input: PathBuf,
        /// Output file path
        #[arg(short, long)]
        output: PathBuf,
        /// Passphrase. Omit to be prompted. Prefer a prompt so it stays off argv.
        #[arg(long)]
        passphrase: Option<String>,
    },
    /// Decrypt an age passphrase file (streams; does not load the file into memory).
    Decrypt {
        /// Input file path
        #[arg(short, long)]
        input: PathBuf,
        /// Output file path
        #[arg(short, long)]
        output: PathBuf,
        /// Passphrase. Omit to be prompted. Prefer a prompt so it stays off argv.
        #[arg(long)]
        passphrase: Option<String>,
    },
}

fn read_passphrase(explicit: Option<String>) -> Result<String, String> {
    if let Some(value) = explicit {
        return Ok(value);
    }
    if io::stdin().is_terminal() {
        rpassword::prompt_password("Passphrase: ").map_err(|err| err.to_string())
    } else {
        Err("passphrase required (pass --passphrase or run in a terminal)".into())
    }
}

fn main() -> ExitCode {
    match run() {
        Ok(message) => {
            println!("{message}");
            ExitCode::SUCCESS
        }
        Err(err) => {
            let _ = writeln!(io::stderr(), "error: {err}");
            ExitCode::FAILURE
        }
    }
}

fn run() -> Result<String, String> {
    match Cli::parse().command {
        Command::Encrypt {
            input,
            output,
            passphrase,
        } => {
            let passphrase = read_passphrase(passphrase)?;
            encrypt_file(&input, &output, &passphrase).map_err(|err| err.to_string())?;
            Ok(format!("encrypted {}", output.display()))
        }
        Command::Decrypt {
            input,
            output,
            passphrase,
        } => {
            let passphrase = read_passphrase(passphrase)?;
            decrypt_file(&input, &output, &passphrase).map_err(|err| err.to_string())?;
            Ok(format!("decrypted {}", output.display()))
        }
    }
}
