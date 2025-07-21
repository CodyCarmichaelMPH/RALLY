#' R Copilot with Ollama
#' 
#' A minimal R copilot that provides AI assistance using local Ollama models.
#' No admin permissions required, clean UI, easy RStudio integration.

#' @title Launch R Copilot
#' @description Start the R copilot with a clean Shiny interface
#' @export
copilot <- function() {
  # Check if ollamar is available, install if needed
  if (!requireNamespace("ollamar", quietly = TRUE)) {
    message("Installing ollamar package...")
    if (!requireNamespace("remotes", quietly = TRUE)) {
      message("Installing remotes package first...")
      install.packages("remotes")
    }
    remotes::install_github("hauselin/ollama-r")
  }
  
  # Load required packages
  library(shiny)
  library(shinydashboard)
  library(ollamar)
  
  # UI
  ui <- dashboardPage(
    dashboardHeader(title = "R Copilot"),
    dashboardSidebar(
      sidebarMenu(
        menuItem("Chat", tabName = "chat", icon = icon("comments")),
        menuItem("Settings", tabName = "settings", icon = icon("cog"))
      )
    ),
    dashboardBody(
      tabItems(
        # Chat Tab
        tabItem(tabName = "chat",
          fluidRow(
            column(12,
              div(style = "height: 400px; overflow-y: auto; border: 1px solid #ddd; padding: 10px; margin-bottom: 10px;",
                uiOutput("chat_messages")
              ),
              fluidRow(
                column(10,
                  textAreaInput("user_input", "Your message:", 
                              placeholder = "Ask for R code help, explanations, or chat...",
                              rows = 3)
                ),
                column(2,
                  actionButton("send_btn", "Send", 
                              style = "margin-top: 20px; width: 100%;")
                )
              )
            )
          )
        ),
        # Settings Tab
        tabItem(tabName = "settings",
          fluidRow(
            column(6,
              h3("Ollama Settings"),
              selectInput("model", "Model:", 
                         choices = get_available_models(),
                         selected = get_default_model()),
              textAreaInput("system_prompt", "System Prompt:", 
                          value = "You are an expert R programmer. Provide clear, concise R code examples and explanations. Always show complete, runnable code.",
                          rows = 4),
              actionButton("test_connection", "Test Connection")
            ),
            column(6,
              h3("Status"),
              verbatimTextOutput("status_output")
            )
          )
        )
      )
    )
  )
  
  # Server
  server <- function(input, output, session) {
    
    # Reactive values for chat
    chat_history <- reactiveVal(list())
    
    # Initialize chat
    observe({
      chat_history(list(
        list(role = "assistant", 
             content = "Hello! I'm your R copilot. How can I help you with R programming today?")
      ))
    })
    
    # Render chat messages
    output$chat_messages <- renderUI({
      messages <- chat_history()
      lapply(seq_along(messages), function(i) {
        msg <- messages[[i]]
        style <- if(msg$role == "user") "background-color: #e3f2fd; margin: 5px; padding: 10px; border-radius: 10px;" 
                else "background-color: #f5f5f5; margin: 5px; padding: 10px; border-radius: 10px;"
        div(style = style,
            strong(if(msg$role == "user") "You" else "Copilot"), ": ",
            tags$pre(style = "white-space: pre-wrap; margin: 0;", msg$content)
        )
      })
    })
    
    # Send message
    observeEvent(input$send_btn, {
      req(input$user_input)
      if (trimws(input$user_input) == "") return()
      
      # Add user message
      current_chat <- chat_history()
      current_chat[[length(current_chat) + 1]] <- list(
        role = "user", 
        content = input$user_input
      )
      chat_history(current_chat)
      
      # Get AI response
      tryCatch({
        # Validate model name
        model_name <- input$model
        if (is.null(model_name) || model_name == "") {
          model_name <- get_default_model()
        }
        
        # Debug: Print what we're sending
        cat("Debug: Using model:", model_name, "\n")
        cat("Debug: Messages count:", length(current_chat), "\n")
        
        # Create chat request with minimal parameters
        response <- ollamar::chat(
          messages = current_chat,
          model = model_name,
          stream = FALSE
        )
        
        # Add AI response
        current_chat <- chat_history()
        current_chat[[length(current_chat) + 1]] <- list(
          role = "assistant",
          content = response$message$content
        )
        chat_history(current_chat)
        
      }, error = function(e) {
        # Add error message with more details
        current_chat <- chat_history()
        error_msg <- paste("Error:", e$message, "\n\n")
        error_msg <- paste(error_msg, "Debug info:\n")
        error_msg <- paste(error_msg, "- Model:", input$model, "\n")
        error_msg <- paste(error_msg, "- Messages:", length(current_chat), "\n")
        error_msg <- paste(error_msg, "\nTroubleshooting:\n")
        error_msg <- paste(error_msg, "1. Make sure Ollama is running: ollama serve\n")
        error_msg <- paste(error_msg, "2. Check available models: ollama list\n")
        error_msg <- paste(error_msg, "3. Install a model: ollama pull llama3.2:1b\n")
        error_msg <- paste(error_msg, "4. Try running check_ollama() to verify connection")
        
        current_chat[[length(current_chat) + 1]] <- list(
          role = "assistant",
          content = error_msg
        )
        chat_history(current_chat)
      })
      
      # Clear input
      updateTextAreaInput(session, "user_input", value = "")
    })
    
    # Test connection
    observeEvent(input$test_connection, {
      tryCatch({
        models <- ollamar::list_models()
        available_models <- if (!is.null(models$models) && nrow(models$models) > 0) {
          models$models$name
        } else {
          "No models found"
        }
        
        output$status_output <- renderText({
          paste("✅ Connected to Ollama\nAvailable models:\n", 
                paste(available_models, collapse = "\n"))
        })
        
        # Update model choices if we got real models
        if (length(available_models) > 0 && available_models[1] != "No models found") {
          updateSelectInput(session, "model", choices = available_models, selected = available_models[1])
        }
      }, error = function(e) {
        output$status_output <- renderText({
          paste("❌ Connection failed:", e$message, "\n\nMake sure Ollama is running.")
        })
      })
    })
    
    # Status on load
    output$status_output <- renderText({
      "Click 'Test Connection' to check Ollama status"
    })
  }
  
  # Run the app
  shinyApp(ui = ui, server = server)
}

#' @title Quick Chat
#' @description Simple chat interface for quick questions
#' @export
# Helper functions
get_available_models <- function() {
  tryCatch({
    if (requireNamespace("ollamar", quietly = TRUE)) {
      models <- ollamar::list_models()
      if (!is.null(models$models) && nrow(models$models) > 0) {
        return(models$models$name)
      }
    }
    # Fallback models if ollamar not available or no models found
    return(c("llama3.2:1b", "phi4:latest", "mistral:latest", "phi3:mini"))
  }, error = function(e) {
    # Return fallback models on error
    return(c("llama3.2:1b", "phi4:latest", "mistral:latest", "phi3:mini"))
  })
}

get_default_model <- function() {
  models <- get_available_models()
  # Try to find a good default model
  preferred_models <- c("llama3.2:1b", "phi4:latest", "mistral:latest", "phi3:mini")
  for (model in preferred_models) {
    if (model %in% models) {
      return(model)
    }
  }
  # Return first available model or fallback
  if (length(models) > 0) {
    return(models[1])
  }
  return("llama3.2:1b")
}

#' @title Check Ollama Status
#' @description Check if Ollama is running and get available models
#' @export
check_ollama <- function() {
  if (!requireNamespace("ollamar", quietly = TRUE)) {
    message("ollamar package not available. Installing...")
    if (!requireNamespace("remotes", quietly = TRUE)) {
      install.packages("remotes")
    }
    remotes::install_github("hauselin/ollama-r")
    library(ollamar)
  }
  
  tryCatch({
    models <- ollamar::list_models()
    if (!is.null(models$models) && nrow(models$models) > 0) {
      cat("✅ Ollama is running\n")
      cat("Available models:\n")
      for (model in models$models$name) {
        cat("  -", model, "\n")
      }
      
      # Test a simple chat request
      cat("\nTesting chat request...\n")
      test_response <- ollamar::chat(
        messages = list(list(role = "user", content = "Hello")),
        model = models$models$name[1]
      )
      cat("✅ Chat test successful\n")
      
    } else {
      cat("⚠️  Ollama is running but no models found\n")
      cat("Install models with: ollama pull llama3.2:1b\n")
    }
  }, error = function(e) {
    cat("❌ Ollama connection failed:", e$message, "\n")
    cat("Make sure Ollama is running: ollama serve\n")
  })
}

quick_chat <- function() {
  if (!requireNamespace("ollamar", quietly = TRUE)) {
    message("Installing ollamar package...")
    if (!requireNamespace("remotes", quietly = TRUE)) {
      message("Installing remotes package first...")
      install.packages("remotes")
    }
    remotes::install_github("hauselin/ollama-r")
  }
  
  library(ollamar)
  
  # Get available models
  models <- get_available_models()
  default_model <- get_default_model()
  
  cat("R Copilot Quick Chat (type 'quit' to exit)\n")
  cat("==========================================\n\n")
  cat("Available models:", paste(models, collapse = ", "), "\n")
  cat("Using model:", default_model, "\n\n")
  
  while(TRUE) {
    user_input <- readline("You: ")
    if (tolower(user_input) == "quit") break
    
    tryCatch({
      response <- ollamar::chat(
        messages = list(list(role = "user", content = user_input)),
        model = default_model
      )
      cat("Copilot:", response$message$content, "\n\n")
    }, error = function(e) {
      cat("Error:", e$message, "\n")
      cat("Troubleshooting:\n")
      cat("1. Make sure Ollama is running: ollama serve\n")
      cat("2. Check available models: ollama list\n")
      cat("3. Install a model: ollama pull llama3.2:1b\n\n")
    })
  }
} 