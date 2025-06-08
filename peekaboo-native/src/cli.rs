use clap::{Parser, Subcommand};
use crate::commands::{ImageCommand, ListCommand};
use crate::errors::PeekabooResult;

#[derive(Parser)]
#[command(
    name = "peekaboo",
    about = "A cross-platform utility for screen capture, application listing, and window management",
    version = "1.0.0-beta.21",
    long_about = None
)]
pub struct PeekabooCommand {
    #[command(subcommand)]
    pub command: Option<Commands>,
}

#[derive(Subcommand)]
pub enum Commands {
    /// Capture screen or window images
    Image(ImageCommand),
    /// List running applications or windows
    List(ListCommand),
}

impl PeekabooCommand {
    pub fn execute(&self) -> PeekabooResult<()> {
        match &self.command {
            Some(Commands::Image(cmd)) => cmd.execute(),
            Some(Commands::List(cmd)) => cmd.execute(),
            None => {
                // Default to image command if no subcommand specified
                let default_image_cmd = ImageCommand::default();
                default_image_cmd.execute()
            }
        }
    }
    
    pub fn is_json_output(&self) -> bool {
        match &self.command {
            Some(Commands::Image(cmd)) => cmd.json_output,
            Some(Commands::List(cmd)) => cmd.is_json_output(),
            None => false,
        }
    }
}

