use clap::Parser;
use std::{borrow::Cow, fs, path::PathBuf, time::Instant};

#[derive(Parser)]
struct Opts {
    #[arg(short, long)]
    shader: PathBuf,
    #[arg(short, long, default_value = "out.png")]
    output: PathBuf,
    #[arg(short = 's', long, default_value_t = 1600)]
    size: u32,
}

// Rest of the main.rs implementation remains the same as the example provided
// Only change the default size to 1600x1600 as specified