use std::io::{self, IsTerminal, Write};
use std::path::PathBuf;
use std::process::ExitCode;

use clap::{CommandFactory, Parser, Subcommand};
use devkit_core::crypto::{decrypt_file, encrypt_file};

#[derive(Parser, Debug)]
#[command(
    name = "devkit",
    version,
    about = "DevKit 命令行：流式 age 文件加解密。图形界面请解压 devkit-desktop-windows-amd64.zip。"
)]
struct Cli {
    #[command(subcommand)]
    command: Option<Command>,
}

#[derive(Subcommand, Debug)]
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

fn no_command_message(bin: &str) -> String {
    format!(
        "这是命令行工具，不是桌面工作台。\n\
         图形界面请下载并解压 devkit-desktop-windows-amd64.zip，运行其中的 devkit.exe。\n\n\
         命令行用法：\n  {bin} encrypt --input IN --output OUT\n  {bin} decrypt --input IN --output OUT\n"
    )
}

fn should_pause_console(process_count: u32, stdin_is_terminal: bool) -> bool {
    stdin_is_terminal && process_count == 1
}

#[cfg(windows)]
fn console_process_count() -> u32 {
    #[link(name = "kernel32")]
    extern "system" {
        fn GetConsoleProcessList(process_list: *mut u32, count: u32) -> u32;
    }
    let mut ids = [0u32; 8];
    unsafe { GetConsoleProcessList(ids.as_mut_ptr(), ids.len() as u32) }
}

#[cfg(not(windows))]
fn console_process_count() -> u32 {
    2
}

fn pause_if_double_clicked() {
    if !should_pause_console(console_process_count(), io::stdin().is_terminal()) {
        return;
    }
    print!("按 Enter 关闭…");
    let _ = io::stdout().flush();
    let _ = io::stdin().read_line(&mut String::new());
}

fn main() -> ExitCode {
    match run() {
        Ok(None) => ExitCode::SUCCESS,
        Ok(Some(message)) => {
            println!("{message}");
            ExitCode::SUCCESS
        }
        Err(err) => {
            let _ = writeln!(io::stderr(), "error: {err}");
            ExitCode::FAILURE
        }
    }
}

fn run() -> Result<Option<String>, String> {
    let cli = Cli::parse();
    match cli.command {
        None => {
            let bin = std::env::args()
                .next()
                .and_then(|path| {
                    std::path::Path::new(&path)
                        .file_name()
                        .map(|name| name.to_string_lossy().into_owned())
                })
                .unwrap_or_else(|| "devkit".into());
            print!("{}", no_command_message(&bin));
            let _ = Cli::command().print_help();
            println!();
            pause_if_double_clicked();
            Ok(None)
        }
        Some(Command::Encrypt {
            input,
            output,
            passphrase,
        }) => {
            let passphrase = read_passphrase(passphrase)?;
            encrypt_file(&input, &output, &passphrase).map_err(|err| err.to_string())?;
            Ok(Some(format!("encrypted {}", output.display())))
        }
        Some(Command::Decrypt {
            input,
            output,
            passphrase,
        }) => {
            let passphrase = read_passphrase(passphrase)?;
            decrypt_file(&input, &output, &passphrase).map_err(|err| err.to_string())?;
            Ok(Some(format!("decrypted {}", output.display())))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn no_args_is_usage_not_a_required_subcommand_error() {
        let parsed = Cli::try_parse_from(["devkit"]).expect("no-args should parse");
        assert!(parsed.command.is_none());
        let text = no_command_message("devkit");
        assert!(text.contains("devkit-desktop-windows-amd64.zip"));
        assert!(text.contains("devkit.exe"));
    }

    #[test]
    fn pause_only_when_this_is_the_only_console_process() {
        assert!(should_pause_console(1, true));
        assert!(!should_pause_console(2, true));
        assert!(!should_pause_console(1, false));
    }
}
