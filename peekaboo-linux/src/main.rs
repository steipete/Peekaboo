use clap::Parser;
use std::process;

mod cli;
mod models;
mod errors;
mod screen_capture;
mod json_output;
mod logger;
mod application_finder;
mod window_manager;
mod permissions;
mod environment;

use cli::{PeekabooCommand, Commands};
use json_output::JsonOutputMode;
use logger::Logger;

#[tokio::main]
async fn main() {
    let args = PeekabooCommand::parse();
    
    // Initialize logger
    let logger = Logger::new();
    
    // Set JSON output mode if specified
    let json_mode = match &args.command {
        Some(Commands::Image(cmd)) => cmd.json_output,
        Some(Commands::List(cmd)) => match cmd {
            cli::ListCommands::Apps(subcmd) => subcmd.json_output,
            cli::ListCommands::Windows(subcmd) => subcmd.json_output,
            cli::ListCommands::ServerStatus(subcmd) => subcmd.json_output,
        },
        None => false, // Default to image command
    };
    
    JsonOutputMode::set_global(json_mode);
    
    // Execute the command
    let result = match args.command.unwrap_or(Commands::Image(Default::default())) {
        Commands::Image(cmd) => {
            logger.debug(&format!("Executing image command: {:?}", cmd));
            cmd.execute().await
        }
        Commands::List(list_cmd) => {
            logger.debug(&format!("Executing list command: {:?}", list_cmd));
            match list_cmd {
                cli::ListCommands::Apps(cmd) => cmd.execute().await,
                cli::ListCommands::Windows(cmd) => cmd.execute().await,
                cli::ListCommands::ServerStatus(cmd) => cmd.execute().await,
            }
        }
    };
    
    match result {
        Ok(_) => {
            logger.debug("Command executed successfully");
        }
        Err(error) => {
            logger.error(&format!("Command failed: {}", error));
            
            if json_mode {
                json_output::output_error(&error);
            } else {
                eprintln!("Error: {}", error);
            }
            
            process::exit(error.exit_code());
        }
    }
}
