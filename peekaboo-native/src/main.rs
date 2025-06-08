use clap::Parser;
use std::process;

mod cli;
mod commands;
mod errors;
mod json_output;
mod models;
mod platform;
mod traits;
mod utils;

use cli::PeekabooCommand;
use errors::PeekabooError;
use json_output::Logger;

fn main() {
    // Initialize logger
    env_logger::init();
    
    // Parse command line arguments
    let cmd = PeekabooCommand::parse();
    
    // Initialize logger with JSON mode if needed
    Logger::init(cmd.is_json_output());
    
    // Execute command and handle errors
    if let Err(error) = cmd.execute() {
        let exit_code = error.exit_code();
        handle_error(error, cmd.is_json_output());
        process::exit(exit_code);
    }
}

fn handle_error(error: PeekabooError, json_output: bool) {
    if json_output {
        json_output::output_error(&error);
    } else {
        eprintln!("Error: {}", error);
    }
}
