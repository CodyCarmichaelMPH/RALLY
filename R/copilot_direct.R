
# Default system prompt - load from file if available, otherwise use default
default_system_prompt <- function() {
  if (file.exists("DefaultPrompt.txt")) {
    readLines("DefaultPrompt.txt", warn = FALSE) %>% paste(collapse = "\n")
  } else {
    "You are an expert R programmer and data scientist. Follow these guidelines:

1. **Code Quality**: Write clean, readable R code using tidyverse when appropriate
2. **Best Practices**: Use snake_case for variables, meaningful names, add comments for complex logic
3. **Error Handling**: Include input validation and error messages where relevant
4. **Documentation**: Explain what the code does and why certain approaches were chosen
5. **Examples**: Provide complete, runnable examples with sample data
6. **Performance**: Suggest efficient approaches for large datasets
7. **Packages**: Recommend appropriate R packages and explain their benefits
8. **Debugging**: Help identify and fix common R programming issues

Always format code blocks with ```r and provide context for your recommendations."
  }
}

# Function to read file content safely
read_file_content <- function(file_path) {
  if (is.null(file_path) || !file.exists(file_path)) {
    return(NULL)
  }
  
  tryCatch({
    ext <- tolower(tools::file_ext(file_path))
    if (ext %in% c("r", "rmd", "md", "txt")) {
      content <- readLines(file_path, warn = FALSE)
      paste(content, collapse = "\n")
    } else if (ext == "csv") {
      # For CSV files, just read first few lines as context
      content <- readLines(file_path, n = 10, warn = FALSE)
      paste(content, collapse = "\n")
    } else {
      NULL
    }
  }, error = function(e) {
    NULL
  })
}

# Function to get system prompt from file or use default
get_system_prompt <- function(prompt_file = NULL) {
  if (!is.null(prompt_file) && file.exists(prompt_file)) {
    file_content <- read_file_content(prompt_file)
    if (!is.null(file_content)) {
      return(file_content)
    }
  }
  return(default_system_prompt)
}

# Direct API functions
get_models_direct <- function() {
  tryCatch({
    response <- GET("http://localhost:11434/api/tags")
    if (response$status_code == 200) {
      data <- fromJSON(rawToChar(response$content))
      if (length(data$models) > 0) {
        return(data$models$name)
      }
    }
    return(character(0))  # Return empty if no models found
  }, error = function(e) {
    return(character(0))  # Return empty on error
  })
}

# Function to get user's saved model preference
get_saved_model <- function() {
  if (file.exists(".rally_model")) {
    tryCatch({
      readLines(".rally_model", warn = FALSE)[1]
    }, error = function(e) {
      NULL
    })
  } else {
    NULL
  }
}

# Function to save user's model preference
save_model_preference <- function(model) {
  tryCatch({
    writeLines(model, ".rally_model")
  }, error = function(e) {
    # Silently fail if can't save
  })
}

chat_direct <- function(message, model = "llama3.2:1b", system_prompt = default_system_prompt(), context_files = NULL) {
  # Build context from files
  context_content <- ""
  if (!is.null(context_files) && length(context_files) > 0) {
    # Extract datapaths from context_files list
    file_paths <- sapply(context_files, function(x) x$datapath)
    file_contents <- lapply(file_paths, read_file_content)
    valid_contents <- file_contents[!sapply(file_contents, is.null)]
    if (length(valid_contents) > 0) {
      context_content <- paste0("\n\n**Context from files:**\n", 
                               paste(valid_contents, collapse = "\n\n---\n\n"))
    }
  }
  
  # Combine system prompt with context
  full_system_prompt <- paste0(system_prompt, context_content)
  
  tryCatch({
    response <- POST(
      "http://localhost:11434/api/chat",
      body = list(
        model = model,
        messages = list(
          list(role = "system", content = full_system_prompt),
          list(role = "user", content = message)
        ),
        stream = FALSE
      ),
      encode = "json"
    )
    
    if (response$status_code == 200) {
      data <- fromJSON(rawToChar(response$content))
      return(data$message$content)
    } else {
      return("Error: Unable to get response from Ollama")
    }
  }, error = function(e) {
    return(paste("Error:", e$message))
  })
}

# Shiny App
copilot_direct <- function() {
  # Load required packages
  library(shiny)
  library(shinydashboard)
  library(httr)
  library(jsonlite)
  library(shinyjs)
  library(magrittr)
  
  ui <- dashboardPage(
    dashboardHeader(
      title = span(icon("robot"), " R-Ally", style = "color: white; font-weight: bold;"),
      titleWidth = 300
    ),
    dashboardSidebar(
      width = 250,
      sidebarMenu(
        menuItem("Chat", tabName = "chat", icon = icon("comments"), selected = TRUE),
        menuItem("Settings", tabName = "settings", icon = icon("cog")),
        hr(),
        menuItem("About", tabName = "about", icon = icon("info-circle"))
      )
    ),
    dashboardBody(
      useShinyjs(),
      tags$head(
        tags$style(HTML("
          .content-wrapper { background: #f8f9fa; }
          .main-header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); }
          .sidebar { background: #343a40; }
          
          /* Chat styling */
          .chat-container { 
            height: calc(100vh - 200px); 
            overflow-y: auto; 
            padding: 20px;
            background: white;
            border-radius: 10px;
            margin: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
          }
          
          .message { 
            margin: 15px 0; 
            padding: 15px; 
            border-radius: 15px; 
            max-width: 80%; 
            word-wrap: break-word;
            position: relative;
          }
          
          .user-message { 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
            color: white; 
            margin-left: auto; 
            text-align: right;
            box-shadow: 0 2px 8px rgba(102, 126, 234, 0.3);
          }
          
          .assistant-message { 
            background: #f8f9fa; 
            border: 1px solid #dee2e6; 
            margin-right: auto;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
          }
          
          /* Code block styling */
          .code-block { 
            background: #2d3748; 
            color: #e2e8f0; 
            padding: 15px; 
            border-radius: 8px; 
            margin: 10px 0; 
            position: relative;
            font-family: 'Courier New', monospace;
            font-size: 13px;
            line-height: 1.4;
            overflow-x: auto;
          }
          
          .copy-button { 
            position: absolute; 
            top: 5px; 
            right: 5px; 
            background: #4a5568; 
            color: white; 
            border: none; 
            border-radius: 4px; 
            padding: 4px 8px; 
            font-size: 11px; 
            cursor: pointer;
            transition: background 0.2s;
          }
          
          .copy-button:hover { background: #2d3748; }
          .copy-button.copied { background: #38a169; }
          
          /* Input styling */
          .input-container { 
            padding: 20px; 
            background: white; 
            border-radius: 10px; 
            margin: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
          }
          
          .input-container textarea { 
            width: 100%; 
            min-height: 60px; 
            padding: 15px; 
            border: 2px solid #e2e8f0; 
            border-radius: 8px; 
            resize: vertical;
            font-family: inherit;
            font-size: 14px;
            line-height: 1.5;
            transition: border-color 0.2s;
          }
          
          .input-container textarea:focus { 
            outline: none; 
            border-color: #667eea; 
            box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
          }
          
          .send-button { 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
            color: white; 
            border: none; 
            padding: 12px 24px; 
            border-radius: 8px; 
            cursor: pointer; 
            font-weight: bold;
            margin-top: 10px;
            transition: transform 0.2s, box-shadow 0.2s;
          }
          
          .send-button:hover { 
            transform: translateY(-1px); 
            box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
          }
          
          /* Loading indicator */
          .loading { 
            display: none; 
            text-align: center; 
            padding: 20px; 
            color: #6c757d;
            font-style: italic;
          }
          
          .loading.show { display: block; }
          
          /* Custom scrollbar */
          .chat-container::-webkit-scrollbar { width: 8px; }
          .chat-container::-webkit-scrollbar-track { background: #f1f1f1; border-radius: 4px; }
          .chat-container::-webkit-scrollbar-thumb { background: #c1c1c1; border-radius: 4px; }
          .chat-container::-webkit-scrollbar-thumb:hover { background: #a8a8a8; }
        "))
      ),
      tabItems(
        # Chat Tab
        tabItem(tabName = "chat",
          div(class = "chat-container", id = "chat_container"),
          div(class = "loading", id = "loading", 
              span(icon("spinner", class = "fa-spin"), " Copilot is thinking...")),
          div(class = "input-container",
            fluidRow(
              column(9,
                textAreaInput("message", "", placeholder = "Ask me anything about R programming...", 
                            rows = 2)
              ),
              column(3,
                actionButton("send", "Send", class = "send-button",
                           style = "margin-top: 10px; width: 120px; height: 60px; margin-left: -10px; text-align: center; font-weight: bold; font-size: 14px;")
              )
            )
          )
        ),
        
        # Settings Tab
        tabItem(tabName = "settings",
          fluidRow(
            column(6,
              div(style = "background: white; padding: 20px; border-radius: 10px; border: 1px solid #dee2e6;",
                h3(icon("cog"), " Ollama Settings"),
                selectInput("model", "Model:", 
                           choices = c("Please select a model..." = "", get_models_direct()),
                           selected = get_saved_model() %||% ""),
                textAreaInput("system_prompt", "System Prompt:", 
                            value = default_system_prompt(),
                            rows = 8),
                fileInput("prompt_file", "Load System Prompt from File:", 
                         accept = c(".txt", ".md", ".r")),
                actionButton("load_prompt", "Load Prompt", 
                            class = "send-button",
                            style = "margin-top: 10px;")
              )
            ),
            column(6,
              div(style = "background: white; padding: 20px; border-radius: 10px; border: 1px solid #dee2e6;",
                h3(icon("info-circle"), " Status"),
                uiOutput("status_output"),
                br(),
                h4(icon("file"), " Context Files"),
                fileInput("context_files", "Add Context Files:", 
                         multiple = TRUE,
                         accept = c(".r", ".rmd", ".md", ".csv", ".txt")),
                uiOutput("context_files_list"),
                br(),
                actionButton("test_connection", "Test Connection", 
                            class = "send-button",
                            style = "width: 100%; margin-top: 10px;")
              )
            )
          )
        ),
        
        # About Tab
        tabItem(tabName = "about",
          div(style = "background: white; padding: 30px; border-radius: 10px; margin: 20px;",
            h2(icon("robot"), " R-Ally"),
            p("An intelligent R programming assistant powered by Ollama."),
            hr(),
            h4("Features:"),
            tags$ul(
              tags$li("Interactive chat interface"),
              tags$li("Code completion and suggestions"),
              tags$li("Custom system prompts"),
              tags$li("File context integration"),
              tags$li("Markdown rendering"),
              tags$li("Copy-to-clipboard functionality")
            ),
            hr(),
            h4("Usage:"),
            p("1. Select your preferred model in Settings"),
            p("2. Customize the system prompt or load from file"),
            p("3. Add context files for better responses"),
            p("4. Start chatting in the Chat tab"),
            hr(),
            p(style = "color: #6c757d; font-size: 12px;", 
              "Built with Shiny, shinydashboard, and Ollama")
          )
        )
      )
    )
  )

  server <- function(input, output, session) {
    # Initialize chat history with appropriate initial message
    chat_history <- reactiveVal(list())
    
    # Show initial message based on model selection
    observe({
      model <- input$model
      if (!is.null(model) && model != "") {
        # Model is selected - show welcome message
        if (length(chat_history()) == 0) {
          add_message("assistant", "Hello! I'm Rally, your R Ally. Please feel free to ask for my help on your R projects. Keep in mind I probably will work better by asking me to produce small, testable lines of code as opposed to whole scripts. You can enter context scripts in the Settings Page, or change my prompt style there as well.")
        }
      } else {
        # No model selected - show guidance message
        if (length(chat_history()) == 0) {
          add_message("assistant", "Welcome to R-Ally! To get started:\n\n1. **Start Ollama**: Open a command prompt and run `ollama serve`\n2. **Install a model**: Run `ollama pull llama3.2:1b` (or another model)\n3. **Select model**: Go to Settings tab and choose your model\n4. **Start chatting**: Come back here and ask me anything about R programming!")
        }
      }
    })
    
    # Check if model is selected and redirect to settings if not
    observe({
      model <- input$model
      if (is.null(model) || model == "") {
        updateTabItems(session, "sidebar", "settings")
        showNotification("Please select a model in Settings to start chatting!", type = "warning")
      }
    })
    
    # Update initial message when model selection changes
    observeEvent(input$model, {
      # Clear chat history to show new initial message
      chat_history(list())
      
      # Show appropriate message based on model selection
      if (!is.null(input$model) && input$model != "") {
        add_message("assistant", "Hello! I'm Rally, your R Ally. Please feel free to ask for my help on your R projects. Keep in mind I probably will work better by asking me to produce small, testable lines of code as opposed to whole scripts. You can enter context scripts in the Settings Page, or change my prompt style there as well.")
      } else {
        add_message("assistant", "Welcome to R-Ally! To get started:\n\n1. **Start Ollama**: Open a command prompt and run `ollama serve`\n2. **Install a model**: Run `ollama pull llama3.2:1b` (or another model)\n3. **Select model**: Go to Settings tab and choose your model\n4. **Start chatting**: Come back here and ask me anything about R programming!")
      }
    })
    
    # Reactive values for context - load sample files by default
    context_files <- reactiveVal(list())
    
    # Load sample context files by default
    observe({
      sample_files <- list()
      if (file.exists("sample_context.R")) {
        sample_files$sample_context.R <- list(
          name = "sample_context.R",
          datapath = "sample_context.R"
        )
      }
      if (file.exists("sample_prompt.txt")) {
        sample_files$sample_prompt.txt <- list(
          name = "sample_prompt.txt", 
          datapath = "sample_prompt.txt"
        )
      }
      if (length(sample_files) > 0) {
        context_files(sample_files)
      }
    })
    
    # Ensure default prompt is loaded
    observe({
      current_prompt <- input$system_prompt
      if (is.null(current_prompt) || current_prompt == "") {
        updateTextAreaInput(session, "system_prompt", value = default_system_prompt())
      }
    })
    
    # Process markdown and add copy buttons
    process_markdown <- function(text) {
      # Split into code blocks and regular text
      parts <- strsplit(text, "```")[[1]]
      result <- ""
      
      for (i in seq_along(parts)) {
        if (i %% 2 == 1) {
          # Regular text - render markdown
          result <- paste0(result, render_markdown(parts[i]))
        } else {
          # Code block
          result <- paste0(result, render_code_block(parts[i]))
        }
      }
      
      return(result)
    }
    
    render_markdown <- function(text) {
      # Simple markdown rendering
      text <- gsub("\\*\\*(.*?)\\*\\*", "<strong>\\1</strong>", text)
      text <- gsub("\\*(.*?)\\*", "<em>\\1</em>", text)
      text <- gsub("`([^`]+)`", "<code>\\1</code>", text)
      text <- gsub("\n", "<br>", text)
      return(text)
    }
    
    render_code_block <- function(code) {
      # Extract language if specified
      lines <- strsplit(code, "\n")[[1]]
      if (length(lines) > 0 && grepl("^[a-zA-Z]+$", lines[1])) {
        language <- lines[1]
        code_content <- paste(lines[-1], collapse = "\n")
      } else {
        language <- "r"
        code_content <- code
      }
      
      # Create code block with copy button
      paste0(
        '<div class="code-block">',
        '<button class="copy-button" onclick="copyToClipboard(this)">Copy</button>',
        '<pre><code class="language-', language, '">',
        gsub("<", "&lt;", gsub(">", "&gt;", code_content)),
        '</code></pre></div>'
      )
    }
    
    # Add message to chat
    add_message <- function(role, content) {
      current_history <- chat_history()
      new_message <- list(role = role, content = content, timestamp = Sys.time())
      chat_history(c(current_history, list(new_message)))
      
      # Update UI
      update_chat_display()
    }
    
    # Update chat display
    update_chat_display <- function() {
      history <- chat_history()
      if (length(history) == 0) return()
      
      chat_html <- ""
      for (msg in history) {
        if (msg$role == "user") {
          chat_html <- paste0(chat_html, 
            '<div class="message user-message">', 
            gsub("\n", "<br>", msg$content), 
            '</div>'
          )
        } else {
          chat_html <- paste0(chat_html, 
            '<div class="message assistant-message">', 
            process_markdown(msg$content), 
            '</div>'
          )
        }
      }
      
      runjs(paste0('
        document.getElementById("chat_container").innerHTML = `', chat_html, '`;
        document.getElementById("chat_container").scrollTop = document.getElementById("chat_container").scrollHeight;
      '))
    }
    
    # Send message
    observeEvent(input$send, {
      message <- trimws(input$message)
      if (message == "") return()
      
      # Check if model is selected
      model <- input$model
      if (is.null(model) || model == "") {
        add_message("assistant", "Please select a model in the Settings tab before sending messages.")
        return()
      }
      
      # Add user message
      add_message("user", message)
      
      # Clear input
      updateTextAreaInput(session, "message", value = "")
      
      # Show loading
      runjs('document.getElementById("loading").classList.add("show");')
      
      # Get current settings
      system_prompt <- input$system_prompt
      context_files_list <- context_files()
      
      # Send to Ollama
      response <- chat_direct(message, model, system_prompt, context_files_list)
      
      # Hide loading
      runjs('document.getElementById("loading").classList.remove("show");')
      
      # Add assistant response
      add_message("assistant", response)
    })
    
    # Handle Enter key for sending messages
    runjs('
      document.addEventListener("DOMContentLoaded", function() {
        const messageInput = document.getElementById("message");
        if (messageInput) {
          messageInput.addEventListener("keydown", function(e) {
            if (e.key === "Enter" && !e.shiftKey) {
              e.preventDefault();
              const sendButton = document.getElementById("send");
              if (sendButton) {
                sendButton.click();
              }
            }
            // Shift+Enter allows new line (default behavior)
          });
        }
      });
    ')
    
    # Load prompt from file
    observeEvent(input$load_prompt, {
      req(input$prompt_file)
      file_content <- read_file_content(input$prompt_file$datapath)
      if (!is.null(file_content)) {
        updateTextAreaInput(session, "system_prompt", value = file_content)
        showNotification("System prompt loaded successfully!", type = "default")
      } else {
        showNotification("Could not read file. Please check the file format.", type = "error")
      }
    })
    
    # Handle context files
    # Save model preference when changed
    observeEvent(input$model, {
      if (!is.null(input$model) && input$model != "") {
        save_model_preference(input$model)
      }
    })
    
    # Display context files with remove buttons
    output$context_files_list <- renderUI({
      files <- context_files()
      if (length(files) == 0) {
        return(HTML("<p style='color: #6c757d; font-style: italic;'>No context files added</p>"))
      }
      
      # Create file list with remove buttons
      file_items <- sapply(names(files), function(file_name) {
        paste0(
          "<div style='display: flex; justify-content: space-between; align-items: center; margin: 5px 0; padding: 5px; background: #f8f9fa; border-radius: 5px;'>",
          "<span>📄 ", file_name, "</span>",
          "<button onclick='Shiny.setInputValue(\"remove_file\", \"", file_name, "\", {priority: \"event\"})' ",
          "style='background: #dc3545; color: white; border: none; border-radius: 3px; padding: 2px 8px; font-size: 12px; cursor: pointer;'>",
          "Remove</button>",
          "</div>"
        )
      })
      
      file_list <- paste0(
        "<div style='margin-top: 10px;'>",
        "<strong>Context files:</strong><br>",
        paste(file_items, collapse = ""),
        "</div>"
      )
      
      HTML(file_list)
    })
    
    # Handle file removal
    observeEvent(input$remove_file, {
      req(input$remove_file)
      current_files <- context_files()
      file_to_remove <- input$remove_file
      
      if (file_to_remove %in% names(current_files)) {
        current_files[[file_to_remove]] <- NULL
        context_files(current_files)
      }
    })
    
    # Update context files when new files are uploaded
    observeEvent(input$context_files, {
      req(input$context_files)
      current_files <- context_files()
      new_files <- input$context_files
      
      # Add new files to existing ones
      for (i in 1:nrow(new_files)) {
        current_files[[new_files$name[i]]] <- list(
          name = new_files$name[i],
          datapath = new_files$datapath[i]
        )
      }
      context_files(current_files)
    })
    
    # Test connection
    observeEvent(input$test_connection, {
      tryCatch({
        models <- get_models_direct()
        if (length(models) > 0 && models[1] != "llama3.2:1b") {
          status_html <- paste0(
            "<div style='color: #28a745; font-weight: bold; margin-bottom: 15px;'>",
            "✅ Connected to Ollama",
            "</div>",
            "<div style='margin-bottom: 10px;'><strong>Available models:</strong></div>",
            "<ul style='margin: 0; padding-left: 20px;'>",
            paste0("<li>", models, "</li>", collapse = ""),
            "</ul>",
            "<div style='margin-top: 15px; color: #6c757d; font-size: 12px;'>",
            "Click 'Test Connection' to refresh",
            "</div>"
          )
          output$status_output <- renderUI({
            HTML(status_html)
          })
          
          # Update model choices
          current_selection <- input$model
          new_choices <- c("Please select a model..." = "", models)
          if (current_selection %in% models) {
            # Keep current selection if it's still valid
            updateSelectInput(session, "model", choices = new_choices, selected = current_selection)
          } else {
            # Use saved preference or first model
            saved_model <- get_saved_model()
            if (!is.null(saved_model) && saved_model %in% models) {
              updateSelectInput(session, "model", choices = new_choices, selected = saved_model)
            } else {
              updateSelectInput(session, "model", choices = new_choices, selected = "")
            }
          }
        } else {
          output$status_output <- renderUI({
            HTML("<div style='color: #dc3545; font-weight: bold;'>⚠️ No models found. Install models with: ollama pull llama3.2:1b</div>")
          })
        }
      }, error = function(e) {
        output$status_output <- renderUI({
          HTML(paste0("<div style='color: #dc3545; font-weight: bold;'>❌ Connection failed: ", e$message, "</div>"))
        })
      })
    })
    
    # Status on load
    output$status_output <- renderUI({
      HTML("<div style='color: #28a745; font-weight: bold;'>Ready! Click 'Test Connection' to check Ollama status</div>")
    })
    
    # Copy to clipboard JavaScript
    runjs('
      function copyToClipboard(button) {
        const codeBlock = button.nextElementSibling;
        const text = codeBlock.textContent;
        
        if (navigator.clipboard && window.isSecureContext) {
          navigator.clipboard.writeText(text).then(function() {
            button.textContent = "Copied!";
            button.classList.add("copied");
            setTimeout(function() {
              button.textContent = "Copy";
              button.classList.remove("copied");
            }, 2000);
          });
        } else {
          // Fallback for older browsers
          const textArea = document.createElement("textarea");
          textArea.value = text;
          document.body.appendChild(textArea);
          textArea.select();
          try {
            document.execCommand("copy");
            button.textContent = "Copied!";
            button.classList.add("copied");
            setTimeout(function() {
              button.textContent = "Copy";
              button.classList.remove("copied");
            }, 2000);
          } catch (err) {
            console.error("Copy failed:", err);
          }
          document.body.removeChild(textArea);
        }
      }
    ')
  }

  shinyApp(ui, server)
}

# Console chat function
quick_chat_direct <- function() {
  cat("R-Ally - Quick Chat Mode\n")
  cat("Type 'quit' to exit\n\n")

  while (TRUE) {
    message <- readline("You: ")
    if (tolower(message) == "quit") break

    response <- chat_direct(message)
    cat("R-Ally:", response, "\n\n")
  }
}

