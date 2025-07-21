# RALLY: R Programming Assistant

RALLY is an intelligent R programming assistant that provides AI-powered code assistance and chat functionality using local Ollama models. It offers a modern Shiny web interface for interactive programming help.

## Features

- **Interactive Chat Interface**: Ask questions about R programming and get intelligent responses
- **Code Assistance**: Receive code suggestions, explanations, and debugging help
- **Local AI Models**: Uses Ollama for privacy-focused, local AI processing
- **Context Integration**: Upload R scripts, R Markdown files, and other documents for context-aware responses
- **Custom Prompts**: Load custom system prompts to tailor the assistant's behavior
- **Model Selection**: Choose from available Ollama models
- **Markdown Support**: Rich text rendering with code highlighting
- **Copy-to-Clipboard**: Easy copying of code snippets

## Prerequisites

### Install Ollama

Before using RALLY, you need to install Ollama:

1. **Download Ollama**: Visit [ollama.ai](https://ollama.ai) and download for your operating system
2. **Install Ollama**: Follow the installation instructions for your platform
3. **Start Ollama**: Open a terminal/command prompt and run:
   ```bash
   ollama serve
   ```
4. **Install a Model**: Install at least one model:
   ```bash
   ollama pull llama3.2:1b
   ```

## Installation

### From GitHub

```r
# Install devtools if you don't have it
if (!require(devtools)) install.packages("devtools")

# Install RALLY from GitHub
devtools::install_github("CodyCarmichaelMPH/RALLY")
```

### From Local Source

```r
# Navigate to the RALLY directory
# Install the package
install.packages(".", repos = NULL, type = "source")
```

## Quick Start

```r
# Load the package
library(rally)

# Launch the main application
copilot_direct()
```

## Key Functions

### `copilot_direct()`
Launches the main Shiny web application with a modern dashboard interface.

**Features:**
- Chat interface with model selection
- Settings panel for configuration
- Context file upload and management
- Custom system prompt loading

### `quick_chat_direct()`
Provides a console-based chat interface for quick interactions.

**Usage:**
```r
quick_chat_direct()
# Type your questions and press Enter
# Type 'quit' to exit
```

## Configuration

### Model Selection
1. Launch the application with `copilot_direct()`
2. Go to the Settings tab
3. Select your preferred Ollama model from the dropdown
4. Click "Test Connection" to verify Ollama is running

### Context Files
Upload R scripts, R Markdown files, CSV files, or text files to provide context for more accurate responses:
1. In Settings tab, use "Add Context Files"
2. Select your files
3. The assistant will use these files for context in conversations

### Custom Prompts
Load custom system prompts to tailor the assistant's behavior:
1. Create a text file with your custom prompt
2. In Settings tab, use "Load System Prompt from File"
3. Select your prompt file
4. The assistant will use your custom prompt

## Usage Examples

### Basic Questions
```
"How do I create a data frame in R?"
"What's the difference between %>% and |> in R?"
"How do I install packages in R?"
```

### Code Assistance
```
"Help me debug this code: [paste your code]"
"Explain what this function does: [paste function]"
"Optimize this R code: [paste code]"
```

### Data Analysis Help
```
"How do I create a scatter plot with ggplot2?"
"What's the best way to handle missing data?"
"How do I perform a t-test in R?"
```

## Troubleshooting

### Common Issues

**"No models found"**
- Ensure Ollama is running: `ollama serve`
- Install a model: `ollama pull llama3.2:1b`
- Check model selection in Settings tab

**"Connection failed"**
- Verify Ollama is running on localhost:11434
- Check firewall settings
- Ensure no other service is using port 11434

**Package installation errors**
- Ensure all dependencies are installed
- Try installing from GitHub with devtools
- Check R version compatibility

### Getting Help

If you encounter issues:
1. Check that Ollama is running and accessible
2. Verify you have at least one model installed
3. Test the connection in the Settings tab
4. Check the R console for error messages

## Dependencies

RALLY requires the following R packages:
- shiny
- shinydashboard
- httr
- jsonlite
- shinyjs
- magrittr

These will be installed automatically when you install RALLY.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## Version

Current version: 1.0.0 